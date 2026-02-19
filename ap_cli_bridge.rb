#-------------------------------------------------------------------------------
# "CLI Bridge" SketchUp Plugin
#-------------------------------------------------------------------------------
# Author    : Anay's AI Assistant (Codex)
# Version   : 0.1.0
# Date      : 2026-02-19
#-------------------------------------------------------------------------------
# Lightweight extension wrapper. Core functionality is in `ap_cli_bridge/core.rb`.
#-------------------------------------------------------------------------------
require 'sketchup.rb'
require 'extensions.rb'

module AP
  module Plugins
    module CliBridge
      EXTENSION_NAME = 'CLI Bridge'.freeze
      EXTENSION_VERSION = '0.1.0'.freeze
      FILENAMESPACE = File.basename(__FILE__, '.rb')
      PATH_ROOT = File.dirname(__FILE__).freeze
      PATH = File.join(PATH_ROOT, FILENAMESPACE).freeze

      unless file_loaded?(__FILE__)
        loader = File.join(PATH, 'core.rb')
        ex = SketchupExtension.new(EXTENSION_NAME, loader)
        ex.description = 'Localhost JSON bridge for CLI and agent automation.'
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
