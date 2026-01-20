#-------------------------------------------------------------------------------
# "Length Converter" SketchUp Plugin
#-------------------------------------------------------------------------------
# Author    : Anay's AI Assistant (Cascade)
# Version   : 1.0.0
# Date      : 2025-07-28
#-------------------------------------------------------------------------------
# Lightweight extension wrapper. Core functionality is in `ap_length_converter/core.rb`.
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

module AP
  module Plugins
    module LengthConverter

      EXTENSION_NAME    = 'Length Converter'.freeze
      EXTENSION_VERSION = '1.0.0'.freeze
      FILENAMESPACE     = File.basename(__FILE__, '.rb')
      PATH_ROOT         = File.dirname(__FILE__).freeze
      PATH              = File.join(PATH_ROOT, FILENAMESPACE).freeze

      unless file_loaded?(__FILE__)
        loader = File.join(PATH, 'core.rb')
        ex = SketchupExtension.new(EXTENSION_NAME, loader)
        ex.description = 'Convert between feet, meters, inches, cm, yards, km, miles.'
        ex.version     = EXTENSION_VERSION
        ex.creator     = 'Cascade AI Assistant'
        Sketchup.register_extension(ex, true)
      end

    end # module LengthConverter
  end   # module Plugins
end     # module AP

#-------------------------------------------------------------------------------

file_loaded(__FILE__)

#-------------------------------------------------------------------------------
