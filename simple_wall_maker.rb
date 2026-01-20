require 'sketchup.rb'

module SimpleWallMaker
  # Constants
  Z_AXIS = Geom::Vector3d.new(0, 0, 1)
  WALL_THICKNESS = 2.5
  MOJO_BASE_HEIGHT = 2.0
  MOJO_BASE_HALF_WIDTH = 1.5 * 12.0
  
  # Find connected chains of edges
  def self.find_chains(edges)
    chains = []
    remaining_edges = edges.dup
    
    # Process until all edges are assigned to chains
    until remaining_edges.empty?
      current_chain = []
      current_edge = remaining_edges.first
      current_chain << current_edge
      remaining_edges.delete(current_edge)
      
      # Track the current endpoint we're working from
      current_endpoint = current_edge.end
      
      # Keep extending the chain as long as we find connecting edges
      loop do
        # Find an edge that connects to our current endpoint
        next_edge = remaining_edges.find { |e| e.start == current_endpoint || e.end == current_endpoint }
        break unless next_edge
        
        # Add the edge to our chain and remove from remaining edges
        current_chain << next_edge
        remaining_edges.delete(next_edge)
        
        # Update the current endpoint to the other end of the found edge
        current_endpoint = (next_edge.start == current_endpoint) ? next_edge.end : next_edge.start
      end
      
      chains << current_chain
    end
    
    chains
  end
  
  # Create walls from selected edges
  def self.create_walls(height)
    model = Sketchup.active_model
    selection = model.selection
    edges = selection.grep(Sketchup::Edge)
    
    if edges.empty?
      UI.messagebox("Please select edges first.")
      return
    end
    
    model.start_operation("Create Walls", true)
    group = model.active_entities.add_group
    
    # Find chains of connected edges
    chains = find_chains(edges)
    puts "Found #{chains.length} chains of edges"
    
    # Process each chain of edges
    chains.each_with_index do |chain, chain_index|
      puts "Processing chain #{chain_index + 1} with #{chain.length} edges"
      
      # Create walls for each edge in the chain
      chain.each do |edge|
        # Get edge start and end points
        start_pt = edge.start.position
        end_pt = edge.end.position
        
        # Get direction vector of edge
        vec = start_pt.vector_to(end_pt)
        
        # Skip zero-length edges
        next if vec.length < 0.001
        
        # Project to XY plane for wall creation
        vec_xy = Geom::Vector3d.new(vec.x, vec.y, 0)
        if vec_xy.length < 0.001
          puts "Skipping vertical edge"
          next
        end
        vec_xy.normalize!
        
        # Calculate perpendicular vectors (left and right)
        # Left is counter-clockwise from path direction
        left_vec = Z_AXIS.cross(vec_xy)
        right_vec = vec_xy.cross(Z_AXIS)
        
        # Set length to half wall thickness
        left_vec.length = right_vec.length = WALL_THICKNESS / 2.0
        
        # Calculate the four corners of the wall
        p1 = start_pt.offset(left_vec)
        p2 = start_pt.offset(right_vec)
        p3 = end_pt.offset(right_vec)
        p4 = end_pt.offset(left_vec)
        
        # Create the face with correct winding for normal pointing up
        begin
          face = group.entities.add_face([p1, p2, p3, p4])
          
          # Ensure face normal is pointing upward
          if face && face.valid?
            if face.normal.dot(Z_AXIS) < 0
              face.reverse!
            end
            
            # Extrude upward (positive Z)
            face.pushpull(height) 
            puts "Created wall for edge #{edge}"
          end
        rescue => e
          puts "Error creating wall: #{e.message}"
        end
      end
    end
    
    model.commit_operation
  end

  # Create mojo barricades from selected edges
  def self.create_mojo_barricades(total_height, base_height, base_half_width)
    model = Sketchup.active_model
    selection = model.selection
    edges = selection.grep(Sketchup::Edge)

    if edges.empty?
      UI.messagebox("Please select edges first.")
      return
    end

    if total_height <= base_height
      UI.messagebox("Mojo height must be greater than base height.")
      return
    end

    model.start_operation("Create Mojos", true)
    group = model.active_entities.add_group

    # Find chains of connected edges
    chains = find_chains(edges)
    puts "Found #{chains.length} chains of edges for mojos"

    chains.each_with_index do |chain, chain_index|
      puts "Processing mojo chain #{chain_index + 1} with #{chain.length} edges"

      chain.each do |edge|
        start_pt = edge.start.position
        end_pt = edge.end.position

        vec = start_pt.vector_to(end_pt)
        next if vec.length < 0.001

        vec_xy = Geom::Vector3d.new(vec.x, vec.y, 0)
        if vec_xy.length < 0.001
          puts "Skipping vertical edge"
          next
        end
        vec_xy.normalize!

        left_vec = Z_AXIS.cross(vec_xy)
        right_vec = vec_xy.cross(Z_AXIS)

        # Base (wide, short)
        left_vec_base = left_vec.clone
        right_vec_base = right_vec.clone
        left_vec_base.length = right_vec_base.length = base_half_width

        p1 = start_pt.offset(left_vec_base)
        p2 = start_pt.offset(right_vec_base)
        p3 = end_pt.offset(right_vec_base)
        p4 = end_pt.offset(left_vec_base)

        begin
          base_face = group.entities.add_face([p1, p2, p3, p4])
          if base_face && base_face.valid?
            base_face.reverse! if base_face.normal.dot(Z_AXIS) < 0
            base_face.pushpull(base_height)
          end
        rescue => e
          puts "Error creating mojo base: #{e.message}"
        end

        # Stem (narrow, tall) starting at top of base
        left_vec_stem = left_vec.clone
        right_vec_stem = right_vec.clone
        left_vec_stem.length = right_vec_stem.length = WALL_THICKNESS / 2.0

        p1s = start_pt.offset(left_vec_stem).offset(Z_AXIS, base_height)
        p2s = start_pt.offset(right_vec_stem).offset(Z_AXIS, base_height)
        p3s = end_pt.offset(right_vec_stem).offset(Z_AXIS, base_height)
        p4s = end_pt.offset(left_vec_stem).offset(Z_AXIS, base_height)

        begin
          stem_face = group.entities.add_face([p1s, p2s, p3s, p4s])
          if stem_face && stem_face.valid?
            stem_face.reverse! if stem_face.normal.dot(Z_AXIS) < 0
            stem_face.pushpull(total_height - base_height)
          end
        rescue => e
          puts "Error creating mojo stem: #{e.message}"
        end
      end
    end

    model.commit_operation
  end
  
  # Menu items
  unless file_loaded?(__FILE__)
    menu = UI.menu("Extensions")
    submenu = menu.add_submenu("Wall banane waala majdoor")
    
    submenu.add_item("bolo saab! 10 foot ki banaayein?") {
      create_walls(10 * 12.0)
    }
    
    submenu.add_item("ki 3.5 feet unchi wall chalegi?") {
      create_walls(3.5 * 12.0)
    }

    submenu.add_item("mojo barricade (3.5 feet) banaayein?") {
      create_mojo_barricades(3.5 * 12.0, MOJO_BASE_HEIGHT, MOJO_BASE_HALF_WIDTH)
    }

    UI.add_context_menu_handler do |context_menu|
      selection = Sketchup.active_model.selection
      edges = selection.grep(Sketchup::Edge)
      next if edges.empty?

      context_submenu = context_menu.add_submenu("Wall banane waala majdoor")
      context_submenu.add_item("bolo saab! 10 foot ki banaayein?") {
        create_walls(10 * 12.0)
      }
      context_submenu.add_item("ki 3.5 feet unchi wall chalegi?") {
        create_walls(3.5 * 12.0)
      }
      context_submenu.add_item("mojo barricade (3.5 feet) banaayein?") {
        create_mojo_barricades(3.5 * 12.0, MOJO_BASE_HEIGHT, MOJO_BASE_HALF_WIDTH)
      }
    end
    
    file_loaded(__FILE__)
  end
end # module
