require 'sketchup.rb'
require 'json'

module AP
  module Plugins
    module PublishPack
      PREF_KEY = 'AP_PublishPack'.freeze
      DIALOG_TITLE = 'AP Publish Pack'.freeze

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
          min_height: 480,
          style: UI::HtmlDialog::STYLE_DIALOG
        )

        html_path = File.join(File.dirname(__FILE__), 'ui', 'publish.html')
        @dialog.set_file(html_path)
        wire_callbacks(@dialog)
        @dialog.show
      end

      def wire_callbacks(dialog)
        dialog.add_action_callback('ready') { |_d| send_state }
        dialog.add_action_callback('pick_folder') { |_d| pick_folder }
        dialog.add_action_callback('publish') { |_d, options| publish(options) }
      end

      def send_state
        payload = { default_dir: default_dir }
        execute_script("window.PublishPack.setState(#{payload.to_json})")
      end

      def pick_folder
        folder = UI.select_directory(title: 'Choose output folder', directory: default_dir)
        return unless folder

        execute_script("window.PublishPack.setFolder(#{folder.to_json})")
      end

      def publish(options)
        model = Sketchup.active_model
        opts = options.is_a?(Hash) ? options : {}
        folder = opts['folder'].to_s
        unless folder && Dir.exist?(folder)
          execute_script("window.PublishPack.showError('Choose a valid output folder.')")
          return
        end

        base_name = model.title.to_s.strip
        base_name = File.basename(model.path, '.*') if base_name.empty?
        base_name = 'sketchup_model' if base_name.empty?

        stamp = Time.now.strftime('%Y%m%d_%H%M%S')
        out_dir = File.join(folder, "#{base_name}_#{stamp}")
        Dir.mkdir(out_dir) unless Dir.exist?(out_dir)

        results = []

        if opts['skp']
          target = File.join(out_dir, "#{base_name}.skp")
          if model.save_copy(target)
            results << "Saved SKP: #{File.basename(target)}"
          else
            results << "SKP save failed"
          end
        end

        if opts['png']
          target = File.join(out_dir, "#{base_name}.png")
          ok = model.active_view.write_image(filename: target, width: 1920, height: 1080, antialias: true)
          results << (ok ? "Saved preview PNG" : "PNG export failed")
        end

        export_if(opts['obj'], model, out_dir, base_name, 'obj', results)
        export_if(opts['stl'], model, out_dir, base_name, 'stl', results)
        export_if(opts['dae'], model, out_dir, base_name, 'dae', results)

        if opts['json']
          target = File.join(out_dir, "#{base_name}.json")
          File.write(target, JSON.pretty_generate(build_metadata(model)))
          results << "Saved metadata JSON"
        end

        execute_script("window.PublishPack.showResult(#{results.to_json}, #{out_dir.to_json})")
      rescue StandardError => e
        execute_script("window.PublishPack.showError(#{e.message.to_json})")
      end

      def export_if(enabled, model, out_dir, base_name, ext, results)
        return unless enabled

        target = File.join(out_dir, "#{base_name}.#{ext}")
        ok = model.export(target)
        results << (ok ? "Exported #{ext.upcase}" : "#{ext.upcase} export failed")
      end

      def build_metadata(model)
        {
          name: model.title.to_s,
          path: model.path.to_s,
          exported_at: Time.now.to_s,
          stats: collect_stats(model)
        }
      end

      def collect_stats(model)
        faces = 0
        edges = 0
        groups = 0
        components = 0

        traverse_entities(model.entities) do |entity|
          case entity
          when Sketchup::Face
            faces += 1
          when Sketchup::Edge
            edges += 1
          when Sketchup::Group
            groups += 1
          when Sketchup::ComponentInstance
            components += 1
          end
        end

        {
          faces: faces,
          edges: edges,
          groups: groups,
          component_instances: components,
          component_definitions: model.definitions.size,
          materials: model.materials.size,
          tags: model.layers.size
        }
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

      def default_dir
        home = ENV['USERPROFILE'] || Dir.home
        docs = File.join(home, 'Documents')
        Dir.exist?(docs) ? docs : home
      rescue StandardError
        Dir.home
      end

      def execute_script(script)
        @dialog&.execute_script(script)
      end

      unless file_loaded?(__FILE__)
        UI.menu('Plugins').add_item('Publish Pack') { show_dialog }
        file_loaded(__FILE__)
      end
    end
  end
end
