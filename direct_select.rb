# DirectSelect plugin disabled on 2025-08-25
# No code will execute.
__END__

# DirectSelect plugin disabled on 2025-08-25
# Original implementation moved aside. No code executed.
return true


  class Tool
    def activate
      @ip = Sketchup::InputPoint.new
      @points = []
      @state = :select_first_corner
      update_status_text
    end

    def deactivate(view)
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      @points = []
      @points << [x, y]
      @state = :select_second_corner
      view.invalidate
    end

    def onLButtonUp(flags, x, y, view)
      return if @points.size < 2

      model = Sketchup.active_model
      selection = model.selection
      selection.clear

      # Gather all top-level and nested containers while avoiding cycles
      entities = []
      visited_defs = Set.new
      model.entities.each { |e| collect_entities(e, entities, visited_defs) }

      rect = selection_rect

      entities.each do |entity|
        next unless entity.respond_to?(:bounds)
        bounds = entity.bounds
        if bounds && bounds_intersect_rect_screen?(bounds, rect, view)
          selection.add(entity)
        end
      end

      @state = :select_first_corner
      view.invalidate
    end

    def onMouseMove(flags, x, y, view)
      if @state == :select_second_corner
        @points[1] = [x, y]
        view.invalidate
      end
    end

    def draw(view)
      draw_selection_rectangle(view) if @points.size == 2
    end

    private

    # Recursively collects groups and component instances while guarding against
    # cyclic references via a visited definition set.
    def collect_entities(entity, collection, visited_defs)
      case entity
      when Sketchup::Group, Sketchup::ComponentInstance
        collection << entity   # We only need to select the container, not its raw geometry.
        defn = entity.definition
        return if visited_defs.include?(defn)
        visited_defs << defn
        defn.entities.each { |child| collect_entities(child, collection, visited_defs) }
      else
        # Keep non-container geometry that is directly in the model (edges/faces).
        # Nested raw geometry will be selected indirectly via its parent container.
        collection << entity if entity.is_a?(Sketchup::Edge) || entity.is_a?(Sketchup::Face)
      end
    end

    # Returns the selection rectangle in screen coordinates as a hash
    # { xmin:, xmax:, ymin:, ymax: }
    def selection_rect
      x1, y1 = @points[0]
      x2, y2 = @points[1]
      {
        xmin: [x1, x2].min,
        xmax: [x1, x2].max,
        ymin: [y1, y2].min,
        ymax: [y1, y2].max
      }
    end

    # Returns true if the entity bounds intersects the screen-space selection rectangle
    def bounds_intersect_rect_screen?(bounds, rect, view)
      # Project all 8 corners to screen space and build a 2D bounding box
      screen_pts = 8.times.map { |i| view.screen_coords(bounds.corner(i)) }
      sxmin = screen_pts.map(&:x).min
      sxmax = screen_pts.map(&:x).max
      symin = screen_pts.map(&:y).min
      symax = screen_pts.map(&:y).max

      # Axis-aligned rectangle intersection in screen space
      !(sxmax < rect[:xmin] || sxmin > rect[:xmax] ||
        symax < rect[:ymin] || symin > rect[:ymax])
    end


    def draw_selection_rectangle(view)
      x1, y1 = @points[0]
      x2, y2 = @points[1]
      
      # Draw border rectangle (outline only) to avoid using deprecated GL_QUADS
      view.drawing_color = [0, 0, 255]
      view.line_width = 2
      rect_pts = [
        Geom::Point3d.new(x1, y1, 0),
        Geom::Point3d.new(x2, y1, 0),
        Geom::Point3d.new(x2, y2, 0),
        Geom::Point3d.new(x1, y2, 0)
      ]
      view.draw2d(GL_LINE_LOOP, rect_pts)
    end

    def update_status_text
      Sketchup::set_status_text("Click and drag to select through all groups", SB_PROMPT)
    end
  end

  # Add menu item
  unless file_loaded?(__FILE__)
    UI.menu("Draw").add_item("Direct Select") do
      Sketchup.active_model.select_tool(DirectSelect::Tool.new)
    end
    file_loaded(__FILE__)
  end
end
