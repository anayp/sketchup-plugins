#!/usr/bin/env ruby

require 'json'
require 'optparse'
require 'securerandom'
require 'socket'

options = {
  host: ENV.fetch('AP_CLI_BRIDGE_HOST', '127.0.0.1'),
  port: ENV.fetch('AP_CLI_BRIDGE_PORT', '7464').to_i,
  params: {}
}

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: ruby tools/su_cli_bridge.rb [options] <command>'
  opts.on('--host HOST', 'Bridge host (default: 127.0.0.1)') { |value| options[:host] = value }
  opts.on('--port PORT', Integer, 'Bridge port (default: 7464)') { |value| options[:port] = value }
  opts.on('--params JSON', 'JSON object passed as command params') do |value|
    options[:params] = JSON.parse(value)
  end
  opts.on('--help', 'Show this help') do
    puts opts
    exit 0
  end
end

parser.parse!

command = ARGV.shift || 'ping'
request = {
  id: SecureRandom.hex(6),
  command: command,
  params: options[:params]
}

begin
  socket = TCPSocket.new(options[:host], options[:port])
  socket.write(JSON.dump(request) + "\n")
  raw_response = socket.gets
  abort('No response from bridge.') if raw_response.nil?

  response = JSON.parse(raw_response)
  if response['ok']
    puts JSON.pretty_generate(response['result'])
    exit 0
  else
    warn JSON.pretty_generate(response['error'])
    exit 2
  end
rescue JSON::ParserError => e
  warn "Invalid JSON input/response: #{e.message}"
  exit 3
rescue SystemCallError => e
  warn "Bridge connection failed: #{e.message}"
  exit 4
ensure
  socket&.close
end
