#-------------------------------------------------------------------------------
# Select Groups Current Level – Core Implementation
#-------------------------------------------------------------------------------
# NOTE: This file is auto-loaded via ap_select_groups_current_level.rb
#-------------------------------------------------------------------------------

require 'sketchup.rb'

module AP
  module Plugins
    module SelectGroupsCurrentLevel

      #-----------------------------------------------------------------------------#
      #  Main functionality – select all group entities in the current context.
      #-----------------------------------------------------------------------------#
      module Main
        extend self

        # Entry point called by the menu item.
        def execute
          model = Sketchup.active_model
          selection = model.selection
          entities  = model.active_entities

          groups = entities.grep(Sketchup::Group)

          if groups.empty?
            UI.messagebox('No group entities found in the current editing context.')
            return
          end

          model.start_operation('Select Groups Current Level', true)
          begin
            selection.clear
            selection.add(groups)
            model.commit_operation
          rescue => e
            model.abort_operation
            UI.messagebox("Select Groups Current Level failed:\n#{e.message}\nSee Ruby console for details.")
            raise e
          end
        end
      end # module Main

      #-----------------------------------------------------------------------------#
      #  MENU & SHORTCUT REGISTRATION
      #-----------------------------------------------------------------------------#
      unless file_loaded?(__FILE__)
        menu = UI.menu('Plugins')
        menu.add_item('Select Groups Current Level') { Main.execute }

        # Toolbar button (optional)
        toolbar = UI::Toolbar.new('Select Groups Level')
        cmd = UI::Command.new('Select Groups Current Level') { Main.execute }
        cmd.tooltip = 'Select all groups in the current editing context'
        cmd.status_bar_text = 'Select all groups in the current editing context'

        # Toolbar icons
        base_dir = File.dirname(__FILE__)
        small_in_icons = File.join(base_dir, 'icons', 'select_groups_current_level_24.png')
        large_in_icons = File.join(base_dir, 'icons', 'select_groups_current_level_48.png')
        small_root     = File.join(base_dir, 'select_groups_current_level_24.png')
        large_root     = File.join(base_dir, 'select_groups_current_level_48.png')

        if File.exist?(small_in_icons)
          cmd.small_icon = 'icons/select_groups_current_level_24.png'
        elsif File.exist?(small_root)
          cmd.small_icon = 'select_groups_current_level_24.png'
        else
          cmd.small_icon = ''
        end

        if File.exist?(large_in_icons)
          cmd.large_icon = 'icons/select_groups_current_level_48.png'
        elsif File.exist?(large_root)
          cmd.large_icon = 'select_groups_current_level_48.png'
        else
          cmd.large_icon = cmd.small_icon
        end

        toolbar.add_item(cmd)
        toolbar.restore

        # Context Menu entry when groups present
        UI.add_context_menu_handler do |context_menu|
          ents = Sketchup.active_model.active_entities
          if ents.grep(Sketchup::Group).any?
            context_menu.add_item('Select Groups Current Level') { Main.execute }
          end
        end
      end

    end # module SelectGroupsCurrentLevel
  end   # module Plugins
end     # module AP

#-------------------------------------------------------------------------------

file_loaded(__FILE__)

#-------------------------------------------------------------------------------
