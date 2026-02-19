# Test Harness

Run all unit tests:

```bash
ruby test/run_tests.rb
```

Current scope:
- Pure logic tests runnable outside SketchUp.
- SketchUp APIs are stubbed via `test/support/sketchup.rb`.
- Bridge command/caching behavior is covered by `test/test_ap_cli_bridge_commands.rb`.
