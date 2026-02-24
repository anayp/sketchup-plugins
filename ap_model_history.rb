#-------------------------------------------------------------------------------
# "Model History" SketchUp Plugin
#-------------------------------------------------------------------------------
# Author    : Anay's AI Assistant (Codex)
# Version   : 0.1.0
# Date      : 2026-02-24
#-------------------------------------------------------------------------------
# Lightweight extension wrapper. Core functionality is in `ap_model_history/core.rb`.
#-------------------------------------------------------------------------------
require 'sketchup.rb'
require 'extensions.rb'

module AP
  module Plugins
    module ModelHistory
      EXTENSION_NAME = 'Model History'.freeze
      EXTENSION_VERSION = '0.1.0'.freeze
      FILENAMESPACE = File.basename(__FILE__, '.rb')
      PATH_ROOT = File.dirname(__FILE__).freeze
      PATH = File.join(PATH_ROOT, FILENAMESPACE).freeze

      unless file_loaded?(__FILE__)
        loader = File.join(PATH, 'core.rb')
        ex = SketchupExtension.new(EXTENSION_NAME, loader)
        ex.description = 'Git-like local history commits for the current SketchUp model.'
        ex.version = EXTENSION_VERSION
        ex.creator = 'Codex AI Assistant'
        Sketchup.register_extension(ex, true)
      end
    end
  end
end

#-------------------------------------------------------------------------------
file_loaded(__FILE__)
#-------------------------------------------------------------------------------
