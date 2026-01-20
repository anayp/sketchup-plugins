#-------------------------------------------------------------------------------
# "Select Connected & Group" SketchUp Plugin
#-------------------------------------------------------------------------------
# Author    : Anay's AI Assistant (Cascade)
# Version   : 1.0.0
# Date      : 2025-07-25
# License   : MIT (Free to use & modify)
#-------------------------------------------------------------------------------
# This is a lightweight wrapper that registers the main extension.
# The core implementation lives inside `ap_select_connected_group/core.rb`.
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

module AP # Author initials – adjust if required
  module Plugins
    module SelectConnectedGroup

      # -------------------------------------------------------------------
      #  CONSTANTS
      # -------------------------------------------------------------------

      EXTENSION_NAME    = 'Select Connected & Group'.freeze
      EXTENSION_VERSION = '1.0.0'.freeze
      EXTENSION_ID      = 'AP_SelectConnectedGroup'.freeze

      # Path calculations
      FILENAMESPACE = File.basename(__FILE__, '.rb')
      PATH_ROOT     = File.dirname(__FILE__).freeze
      PATH          = File.join(PATH_ROOT, FILENAMESPACE).freeze

      # -------------------------------------------------------------------
      #  EXTENSION REGISTRATION (loads core on demand)
      # -------------------------------------------------------------------

      unless file_loaded?(__FILE__)
        loader = File.join(PATH, 'core.rb')
        ex     = SketchupExtension.new(EXTENSION_NAME, loader)
        ex.description = 'Expands the current selection to all connected geometry and groups it.'
        ex.version     = EXTENSION_VERSION
        ex.copyright   = '© 2025 Anay (and Cascade Assistant)'
        ex.creator     = 'Cascade AI Assistant'
        Sketchup.register_extension(ex, true)
      end

    end # module SelectConnectedGroup
  end   # module Plugins
end     # module AP

#-------------------------------------------------------------------------------

file_loaded(__FILE__)

#-------------------------------------------------------------------------------
