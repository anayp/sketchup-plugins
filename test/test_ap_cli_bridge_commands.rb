require_relative 'minitest_helper'
require_relative '../ap_cli_bridge/core'
require 'tmpdir'
require 'fileutils'

class CliBridgeCollection
  def initialize(items)
    @items = items
  end

  def each(&block)
    @items.each(&block)
  end

  def size
    @items.size
  end

  def to_a
    @items.dup
  end
end

class CliBridgeSelection
  def initialize(items)
    @items = items
  end

  def to_a
    @items.dup
  end
end

class CliBridgeModel
  attr_reader :title, :path, :entities, :definitions, :materials, :layers, :selection, :active_view

  def initialize(title:, path:, entities:, definitions:, materials_count:, layers_count:, selection:, active_view:)
    @title = title
    @path = path
    @entities = CliBridgeCollection.new(entities)
    @definitions = definitions
    @materials = CliBridgeCollection.new(Array.new(materials_count))
    @layers = CliBridgeCollection.new(Array.new(layers_count))
    @selection = selection
    @active_view = active_view
  end

  def save_copy(target)
    FileUtils.cp(@path, target)
    true
  end
end

class CliBridgeView
  def write_image(options)
    path = options[:filename] || options['filename']
    return false if path.to_s.empty?

    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, "png-stub-#{options[:width]}x#{options[:height]}")
    true
  end
end

class CliBridgeCommandTest < Minitest::Test
  def setup
    AP::Plugins::CliBridge.reset_for_tests
    @tmpdir = Dir.mktmpdir('ap-cli-bridge-test')
    Sketchup.instance_variable_set(:@active_model, build_model)
    @original_eval_flag = ENV['AP_CLI_BRIDGE_ENABLE_EVAL']
    @original_eval_token = ENV['AP_CLI_BRIDGE_TOKEN']
    @original_capture_dir = ENV['AP_CLI_BRIDGE_CAPTURE_DIR']
  end

  def teardown
    AP::Plugins::CliBridge.reset_for_tests
    FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    ENV['AP_CLI_BRIDGE_ENABLE_EVAL'] = @original_eval_flag
    ENV['AP_CLI_BRIDGE_TOKEN'] = @original_eval_token
    ENV['AP_CLI_BRIDGE_CAPTURE_DIR'] = @original_capture_dir
  end

  def test_ping_command_returns_versioned_payload
    response = AP::Plugins::CliBridge.handle_request('id' => 'req-1', 'command' => 'ping')

    assert_equal true, response['ok']
    assert_equal 'req-1', response['id']
    assert_equal 'ap_cli_bridge', response['result']['service']
    refute_nil response['result']['version']
  end

  def test_unknown_command_returns_structured_error
    response = AP::Plugins::CliBridge.handle_request('id' => 'req-2', 'command' => 'does.not.exist')

    assert_equal false, response['ok']
    assert_equal 'invalid_command', response['error']['code']
  end

  def test_snapshot_get_reuses_cache_until_marked_dirty
    first = AP::Plugins::CliBridge.handle_request('id' => 'req-3', 'command' => 'snapshot.get')
    second = AP::Plugins::CliBridge.handle_request('id' => 'req-4', 'command' => 'snapshot.get')
    AP::Plugins::CliBridge.mark_snapshot_dirty('test')
    third = AP::Plugins::CliBridge.handle_request('id' => 'req-5', 'command' => 'snapshot.get')

    assert_equal false, first['result']['cached']
    assert_equal true, second['result']['cached']
    assert_equal false, third['result']['cached']
  end

  def test_selection_summary_reports_entity_type_counts
    response = AP::Plugins::CliBridge.handle_request('id' => 'req-6', 'command' => 'selection.summary')
    summary = response['result']['selection']

    assert_equal true, response['ok']
    assert_equal 3, summary['total']
    assert_equal 1, summary['groups']
    assert_equal 1, summary['edges']
    assert_equal 1, summary['faces']
    assert_equal 0, summary['components']
    assert_equal 0, summary['others']
  end

  def test_view_capture_writes_image_file_and_returns_path
    ENV['AP_CLI_BRIDGE_CAPTURE_DIR'] = File.join(@tmpdir, 'captures')
    response = AP::Plugins::CliBridge.handle_request(
      'id' => 'req-7',
      'command' => 'view.capture',
      'params' => { 'width' => 800, 'height' => 600 }
    )

    assert_equal true, response['ok']
    path = response['result']['path']
    assert File.exist?(path), "Expected capture file at #{path}"
    assert_equal 800, response['result']['width']
    assert_equal 600, response['result']['height']
  end

  def test_batch_run_executes_multiple_commands
    response = AP::Plugins::CliBridge.handle_request(
      'id' => 'req-8',
      'command' => 'batch.run',
      'params' => {
        'commands' => [
          { 'command' => 'ping' },
          { 'command' => 'selection.summary' }
        ]
      }
    )

    assert_equal true, response['ok']
    assert_equal 2, response['result']['results'].size
    assert_equal true, response['result']['results'].all? { |r| r['ok'] == true }
  end

  def test_ruby_eval_is_blocked_by_default
    response = AP::Plugins::CliBridge.handle_request(
      'id' => 'req-9',
      'command' => 'ruby.eval',
      'params' => { 'code' => '1 + 2' }
    )

    assert_equal false, response['ok']
    assert_equal 'eval_disabled', response['error']['code']
  end

  def test_ruby_eval_runs_when_enabled_and_token_matches
    ENV['AP_CLI_BRIDGE_ENABLE_EVAL'] = '1'
    ENV['AP_CLI_BRIDGE_TOKEN'] = 'secret-token'

    response = AP::Plugins::CliBridge.handle_request(
      'id' => 'req-10',
      'command' => 'ruby.eval',
      'params' => { 'code' => '40 + 2', 'token' => 'secret-token' }
    )

    assert_equal true, response['ok']
    assert_equal '42', response['result']['inspected']
  end

  private

  def build_model
    model_path = File.join(@tmpdir, 'bridge_test.skp')
    File.write(model_path, 'stub model content')

    top_face = Sketchup::Face.new
    top_edge = Sketchup::Edge.new
    group_face = Sketchup::Face.new
    group = Sketchup::Group.new([group_face])
    definition = Sketchup::ComponentDefinition.new([Sketchup::Edge.new])
    instance = Sketchup::ComponentInstance.new(definition)

    selection = CliBridgeSelection.new([group, top_edge, top_face])

    CliBridgeModel.new(
      title: 'Bridge Test',
      path: model_path,
      entities: [top_face, top_edge, group, instance],
      definitions: [definition],
      materials_count: 2,
      layers_count: 3,
      selection: selection,
      active_view: CliBridgeView.new
    )
  end
end
