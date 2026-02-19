require 'minitest/autorun'

# Ensure tests load our SketchUp API stub before plugin files call require 'sketchup.rb'.
$LOAD_PATH.unshift(File.expand_path('support', __dir__))

require 'sketchup'
