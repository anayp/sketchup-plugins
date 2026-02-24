require_relative 'minitest_helper'
require_relative '../ap_model_history/core'
require 'tmpdir'
require 'fileutils'

class ModelHistoryCollection
  def initialize(items = [])
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

class ModelHistorySelection
  def to_a
    []
  end
end

class ModelHistoryView
  def write_image(**_options)
    true
  end
end

class ModelHistoryModel
  attr_reader :title, :path, :entities, :definitions, :materials, :layers, :selection, :active_view

  def initialize(path)
    @title = 'History Test Model'
    @path = path
    @entities = ModelHistoryCollection.new([])
    @definitions = []
    @materials = ModelHistoryCollection.new([])
    @layers = ModelHistoryCollection.new([])
    @selection = ModelHistorySelection.new
    @active_view = ModelHistoryView.new
  end

  def save_copy(target)
    FileUtils.cp(@path, target)
    true
  end
end

class ModelHistoryTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir('ap-model-history-test')
    @model_path = File.join(@tmpdir, 'history_target.skp')
    File.write(@model_path, 'model-data')
    @model = ModelHistoryModel.new(@model_path)
    Sketchup.instance_variable_set(:@active_model, @model)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
  end

  def test_commit_and_log_round_trip
    first = AP::Plugins::ModelHistory.commit_current_model('first checkpoint')
    sleep 1
    second = AP::Plugins::ModelHistory.commit_current_model('second checkpoint')

    log = AP::Plugins::ModelHistory.history_log

    assert_equal 2, log['total']
    assert_equal second['id'], log['commits'][0]['id']
    assert_equal first['id'], log['commits'][1]['id']
  end

  def test_checkout_restores_commit_to_target_path
    commit = AP::Plugins::ModelHistory.commit_current_model('restore test')
    checkout_path = File.join(@tmpdir, 'restored.skp')

    result = AP::Plugins::ModelHistory.checkout_commit(commit['id'], checkout_path)

    assert_equal checkout_path, result['target_path']
    assert File.exist?(checkout_path), "Expected restored file at #{checkout_path}"
  end

  def test_diff_between_commits_returns_delta_map
    first = AP::Plugins::ModelHistory.commit_current_model('first')
    sleep 1
    second = AP::Plugins::ModelHistory.commit_current_model('second')

    diff = AP::Plugins::ModelHistory.diff_commits(first['id'], second['id'])

    assert_equal first['id'], diff['from']['id']
    assert_equal second['id'], diff['to']['id']
    assert diff['delta'].is_a?(Hash)
  end
end
