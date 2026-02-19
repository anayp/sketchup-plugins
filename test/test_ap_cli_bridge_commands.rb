require_relative 'minitest_helper'
require_relative '../ap_cli_bridge/core'

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
  attr_reader :title, :path, :entities, :definitions, :materials, :layers, :selection

  def initialize(title:, path:, entities:, definitions:, materials_count:, layers_count:, selection:)
    @title = title
    @path = path
    @entities = CliBridgeCollection.new(entities)
    @definitions = definitions
    @materials = CliBridgeCollection.new(Array.new(materials_count))
    @layers = CliBridgeCollection.new(Array.new(layers_count))
    @selection = selection
  end
end

class CliBridgeCommandTest < Minitest::Test
  def setup
    AP::Plugins::CliBridge.reset_for_tests
    Sketchup.instance_variable_set(:@active_model, build_model)
  end

  def teardown
    AP::Plugins::CliBridge.reset_for_tests
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

  private

  def build_model
    top_face = Sketchup::Face.new
    top_edge = Sketchup::Edge.new
    group_face = Sketchup::Face.new
    group = Sketchup::Group.new([group_face])
    definition = Sketchup::ComponentDefinition.new([Sketchup::Edge.new])
    instance = Sketchup::ComponentInstance.new(definition)

    selection = CliBridgeSelection.new([group, top_edge, top_face])

    CliBridgeModel.new(
      title: 'Bridge Test',
      path: 'C:/tmp/bridge_test.skp',
      entities: [top_face, top_edge, group, instance],
      definitions: [definition],
      materials_count: 2,
      layers_count: 3,
      selection: selection
    )
  end
end
