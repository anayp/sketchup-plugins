# ap_model_history QA Checklist

## Environment
- SketchUp Version: `2026`
- OS: `Windows | macOS`
- Model Fixture: `saved sample model with known filename`

## Precondition
- [ ] Plugin is installed/loaded.
- [ ] Required sample model is open and saved to disk.
- [ ] `Plugins > AP Model History` menu is visible.

## Test Cases

### TC-01 Happy Path
- Steps:
1. Run `Initialize History`.
2. Run `Commit Current Model...` with message `baseline`.
3. Run `Show Latest Commits`.
- Expected:
  - History folder and manifest are created.
  - Commit appears in log with message and timestamp.
- [ ] Pass
- Notes:

### TC-02 Validation/Error Path
- Steps:
1. Open an unsaved model.
2. Run `Commit Current Model...`.
- Expected:
  - Plugin blocks operation with clear unsaved-model error.
- [ ] Pass
- Notes:

### TC-03 Regression/Cross-Platform Path
- Steps:
1. Commit twice.
2. Copy commit ID from log.
3. Run bridge checkout command:
   `ruby tools/su_cli_bridge.rb history.checkout --params "{\"commit_id\":\"<id>\"}"`
- Expected:
  - Restored `.skp` file is created successfully.
  - Path handling is valid on both Windows and macOS.
- [ ] Pass
- Notes:

## Result Summary
- Windows: `Pass | Fail | Blocked`
- macOS: `Pass | Fail | Blocked`
- Final: `Pass | Fail | Blocked`
