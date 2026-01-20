require 'sketchup.rb'
require 'json'

module AP
  module Plugins
    module FileBrowser
      PREF_KEY = 'AP_FileBrowser'.freeze
      DIALOG_TITLE = 'AP File Browser'.freeze
      DEFAULT_WIDTH = 980
      DEFAULT_HEIGHT = 680

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
          width: DEFAULT_WIDTH,
          height: DEFAULT_HEIGHT,
          min_width: 760,
          min_height: 520,
          style: UI::HtmlDialog::STYLE_DIALOG
        )

        html_path = File.join(File.dirname(__FILE__), 'ui', 'file_browser.html')
        @dialog.set_file(html_path)
        wire_callbacks(@dialog)
        @dialog.show
      end

      def wire_callbacks(dialog)
        dialog.add_action_callback('ready') { |_d| send_state }
        dialog.add_action_callback('list_dir') { |_d, path| handle_list_dir(path) }
        dialog.add_action_callback('import_file') { |_d, path| import_file(path) }
        dialog.add_action_callback('open_model') { |_d, path| open_model(path) }
        dialog.add_action_callback('add_favorite') { |_d, path| add_favorite(path) }
        dialog.add_action_callback('remove_favorite') { |_d, path| remove_favorite(path) }
      end

      def send_state
        payload = {
          path: last_path,
          favorites: favorites,
          home: default_root
        }
        execute_script("window.FileBrowser.setState(#{payload.to_json})")
        handle_list_dir(last_path)
      end

      def handle_list_dir(path)
        target = normalize_path(path)
        unless target && File.directory?(target)
          show_error("Folder not found: #{path}")
          return
        end

        save_last_path(target)
        entries = read_entries(target)
        payload = {
          path: target,
          entries: entries,
          favorites: favorites
        }
        execute_script("window.FileBrowser.receiveList(#{payload.to_json})")
      end

      def read_entries(path)
        entries = []
        Dir.children(path).each do |name|
          full = File.join(path, name)
          begin
            stat = File.stat(full)
            entries << {
              name: name,
              path: full,
              type: stat.directory? ? 'dir' : 'file',
              size: stat.directory? ? nil : stat.size,
              mtime: stat.mtime.to_i
            }
          rescue StandardError
            entries << {
              name: name,
              path: full,
              type: File.directory?(full) ? 'dir' : 'file',
              size: nil,
              mtime: nil
            }
          end
        end

        entries.sort_by do |entry|
          [entry[:type] == 'dir' ? 0 : 1, entry[:name].downcase]
        end
      end

      def import_file(path)
        target = normalize_path(path)
        unless target && File.file?(target)
          show_error('Select a file to import.')
          return
        end

        model = Sketchup.active_model
        model.start_operation('Import File', true)
        ok = model.import(target)
        if ok
          model.commit_operation
          notify("Imported: #{File.basename(target)}")
        else
          model.abort_operation
          show_error("Import failed: #{File.basename(target)}")
        end
      rescue StandardError => e
        model.abort_operation if model
        show_error("Import failed: #{e.message}")
      end

      def open_model(path)
        target = normalize_path(path)
        unless target && File.file?(target)
          show_error('Select a model file to open.')
          return
        end

        unless File.extname(target).downcase == '.skp'
          show_error('Open Model supports .skp files only.')
          return
        end

        if Sketchup.respond_to?(:open_file)
          Sketchup.open_file(target)
        else
          show_error('SketchUp.open_file is not available in this version.')
        end
      rescue StandardError => e
        show_error("Open failed: #{e.message}")
      end

      def add_favorite(path)
        target = normalize_path(path)
        return unless target && File.directory?(target)

        list = favorites
        unless list.include?(target)
          list << target
          save_favorites(list)
        end

        send_state
      end

      def remove_favorite(path)
        target = normalize_path(path)
        return unless target

        list = favorites
        list.delete(target)
        save_favorites(list)
        send_state
      end

      def favorites
        raw = Sketchup.read_default(PREF_KEY, 'favorites', '[]')
        parsed = JSON.parse(raw)
        parsed.select { |item| item.is_a?(String) }
      rescue StandardError
        []
      end

      def save_favorites(list)
        Sketchup.write_default(PREF_KEY, 'favorites', JSON.dump(list.uniq))
      end

      def last_path
        raw = Sketchup.read_default(PREF_KEY, 'last_path', default_root)
        path = normalize_path(raw)
        return default_root unless path && File.directory?(path)

        path
      end

      def save_last_path(path)
        Sketchup.write_default(PREF_KEY, 'last_path', path)
      end

      def default_root
        home = ENV['USERPROFILE'] || Dir.home
        docs = File.join(home, 'Documents')
        File.directory?(docs) ? docs : home
      rescue StandardError
        Dir.home
      end

      def normalize_path(path)
        return nil unless path

        cleaned = path.to_s.strip
        return nil if cleaned.empty?

        File.expand_path(cleaned)
      rescue StandardError
        nil
      end

      def show_error(message)
        execute_script("window.FileBrowser.showError(#{message.to_json})")
      end

      def notify(message)
        execute_script("window.FileBrowser.notify(#{message.to_json})")
      end

      def execute_script(script)
        @dialog&.execute_script(script)
      end

      unless file_loaded?(__FILE__)
        UI.menu('Plugins').add_item('File Browser') { show_dialog }
        file_loaded(__FILE__)
      end
    end
  end
end
