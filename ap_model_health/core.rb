require 'sketchup.rb'
require 'json'

module AP
  module Plugins
    module ModelHealth
      PREF_KEY = 'AP_ModelHealth'.freeze
      DIALOG_TITLE = 'AP Model Health'.freeze

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

        html_path = File.join(File.dirname(__FILE__), 'ui', 'health.html')
        @dialog.set_file(html_path)
        wire_callbacks(@dialog)
        @dialog.show
      end

      def wire_callbacks(dialog)
        dialog.add_action_callback('ready') { |_d| refresh }
        dialog.add_action_callback('refresh') { |_d| refresh }
      end

      def refresh
        stats = collect_stats(Sketchup.active_model)
        payload = { stats: stats, warnings: build_warnings(stats) }
        execute_script("window.ModelHealth.setState(#{payload.to_json})")
      rescue StandardError => e
        execute_script("window.ModelHealth.showError(#{e.message.to_json})")
      end

      def collect_stats(model)
        faces = 0
        edges = 0
        groups = 0
        components = 0
        stray_edges = 0
        back_faces = 0
        max_depth = 0

        traverse_entities(model.entities, 0) do |entity, depth|
          max_depth = depth if depth > max_depth
          case entity
          when Sketchup::Face
            faces += 1
            back_faces += 1 if entity.back_material && !entity.material
          when Sketchup::Edge
            edges += 1
            stray_edges += 1 if entity.faces.empty?
          when Sketchup::Group
            groups += 1
          when Sketchup::ComponentInstance
            components += 1
          end
        end

        defs = model.definitions.to_a
        unused_defs = defs.count { |d| d.instances.empty? && !d.image? }

        {
          faces: faces,
          edges: edges,
          groups: groups,
          component_instances: components,
          component_definitions: defs.size,
          unused_definitions: unused_defs,
          materials: model.materials.size,
          tags: model.layers.size,
          stray_edges: stray_edges,
          back_faces: back_faces,
          max_depth: max_depth
        }
      end

      def traverse_entities(entities, depth, &block)
        return if depth > 50

        entities.each do |entity|
          yield entity, depth
          if entity.is_a?(Sketchup::Group)
            traverse_entities(entity.entities, depth + 1, &block)
          elsif entity.is_a?(Sketchup::ComponentInstance)
            traverse_entities(entity.definition.entities, depth + 1, &block)
          end
        end
      end

      def build_warnings(stats)
        warnings = []
        warnings << "Stray edges: #{stats[:stray_edges]}" if stats[:stray_edges] > 0
        warnings << "Back-face materials: #{stats[:back_faces]}" if stats[:back_faces] > 0
        warnings << "Unused definitions: #{stats[:unused_definitions]}" if stats[:unused_definitions] > 0
        warnings << "Deep nesting depth: #{stats[:max_depth]}" if stats[:max_depth] >= 6
        warnings
      end

      def execute_script(script)
        @dialog&.execute_script(script)
      end

      unless file_loaded?(__FILE__)
        UI.menu('Plugins').add_item('Model Health Dashboard') { show_dialog }
        file_loaded(__FILE__)
      end
    end
  end
end
