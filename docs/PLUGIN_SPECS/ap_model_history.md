# ap_model_history Spec

## Metadata
- Plugin: `ap_model_history`
- Owner: `user`
- Priority: `P1`
- Sprint Target: `Sprint 2`
- Status: `baseline implemented`

## 1. Purpose
- Provide git-like history for the active SketchUp model by creating timestamped commit snapshots.
- Enable log, restore, and commit-diff workflows for conversational and batch automation.

## 2. Supported Workflows
- Primary flow:
1. Initialize history for a saved model.
2. Commit snapshots with messages.
3. Review history log.
4. Restore a commit to a new output path.
- Secondary flow:
1. Compare two commits using recorded model stats delta.
2. Access the same operations through `ap_cli_bridge` commands.

## 3. Inputs and Options
- User inputs:
  - Commit message.
  - Commit ID(s) for checkout/diff.
  - Optional restore target path.
- Defaults:
  - History folder root: `<model_dir>/.ap_model_history/<model_slug>_<pathhash>/`
  - Checkout target path: `<model_name>_checkout_<commit_id>.skp` in model directory.
- Validation rules:
  - Active model must be saved (path present).
  - `history.checkout` requires a valid commit ID.
  - `history.diff` requires `from_id` and `to_id`.

## 4. Output and Side Effects
- Geometry/data changes:
  - No direct geometry edits to active model.
- Files/preferences changed:
  - Writes commit `.skp` files under `.ap_model_history/.../commits/`.
  - Writes `manifest.json` metadata.
- UI feedback:
  - SketchUp menu actions with messagebox feedback.
  - Bridge returns structured JSON for all history commands.

## 5. Error Cases and Messages
- Invalid input:
  - Unknown commit ID returns `commit_not_found`.
- Missing selection/context:
  - No active model returns `model_unavailable`.
  - Unsaved model returns `unsaved_model`.
- Recoverable failures:
  - Save copy failure returns `commit_failed`.
  - Manifest parse/write failures return `manifest_invalid` / `manifest_write_failed`.

## 6. Cross-Platform Rules (Windows + macOS)
- Path behavior:
  - All paths built with `File.join`; no OS-specific separators hardcoded.
- Dialog/OS interaction:
  - Uses SketchUp menu, input box, and messagebox APIs only.
- Known platform differences:
  - File permission behavior may vary; errors are surfaced with explicit codes/messages.

## 7. Acceptance Tests
- [x] AT-01 Commit and log round trip.
- [x] AT-02 Checkout restores commit file to requested path.
- [x] AT-03 Diff returns stat delta map between two commits.
- [ ] AT-04 Manual test in SketchUp 2026 on Windows.
- [ ] AT-05 Manual test in SketchUp 2026 on macOS.

## 8. Non-Goals and Known Limits
- Not covered by this plugin:
  - Binary diffs/merges of `.skp` contents.
  - Branching/rebasing semantics equivalent to full git.
- Current limitations:
  - Stores full copy per commit (disk-heavy for large models).
  - Diff is metadata/stat based, not geometric delta.

## 9. Change Log
- 2026-02-24: Initial implementation (init/commit/log/checkout/diff + bridge integration + tests).
