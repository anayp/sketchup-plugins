# SketchUp Plugins Audit (2026-02-17)

Repository: `C:\Users\user\Documents\sketchup-plugins`  
Target runtime: SketchUp 2026 on Windows + macOS

## Executive Summary

- Repo integrity is strong: syntax checks passed for all `.rb` files and no missing `require_relative` targets.
- Main incompleteness is `direct_select` being intentionally disabled.
- Highest value cross-platform patch is in `ap_file_browser` UI path parent logic.
- There is no automated test suite yet.
- Several plugins are functional but need maintainability and reliability hardening.

## What Was Audited

- Top-level and recursive file inventory.
- Ruby syntax checks (`ruby -c`) across the repository.
- Loader/folder consistency and missing dependency checks.
- TODO/FIXME/incomplete marker scans.
- Static review of core plugin logic for:
  - operation lifecycle (`start_operation`/`commit`/`abort`)
  - path handling and OS assumptions
  - data persistence behavior
  - recursion/performance risk
  - user-facing failure modes

## Confirmed Findings

### P0/P1 (Finish/Patch First)

1. `direct_select` is disabled.
- Evidence: `direct_select.rb` starts with `__END__`, so no runtime code executes.
- Files:
  - `direct_select.rb:1`
  - `direct_select.rb:3`
  - `README.md:32`
- Impact: feature incomplete by design.

2. `ap_file_browser` parent path logic is Windows-biased.
- Evidence: JS uses `parts.join('\\')` and drive-letter specific logic.
- File:
  - `ap_file_browser/ui/file_browser.html:456`
  - `ap_file_browser/ui/file_browser.html:458`
- Impact: incorrect parent path behavior risk on macOS.

3. `ap_drop_to_mesh` likely uses incorrect status API target.
- Evidence: assigns `model.status_text = ...` instead of using SketchUp status API at module level.
- File:
  - `ap_drop_to_mesh.rb:39`
- Impact: potential post-operation exception and confusing failure message path.

### P2 (Stability/Quality)

4. `ap_calculator/core.rb` contains large dead commented duplicate block.
- Evidence: `=begin ... =end` block with obsolete/duplicated dialog logic.
- File:
  - `ap_calculator/core.rb:131`
- Impact: maintainability and readability debt.

5. `remove_all_tags` recursive traversal has no visited-definition guard.
- Evidence: recursive definition traversal without cycle guard.
- File:
  - `remove_all_tags.rb:60`
- Impact: risk of repeated traversal or pathological recursion in complex definition graphs.

6. `ap_tag_material_audit` duplicate-merge orchestration is operation-heavy.
- Evidence: repeated merge calls each opening operations and refreshing UI.
- Files:
  - `ap_tag_material_audit/core.rb:136`
  - `ap_tag_material_audit/core.rb:144`
- Impact: performance overhead on large models.

7. `ap_selection_sets` apply silently drops missing IDs.
- Evidence: missing entities are ignored, no user feedback on stale set members.
- File:
  - `ap_selection_sets/core.rb:84`
- Impact: weak UX/debuggability for stale selections.

### P3 (Optimization/Polish)

8. Standalone geometry scripts are operational but inconsistent in architecture and robustness:
- `0.5inch radius pipes (optimized).rb` has deeply nested rescue/flow complexity.
- `simple_wall_maker.rb` and `RoadBuilder.rb` are feature-rich but need structured acceptance tests for edge cases.
- Impact: higher regression risk during future edits.

## Cross-Platform Audit Notes (Windows + macOS)

### Good
- Most path construction in Ruby uses `File.join` and `Dir.home`.
- No hard dependency on Windows-only shells or registry APIs.
- HtmlDialog-based plugins should work on both platforms in SketchUp 2026.

### Needs Patch
- `ap_file_browser` JS path parent reconstruction should not force `\`.

### Needs Validation in Test Matrix
- File browser navigation from root path on both OSes.
- Export formats in `ap_publish_pack` when optional exporters are missing or unavailable.
- Behavior inside active edit context for geometry creation plugins.

## Plugin Status Matrix

- `ap_calculator`: Functional, needs cleanup + tests.
- `ap_length_converter`: Functional, low risk, needs basic UI/precision checks.
- `ap_file_browser`: Functional, patch required for cross-platform parent path behavior.
- `ap_mini_browser`: Functional, test embedded-site fallback and external open flow.
- `ap_model_health`: Functional, needs benchmark and warning-threshold tests.
- `ap_model_snapshot`: Functional, needs stale snapshot and diff consistency tests.
- `ap_overlay_hud`: Functional, low risk.
- `ap_publish_pack`: Functional, needs export capability preflight tests.
- `ap_select_connected_group`: Functional, includes WebDialog fallback; needs context/regression tests.
- `ap_select_groups_current_level`: Functional, low risk.
- `ap_selection_sets`: Functional, needs stale-ID feedback and persistence tests.
- `ap_stair_builder`: Functional, needs geometry sanity tests.
- `ap_tag_material_audit`: Functional, needs large-model performance pass.
- `direct_select`: Incomplete (disabled).
- `RoadBuilder`: Functional, high-complexity; needs dedicated geometry test suite.
- `simple_wall_maker`: Functional, medium complexity; needs chain/junction tests.
- `ap_drop_to_mesh`: Functional intent, patch needed for status API usage.
- `ap_crowd_scatter`: Functional intent, needs deterministic seeded regression checks.
- `0.5inch radius pipes`, `1inch radius pipes`, `GrillMaker`: Functional scripts; need consistency and non-crash tests.

## Recommended Execution Order

1. Sprint 1: fix disabled/broken behavior and cross-platform blockers.
2. Sprint 2: harden persistence and operation semantics.
3. Sprint 3: performance and geometry correctness for heavy plugins.
4. Sprint 4+: UX polish, docs, release hardening.
