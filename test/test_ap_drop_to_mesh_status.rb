require_relative 'minitest_helper'
require_relative '../ap_drop_to_mesh'

class APDropToMeshStatusTest < Minitest::Test
  def teardown
    sc = Sketchup.singleton_class
    if sc.method_defined?(:set_status_text)
      sc.send(:remove_method, :set_status_text)
    end

    if Object.const_defined?(:SB_PROMPT)
      Object.send(:remove_const, :SB_PROMPT)
    end

    Sketchup.status_text = nil if Sketchup.respond_to?(:status_text=)
  end

  def test_uses_set_status_text_with_prompt_when_available
    Object.const_set(:SB_PROMPT, 1)
    calls = []

    Sketchup.define_singleton_method(:set_status_text) do |*args|
      calls << args
      true
    end

    APDropToMesh.send(:set_status, 'done')

    assert_equal [['done', 1]], calls
  end

  def test_falls_back_to_single_arg_when_prompt_call_fails
    Object.const_set(:SB_PROMPT, 1)
    calls = []

    Sketchup.define_singleton_method(:set_status_text) do |*args|
      calls << args
      raise ArgumentError, 'arity mismatch' if args.length == 2
      true
    end

    APDropToMesh.send(:set_status, 'done')

    assert_equal [['done', 1], ['done']], calls
  end

  def test_uses_status_text_setter_if_set_status_text_missing
    APDropToMesh.send(:set_status, 'done')

    assert_equal 'done', Sketchup.status_text
  end
end
