require 'sketchup.rb'
require 'json'

module AP
  module Plugins
    module MiniBrowser
      PREF_KEY = 'AP_MiniBrowser'.freeze
      DIALOG_TITLE = 'AP Mini Browser'.freeze
      DEFAULT_WIDTH = 1100
      DEFAULT_HEIGHT = 720
      DEFAULT_HOME = 'https://duckduckgo.com'.freeze

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
          min_width: 820,
          min_height: 560,
          style: UI::HtmlDialog::STYLE_DIALOG
        )

        html_path = File.join(File.dirname(__FILE__), 'ui', 'mini_browser.html')
        @dialog.set_file(html_path)
        wire_callbacks(@dialog)
        @dialog.show
      end

      def wire_callbacks(dialog)
        dialog.add_action_callback('ready') { |_d| send_state }
        dialog.add_action_callback('set_home') { |_d, url| set_home(url) }
        dialog.add_action_callback('add_bookmark') { |_d, url| add_bookmark(url) }
        dialog.add_action_callback('remove_bookmark') { |_d, url| remove_bookmark(url) }
        dialog.add_action_callback('open_external') { |_d, url| open_external(url) }
      end

      def send_state
        payload = {
          home: home_url,
          bookmarks: bookmarks
        }
        execute_script("window.MiniBrowser.setState(#{payload.to_json})")
      end

      def set_home(url)
        target = normalize_url(url)
        return unless target

        Sketchup.write_default(PREF_KEY, 'home_url', target)
        send_state
      end

      def add_bookmark(url)
        target = normalize_url(url)
        return unless target

        list = bookmarks
        unless list.include?(target)
          list << target
          save_bookmarks(list)
        end

        send_state
      end

      def remove_bookmark(url)
        target = normalize_url(url)
        return unless target

        list = bookmarks
        list.delete(target)
        save_bookmarks(list)
        send_state
      end

      def bookmarks
        raw = Sketchup.read_default(PREF_KEY, 'bookmarks', '[]')
        parsed = JSON.parse(raw)
        parsed.select { |item| item.is_a?(String) }
      rescue StandardError
        []
      end

      def save_bookmarks(list)
        Sketchup.write_default(PREF_KEY, 'bookmarks', JSON.dump(list.uniq))
      end

      def home_url
        raw = Sketchup.read_default(PREF_KEY, 'home_url', DEFAULT_HOME)
        normalize_url(raw) || DEFAULT_HOME
      end

      def normalize_url(url)
        return nil unless url

        trimmed = url.to_s.strip
        return nil if trimmed.empty?

        return trimmed if trimmed =~ %r{\A[a-zA-Z][a-zA-Z0-9+.-]*://}

        "https://#{trimmed}"
      end

      def open_external(url)
        target = normalize_url(url)
        return unless target

        UI.openURL(target)
      end

      def execute_script(script)
        @dialog&.execute_script(script)
      end

      unless file_loaded?(__FILE__)
        UI.menu('Plugins').add_item('Mini Browser') { show_dialog }
        file_loaded(__FILE__)
      end
    end
  end
end
