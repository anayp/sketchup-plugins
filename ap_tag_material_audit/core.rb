require 'sketchup.rb'
require 'json'

module AP
  module Plugins
    module TagMaterialAudit
      PREF_KEY = 'AP_TagMaterialAudit'.freeze
      DIALOG_TITLE = 'AP Tag + Material Audit'.freeze

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
          height: 600,
          min_width: 680,
          min_height: 520,
          style: UI::HtmlDialog::STYLE_DIALOG
        )

        html_path = File.join(File.dirname(__FILE__), 'ui', 'audit.html')
        @dialog.set_file(html_path)
        wire_callbacks(@dialog)
        @dialog.show
      end

      def wire_callbacks(dialog)
        dialog.add_action_callback('ready') { |_d| send_state }
        dialog.add_action_callback('merge_tags') { |_d, source, target| merge_tags(source, target) }
        dialog.add_action_callback('merge_materials') { |_d, source, target| merge_materials(source, target) }
        dialog.add_action_callback('merge_duplicate_tags') { |_d| merge_duplicate_tags }
        dialog.add_action_callback('merge_duplicate_materials') { |_d| merge_duplicate_materials }
      end

      def send_state
        payload = {
          tags: tag_names,
          materials: material_names,
          tag_duplicates: duplicate_groups(tag_names),
          material_duplicates: duplicate_groups(material_names)
        }
        execute_script("window.TagMaterialAudit.setState(#{payload.to_json})")
      end

      def tag_names
        Sketchup.active_model.layers.map(&:name).sort
      end

      def material_names
        Sketchup.active_model.materials.map(&:display_name).sort
      end

      def duplicate_groups(names)
        grouped = names.group_by { |name| name.downcase }
        grouped.values.select { |group| group.size > 1 }
      end

      def merge_tags(source, target)
        return if source.to_s.strip.empty? || target.to_s.strip.empty?
        return if source == target

        model = Sketchup.active_model
        source_layer = model.layers[source]
        target_layer = model.layers[target]
        if !source_layer || !target_layer
          execute_script("window.TagMaterialAudit.showError('Tag not found.')")
          return
        end

        if source_layer == model.layers[0]
          execute_script("window.TagMaterialAudit.showError('Cannot merge the default tag.')")
          return
        end

        model.start_operation('Merge Tags', true)
        traverse_entities(model.entities) do |entity|
          next unless entity.respond_to?(:layer)
          entity.layer = target_layer if entity.layer == source_layer
        end

        begin
          model.layers.remove(source_layer)
        rescue StandardError
          # ignore if locked
        end

        model.commit_operation
        send_state
      rescue StandardError => e
        model.abort_operation if model
        execute_script("window.TagMaterialAudit.showError(#{e.message.to_json})")
      end

      def merge_materials(source, target)
        return if source.to_s.strip.empty? || target.to_s.strip.empty?
        return if source == target

        model = Sketchup.active_model
        source_mat = model.materials[source]
        target_mat = model.materials[target]
        if !source_mat || !target_mat
          execute_script("window.TagMaterialAudit.showError('Material not found.')")
          return
        end

        model.start_operation('Merge Materials', true)
        traverse_entities(model.entities) do |entity|
          if entity.is_a?(Sketchup::Face)
            entity.material = target_mat if entity.material == source_mat
            entity.back_material = target_mat if entity.back_material == source_mat
          elsif entity.respond_to?(:material)
            entity.material = target_mat if entity.material == source_mat
          end
        end

        begin
          model.materials.remove(source_mat)
        rescue StandardError
          # ignore
        end

        model.commit_operation
        send_state
      rescue StandardError => e
        model.abort_operation if model
        execute_script("window.TagMaterialAudit.showError(#{e.message.to_json})")
      end

      def merge_duplicate_tags
        duplicates = duplicate_groups(tag_names)
        duplicates.each do |group|
          target = group.first
          group.drop(1).each { |source| merge_tags(source, target) }
        end
        send_state
      end

      def merge_duplicate_materials
        duplicates = duplicate_groups(material_names)
        duplicates.each do |group|
          target = group.first
          group.drop(1).each { |source| merge_materials(source, target) }
        end
        send_state
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

      def execute_script(script)
        @dialog&.execute_script(script)
      end

      unless file_loaded?(__FILE__)
        UI.menu('Plugins').add_item('Tag + Material Audit') { show_dialog }
        file_loaded(__FILE__)
      end
    end
  end
end
