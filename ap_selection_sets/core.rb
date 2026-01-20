require 'sketchup.rb'
require 'json'

module AP
  module Plugins
    module SelectionSets
      PREF_KEY = 'AP_SelectionSets'.freeze
      DIALOG_TITLE = 'AP Selection Sets'.freeze

      module_function

      def show_dialog
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          return
        end

        @dialog = UI::HtmlDialog.new(
          dialog_title: DIALOG_TITLE,
          preferences_key: PREF_KEY,
          scrollable: true,
          resizable: true,
          width: 760,
          height: 580,
          min_width: 680,
          min_height: 500,
          style: UI::HtmlDialog::STYLE_DIALOG
        )

        html_path = File.join(File.dirname(__FILE__), 'ui', 'selection_sets.html')
        @dialog.set_file(html_path)
        wire_callbacks(@dialog)
        @dialog.show
      end

      def wire_callbacks(dialog)
        dialog.add_action_callback('ready') { |_d| send_state }
        dialog.add_action_callback('save_set') { |_d, name| save_set(name) }
        dialog.add_action_callback('apply_set') { |_d, name| apply_set(name) }
        dialog.add_action_callback('delete_set') { |_d, name| delete_set(name) }
        dialog.add_action_callback('filter_tag') { |_d, name| filter_by_tag(name) }
        dialog.add_action_callback('filter_material') { |_d, name| filter_by_material(name) }
        dialog.add_action_callback('filter_name') { |_d, text| filter_by_name(text) }
      end

      def send_state
        payload = {
          sets: load_sets,
          tags: tags_list,
          materials: materials_list
        }
        execute_script("window.SelectionSets.setState(#{payload.to_json})")
      end

      def save_set(name)
        clean = name.to_s.strip
        return if clean.empty?

        model = Sketchup.active_model
        ids = model.selection.map { |e| e.respond_to?(:persistent_id) ? e.persistent_id : nil }.compact
        if ids.empty?
          execute_script("window.SelectionSets.showError('Selection is empty.')")
          return
        end

        sets = load_sets
        sets[clean] = ids
        save_sets(sets)
        send_state
      end

      def apply_set(name)
        sets = load_sets
        ids = sets[name]
        if !ids || ids.empty?
          execute_script("window.SelectionSets.showError('Selection set not found.')")
          return
        end

        model = Sketchup.active_model
        unless model.respond_to?(:find_entity_by_persistent_id)
          execute_script("window.SelectionSets.showError('Persistent IDs are not supported in this SketchUp version.')")
          return
        end

        selection = model.selection
        selection.clear

        ids.each do |pid|
          entity = model.find_entity_by_persistent_id(pid)
          selection.add(entity) if entity
        end
      end

      def delete_set(name)
        sets = load_sets
        sets.delete(name)
        save_sets(sets)
        send_state
      end

      def filter_by_tag(tag_name)
        name = tag_name.to_s.strip
        return if name.empty?

        model = Sketchup.active_model
        selection = model.selection
        selection.clear

        traverse_entities(model.entities) do |entity|
          next unless entity.respond_to?(:layer)
          selection.add(entity) if entity.layer && entity.layer.name == name
        end
      end

      def filter_by_material(material_name)
        name = material_name.to_s.strip
        return if name.empty?

        model = Sketchup.active_model
        selection = model.selection
        selection.clear

        traverse_entities(model.entities) do |entity|
          if entity.is_a?(Sketchup::Face)
            selection.add(entity) if material_matches?(entity.material, name) || material_matches?(entity.back_material, name)
          elsif entity.respond_to?(:material)
            selection.add(entity) if material_matches?(entity.material, name)
          end
        end
      end

      def filter_by_name(text)
        query = text.to_s.strip
        return if query.empty?

        model = Sketchup.active_model
        selection = model.selection
        selection.clear

        traverse_entities(model.entities) do |entity|
          next unless entity.respond_to?(:name)
          selection.add(entity) if entity.name.to_s.downcase.include?(query.downcase)
        end
      end

      def material_matches?(material, name)
        material && material.display_name == name
      end

      def traverse_entities(entities, &block)
        entities.each do |entity|
          yield entity
          if entity.is_a?(Sketchup::Group)
            traverse_entities(entity.entities, &block)
          elsif entity.is_a?(Sketchup::ComponentInstance)
            traverse_entities(entity.definition.entities, &block)
          end
        end
      end

      def tags_list
        Sketchup.active_model.layers.map(&:name).sort
      end

      def materials_list
        Sketchup.active_model.materials.map(&:display_name).sort
      end

      def load_sets
        raw = Sketchup.active_model.get_attribute(PREF_KEY, 'sets', '{}')
        parsed = JSON.parse(raw)
        parsed.is_a?(Hash) ? parsed : {}
      rescue StandardError
        {}
      end

      def save_sets(sets)
        Sketchup.active_model.set_attribute(PREF_KEY, 'sets', JSON.dump(sets))
      end

      def execute_script(script)
        @dialog&.execute_script(script)
      end

      unless file_loaded?(__FILE__)
        UI.menu('Plugins').add_item('Selection Sets') { show_dialog }
        file_loaded(__FILE__)
      end
    end
  end
end
