module PointFiveInchPipesOptimized
  # Enhanced logger with timestamp and log levels
  def self.log(msg, level = :info)
    timestamp = Time.now.strftime("%H:%M:%S.%L")
    puts "[#{timestamp}] [0.5inchPipes] [#{level.upcase}] #{msg}"
  end
  
  def self.log_error(msg, exception = nil)
    log("ERROR: #{msg}", :error)
    if exception
      log("Exception: #{exception.message}", :error)
      log("Backtrace:\n#{exception.backtrace.join("\n")}", :error)
    end
  end

  # This version is optimized for large numbers of edges (10,000+)
  # It uses instance components and batch processing for better performance
  def self.create_optimized_pipes
    begin
      model = Sketchup.active_model
      selection = model.selection
      
      log("Starting optimized pipe creation for large datasets")
      log("Model: #{model.title}")
      log("Selection count: #{selection.count} items")
      
      edges = selection.grep(Sketchup::Edge)
      total_edges = edges.size
      
      log("Found #{total_edges} edges in selection")
      
      if edges.empty?
        log("No edges found in selection", :warn)
        UI.messagebox("Please select some edges first.")
        return
      end

      # For very large selections, use smaller batch sizes
    suggested_batch_size = if total_edges > 100_000
                             log("Very large selection detected (#{total_edges} edges)", :warn)
                             UI.messagebox("Warning: Processing #{total_edges} edges.\n\nThis is a large number of edges and may take a while.\n\nProcessing in smaller batches is recommended.")
                             100
                           elsif total_edges > 10_000
                             log("Large selection detected (#{total_edges} edges)", :info)
                             250
                           else
                             log("Processing #{total_edges} edges", :info)
                             500
                           end
                           
    log("Using batch size: #{suggested_batch_size}")

      # Prompt user for optimization settings
      prompts = ["Cylinder Segments (8-24, lower is faster):", 
                "Batch Size (edges per operation, 100-5000):"]
      defaults = ["12", suggested_batch_size.to_s]
      
      log("Showing input dialog to user")
      input = UI.inputbox(prompts, defaults, "Optimized Pipe Settings")
      
      unless input
        log("User cancelled the operation", :info)
        return 
      end

      segments = input[0].to_i.clamp(8, 24)
      batch_size = input[1].to_i.clamp(100, 5000)
      
      log("User settings - Segments: #{segments}, Batch size: #{batch_size}")

      # Show a warning for very large operations
      if total_edges > 10_000
        log("Showing confirmation dialog for large operation")
        result = UI.messagebox("Warning: Processing #{total_edges} edges.\n\nThis may take a while. Continue?", 4) # 4 = MB_YESNO
        if result != 6 # 6 = IDYES in SketchUp's messagebox
          log("User cancelled the operation", :info)
          return 
        end
        log("User confirmed to continue with large operation")
      end

      log("Starting model operation")
      model.start_operation("Create Optimized Pipes", true)
      
      begin
        # Show initial status
        UI.messagebox("Starting to process #{total_edges} edges. This may take a while...")
        log("Creating cylinder component definition")
        
        # Create a component definition for the cylinder
        begin
          cyl_def = create_optimized_cylinder_component(model, segments)
          unless cyl_def
            raise "Failed to create cylinder component definition"
          end
          log("Created cylinder component: #{cyl_def.name}")
        rescue => e
          log_error("Failed to create cylinder component", e)
          UI.messagebox("Failed to create cylinder component: #{e.message}")
          model.abort_operation
          return
        end
      
      # Process edges in batches
      successful_edges = 0
      failed_edges = 0
      start_time = Time.now
      last_log_time = Time.now
      
      log("Starting to process edges in batches of #{batch_size}")
      
      edges.each_slice(batch_size).with_index do |batch, batch_index|
        begin
          # Update status
          edges_processed = batch_index * batch_size
          progress = (edges_processed.to_f / total_edges * 100).round(1)
          
          # Log progress every 5 seconds or 1000 edges
          current_time = Time.now
          if (current_time - last_log_time) >= 5 || (edges_processed % 1000 == 0 && edges_processed > 0)
            progress = (edges_processed.to_f / total_edges * 100).round(1)
            log("Processing: #{edges_processed}/#{total_edges} edges (#{progress}%)")
            last_log_time = current_time
          end
        # Update progress counter
        edges_processed = batch_index * batch_size
        
          # Create a group for this batch
          begin
            group = model.active_entities.add_group
            batch_entities = group.entities
            log("Created batch group ##{batch_index + 1} with #{batch.size} edges") 
          rescue => e
            log_error("Failed to create batch group", e)
            failed_edges += batch.size
            next
          end
          
          # Process each edge in the batch
          batch.each_with_index do |edge, edge_index|
            begin
              log("Processing edge #{edges_processed + edge_index + 1}/#{total_edges}", :debug) if (edges_processed + edge_index) % 1000 == 0
              
              # Check if the edge is still valid
              unless edge.valid?
                log("Edge is no longer valid, skipping", :warn)
                failed_edges += 1
                next
              end
              
              create_cylinder_instance(batch_entities, cyl_def, edge)
              successful_edges += 1
            rescue => e
              log_error("Error processing edge #{edges_processed + edge_index + 1}", e)
              failed_edges += 1
              next
            end
          end
        
          # Force garbage collection between batches
          GC.start
          
          # Log batch completion
          batch_end_time = Time.now
          batch_duration = (batch_end_time - start_time).round(2)
          edges_per_second = ((batch_index + 1) * batch_size) / [batch_duration, 0.1].max
          
          log("Batch #{batch_index + 1} completed - " +
              "#{successful_edges} successful, #{failed_edges} failed - " +
              "#{edges_per_second.round(2)} edges/sec", 
              :info)
              
          # Future: implement user cancellation if SketchUp provides appropriate API
        rescue => e
          log_error("Error processing batch #{batch_index + 1}", e)
          failed_edges += batch.size
        end
      end
      
      # Clear any pending operations
      
      # Calculate statistics
      end_time = Time.now
      duration = (end_time - start_time).round(2)
      edges_per_second = (successful_edges / [duration, 0.01].max).round(2)
      
      # Log completion
      completion_msg = "Processing completed in #{duration} seconds\n" +
                     "Total edges: #{total_edges}\n" +
                     "Success: #{successful_edges}\n" +
                     "Failed: #{failed_edges}\n" +
                     "Speed: #{edges_per_second} edges/second"
      
      log(completion_msg, :info)
      
      # Show completion message
      UI.messagebox("Processing completed!\n\n" +
                   "Total edges: #{total_edges}\n" +
                   "Success: #{successful_edges}\n" +
                   "Failed: #{failed_edges}\n" +
                   "Time: #{duration} seconds\n" +
                   "Speed: #{edges_per_second} edges/second")
      
      log("Operation completed successfully", :info)
      
    rescue => e
      log_error("Fatal error during pipe creation", e)
      begin
        model.abort_operation
        log("Operation aborted due to error", :error)
      rescue => inner_e
        log_error("Failed to abort operation", inner_e)
      end
      
      error_msg = "A serious error occurred: #{e.message}\n\n" +
                "Check the Ruby console for more details."
      UI.messagebox(error_msg)
      return
    end
    
    # End of the begin block that started on line 19
    end
    
    begin
      model.commit_operation
      log("Model operation committed successfully")
    rescue => e
      log_error("Failed to commit model operation", e)
      UI.messagebox("Warning: The operation completed but there was an error saving the model.\n\n" +
                  "Please save your work and restart SketchUp.")
    end
    UI.messagebox("Successfully created optimized pipes for #{edges.size} edges.")
    log("Optimized pipe creation completed successfully.")
  end
  
  private
  
  # Create an optimized cylinder component with specified number of segments
  def self.create_optimized_cylinder_component(model, segments)
    begin
      comp_name = "0.5inch_Pipe_Segment_Optimized_#{segments}"
      definitions = model.definitions
      
      log("Checking for existing component: #{comp_name}")
      
      # Return existing definition if it exists
      existing_def = definitions[comp_name]
      if existing_def
        log("Using existing component: #{comp_name}")
        return existing_def 
      end
      
      log("Creating new component: #{comp_name}")
      
      # Create new definition
      definition = definitions.add(comp_name)
      definition.description = "Optimized 0.5 inch pipe segment with #{segments} sides"
      
      # Add geometry to the definition
      ents = definition.entities
      radius = 0.5
      
      log("Creating circle with #{segments} segments")
      
      # Create a circle with specified number of segments
      circle = ents.add_circle(ORIGIN, Z_AXIS, radius, segments)
      unless circle && !circle.empty?
        raise "Failed to create circle with #{segments} segments"
      end
      
      log("Creating face from circle")
      face = ents.add_face(circle)
      unless face
        raise "Failed to create face from circle"
      end
      
      log("Extruding face to create cylinder")
      # Extrude to create a cylinder of unit height (will be scaled later)
      begin
        face.pushpull(1.0)
      rescue => e
        log_error("Failed to extrude face", e)
        raise
      end
      
      # Add attributes for reference
      definition.set_attribute("pipe_properties", "radius", radius)
      definition.set_attribute("pipe_properties", "segments", segments)
      
      log("Successfully created cylinder component")
      return definition
      
    rescue => e
      log_error("Error in create_optimized_cylinder_component", e)
      raise
    end
  end
  
  # Create a cylinder instance from an edge
  def self.create_cylinder_instance(entities, definition, edge)
    begin
      start_pt = edge.start.position
      end_pt = edge.end.position
      vector = start_pt.vector_to(end_pt)
      length = vector.length
      
      return if length.zero?
      
      # Create a transformation that moves the cylinder to the start point
      # and orients it along the edge
      t = Geom::Transformation.new
      
      # If the edge is not vertical, we need to rotate it
      unless vector.parallel?(Z_AXIS)
        # Create a rotation that aligns the Z axis with the edge direction
        rotation_axis = Z_AXIS * vector
        rotation_angle = Z_AXIS.angle_between(vector)
        
        # Only rotate if we have a valid rotation axis
        if rotation_axis.valid? && !rotation_axis.length.zero? && !rotation_angle.zero?
          rotation = Geom::Transformation.rotation(ORIGIN, rotation_axis, rotation_angle)
          t = t * rotation
        end
      end
      
      # Scale the cylinder to match the edge length
      scale = Geom::Transformation.scaling(1, 1, length)
      t = t * scale
      
      # Move to the start point
      translation = Geom::Transformation.translation(start_pt)
      t = translation * t
      
      # Add the instance
      entities.add_instance(definition, t)
    rescue => e
      log("Error creating cylinder instance: #{e.message}")
      log("Edge: #{edge.inspect}")
      log("Start: #{start_pt.inspect}, End: #{end_pt.inspect}")
      raise
    end
  end
  
  # Add menu item
  unless file_loaded?(__FILE__)
    UI.menu("Plugins").add_item("0.5inch Radius Pipes (Optimized for Large Datasets)") do
      self.create_optimized_pipes
    end
    file_loaded(__FILE__)
  end
end
