# Remove all tags from objects and delete all tags from the model
module MyPlugins
  module TagCleaner
    
    def self.clean_all_tags
      puts "Starting tag cleanup process..."
      model = Sketchup.active_model
      
      if model.nil?
        UI.messagebox("No active model found!")
        return
      end
      
      model.start_operation('Remove All Tags', true)
      begin
        # Get all entities in the model recursively
        all_entities = get_all_entities(model)
        tag_count = 0
        entity_count = 0
        
        # First, remove tags from all entities
        puts "Removing tags from entities..."
        all_entities.each do |entity|
          if entity.respond_to?(:layer=) # In SketchUp, tags are still referred to as 'layer' in the API
            entity.layer = model.layers[0] # Set to default layer
            entity_count += 1
          end
        end
        
        # Then, delete all tags except layer0 (default layer)
        puts "Deleting all tags..."
        layers_to_delete = model.layers.to_a
        layers_to_delete.shift # Remove layer0 from deletion list
        
        layers_to_delete.each do |layer|
          begin
            model.layers.remove(layer)
            tag_count += 1
          rescue => e
            puts "Could not delete tag: #{layer.name}. Error: #{e.message}"
          end
        end
        
        model.commit_operation
        
        message = "Cleanup complete!\n"
        message += "Removed tags from #{entity_count} entities\n"
        message += "Deleted #{tag_count} tags"
        
        UI.messagebox(message)
        puts message
        
      rescue => e
        puts "Error during tag cleanup: #{e.message}"
        puts e.backtrace
        model.abort_operation
        UI.messagebox("Error during tag cleanup: #{e.message}")
      end
    end
    
    private
    
    def self.get_all_entities(model)
      entities = []
      
      # Helper method to recursively collect all entities
      def self.collect_entities(container, collection)
        container.entities.each do |entity|
          collection << entity
          if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
            # For groups and components, recursively collect their entities
            definition = entity.is_a?(Sketchup::Group) ? entity.definition : entity.definition
            collect_entities(definition, collection)
          end
        end
      end
      
      # Start collection from model root
      collect_entities(model, entities)
      entities
    end
    
    # Add menu item
    unless file_loaded?(__FILE__)
      menu = UI.menu("Extensions")
      menu.add_item("Remove All Tags") {
        self.clean_all_tags
      }
      file_loaded(__FILE__)
    end
    
  end # module TagCleaner
end # module MyPlugins
