require 'sketchup.rb'
require 'json'
require 'socket'
require 'thread'
require 'time'

module AP
  module Plugins
    module CliBridge
      VERSION = '0.1.0'.freeze
      SERVICE_NAME = 'ap_cli_bridge'.freeze
      HOST_DEFAULT = '127.0.0.1'.freeze
      PORT_DEFAULT = 7464
      TIMER_INTERVAL_SECONDS = 0.05
      MAX_COMMANDS_PER_TICK = 50

      class CommandError < StandardError
        attr_reader :code, :data

        def initialize(code, message, data = nil)
          super(message)
          @code = code
          @data = data
        end
      end

      module_function

      def command_list
        [
          'help',
          'ping',
          'bridge.start',
          'bridge.stop',
          'bridge.status',
          'snapshot.get',
          'snapshot.refresh',
          'selection.summary'
        ]
      end

      def start_bridge
        return bridge_status if running?

        host = configured_host
        port = configured_port

        @request_queue = Queue.new
        @snapshot_dirty = true if @snapshot_dirty.nil?
        @server = TCPServer.new(host, port)
        @server_host = host
        @server_port = port
        @running = true

        start_accept_thread
        start_pump_timer
        attach_observers
        set_status("CLI Bridge listening on #{host}:#{port}")

        bridge_status
      rescue StandardError => e
        stop_bridge(silent: true)
        raise CommandError.new('bridge_start_failed', e.message)
      end

      def stop_bridge(silent: false)
        was_running = running?
        @running = false

        drain_pending_requests
        close_server
        stop_accept_thread
        stop_client_threads
        stop_pump_timer

        @server_host = nil
        @server_port = nil

        set_status('CLI Bridge stopped.') if was_running && !silent
        bridge_status
      end

      def running?
        @running == true
      end

      def bridge_status
        {
          'running' => running?,
          'host' => @server_host,
          'port' => @server_port,
          'queue_depth' => queue_depth,
          'snapshot_dirty' => @snapshot_dirty == true
        }
      end

      def handle_request(raw_request)
        request = normalize_request(raw_request)
        request_id = request['id']
        command = request['command']
        params = request['params']

        raise CommandError.new('invalid_request', 'Missing command.') if command.empty?

        result = dispatch_command(command, params)
        success_response(request_id, result)
      rescue CommandError => e
        error_response(raw_request_id(raw_request), e.code, e.message, e.data)
      rescue StandardError => e
        error_response(raw_request_id(raw_request), 'internal_error', e.message)
      end

      def process_request_queue
        return unless @request_queue

        processed = 0
        loop do
          break if processed >= MAX_COMMANDS_PER_TICK

          item = @request_queue.pop(true)
          response = handle_request(item[:request])
          item[:response_queue] << response
          processed += 1
        rescue ThreadError
          break
        rescue StandardError => e
          item[:response_queue] << error_response(raw_request_id(item[:request]), 'internal_error', e.message) if item
          processed += 1
        end
      end

      def mark_snapshot_dirty(_reason = nil)
        @snapshot_dirty = true
      end

      def reset_for_tests
        stop_bridge(silent: true) if running?
        @snapshot_cache = nil
        @snapshot_dirty = true
        @observed_model = nil
        @model_observer = nil
        @selection_observer = nil
      end

      def collect_selection_summary(model = Sketchup.active_model)
        selection = if model && model.respond_to?(:selection)
                      model.selection
                    else
                      nil
                    end
        entities = selection.respond_to?(:to_a) ? selection.to_a : []
        groups = 0
        components = 0
        faces = 0
        edges = 0

        entities.each do |entity|
          case entity
          when Sketchup::Group
            groups += 1
          when Sketchup::ComponentInstance
            components += 1
          when Sketchup::Face
            faces += 1
          when Sketchup::Edge
            edges += 1
          end
        end

        known = groups + components + faces + edges
        {
          'total' => entities.size,
          'groups' => groups,
          'components' => components,
          'faces' => faces,
          'edges' => edges,
          'others' => [entities.size - known, 0].max
        }
      end

      def build_snapshot(model)
        {
          'model' => {
            'title' => model_title(model),
            'path' => model_path(model)
          },
          'captured_at' => Time.now.utc.iso8601,
          'stats' => collect_stats(model),
          'selection' => collect_selection_summary(model)
        }
      end

      def collect_stats(model)
        faces = 0
        edges = 0
        groups = 0
        components = 0
        stray_edges = 0
        back_faces = 0
        max_depth = 0

        traverse_entities(model_entities(model), 0) do |entity, depth|
          max_depth = depth if depth > max_depth

          case entity
          when Sketchup::Face
            faces += 1
            if entity.respond_to?(:back_material) && entity.back_material &&
               (!entity.respond_to?(:material) || !entity.material)
              back_faces += 1
            end
          when Sketchup::Edge
            edges += 1
            linked_faces = entity.respond_to?(:faces) ? entity.faces : []
            stray_edges += 1 if linked_faces.respond_to?(:empty?) && linked_faces.empty?
          when Sketchup::Group
            groups += 1
          when Sketchup::ComponentInstance
            components += 1
          end
        end

        defs = model_definitions(model)
        unused_defs = defs.count do |definition|
          no_instances = !definition.respond_to?(:instances) || definition.instances.empty?
          no_image = !definition.respond_to?(:image?) || !definition.image?
          no_instances && no_image
        end

        {
          'faces' => faces,
          'edges' => edges,
          'groups' => groups,
          'component_instances' => components,
          'component_definitions' => defs.size,
          'unused_definitions' => unused_defs,
          'materials' => model_collection_size(model, :materials),
          'tags' => model_collection_size(model, :layers),
          'stray_edges' => stray_edges,
          'back_faces' => back_faces,
          'max_depth' => max_depth
        }
      end

      def traverse_entities(entities, depth, &block)
        return if entities.nil? || depth > 50

        entities.each do |entity|
          yield entity, depth

          if entity.is_a?(Sketchup::Group) && entity.respond_to?(:entities)
            traverse_entities(entity.entities, depth + 1, &block)
          elsif entity.is_a?(Sketchup::ComponentInstance) && entity.respond_to?(:definition)
            definition = entity.definition
            nested_entities = definition.respond_to?(:entities) ? definition.entities : nil
            traverse_entities(nested_entities, depth + 1, &block)
          end
        end
      end

      def attach_observers(model = Sketchup.active_model)
        return unless model
        return unless defined?(Sketchup::ModelObserver) && defined?(Sketchup::SelectionObserver)
        return if @observed_model.equal?(model)

        detach_observers

        @model_observer ||= BridgeModelObserver.new(method(:mark_snapshot_dirty))
        @selection_observer ||= BridgeSelectionObserver.new(method(:mark_snapshot_dirty))

        model.add_observer(@model_observer) if model.respond_to?(:add_observer)

        if model.respond_to?(:selection) && model.selection.respond_to?(:add_observer)
          model.selection.add_observer(@selection_observer)
        end

        @observed_model = model
      rescue StandardError
        @observed_model = nil
      end

      def detach_observers
        return unless @observed_model

        if @model_observer && @observed_model.respond_to?(:remove_observer)
          @observed_model.remove_observer(@model_observer)
        end

        if @selection_observer &&
           @observed_model.respond_to?(:selection) &&
           @observed_model.selection.respond_to?(:remove_observer)
          @observed_model.selection.remove_observer(@selection_observer)
        end
      rescue StandardError
        nil
      ensure
        @observed_model = nil
      end

      def dispatch_command(command, params)
        case command
        when 'help'
          { 'commands' => command_list }
        when 'ping'
          {
            'service' => SERVICE_NAME,
            'version' => VERSION,
            'time' => Time.now.utc.iso8601
          }
        when 'bridge.start'
          start_bridge
        when 'bridge.stop'
          stop_bridge
        when 'bridge.status'
          bridge_status
        when 'snapshot.get'
          snapshot, cached = snapshot_for_active_model(force: false)
          { 'snapshot' => snapshot, 'cached' => cached }
        when 'snapshot.refresh'
          snapshot, = snapshot_for_active_model(force: true)
          { 'snapshot' => snapshot, 'cached' => false }
        when 'selection.summary'
          { 'selection' => collect_selection_summary(Sketchup.active_model) }
        else
          raise CommandError.new('invalid_command', "Unsupported command: #{command}")
        end
      end

      def snapshot_for_active_model(force: false)
        model = Sketchup.active_model
        raise CommandError.new('model_unavailable', 'No active model available.') unless model

        attach_observers(model)

        model_key = model.object_id
        if !force && @snapshot_cache && @snapshot_cache[:model_key] == model_key && @snapshot_dirty != true
          return [@snapshot_cache[:snapshot], true]
        end

        snapshot = build_snapshot(model)
        @snapshot_cache = {
          model_key: model_key,
          snapshot: snapshot,
          captured_at: Time.now.to_f
        }
        @snapshot_dirty = false
        [snapshot, false]
      end

      def configured_host
        host = ENV['AP_CLI_BRIDGE_HOST'].to_s.strip
        host.empty? ? HOST_DEFAULT : host
      end

      def configured_port
        port = ENV['AP_CLI_BRIDGE_PORT'].to_i
        return PORT_DEFAULT if port <= 0

        port
      end

      def enqueue_request(request)
        raise CommandError.new('bridge_not_running', 'CLI Bridge is not running.') unless running?

        response_queue = Queue.new
        @request_queue << { request: request, response_queue: response_queue }
        response_queue.pop
      end

      def start_accept_thread
        @client_threads ||= []
        @accept_thread = Thread.new do
          loop do
            break unless running?

            socket = @server.accept
            @client_threads << Thread.new(socket) { |client| handle_client_connection(client) }
          rescue IOError, Errno::EBADF
            break unless running?
          rescue StandardError
            next if running?
            break
          end
        end
      end

      def handle_client_connection(socket)
        socket.sync = true

        while running? && (line = socket.gets)
          response = begin
            request = JSON.parse(line)
            enqueue_request(request)
          rescue JSON::ParserError
            error_response(nil, 'invalid_json', 'Request must be valid JSON.')
          rescue CommandError => e
            error_response(raw_request_id(request), e.code, e.message)
          rescue StandardError => e
            error_response(raw_request_id(request), 'internal_error', e.message)
          end

          socket.write(JSON.dump(response) + "\n")
        end
      rescue StandardError
        nil
      ensure
        socket.close unless socket.closed?
      end

      def start_pump_timer
        return unless UI.respond_to?(:start_timer)
        return if @pump_timer_id

        @pump_timer_id = UI.start_timer(TIMER_INTERVAL_SECONDS, true) { process_request_queue }
      end

      def stop_pump_timer
        return unless @pump_timer_id
        return unless UI.respond_to?(:stop_timer)

        UI.stop_timer(@pump_timer_id)
      ensure
        @pump_timer_id = nil
      end

      def close_server
        return unless @server

        @server.close
      rescue StandardError
        nil
      ensure
        @server = nil
      end

      def stop_accept_thread
        return unless @accept_thread

        @accept_thread.kill
        @accept_thread.join(0.1)
      rescue StandardError
        nil
      ensure
        @accept_thread = nil
      end

      def stop_client_threads
        return unless @client_threads

        @client_threads.each do |thread|
          next unless thread

          thread.kill
          thread.join(0.1)
        rescue StandardError
          nil
        end
      ensure
        @client_threads = []
      end

      def drain_pending_requests
        return unless @request_queue

        loop do
          item = @request_queue.pop(true)
          item[:response_queue] << error_response(raw_request_id(item[:request]), 'bridge_stopped', 'CLI Bridge is stopping.')
        rescue ThreadError
          break
        end
      end

      def normalize_request(raw_request)
        request = raw_request.is_a?(Hash) ? raw_request : {}
        {
          'id' => request['id'] || request[:id],
          'command' => (request['command'] || request[:command]).to_s.strip,
          'params' => normalize_params(request['params'] || request[:params])
        }
      end

      def normalize_params(params)
        params.is_a?(Hash) ? params : {}
      end

      def raw_request_id(raw_request)
        return nil unless raw_request.is_a?(Hash)

        raw_request['id'] || raw_request[:id]
      rescue StandardError
        nil
      end

      def success_response(request_id, result)
        {
          'id' => request_id,
          'ok' => true,
          'result' => result
        }
      end

      def error_response(request_id, code, message, data = nil)
        payload = {
          'id' => request_id,
          'ok' => false,
          'error' => {
            'code' => code.to_s,
            'message' => message.to_s
          }
        }
        payload['error']['data'] = data if data
        payload
      end

      def queue_depth
        return 0 unless @request_queue

        @request_queue.length
      rescue StandardError
        0
      end

      def model_entities(model)
        return [] unless model.respond_to?(:entities)

        model.entities
      end

      def model_definitions(model)
        return [] unless model.respond_to?(:definitions)

        defs = model.definitions
        defs.respond_to?(:to_a) ? defs.to_a : []
      rescue StandardError
        []
      end

      def model_collection_size(model, attribute)
        return 0 unless model.respond_to?(attribute)

        collection = model.public_send(attribute)
        if collection.respond_to?(:size)
          collection.size
        elsif collection.respond_to?(:to_a)
          collection.to_a.size
        else
          0
        end
      rescue StandardError
        0
      end

      def model_title(model)
        title = model.respond_to?(:title) ? model.title.to_s : ''
        title.empty? ? 'Untitled' : title
      rescue StandardError
        'Untitled'
      end

      def model_path(model)
        model.respond_to?(:path) ? model.path.to_s : ''
      rescue StandardError
        ''
      end

      def set_status(message)
        if Sketchup.respond_to?(:set_status_text)
          begin
            Sketchup.set_status_text(message, SB_PROMPT)
          rescue StandardError
            Sketchup.set_status_text(message)
          end
        elsif Sketchup.respond_to?(:status_text=)
          Sketchup.status_text = message
        end
      end

      def start_bridge_with_feedback
        status = start_bridge
        UI.messagebox("CLI Bridge running on #{status['host']}:#{status['port']}")
      rescue CommandError => e
        UI.messagebox("CLI Bridge failed to start: #{e.message}")
      end

      def stop_bridge_with_feedback
        status = stop_bridge
        if status['running']
          UI.messagebox('CLI Bridge could not stop cleanly. Check Ruby Console.')
        else
          UI.messagebox('CLI Bridge stopped.')
        end
      end

      def show_status_with_feedback
        status = bridge_status
        message = "running: #{status['running']}\n" \
                  "host: #{status['host']}\n" \
                  "port: #{status['port']}\n" \
                  "queue_depth: #{status['queue_depth']}\n" \
                  "snapshot_dirty: #{status['snapshot_dirty']}"
        UI.messagebox(message)
      end

      def autostart?
        ENV['AP_CLI_BRIDGE_AUTOSTART'].to_s == '1'
      end

      unless file_loaded?(__FILE__)
        menu = UI.menu('Plugins').add_submenu('AP CLI Bridge')
        menu.add_item('Start Bridge') { start_bridge_with_feedback }
        menu.add_item('Stop Bridge') { stop_bridge_with_feedback }
        menu.add_item('Bridge Status') { show_status_with_feedback }
        start_bridge if autostart?
        file_loaded(__FILE__)
      end

      if defined?(Sketchup::ModelObserver)
        class BridgeModelObserver < Sketchup::ModelObserver
          def initialize(callback)
            @callback = callback
          end

          def onTransactionCommit(_model)
            @callback.call('transaction_commit')
          end

          def onEraseAll(_model)
            @callback.call('erase_all')
          end
        end
      end

      if defined?(Sketchup::SelectionObserver)
        class BridgeSelectionObserver < Sketchup::SelectionObserver
          def initialize(callback)
            @callback = callback
          end

          def onSelectionBulkChange(_selection)
            @callback.call('selection_change')
          end

          def onSelectionCleared(_selection)
            @callback.call('selection_clear')
          end
        end
      end
    end
  end
end
