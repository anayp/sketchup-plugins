# Spec-Driven Sprint Roadmap

This roadmap is for finishing/patching `sketchup-plugins` with test-based delivery and Windows/macOS compatibility.

## Sprint 0 - Spec and Harness Foundation (2-3 days)

Goal: establish repeatable delivery mechanics before feature changes.

### Scope
- Create plugin spec template.
- Define acceptance test template per plugin.
- Set up lightweight Ruby test harness for pure logic and helpers.
- Define manual integration checklist for SketchUp 2026 on Windows + macOS.

### Deliverables
- `docs/TEST_STRATEGY.md` finalized and approved.
- `docs/PLUGIN_SPECS/` with one spec file per plugin (empty template + priority tags).
- Initial smoke test checklist.

### Exit Criteria
- Every plugin has a named owner, priority, and acceptance checklist.
- CI-independent local command exists to run non-SketchUp unit tests.

## Sprint 1 - Critical Patches and Cross-Platform Fixes (3-5 days)

Goal: remove known blockers and incomplete items.

### Scope
- Patch `ap_file_browser` parent path logic for Windows/macOS-safe behavior.
- Patch `ap_drop_to_mesh` status text handling.
- Decide `direct_select` path:
  - Option A: re-enable with spec and tests.
  - Option B: keep disabled and document as intentionally archived.
- Clean dead commented block in `ap_calculator/core.rb`.

### Test Cases (minimum)
- `ap_file_browser` parent navigation:
  - Windows drive root (`C:\`)
  - Windows deep path
  - macOS root (`/`) and nested path
- `ap_drop_to_mesh`:
  - successful drop path
  - no-hit path
  - no exception after commit
- `ap_calculator`:
  - arithmetic validity matrix
  - invalid expression error path

### Exit Criteria
- No known P0/P1 findings remain unresolved.
- All Sprint 1 patches validated on both OSes.

## Sprint 2 - Data Integrity and Reliability (4-6 days)

Goal: harden persistence-heavy and merge-heavy plugins.

### Scope
- `ap_selection_sets`: report stale IDs and improve apply feedback.
- `ap_tag_material_audit`: batch duplicate merge flow into fewer operations, reduce repeated UI updates.
- `remove_all_tags`: add visited-definition guard in recursion.

### Test Cases (minimum)
- Selection set save/apply/delete with deleted entities.
- Tag/material merge correctness for:
  - case-insensitive duplicates
  - default tag protection
  - locked/deletion-failure scenarios
- Recursive traversal on nested component definitions without runaway recursion.

### Exit Criteria
- Reliability fixes merged with regression checks.
- Clear user feedback for partial success paths.

## Sprint 3 - Geometry Correctness and Performance (5-8 days)

Goal: improve robustness for geometry generators and heavy operations.

### Scope
- Priority plugins:
  - `RoadBuilder`
  - `simple_wall_maker`
  - `ap_crowd_scatter`
  - `0.5inch radius pipes (optimized)`
- Add deterministic scenarios for seeded/randomized behavior.
- Validate behavior for active edit context vs model root.

### Test Cases (minimum)
- Junctions, loops, and open chains.
- Degenerate input (zero-length edges, vertical-only sets, empty selection).
- Performance baseline for large edge counts/model sizes.

### Exit Criteria
- No crashes on stress cases in manual QA.
- Measured performance baseline captured and documented.

## Sprint 4 - UX and Consistency Pass (3-4 days)

Goal: standardize plugin UX and error semantics.

### Scope
- Normalize menu naming, user messages, and status output style.
- Standardize operation naming and failure handling.
- Document plugin behavior differences and limitations.

### Exit Criteria
- Consistent UX language across plugin dialogs and menus.
- Known limitations documented per plugin spec.

## Sprint 5 - Release Hardening (2-3 days)

Goal: shipping confidence.

### Scope
- Full regression pass on Windows + macOS.
- Final packaging/instructions review.
- Release notes with fixed issues and compatibility statement.

### Exit Criteria
- Sign-off checklist complete on both OSes.
- Versioned release tag with changelog.

## Backlog Priorities

- `P0`: direct functionality blocked or disabled.
- `P1`: cross-platform or correctness risk.
- `P2`: reliability/performance debt.
- `P3`: UX polish and consistency.

## Working Rules

- No plugin change merges without:
  - updated spec section
  - acceptance tests updated
  - Windows/macOS checklist entries completed
- Any behavior change must include before/after notes in plugin spec.

