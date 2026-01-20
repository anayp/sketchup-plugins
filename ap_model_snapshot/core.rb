require 'sketchup.rb'
require 'json'

module AP
  module Plugins
    module ModelSnapshot
      PREF_KEY = 'AP_ModelSnapshot'.freeze
      DIALOG_TITLE = 'AP Model Snapshot'.freeze

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
          width: 720,
          height: 560,
          min_width: 640,
          min_height: 460,
          style: UI::HtmlDialog::STYLE_DIALOG
        )

        html_path = File.join(File.dirname(__FILE__), 'ui', 'snapshot.html')
        @dialog.set_file(html_path)
        wire_callbacks(@dialog)
        @dialog.show
      end

      def wire_callbacks(dialog)
        dialog.add_action_callback('ready') { |_d| send_state }
        dialog.add_action_callback('capture') { |_d| capture_snapshot }
        dialog.add_action_callback('compare') { |_d| compare_snapshot }
        dialog.add_action_callback('clear') { |_d| clear_snapshot }
      end

      def send_state
        snapshot = load_snapshot
        payload = {
          snapshot: snapshot
        }
        execute_script("window.ModelSnapshot.setState(#{payload.to_json})")
      end

      def capture_snapshot
        model = Sketchup.active_model
        snapshot = build_snapshot(model)
        save_snapshot(snapshot)
        execute_script("window.ModelSnapshot.showSnapshot(#{snapshot.to_json})")
      rescue StandardError => e
        execute_script("window.ModelSnapshot.showError(#{e.message.to_json})")
      end

      def compare_snapshot
        model = Sketchup.active_model
        current = build_snapshot(model)
        previous = load_snapshot
        unless previous
          execute_script("window.ModelSnapshot.showError('No snapshot saved yet.')")
          return
        end

        diff = build_diff(previous, current)
        payload = { previous: previous, current: current, diff: diff }
        execute_script("window.ModelSnapshot.showDiff(#{payload.to_json})")
      rescue StandardError => e
        execute_script("window.ModelSnapshot.showError(#{e.message.to_json})")
      end

      def clear_snapshot
        Sketchup.write_default(PREF_KEY, 'snapshot', '')
        execute_script("window.ModelSnapshot.clearSnapshot()")
      end

      def build_snapshot(model)
        stats = collect_stats(model)
        {
          name: model.title.to_s.empty? ? 'Untitled' : model.title,
          path: model.path.to_s,
          timestamp: Time.now.to_i,
          stats: stats
        }
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

      def build_diff(previous, current)
        diff = {}
        prev_stats = previous['stats'] || previous[:stats] || {}
        cur_stats = current['stats'] || current[:stats] || {}

        cur_stats.each do |key, value|
          prev_value = prev_stats[key] || prev_stats[key.to_s] || 0
          diff[key] = value.to_i - prev_value.to_i
        end

        diff
      end

      def save_snapshot(snapshot)
        Sketchup.write_default(PREF_KEY, 'snapshot', JSON.dump(snapshot))
      end

      def load_snapshot
        raw = Sketchup.read_default(PREF_KEY, 'snapshot', '')
        return nil if raw.to_s.strip.empty?

        JSON.parse(raw)
      rescue StandardError
        nil
      end

      def execute_script(script)
        @dialog&.execute_script(script)
      end

      unless file_loaded?(__FILE__)
        UI.menu('Plugins').add_item('Model Snapshot') { show_dialog }
        file_loaded(__FILE__)
      end
    end
  end
end
