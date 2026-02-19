# ap_drop_to_mesh QA Checklist

## Environment
- SketchUp Version: 2026
- OS: Windows | macOS
- Model Fixture: Model with a terrain mesh and 3+ groups/components above mesh

## Precondition
- [ ] Plugin is installed/loaded.
- [ ] Open model containing drop targets above a mesh.
- [ ] Select only groups/components intended to drop.

## Test Cases

### TC-01 Happy Path
- Steps:
1. Select 3+ groups/components positioned above a mesh.
2. Run `Plugins > Drop Selection to Mesh`.
3. Inspect final positions and status feedback.
- Expected:
- Selected items move down to first mesh hit below each item.
- Operation commits successfully with no exception dialog.
- Status feedback indicates dropped count when no skips.
- [ ] Pass
- Notes:

### TC-02 Validation/Error Path
- Steps:
1. Select at least one group/component with no mesh below.
2. Run `Drop Selection to Mesh`.
3. Repeat with empty selection.
- Expected:
- Partial success path shows dropped/skipped counts.
- Empty selection shows clear prompt and exits safely.
- No hidden-state leakage after failure/cancel path.
- [ ] Pass
- Notes:

### TC-03 Cross-Platform Path
- Steps:
1. Run TC-01 and TC-02 on Windows.
2. Run TC-01 and TC-02 on macOS.
- Expected:
- Same move behavior and messaging semantics on both OSes.
- No platform-specific status API errors.
- [ ] Pass
- Notes:

## Result Summary
- Windows: Pass | Fail | Blocked
- macOS: Pass | Fail | Blocked
- Final: Pass | Fail | Blocked
