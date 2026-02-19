# Test Harness

Run all unit tests:

```bash
ruby test/run_tests.rb
```

Current scope:
- Pure logic tests runnable outside SketchUp.
- SketchUp APIs are stubbed via `test/support/sketchup.rb`.

Current known failures:
- `test/test_calculator_evaluator.rb` intentionally captures real defects in calculator precedence/associativity.
