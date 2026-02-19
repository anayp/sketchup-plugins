require_relative 'minitest_helper'
require_relative '../ap_model_snapshot/core'

class ModelSnapshotDiffTest < Minitest::Test
  def test_build_diff_handles_string_and_symbol_keys
    previous = {
      'stats' => {
        'faces' => 10,
        'edges' => 20,
        'groups' => 2
      }
    }

    current = {
      stats: {
        faces: 15,
        edges: 12,
        groups: 2,
        materials: 5
      }
    }

    diff = AP::Plugins::ModelSnapshot.build_diff(previous, current)

    assert_equal 5, diff[:faces]
    assert_equal(-8, diff[:edges])
    assert_equal 0, diff[:groups]
    assert_equal 5, diff[:materials]
  end
end
