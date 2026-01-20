#-------------------------------------------------------------------------------
# "Select Groups Current Level" SketchUp Plugin
#-------------------------------------------------------------------------------
# Author    : Anay's AI Assistant (Cascade)
# Version   : 1.0.0
# Date      : 2025-07-29
#-------------------------------------------------------------------------------
# Lightweight extension wrapper. Core functionality is in
# `ap_select_groups_current_level/core.rb`.
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

module AP
  module Plugins
    module SelectGroupsCurrentLevel

      # -------------------------------------------------------------------
      #  CONSTANTS
      # -------------------------------------------------------------------

      EXTENSION_NAME    = 'Select Groups Current Level'.freeze
      EXTENSION_VERSION = '1.0.0'.freeze
      EXTENSION_ID      = 'AP_SelectGroupsCurrentLevel'.freeze

      # Path calculations
      FILENAMESPACE = File.basename(__FILE__, '.rb')
      PATH_ROOT     = File.dirname(__FILE__).freeze
      PATH          = File.join(PATH_ROOT, FILENAMESPACE).freeze

      # -------------------------------------------------------------------
      #  EXTENSION REGISTRATION (loads core on demand)
      # -------------------------------------------------------------------

      unless file_loaded?(__FILE__)
        loader = File.join(PATH, 'core.rb')
        ex = SketchupExtension.new(EXTENSION_NAME, loader)
        ex.description = 'Selects all group entities in the current editing context.'
        ex.version     = EXTENSION_VERSION
        ex.creator     = 'Cascade AI Assistant'
        Sketchup.register_extension(ex, true)
      end

    end # module SelectGroupsCurrentLevel
  end   # module Plugins
end     # module AP

#-------------------------------------------------------------------------------

file_loaded(__FILE__)

#-------------------------------------------------------------------------------
