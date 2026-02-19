require_relative 'minitest_helper'
require_relative '../ap_calculator/core'

class CalculatorEvaluatorTest < Minitest::Test
  def test_basic_precedence
    result = AP::Plugins::Calculator::Evaluator.evaluate('2+3*4')
    assert_equal 14.0, result
  end

  def test_parentheses
    result = AP::Plugins::Calculator::Evaluator.evaluate('(2+3)*4')
    assert_equal 20.0, result
  end

  def test_right_associative_exponent
    result = AP::Plugins::Calculator::Evaluator.evaluate('2^3^2')
    assert_equal 512.0, result
  end

  def test_invalid_expression_raises_argument_error
    assert_raises(ArgumentError) do
      AP::Plugins::Calculator::Evaluator.evaluate('2++2')
    end
  end
end
