#-------------------------------------------------------------------------------
# Length Converter – Core
#-------------------------------------------------------------------------------
require 'sketchup.rb'

module AP
  module Plugins
    module LengthConverter
      module UIHelper
        extend self

        def show_dialog
          html_path = File.join(File.dirname(__FILE__), 'ui', 'length_converter.html')
          unless File.exist?(html_path)
            UI.messagebox('Length converter UI not found.')
            return
          end

          @dlg ||= UI::HtmlDialog.new(dialog_title: 'Length Converter', width: 400, height: 360, style: UI::HtmlDialog::STYLE_DIALOG)
          @dlg.set_file(html_path)
          @dlg.show
        end
      end

      # Menu & toolbar
      unless file_loaded?(__FILE__)
        menu = UI.menu('Plugins')
        menu.add_item('Length Converter') { UIHelper.show_dialog }

        tb = UI::Toolbar.new('Length Converter')
        cmd = UI::Command.new('Length Converter') { UIHelper.show_dialog }
        cmd.tooltip = 'Open length converter'
        base_dir = File.dirname(__FILE__)
        small_in_icons = File.join(base_dir, 'icons', 'length_converter_24.png')
        large_in_icons = File.join(base_dir, 'icons', 'length_converter_48.png')
        small_root     = File.join(base_dir, 'length_converter_24.png')
        large_root     = File.join(base_dir, 'length_converter_48.png')

        if File.exist?(small_in_icons)
          cmd.small_icon = 'icons/length_converter_24.png'
        elsif File.exist?(small_root)
          cmd.small_icon = 'length_converter_24.png'
        else
          cmd.small_icon = ''
        end

        if File.exist?(large_in_icons)
          cmd.large_icon = 'icons/length_converter_48.png'
        elsif File.exist?(large_root)
          cmd.large_icon = 'length_converter_48.png'
        else
          cmd.large_icon = cmd.small_icon
        end
        tb.add_item(cmd)
        tb.restore
      end

    end
  end
end

file_loaded(__FILE__)
