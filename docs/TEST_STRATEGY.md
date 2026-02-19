# Test Strategy (Spec-Driven, Windows + macOS)

## Objectives

- Prevent regressions while finishing incomplete plugins.
- Make behavior explicit via plugin-level specs and acceptance tests.
- Ensure parity on SketchUp 2026 for Windows and macOS.

## Test Layers

## 1. Spec Layer

For each plugin create a spec document with:
- Purpose and supported workflows.
- Inputs and expected outputs.
- Error cases and user messaging.
- Cross-platform notes.
- Non-goals and known limits.

Suggested path:
- `docs/PLUGIN_SPECS/<plugin_name>.md`

## 2. Unit Layer (Ruby, outside SketchUp)

Target only extractable pure logic:
- parsing, normalization, data transforms, diff calculations.
- deterministic geometry helper math where possible.

Approach:
- Use `minitest` (simple and standard with Ruby).
- Add thin stubs/mocks for SketchUp API boundaries.

Candidate first unit targets:
- `ap_calculator` expression evaluator.
- `ap_file_browser` path normalization helpers.
- `ap_model_snapshot` diff builder.

## 3. Integration Layer (inside SketchUp)

Manual scripted checks in SketchUp for UI/actions and geometry creation.

Checklist format:
- Precondition
- Steps
- Expected result
- Pass/Fail + notes
- OS + SketchUp build

Store checklists:
- `docs/QA_CHECKLISTS/<plugin_name>.md`

## 4. Regression Layer

Before each sprint closes:
- Run focused regression for modified plugins.
- Run smoke checks for all high-priority plugins:
  - file browser
  - publish pack
  - model health/snapshot
  - selection sets
  - road/wall/pipes tools

## Cross-Platform Gates

A change is not done until verified on both:
- Windows (SketchUp 2026)
- macOS (SketchUp 2026)

Required cross-platform assertions:
- Path behavior (separator, root traversal, parent folder behavior).
- Dialog load and callback behavior.
- File export/import behavior where applicable.
- No platform-specific exceptions in Ruby console.

## Definition of Done (Per Plugin Change)

1. Spec updated with behavior change.
2. Unit tests added/updated where logic is testable outside SketchUp.
3. Integration checklist executed for changed flows.
4. Windows + macOS verification recorded.
5. Errors are actionable and user-facing text is clear.

## Initial Priority Test Matrix

### `ap_file_browser`
- Navigate into and back out of nested folders.
- Parent navigation at root boundary.
- Import supported model/file from dialog.
- Verify behavior on Windows and macOS path formats.

### `ap_drop_to_mesh`
- Drop valid target set onto mesh.
- Handle no-hit case without corrupting operation state.
- Verify no post-commit exception path.

### `direct_select`
- If re-enabled: drag-select behavior, nested group hit behavior, and cancel/retry path.
- If archived: ensure it stays non-loadable and documented.

### `RoadBuilder` / `simple_wall_maker`
- Open chain, closed loop, branching selection behavior.
- Degenerate/invalid edge input handling.
- Geometry orientation and thickness correctness.

### `ap_selection_sets`
- Save/apply/delete lifecycle.
- Stale persistent IDs after entity deletion.
- Filter flows for tag/material/name.

## Tooling Plan

Near-term:
- Keep tests repo-local and runnable from terminal without SketchUp.
- Use markdown QA checklists for in-app testing.

Mid-term:
- Add scripted harness wrappers for repeatable SketchUp manual test sessions.
- Add performance baseline snapshots for heavy geometry plugins.

