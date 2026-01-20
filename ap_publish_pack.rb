#-------------------------------------------------------------------------------
# "Publish Pack" SketchUp Plugin
#-------------------------------------------------------------------------------
# Author    : Anay's AI Assistant (Codex)
# Version   : 1.0.0
# Date      : 2025-12-10
#-------------------------------------------------------------------------------
# Lightweight extension wrapper. Core functionality is in `ap_publish_pack/core.rb`.
#-------------------------------------------------------------------------------
require 'sketchup.rb'
require 'extensions.rb'

module AP
  module Plugins
    module PublishPack
      EXTENSION_NAME    = 'Publish Pack'.freeze
      EXTENSION_VERSION = '1.0.0'.freeze
      FILENAMESPACE     = File.basename(__FILE__, '.rb')
      PATH_ROOT         = File.dirname(__FILE__).freeze
      PATH              = File.join(PATH_ROOT, FILENAMESPACE).freeze

      unless file_loaded?(__FILE__)
        loader = File.join(PATH, 'core.rb')
        ex = SketchupExtension.new(EXTENSION_NAME, loader)
        ex.description = 'Export a bundled set of deliverables.'
        ex.version     = EXTENSION_VERSION
        ex.creator     = 'Codex AI Assistant'
        Sketchup.register_extension(ex, true)
      end

    end # module PublishPack
  end   # module Plugins
end     # module AP

#-------------------------------------------------------------------------------
file_loaded(__FILE__)
#-------------------------------------------------------------------------------
