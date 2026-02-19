# ap_calculator QA Checklist

## Environment
- SketchUp Version: 2026
- OS: Windows | macOS
- Model Fixture: Empty model

## Precondition
- [ ] Plugin is installed/loaded.
- [ ] Open an empty model.
- [ ] Open `Plugins > Calculator`.

## Test Cases

### TC-01 Happy Path
- Steps:
1. In the calculator UI, enter `2+3*4`.
2. Press `=`.
3. Clear and enter `(2+3)*4`, then press `=`.
4. Clear and enter `2^3^2`, then press `=`.
- Expected:
- First result is `14`.
- Second result is `20`.
- Third result is `512`.
- [ ] Pass
- Notes:

### TC-02 Validation/Error Path
- Steps:
1. Enter invalid expression `2++2`.
2. Press `=`.
3. Enter empty input and press `=`.
- Expected:
- Invalid expression is handled with user-visible error feedback (alert/message), no crash.
- Empty input does not crash SketchUp or freeze dialog.
- [ ] Pass
- Notes:

### TC-03 Cross-Platform Path
- Steps:
1. Repeat TC-01 and TC-02 on Windows.
2. Repeat TC-01 and TC-02 on macOS.
- Expected:
- Same numeric results on both OSes.
- Same error behavior for invalid input.
- [ ] Pass
- Notes:

## Result Summary
- Windows: Pass | Fail | Blocked
- macOS: Pass | Fail | Blocked
- Final: Pass | Fail | Blocked
