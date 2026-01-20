#-------------------------------------------------------------------------------
# "Calculator" SketchUp Plugin
#-------------------------------------------------------------------------------
# Author    : Anay's AI Assistant (Cascade)
# Version   : 1.0.0
# Date      : 2025-07-25
#-------------------------------------------------------------------------------
# Lightweight extension wrapper. Core functionality is in `ap_calculator/core.rb`.
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

module AP
  module Plugins
    module Calculator

      EXTENSION_NAME    = 'Calculator'.freeze
      EXTENSION_VERSION = '1.0.0'.freeze
      FILENAMESPACE     = File.basename(__FILE__, '.rb')
      PATH_ROOT         = File.dirname(__FILE__).freeze
      PATH              = File.join(PATH_ROOT, FILENAMESPACE).freeze

      unless file_loaded?(__FILE__)
        loader = File.join(PATH, 'core.rb')
        ex = SketchupExtension.new(EXTENSION_NAME, loader)
        ex.description = 'Simple expression calculator inside SketchUp.'
        ex.version     = EXTENSION_VERSION
        ex.creator     = 'Cascade AI Assistant'
        Sketchup.register_extension(ex, true)
      end

    end # module Calculator
  end   # module Plugins
end     # module AP

#-------------------------------------------------------------------------------

file_loaded(__FILE__)

#-------------------------------------------------------------------------------
