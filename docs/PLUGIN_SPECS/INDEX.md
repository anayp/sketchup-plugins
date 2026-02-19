# Plugin Spec Index

Use this index to track spec ownership, priority, and sprint target.

| Plugin | Priority | Sprint Target | Status |
|---|---|---|---|
| direct_select | P0 | Sprint 1 | Disabled; decision required (restore or archive) |
| ap_file_browser | P1 | Sprint 1 | Cross-platform parent-path patch required |
| ap_drop_to_mesh | P1 | Sprint 1 | Status API patch required |
| ap_calculator | P1 | Sprint 1 | Dead code cleanup + evaluator tests |
| ap_cli_bridge | P1 | Sprint 2 | Baseline localhost bridge + cached snapshot API |
| ap_selection_sets | P2 | Sprint 2 | Stale ID feedback and resilience |
| ap_tag_material_audit | P2 | Sprint 2 | Merge flow optimization |
| remove_all_tags | P2 | Sprint 2 | Recursive traversal guard |
| ap_publish_pack | P2 | Sprint 2/3 | Export preflight + error clarity |
| ap_model_snapshot | P2 | Sprint 2/3 | Diff and persistence regression tests |
| ap_model_health | P2 | Sprint 3 | Performance/stress baseline |
| RoadBuilder | P2 | Sprint 3 | Geometry/perf regression suite |
| simple_wall_maker | P2 | Sprint 3 | Chain/junction correctness tests |
| ap_crowd_scatter | P2 | Sprint 3 | Deterministic seed behavior validation |
| 0.5inch radius pipes (optimized) | P2 | Sprint 3 | Flow simplification and stress tests |
| 0.5inch radius pipes | P3 | Sprint 4 | Consistency/polish |
| 1inch radius pipes | P3 | Sprint 4 | Consistency/polish |
| GrillMaker | P3 | Sprint 4 | Consistency/polish |
| ap_length_converter | P3 | Sprint 4 | UI/conversion sanity checks |
| ap_mini_browser | P3 | Sprint 4 | Embedding/external-open QA |
| ap_overlay_hud | P3 | Sprint 4 | Smoke QA |
| ap_select_connected_group | P3 | Sprint 4 | Context + fallback QA |
| ap_select_groups_current_level | P3 | Sprint 4 | Smoke QA |
| ap_stair_builder | P3 | Sprint 4 | Geometry sanity checks |
| select_faces_same_material | P3 | Sprint 4 | Selection context QA |

## Spec Template

Create one file per plugin: `docs/PLUGIN_SPECS/<plugin_name>.md`

Use this structure:

1. Purpose
2. Supported workflows
3. Inputs and options
4. Output/side effects
5. Error cases and user messages
6. Cross-platform rules (Windows/macOS)
7. Acceptance tests
8. Non-goals and known limits
9. Change log
