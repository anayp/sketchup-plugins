# SketchUp Plugins

Custom SketchUp plugins for day-to-day modeling workflows.

This repository is designed for SketchUp 2026 and is maintained for both Windows and macOS.

## What Is In This Repository

1. Plugin entry files (`*.rb`) in the repo root.
2. Plugin folders with UI/core files (for example `ap_calculator/`).
3. Unit tests in `test/` for logic that can run outside SketchUp.
4. Docs/specs/checklists in `docs/`.
5. CLI bridge helper in `tools/su_cli_bridge.rb`.

Important rule: if a plugin has both `plugin_name.rb` and `plugin_name/`, copy both.

## Requirements

1. SketchUp 2026 installed.
2. Ruby available in terminal for local tests and CLI helper.
3. This repository cloned locally.

## Install On Windows (Detailed)

1. Close SketchUp completely.
2. Open the repository folder.
3. Select all plugin entry files (`*.rb`) and all plugin folders.
4. Copy them.
5. Open File Explorer and go to:
   `C:\Users\user\AppData\Roaming\SketchUp\SketchUp 2026\SketchUp\Plugins`
6. Paste files/folders into the `Plugins` folder.
7. If prompted to replace files, choose replace (when updating an existing install).
8. Start SketchUp.
9. Confirm plugins are loaded from the `Extensions` panel and `Plugins` menu.

Notes:
1. `AppData` is hidden by default in Windows.
2. Fast way to open target folder: press `Win + R` and paste:
   `%APPDATA%\SketchUp\SketchUp 2026\SketchUp\Plugins`

## Install On macOS (Detailed)

1. Close SketchUp completely.
2. Open the repository folder.
3. Select all plugin entry files (`*.rb`) and all plugin folders.
4. Copy them.
5. In Finder, press `Cmd + Shift + G`.
6. Paste this path and press Enter:
   `~/Library/Application Support/SketchUp 2026/SketchUp/Plugins`
7. Paste files/folders into the `Plugins` folder.
8. If prompted to replace files, choose replace (when updating an existing install).
9. Start SketchUp.
10. Confirm plugins are loaded from the `Extensions` panel and `Plugins` menu.

## Verify Installation

1. Open SketchUp 2026.
2. Open `Plugins` menu.
3. Confirm commands for plugins such as `Calculator`, `File Browser`, and `AP CLI Bridge` appear.
4. Run one plugin command and confirm dialog/tool opens without errors.

## Run Tests Before Deploying

From the repo root:

```bash
ruby test/run_tests.rb
```

For syntax checks:

```bash
ruby -c ap_cli_bridge/core.rb
ruby -c ap_cli_bridge.rb
ruby -c tools/su_cli_bridge.rb
```

## AP CLI Bridge Usage (Step By Step)

### In SketchUp

1. Open SketchUp with a model.
2. Go to `Plugins > AP CLI Bridge > Start Bridge`.
3. Bridge starts on `127.0.0.1:7464` by default.

### In Terminal (from repo root)

```bash
ruby tools/su_cli_bridge.rb ping
ruby tools/su_cli_bridge.rb help
ruby tools/su_cli_bridge.rb snapshot.get
ruby tools/su_cli_bridge.rb snapshot.refresh
ruby tools/su_cli_bridge.rb selection.summary
```

### Stop Bridge

1. In SketchUp, go to `Plugins > AP CLI Bridge > Stop Bridge`.
2. Optional check:
   `ruby tools/su_cli_bridge.rb bridge.status`

## Plugin Inventory

- `ap_calculator` - Lightweight expression calculator with a small HTML UI.
- `ap_length_converter` - Converts between common length units (ft, m, in, cm, yd, km, mi).
- `ap_select_connected_group` - Expands the current selection to connected geometry and groups it.
- `ap_select_groups_current_level` - Selects all groups in the current editing context.
- `ap_crowd_scatter` - Scatters component instances across a face with spacing, jitter, and preview.
- `ap_drop_to_mesh` - Drops selected groups or components onto the nearest mesh surface below.
- `ap_file_browser` - Browses folders and imports files without leaving SketchUp.
- `ap_mini_browser` - Lightweight in-SketchUp web viewer with bookmarks and home page.
- `ap_model_snapshot` - Captures a lightweight model snapshot and compares stats over time.
- `ap_model_health` - Dashboard of model stats with quick cleanup warnings.
- `ap_selection_sets` - Saves selection sets and filters by tag, material, or name.
- `ap_publish_pack` - Exports a bundle (SKP, PNG, OBJ/STL/DAE, JSON metadata).
- `ap_tag_material_audit` - Merges duplicate tags and materials.
- `ap_stair_builder` - Builds a straight stair run with optional posts.
- `ap_overlay_hud` - Small HUD panel with camera, selection, units, and bounds.
- `ap_cli_bridge` - Localhost JSON command bridge for CLI/agent automation with cached model snapshots.
- `simple_wall_maker` - Creates walls along selected edges with set thickness and height.
- `RoadBuilder` - Builds a flat road surface from selected centerline edges with width and thickness options.
- `GrillMaker` - Turns selected edges into thin cylindrical grill bars.
- `direct_select` - Box-select tool for picking entities by screen-space bounding boxes (currently disabled in code).
- `remove_all_tags` - Clears tags from entities and deletes all tags except the default.
- `select_faces_same_material` - Selects all faces in the current context that match a reference material.
- `0.5inch radius pipes` - Extrudes 0.5-inch radius cylinders along selected edges.
- `0.5inch radius pipes (optimized)` - Optimized 0.5-inch radius cylinder generation along selected edges.
- `1inch radius pipes` - Extrudes 1-inch radius cylinders along selected edges.
