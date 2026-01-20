#-------------------------------------------------------------------------------
# Select Connected & Group – Core Implementation
#-------------------------------------------------------------------------------
# NOTE: This file is auto-loaded via ap_select_connected_group.rb
#-------------------------------------------------------------------------------
require 'sketchup.rb'

module AP
  module Plugins
    module SelectConnectedGroup

      #-----------------------------------------------------------------------------#
      # Small helper UI that displays running log messages.
      #-----------------------------------------------------------------------------#
      class LoggerDialog
        # @param [String] title
        def initialize(title = 'Progress')
          @steps = []
          @title = title

          # Decide dialog backend
          if defined?(UI::HtmlDialog)
            build_html_dialog
          elsif defined?(UI::WebDialog)
            build_web_dialog
          else
            @dlg = nil # Fallback to messagebox only
          end
        end

        def build_html_dialog
          @dlg = UI::HtmlDialog.new(
            dialog_title: @title,
            scrollable:   true,
            width:        380,
            height:       240,
            style:        UI::HtmlDialog::STYLE_DIALOG
          )

          html = <<-HTML
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="utf-8">
              <title>#{@title}</title>
              <style>
                body { font-family: sans-serif; margin: 8px; }
                pre  { white-space: pre-wrap; word-wrap: break-word; }
              </style>
            </head>
            <body>
              <pre id="log"></pre>
              <script>
                function addLine(txt) {
                  var pre = document.getElementById('log');
                  pre.textContent += txt + "\n";
                  window.scrollTo(0, document.body.scrollHeight);
                }
              </script>
            </body>
            </html>
          HTML
          @dlg.set_html(html)
        end

        def build_web_dialog
          @dlg = UI::WebDialog.new(@title, true, @title.gsub(/\s+/, '_'), 380, 240, 200, 200, true)
          html = <<-HTML
            <html><body style="font-family:sans-serif;margin:8px;">
              <pre id='log'></pre>
              <script>
                function addLine(txt){document.getElementById('log').innerText += txt + "\n";}
              </script>
            </body></html>
          HTML
          @dlg.set_html(html)
        end

        def show
          @dlg.show if @dlg
        end

        # Add a line to the log window (and terminal stdout)
        # @param [String] text
        def log(text)
          @steps << text
          if @dlg
            js = "addLine(" + text.inspect + ");"
            @dlg.execute_script(js)
          end
          puts(text) # Console fallback
        end

        # Show all collected steps in a MessageBox if dialog backend unavailable
        def finish
          if @dlg
            log('---')
            log('Job complete!')
          else
            UI.messagebox(@steps.join("\n") + "\n---\nJob complete!")
          end
        end
      end

      #-----------------------------------------------------------------------------#
      #  Main functionality – expand selection to all connected geometry and group.
      #-----------------------------------------------------------------------------#
      module Main
        extend self

        # Entry point called by the menu item.
        def execute
          model = Sketchup.active_model
          selection = model.selection

          if selection.empty?
            UI.messagebox('Please select at least one entity before running "Select Connected & Group".')
            return
          end

          model.start_operation('Select Connected & Group', true)
          begin
            # 1. Collect connected geometry
            connected = gather_connected_entities(selection.to_a)

            # 2. Replace current selection and group
            selection.clear
            selection.add(connected)
            new_group = model.active_entities.add_group(connected)
            selection.clear
            selection.add(new_group)

            model.commit_operation
            UI.messagebox('Connected geometry grouped.')
          rescue => e
            model.abort_operation
            UI.messagebox("Select Connected & Group failed:\n#{e.message}\nSee Ruby console for details.")
          end
        end

        private

        # Returns array of entities connected to any in +entities+.
        # Uses entity#all_connected if available (SketchUp ≥2014) else manual BFS.
        # @param [Array<Sketchup::Entity>] entities
        # @return [Array<Sketchup::Entity>]
        def gather_connected_entities(entities)
          return entities.dup if entities.empty?

          if entities.first.respond_to?(:all_connected)
            # Fast path – union of all connected sets.
            connected = entities.flat_map { |e| e.all_connected }
            return connected.uniq
          end

          # Legacy fallback – manual traversal.
          queue   = entities.dup
          visited = {}
          until queue.empty?
            ent = queue.pop
            next if visited[ent]
            visited[ent] = true

            case ent
            when Sketchup::Edge
              queue.concat(ent.vertices)
              queue.concat(ent.faces)
            when Sketchup::Vertex
              queue.concat(ent.edges)
              queue.concat(ent.faces)
            when Sketchup::Face
              queue.concat(ent.edges)
            end
          end
          visited.keys
        end
      end # module Main

      #-----------------------------------------------------------------------------#
      #  MENU & SHORTCUT REGISTRATION
      #-----------------------------------------------------------------------------#
      unless file_loaded?(__FILE__)
        menu = UI.menu('Plugins')
        menu.add_item('Select Connected & Group') { Main.execute }

        # Toolbar button
        toolbar = UI::Toolbar.new('Select Connected')
        cmd = UI::Command.new('Select Connected & Group') { Main.execute }
        cmd.tooltip = 'Select all connected geometry and group'
        cmd.status_bar_text = 'Select all connected geometry and group'

        # Toolbar icons
        base_dir = File.dirname(__FILE__)
        small_in_icons = File.join(base_dir, 'icons', 'select_connected_group_24.png')
        large_in_icons = File.join(base_dir, 'icons', 'select_connected_group_48.png')
        small_root     = File.join(base_dir, 'select_connected_group_24.png')
        large_root     = File.join(base_dir, 'select_connected_group_48.png')

        if File.exist?(small_in_icons)
          cmd.small_icon = 'icons/select_connected_group_24.png'
        elsif File.exist?(small_root)
          cmd.small_icon = 'select_connected_group_24.png'
        else
          cmd.small_icon = ''
        end

        if File.exist?(large_in_icons)
          cmd.large_icon = 'icons/select_connected_group_48.png'
        elsif File.exist?(large_root)
          cmd.large_icon = 'select_connected_group_48.png'
        else
          cmd.large_icon = cmd.small_icon
        end
        toolbar.add_item(cmd)
        toolbar.restore

        # Optionally add to Context Menu (right-click)
        UI.add_context_menu_handler do |context_menu|
          if Sketchup.active_model.selection.any?
            context_menu.add_item('Select Connected & Group') { Main.execute }
          end
        end
      end

    end # module SelectConnectedGroup
  end   # module Plugins
end     # module AP

#-------------------------------------------------------------------------------

file_loaded(__FILE__)

#-------------------------------------------------------------------------------
