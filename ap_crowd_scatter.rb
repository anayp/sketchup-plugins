require "sketchup.rb"

module APCrowdScatter
  extend self

  PREVIEW_GROUP_NAME = "AP Crowd Preview".freeze
  MAX_COUNT_CAP = 2500

  POINT_INSIDE = defined?(Sketchup::Face::PointInside) ? Sketchup::Face::PointInside : 1
  POINT_ON_FACE = defined?(Sketchup::Face::PointOnFace) ? Sketchup::Face::PointOnFace : 2
  POINT_ON_EDGE = defined?(Sketchup::Face::PointOnEdge) ? Sketchup::Face::PointOnEdge : 3
  POINT_ON_VERTEX = defined?(Sketchup::Face::PointOnVertex) ? Sketchup::Face::PointOnVertex : 4

  def run
    model = Sketchup.active_model
    selection = model.selection.to_a
    face = pick_face(selection)
    crowd_defs = pick_crowd_definitions(selection)

    unless face && crowd_defs.any?
      UI.messagebox("Select one face (placement area) and at least one crowd component instance.")
      return
    end

    parent_entities = face.parent.entities
    existing_points = existing_preview_points(parent_entities)

    settings = prompt_settings(model, has_preview: existing_points.any?)
    return unless settings

    target_count, min_spacing, jitter, scale_jitter, preview_only, seed = settings
    min_spacing = [min_spacing.to_f.abs, 0.1].max
    jitter = clamp(jitter.to_f, 0.0, 1.0)
    scale_jitter = [scale_jitter.to_f, 0.0].max
    rng = seed.to_i.zero? ? Random.new : Random.new(seed.to_i)

    points = []

    if existing_points.any?
      choice = UI.messagebox("Found an existing crowd preview with #{existing_points.size} markers.\nYes = place crowd there, No = discard preview and resample, Cancel = stop.", MB_YESNOCANCEL)
      case choice
      when IDYES
        points = existing_points
        preview_only = false
      when IDNO
        clear_preview(parent_entities)
      else
        return
      end
    end

    if points.empty?
      target_count = auto_count_from_area(face, min_spacing) if target_count.to_i <= 0
      target_count = [target_count.to_i, MAX_COUNT_CAP].min
      points = scatter_points(face, target_count, min_spacing, jitter, rng)
    end

    if points.empty?
      UI.messagebox("No valid placements found. Try reducing spacing, jitter, or target count.")
      return
    end

    op_name = preview_only ? "AP Crowd Preview" : "AP Crowd Scatter"
    model.start_operation(op_name, true)
    clear_preview(parent_entities)

    if preview_only
      draw_preview(parent_entities, points, face.normal)
      model.commit_operation
      Sketchup.status_text = "Crowd preview: #{points.size} markers." if Sketchup.respond_to?(:status_text=)
    else
      placed = place_crowd(parent_entities, points, crowd_defs, face.normal, scale_jitter, rng)
      clear_preview(parent_entities)
      model.commit_operation
      Sketchup.status_text = "Crowd placed: #{placed} people." if Sketchup.respond_to?(:status_text=)
    end
  rescue => e
    model.abort_operation
    UI.messagebox("Crowd scatter failed: #{e.message}")
    raise e
  end

  # --- Selection helpers -----------------------------------------------------

  def pick_face(selection)
    selection.find { |e| e.is_a?(Sketchup::Face) }
  end

  def pick_crowd_definitions(selection)
    selection.grep(Sketchup::ComponentInstance).map(&:definition).uniq
  end

  # --- Settings --------------------------------------------------------------

  def prompt_settings(model, has_preview: false)
    defaults = [
      @last_count ||= 0,
      @last_spacing ||= model.options["UnitsOptions"]["LengthUnit"] == 4 ? 1000.mm : 36.0, # 3'
      @last_jitter ||= 0.35,
      @last_scale ||= 10.0,
      @last_preview.nil? ? !has_preview : @last_preview,
      @last_seed ||= 0
    ]

    prompts = [
      "Target count (0 = auto)",
      "Min spacing",
      "Jitter (0-1)",
      "Scale jitter +/- (%)",
      "Preview only?",
      "Random seed (0 = random)"
    ]

    lists = ["", "", "", "", "true|false", ""]

    result = UI.inputbox(prompts, defaults, lists, "AP Crowd Scatter")
    return nil unless result

    @last_count, @last_spacing, @last_jitter, @last_scale, @last_preview, @last_seed = result
    result
  end

  # --- Geometry helpers ------------------------------------------------------

  def face_axes(face)
    origin = face.vertices.first.position
    xaxis = face.edges.each_with_object(nil) do |e, memo|
      vec = e.line[1]
      next if vec.parallel?(face.normal) || vec.length < 0.001
      memo.replace(vec.normalize) if memo
      break vec.normalize unless memo
    end
    xaxis ||= Geom::Vector3d.new(1, 0, 0)
    yaxis = face.normal * xaxis
    Geom::Transformation.axes(origin, xaxis, yaxis, face.normal)
  end

  def projected_bounds(face, tr_inv)
    xs = []
    ys = []
    face.loops.each do |loop|
      loop.vertices.each do |v|
        p2d = v.position.transform(tr_inv)
        xs << p2d.x
        ys << p2d.y
      end
    end
    [xs.min, xs.max, ys.min, ys.max]
  end

  def random_point_on_face(face, bounds2d, tr, tr_inv, rng, max_samples: 40)
    minx, maxx, miny, maxy = bounds2d
    return nil unless minx && maxx && miny && maxy

    max_samples.times do
      px = rng.rand * (maxx - minx) + minx
      py = rng.rand * (maxy - miny) + miny
      pt2d = Geom::Point3d.new(px, py, 0)
      pt3d = pt2d.transform(tr)
      classification = face.classify_point(pt3d)
      if [POINT_INSIDE, POINT_ON_FACE, POINT_ON_EDGE, POINT_ON_VERTEX].include?(classification)
        return pt3d
      end
    end
    nil
  end

  # --- Scattering ------------------------------------------------------------

  def auto_count_from_area(face, min_spacing)
    area_sqft = face.area.to_f / 144.0
    spacing_ft = min_spacing / 12.0
    return 0 if spacing_ft <= 0.0

    estimate = area_sqft / (spacing_ft ** 2) * 0.65
    [[estimate.to_i, 1].max, MAX_COUNT_CAP].min
  end

  class SpacingGrid
    def initialize(cell_size)
      @cell = [cell_size, 0.1].max
      @cells = Hash.new { |h, k| h[k] = [] }
    end

    def key(pt)
      [ (pt.x / @cell).floor, (pt.y / @cell).floor, (pt.z / @cell).floor ]
    end

    def far_enough?(pt, min_dist)
      cx, cy, cz = key(pt)
      (cx - 1..cx + 1).each do |x|
        (cy - 1..cy + 1).each do |y|
          (cz - 1..cz + 1).each do |z|
            @cells[[x, y, z]].each do |p|
              return false if p.distance(pt) < min_dist
            end
          end
        end
      end
      true
    end

    def add(pt)
      @cells[key(pt)] << pt
    end
  end

  def scatter_points(face, target_count, min_spacing, jitter, rng)
    tr = face_axes(face)
    tr_inv = tr.inverse
    bounds2d = projected_bounds(face, tr_inv)
    grid = SpacingGrid.new(min_spacing)
    points = []

    max_attempts = [target_count * 60, 30_000].min
    attempts = 0

    while points.size < target_count && attempts < max_attempts
      pt = random_point_on_face(face, bounds2d, tr, tr_inv, rng)
      attempts += 1
      next unless pt

      factor = 1.0 - jitter * 0.5 + rng.rand * jitter
      factor = clamp(factor, 0.1, 2.0)
      req = min_spacing * factor

      if grid.far_enough?(pt, req)
        points << pt
        grid.add(pt)
      end
    end

    points
  end

  # --- Preview and placement -------------------------------------------------

  def draw_preview(parent_entities, points, normal)
    group = parent_entities.add_group
    group.name = PREVIEW_GROUP_NAME
    ents = group.entities
    c1 = Geom::Vector3d.new(0, 0, 1)
    up = normal.valid? ? normal.clone.normalize : c1

    points.each do |pt|
      ents.add_cpoint(pt)
      # Tiny segment helps visibility and selection without heavy geometry.
      ents.add_line(pt, pt.offset(up, 6.0))
    end
    group
  end

  def existing_preview_points(parent_entities)
    preview = parent_entities.grep(Sketchup::Group).find { |g| g.valid? && g.name == PREVIEW_GROUP_NAME }
    return [] unless preview
    preview.entities.grep(Sketchup::ConstructionPoint).map(&:position)
  end

  def clear_preview(parent_entities)
    parent_entities.grep(Sketchup::Group).each do |g|
      next unless g.valid? && g.name == PREVIEW_GROUP_NAME
      g.erase!
    end
  end

  def place_crowd(parent_entities, points, defs, normal, scale_jitter, rng)
    placed = 0
    up = normal.valid? ? normal.clone.normalize : Geom::Vector3d.new(0, 0, 1)

    points.each do |pt|
      defn = defs[rng.rand(defs.size)]
      angle = rng.rand * Math::PI * 2
      rot = Geom::Transformation.rotation(pt, up, angle)
      scale_factor = 1.0 + (rng.rand * 2.0 - 1.0) * (scale_jitter / 100.0)
      scale_factor = clamp(scale_factor, 0.1, 5.0)
      scl = Geom::Transformation.scaling(pt, scale_factor, scale_factor, scale_factor)
      tr = rot * scl * Geom::Transformation.translation(pt.to_a)

      parent_entities.add_instance(defn, tr)
      placed += 1
    end

    placed
  end

  # --- Utility ---------------------------------------------------------------

  def clamp(value, min, max)
    [[value, min].max, max].min
  end

  unless file_loaded?(__FILE__)
    UI.menu("Plugins").add_item("AP Crowd Scatter…") { run }
    file_loaded(__FILE__)
  end
end
