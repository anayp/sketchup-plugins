require 'sketchup.rb'
require 'json'

module AP
  module Plugins
    module OverlayHud
      PREF_KEY = 'AP_OverlayHud'.freeze
      DIALOG_TITLE = 'AP Overlay HUD'.freeze

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
          width: 360,
          height: 480,
          min_width: 320,
          min_height: 420,
          style: UI::HtmlDialog::STYLE_DIALOG
        )

        html_path = File.join(File.dirname(__FILE__), 'ui', 'hud.html')
        @dialog.set_file(html_path)
        wire_callbacks(@dialog)
        @dialog.show
      end

      def wire_callbacks(dialog)
        dialog.add_action_callback('ready') { |_d| refresh }
        dialog.add_action_callback('refresh') { |_d| refresh }
      end

      def refresh
        payload = { stats: collect_stats(Sketchup.active_model) }
        execute_script("window.OverlayHud.setState(#{payload.to_json})")
      rescue StandardError => e
        execute_script("window.OverlayHud.showError(#{e.message.to_json})")
      end

      def collect_stats(model)
        view = model.active_view
        camera = view.camera
        units = model.options['UnitsOptions']
        bbox = model.bounds

        {
          model_name: model.title.to_s.empty? ? 'Untitled' : model.title,
          camera: camera.perspective? ? 'Perspective' : 'Parallel',
          selection_count: model.selection.size,
          units: unit_label(units ? units['LengthUnit'] : nil),
          bbox_x: Sketchup.format_length(bbox.width),
          bbox_y: Sketchup.format_length(bbox.height),
          bbox_z: Sketchup.format_length(bbox.depth)
        }
      end

      def unit_label(value)
        case value
        when 0 then 'Inches'
        when 1 then 'Feet'
        when 2 then 'Millimeters'
        when 3 then 'Centimeters'
        when 4 then 'Meters'
        else 'Unknown'
        end
      end

      def execute_script(script)
        @dialog&.execute_script(script)
      end

      unless file_loaded?(__FILE__)
        UI.menu('Plugins').add_item('Overlay HUD') { show_dialog }
        file_loaded(__FILE__)
      end
    end
  end
end
