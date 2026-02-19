# ap_file_browser QA Checklist

## Environment
- SketchUp Version: 2026
- OS: Windows | macOS
- Model Fixture: Folder tree with at least 3 nested levels and one `.skp` file

## Precondition
- [ ] Plugin is installed/loaded.
- [ ] Open `Plugins > File Browser`.
- [ ] Confirm starting path is visible in path input.

## Test Cases

### TC-01 Happy Path
- Steps:
1. Navigate into a nested folder by double-clicking directories.
2. Select a non-model file and click `Import`.
3. Select a `.skp` file and verify `Open Model` button enables.
4. Click `Open Model`.
- Expected:
- Folder listing updates correctly at each level.
- Import action runs without dialog crash.
- `Open Model` only enables for `.skp`.
- Opening `.skp` triggers model open flow.
- [ ] Pass
- Notes:

### TC-02 Validation/Error Path
- Steps:
1. Enter a non-existent path in the path input and click `Go`.
2. Select a directory and verify `Import` stays disabled.
3. Select a non-`.skp` file and verify `Open Model` stays disabled.
- Expected:
- Clear folder-not-found error is shown.
- Buttons enforce file-type constraints correctly.
- [ ] Pass
- Notes:

### TC-03 Cross-Platform Path
- Steps:
1. On Windows, navigate to a deep path and repeatedly click `Up` until drive root.
2. On macOS, navigate to a deep path and repeatedly click `Up` until `/`.
3. Verify `Up` at root does not break path navigation.
- Expected:
- Windows uses correct parent chain ending at drive root (for example `C:\`).
- macOS uses correct parent chain ending at `/`.
- No malformed path generation (mixed separators or empty invalid path).
- [ ] Pass
- Notes:

## Result Summary
- Windows: Pass | Fail | Blocked
- macOS: Pass | Fail | Blocked
- Final: Pass | Fail | Blocked
