# SketchUp Plugins

Custom SketchUp plugins created for day-to-day modeling workflows.

## Install

Copy the `.rb` files and any same-named folders into:
`C:\Users\anay.pantojee\AppData\Roaming\SketchUp\SketchUp 2026\SketchUp\Plugins`

Restart SketchUp to load the plugins. For plugins with a matching folder (for example `ap_calculator.rb` and `ap_calculator/`), keep the file and folder together.

## Plugins

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
- `simple_wall_maker` - Creates walls along selected edges with set thickness and height.
- `RoadBuilder` - Builds a flat road surface from selected centerline edges with width and thickness options.
- `GrillMaker` - Turns selected edges into thin cylindrical grill bars.
- `direct_select` - Box-select tool for picking entities by screen-space bounding boxes (currently disabled in code).
- `remove_all_tags` - Clears tags from entities and deletes all tags except the default.
- `select_faces_same_material` - Selects all faces in the current context that match a reference material.
- `0.5inch radius pipes` - Extrudes 0.5-inch radius cylinders along selected edges.
- `0.5inch radius pipes (optimized)` - Optimized 0.5-inch radius cylinder generation along selected edges.
- `1inch radius pipes` - Extrudes 1-inch radius cylinders along selected edges.
