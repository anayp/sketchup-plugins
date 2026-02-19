#!/usr/bin/env ruby

Dir[File.expand_path('test_*.rb', __dir__)].sort.each do |file|
  require file
end
