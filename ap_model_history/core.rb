require 'sketchup.rb'
require 'json'
require 'fileutils'
require 'securerandom'
require 'time'
require 'digest'

module AP
  module Plugins
    module ModelHistory
      HISTORY_ROOT_DIR = '.ap_model_history'.freeze
      SCHEMA_VERSION = 1

      class HistoryError < StandardError
        attr_reader :code, :data

        def initialize(code, message, data = nil)
          super(message)
          @code = code
          @data = data
        end
      end

      module_function

      def ensure_history_for_model(model = Sketchup.active_model)
        model_path = validated_model_path(model)
        root_dir = history_root_for_path(model_path)
        commits_dir = File.join(root_dir, 'commits')
        manifest_path = File.join(root_dir, 'manifest.json')

        FileUtils.mkdir_p(commits_dir)
        manifest = read_manifest(manifest_path)
        unless manifest
          manifest = default_manifest(model, model_path)
          write_manifest(manifest_path, manifest)
        end

        {
          'history_root' => root_dir,
          'manifest_path' => manifest_path,
          'commit_count' => Array(manifest['commits']).size
        }
      end

      def commit_current_model(message = '', model = Sketchup.active_model)
        model_path = validated_model_path(model)
        root_dir = history_root_for_path(model_path)
        commits_dir = File.join(root_dir, 'commits')
        manifest_path = File.join(root_dir, 'manifest.json')

        FileUtils.mkdir_p(commits_dir)
        manifest = read_manifest(manifest_path) || default_manifest(model, model_path)

        commit_id = build_commit_id
        filename = "#{commit_id}.skp"
        commit_path = File.join(commits_dir, filename)

        ok = model.respond_to?(:save_copy) ? model.save_copy(commit_path) : false
        raise HistoryError.new('commit_failed', 'SketchUp model save_copy failed.') unless ok

        commit = {
          'id' => commit_id,
          'timestamp' => Time.now.utc.iso8601,
          'message' => message.to_s,
          'file' => filename,
          'size_bytes' => safe_file_size(commit_path),
          'stats' => collect_model_stats(model)
        }

        manifest['commits'] ||= []
        manifest['commits'] << commit
        manifest['updated_at'] = Time.now.utc.iso8601
        write_manifest(manifest_path, manifest)

        commit.merge('history_root' => root_dir)
      end

      def history_log(limit: nil, model: Sketchup.active_model)
        model_path = validated_model_path(model)
        root_dir = history_root_for_path(model_path)
        manifest_path = File.join(root_dir, 'manifest.json')
        manifest = read_manifest(manifest_path) || default_manifest(model, model_path)
        commits = Array(manifest['commits'])
        ordered = commits.sort_by { |entry| entry['timestamp'].to_s }.reverse
        ordered = ordered.first(limit) if limit && limit.positive?

        {
          'history_root' => root_dir,
          'total' => commits.size,
          'commits' => ordered
        }
      end

      def checkout_commit(commit_id, target_path = nil, model = Sketchup.active_model)
        model_path = validated_model_path(model)
        root_dir = history_root_for_path(model_path)
        manifest_path = File.join(root_dir, 'manifest.json')
        manifest = read_manifest(manifest_path)
        raise HistoryError.new('history_missing', 'History is not initialized for this model.') unless manifest

        commits_dir = File.join(root_dir, 'commits')
        commit = find_commit(manifest, commit_id)
        source_path = File.join(commits_dir, commit['file'].to_s)
        raise HistoryError.new('commit_missing_file', "Commit file is missing: #{source_path}") unless File.exist?(source_path)

        destination = target_path.to_s.strip
        destination = default_checkout_path(model_path, commit['id']) if destination.empty?
        destination = File.expand_path(destination)
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(source_path, destination)

        {
          'commit_id' => commit['id'],
          'source_path' => source_path,
          'target_path' => destination
        }
      end

      def diff_commits(from_id, to_id, model = Sketchup.active_model)
        model_path = validated_model_path(model)
        root_dir = history_root_for_path(model_path)
        manifest_path = File.join(root_dir, 'manifest.json')
        manifest = read_manifest(manifest_path)
        raise HistoryError.new('history_missing', 'History is not initialized for this model.') unless manifest

        from = find_commit(manifest, from_id)
        to = find_commit(manifest, to_id)

        from_stats = hash_string_keys(from['stats'] || {})
        to_stats = hash_string_keys(to['stats'] || {})
        delta = {}
        (from_stats.keys | to_stats.keys).each do |key|
          delta[key] = to_stats.fetch(key, 0).to_i - from_stats.fetch(key, 0).to_i
        end

        {
          'from' => commit_summary(from),
          'to' => commit_summary(to),
          'delta' => delta
        }
      end

      def collect_model_stats(model)
        if defined?(AP::Plugins::CliBridge) && AP::Plugins::CliBridge.respond_to?(:collect_stats)
          AP::Plugins::CliBridge.collect_stats(model)
        else
          fallback_collect_stats(model)
        end
      end

      def fallback_collect_stats(model)
        entities = model.respond_to?(:entities) ? model.entities : []
        faces = 0
        edges = 0
        groups = 0
        components = 0

        entities.each do |entity|
          case entity
          when Sketchup::Face
            faces += 1
          when Sketchup::Edge
            edges += 1
          when Sketchup::Group
            groups += 1
          when Sketchup::ComponentInstance
            components += 1
          end
        end

        {
          'faces' => faces,
          'edges' => edges,
          'groups' => groups,
          'component_instances' => components
        }
      end

      def history_root_for_path(model_path)
        model_dir = File.dirname(model_path)
        basename = File.basename(model_path, '.*')
        slug = sanitize_component(basename)
        digest = Digest::SHA1.hexdigest(model_path)[0, 8]
        File.join(model_dir, HISTORY_ROOT_DIR, "#{slug}_#{digest}")
      end

      def sanitize_component(text)
        cleaned = text.to_s.gsub(/[^a-zA-Z0-9_\-]+/, '_').gsub(/_+/, '_').gsub(/\A_+|_+\z/, '')
        cleaned.empty? ? 'model' : cleaned
      end

      def default_checkout_path(model_path, commit_id)
        dir = File.dirname(model_path)
        base = File.basename(model_path, '.*')
        File.join(dir, "#{base}_checkout_#{commit_id}.skp")
      end

      def validated_model_path(model)
        raise HistoryError.new('model_unavailable', 'No active model available.') unless model

        model_path = model.respond_to?(:path) ? model.path.to_s : ''
        if model_path.strip.empty?
          raise HistoryError.new('unsaved_model', 'Save the model once before using history.')
        end

        model_path
      end

      def read_manifest(path)
        return nil unless File.exist?(path)

        JSON.parse(File.read(path))
      rescue StandardError => e
        raise HistoryError.new('manifest_invalid', "Could not parse history manifest: #{e.message}")
      end

      def write_manifest(path, payload)
        File.write(path, JSON.pretty_generate(payload))
      rescue StandardError => e
        raise HistoryError.new('manifest_write_failed', "Could not write history manifest: #{e.message}")
      end

      def default_manifest(model, model_path)
        {
          'schema_version' => SCHEMA_VERSION,
          'created_at' => Time.now.utc.iso8601,
          'updated_at' => Time.now.utc.iso8601,
          'model' => {
            'title' => model.respond_to?(:title) ? model.title.to_s : '',
            'path' => model_path
          },
          'commits' => []
        }
      end

      def build_commit_id
        "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(3)}"
      end

      def safe_file_size(path)
        File.size(path)
      rescue StandardError
        0
      end

      def find_commit(manifest, commit_id)
        commits = Array(manifest['commits'])
        commit = commits.find { |entry| entry['id'].to_s == commit_id.to_s }
        raise HistoryError.new('commit_not_found', "Commit not found: #{commit_id}") unless commit

        commit
      end

      def hash_string_keys(hash)
        hash.each_with_object({}) { |(key, value), acc| acc[key.to_s] = value }
      end

      def commit_summary(commit)
        {
          'id' => commit['id'],
          'timestamp' => commit['timestamp'],
          'message' => commit['message']
        }
      end

      def init_with_feedback
        info = ensure_history_for_model
        UI.messagebox("Model History initialized.\nRoot: #{info['history_root']}")
      rescue HistoryError => e
        UI.messagebox("Model History init failed: #{e.message}")
      end

      def commit_with_feedback
        values = UI.inputbox(['Commit message'], [''], 'Model History Commit')
        return unless values

        commit = commit_current_model(values[0].to_s)
        UI.messagebox("Committed #{commit['id']}\nMessage: #{commit['message']}")
      rescue HistoryError => e
        UI.messagebox("Model History commit failed: #{e.message}")
      end

      def show_log_with_feedback
        log = history_log(limit: 10)
        if log['commits'].empty?
          UI.messagebox('No history commits yet.')
          return
        end

        lines = log['commits'].map { |entry| "#{entry['id']}  #{entry['timestamp']}  #{entry['message']}" }
        UI.messagebox("Latest commits:\n#{lines.join("\n")}")
      rescue HistoryError => e
        UI.messagebox("Model History log failed: #{e.message}")
      end

      unless file_loaded?(__FILE__)
        menu = UI.menu('Plugins').add_submenu('AP Model History')
        menu.add_item('Initialize History') { init_with_feedback }
        menu.add_item('Commit Current Model...') { commit_with_feedback }
        menu.add_item('Show Latest Commits') { show_log_with_feedback }
        file_loaded(__FILE__)
      end
    end
  end
end
