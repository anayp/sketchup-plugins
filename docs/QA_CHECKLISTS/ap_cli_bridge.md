# ap_cli_bridge QA Checklist

## Environment
- SketchUp Version: `2026`
- OS: `Windows | macOS`
- Model Fixture: `small mixed-entity test model`

## Precondition
- [ ] Plugin is installed/loaded.
- [ ] Required sample model is open.
- [ ] Bridge started from `Plugins > AP CLI Bridge > Start Bridge`.

## Test Cases

### TC-01 Happy Path
- Steps:
1. Run `ruby tools/su_cli_bridge.rb ping`.
2. Run `ruby tools/su_cli_bridge.rb snapshot.get`.
3. Run `ruby tools/su_cli_bridge.rb selection.summary`.
- Expected:
  - All commands return valid JSON with `ok: true`.
- [ ] Pass
- Notes:

### TC-02 Validation/Error Path
- Steps:
1. Send an unsupported command: `ruby tools/su_cli_bridge.rb unsupported.command`.
2. Stop bridge from SketchUp.
3. Re-run `ruby tools/su_cli_bridge.rb ping`.
- Expected:
  - Step 1 returns `invalid_command`.
  - Step 3 reports connection failure.
- [ ] Pass
- Notes:

### TC-03 Regression/Cross-Platform Path
- Steps:
1. Run `snapshot.get` twice with no model edits.
2. Make a geometry edit.
3. Run `snapshot.get` again.
- Expected:
  - Second call reports `cached: true`.
  - Post-edit call reports `cached: false`.
- [ ] Pass
- Notes:

## Result Summary
- Windows: `Pass | Fail | Blocked`
- macOS: `Pass | Fail | Blocked`
- Final: `Pass | Fail | Blocked`
