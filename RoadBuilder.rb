module RoadBuilder
  PLUGIN_NAME = "Road Builder".freeze
  DEFAULT_WIDTH = 20.feet
  DEFAULT_THICKNESS = 1.feet
  DEFAULT_CENTER_LINE = false
  CENTER_DASH_LENGTH = 10.feet
  CENTER_GAP_LENGTH = 10.feet
  CENTER_LINE_WIDTH = 0.5.feet

  module_function

  def log(message)
    puts "[RoadBuilder] #{message}"
  end

  def create_flat_road_from_selection
    model = Sketchup.active_model
    selection = model.selection
    edges = selection.grep(Sketchup::Edge).uniq

    if edges.empty?
      UI.messagebox("Select one or more connected edges that represent the road centerline.")
      log("Aborted: no edges selected.")
      return
    end

    vertex_edges = build_vertex_adjacency(edges)

    paths = build_paths(edges, vertex_edges)
    if paths.empty?
      UI.messagebox("Unable to derive road paths from the selected edges.")
      log("Aborted: no paths generated from selection.")
      return
    end

    options = collect_options
    return unless options

    width = options[:width]
    thickness = options[:thickness]
    add_center_line = options[:center_line]

    if width <= 0.0
      UI.messagebox("Road width must be greater than zero.")
      log("Aborted: invalid width #{width}.")
      return
    end

    if thickness.negative?
      UI.messagebox("Road thickness cannot be negative.")
      log("Aborted: invalid thickness #{thickness}.")
      return
    end

    model.start_operation("Build Road", true)
    group = model.active_entities.add_group
    group.name = "Road"
    entities = group.entities

    half_width = width / 2.0
    total_segments = 0
    center_paths = []

    paths.each_with_index do |path, index|
      path_vertices = path[:vertices]
      positions = path_vertices.map(&:position)

      if positions.uniq.size < 2
        log("Skipped path #{index + 1}: not enough distinct points.")
        next
      end

      path_points = prepare_path_points(positions, path[:closed])
      if path_points.length < 2
        log("Skipped path #{index + 1}: insufficient ordered points.")
        next
      end

      cap_start = !path[:closed] && vertex_edges[path_vertices.first].size == 1
      cap_end = !path[:closed] && vertex_edges[path_vertices.last].size == 1

      result = build_path_geometry(
        entities,
        path_points,
        path[:closed],
        half_width,
        thickness,
        cap_start: cap_start,
        cap_end: cap_end
      )
      if result[:segments].zero?
        log("Skipped path #{index + 1}: no segments built.")
        next
      end

      total_segments += result[:segments]
      if add_center_line && result[:center_points].length > 1
        center_paths << { points: result[:center_points], closed: path[:closed] }
      end
    end

    if total_segments.zero?
      model.abort_operation
      UI.messagebox("No faces were created for the selected paths.")
      log("Completed with no geometry created.")
      return
    end

    if add_center_line && !center_paths.empty?
      add_dashed_center_lines(entities, center_paths)
    end

    model.commit_operation
    UI.messagebox("Road created with #{total_segments} segment#{total_segments == 1 ? '' : 's'}.")
    log("Completed: road created with #{total_segments} segment(s) across #{paths.length} path(s).")
  rescue => error
    model.abort_operation
    UI.messagebox("#{PLUGIN_NAME} error: #{error.message}")
    log("Error: #{error.message}\n#{error.backtrace.join("\n")}")
  end

  def collect_options
    prompts = ["Road Width", "Road Thickness", "Add Dashed Center Line?"]
    defaults = [DEFAULT_WIDTH, DEFAULT_THICKNESS, DEFAULT_CENTER_LINE]
    input = UI.inputbox(prompts, defaults, PLUGIN_NAME)
    return nil unless input

    width = normalize_length(input[0])
    thickness = normalize_length(input[1])
    center_line = input[2] ? true : false

    { width: width, thickness: thickness, center_line: center_line }
  end

  def build_vertex_adjacency(edges)
    adjacency = Hash.new { |hash, vertex| hash[vertex] = [] }
    edges.each do |edge|
      edge.vertices.each { |vertex| adjacency[vertex] << edge }
    end
    adjacency
  end

  def build_paths(edges, adjacency)
    visited_edges = {}
    paths = []

    terminals = adjacency.select { |_, list| list.size != 2 }.keys
    terminals.each do |vertex|
      adjacency[vertex].each do |edge|
        next if visited_edges[edge]
        path_vertices = traverse_path(vertex, edge, adjacency, visited_edges)
        paths << { vertices: path_vertices, closed: false } if path_vertices.length >= 2
      end
    end

    edges.each do |edge|
      next if visited_edges[edge]
      path_vertices = traverse_loop(edge, adjacency, visited_edges)
      paths << { vertices: path_vertices, closed: true } if path_vertices.length >= 2
    end

    paths
  end

  def traverse_path(start_vertex, start_edge, adjacency, visited_edges)
    path_vertices = [start_vertex]
    current_vertex = start_vertex
    current_edge = start_edge
    max_steps = adjacency.length * 4

    loop do
      visited_edges[current_edge] = true
      next_vertex = current_edge.other_vertex(current_vertex)
      path_vertices << next_vertex
      break if adjacency[next_vertex].size != 2
      next_edge = adjacency[next_vertex].find { |edge| !visited_edges[edge] }
      break unless next_edge
      current_vertex = next_vertex
      current_edge = next_edge
      break if path_vertices.length > max_steps
    end

    path_vertices
  end

  def traverse_loop(start_edge, adjacency, visited_edges)
    start_vertex = start_edge.start
    path_vertices = [start_vertex]
    current_vertex = start_vertex
    current_edge = start_edge
    max_steps = adjacency.length * 8

    loop do
      visited_edges[current_edge] = true
      next_vertex = current_edge.other_vertex(current_vertex)
      path_vertices << next_vertex
      break if next_vertex == start_vertex
      next_edge = adjacency[next_vertex].find { |edge| !visited_edges[edge] }
      break unless next_edge
      current_vertex = next_vertex
      current_edge = next_edge
      break if path_vertices.length > max_steps
    end

    path_vertices
  end

  def build_path_geometry(entities, points, closed, half_width, thickness, cap_start: true, cap_end: true)
    cross_vectors = compute_cross_vectors(points, closed)
    left_points = []
    right_points = []

    points.each_with_index do |point, index|
      cross = cross_vectors[index]
      left_points << point.offset(cross, half_width)
      right_points << point.offset(cross, -half_width)
    end

    segment_total = closed ? points.length : points.length - 1
    built_segments = 0

    segment_total.times do |index|
      next_index = closed ? (index + 1) % points.length : index + 1
      next if !closed && next_index >= points.length

      face_points = [
        left_points[index],
        left_points[next_index],
        right_points[next_index],
        right_points[index]
      ]

      faces = add_quad(entities, face_points, prefer: :up, soften: true)
      built_segments += 1 unless faces.empty?
    end

    if built_segments.positive? && thickness.positive?
      add_road_thickness(
        entities,
        left_points,
        right_points,
        thickness,
        closed,
        cap_start: cap_start,
        cap_end: cap_end
      )
    end

    center_points = if built_segments.positive?
                      left_points.each_index.map do |i|
                        Geom::Point3d.new(
                          (left_points[i].x + right_points[i].x) / 2.0,
                          (left_points[i].y + right_points[i].y) / 2.0,
                          (left_points[i].z + right_points[i].z) / 2.0
                        )
                      end
                    else
                      []
                    end

    { segments: built_segments, center_points: center_points }
  end

  def prepare_path_points(positions, closed)
    points = positions.dup
    points.pop if closed && points.first == points.last
    points
  end

  def compute_cross_vectors(points, closed)
    count = points.length
    points.map.with_index do |point, index|
      prev_point = if closed
                     points[(index - 1) % count]
                   else
                     index.zero? ? nil : points[index - 1]
                   end

      next_point = if closed
                     points[(index + 1) % count]
                   else
                     index == count - 1 ? nil : points[index + 1]
                   end

      candidate_vectors = []
      candidate_vectors << prev_point.vector_to(point) if prev_point
      candidate_vectors << point.vector_to(next_point) if next_point

      direction = Geom::Vector3d.new(0, 0, 0)
      fallback = nil

      candidate_vectors.each do |vector|
        next if vector.length.zero?

        fallback ||= vector
        direction += vector.normalize
      end

      if direction.length.zero?
        direction = fallback || Geom::Vector3d.new(1, 0, 0)
      end

      horizontal = Geom::Vector3d.new(direction.x, direction.y, 0)
      if horizontal.length.zero?
        horizontal = Geom::Vector3d.new(1, 0, 0)
      else
        horizontal.normalize!
      end

      cross = Geom::Vector3d.new(-horizontal.y, horizontal.x, 0)
      if cross.length.zero?
        cross = Geom::Vector3d.new(0, 1, 0)
      else
        cross.normalize!
      end

      cross
    end
  end

  def add_road_thickness(entities, left_points, right_points, thickness, closed, cap_start: true, cap_end: true)
    vector = Geom::Vector3d.new(0, 0, -thickness)
    left_bottom_points = left_points.map { |point| point.offset(vector) }
    right_bottom_points = right_points.map { |point| point.offset(vector) }

    segment_count = closed ? left_points.length : left_points.length - 1

    segment_count.times do |index|
      next_index = closed ? (index + 1) % left_points.length : index + 1
      break if next_index >= left_points.length

      bottom_points = [
        left_bottom_points[index],
        left_bottom_points[next_index],
        right_bottom_points[next_index],
        right_bottom_points[index]
      ]
      add_quad(entities, bottom_points, prefer: :down)

      left_side = [
        left_points[index],
        left_points[next_index],
        left_bottom_points[next_index],
        left_bottom_points[index]
      ]
      add_quad(entities, left_side)

      right_side = [
        right_points[index],
        right_points[next_index],
        right_bottom_points[next_index],
        right_bottom_points[index]
      ]
      add_quad(entities, right_side)
    end

    unless closed
      if cap_start
        start_cap = [
          left_points.first,
          right_points.first,
          right_bottom_points.first,
          left_bottom_points.first
        ]
        add_quad(entities, start_cap)
      end

      if cap_end
        end_cap = [
          left_points.last,
          left_bottom_points.last,
          right_bottom_points.last,
          right_points.last
        ]
        add_quad(entities, end_cap)
      end
    end
  end

  def add_dashed_center_lines(parent_entities, center_paths)
    dash_length = normalize_length(CENTER_DASH_LENGTH)
    gap_length = normalize_length(CENTER_GAP_LENGTH)
    line_half_width = normalize_length(CENTER_LINE_WIDTH) / 2.0

    group = parent_entities.add_group
    group.name = "Road Center Line"
    entities = group.entities
    color = Sketchup::Color.new(255, 215, 0) # Yellow line
    built_faces = 0

    center_paths.each do |path|
      points = path[:points]
      next unless points && points.length > 1

      spans = generate_dash_spans(points, path[:closed], dash_length, gap_length)
      if spans.empty?
        log("Center line skipped for one path: no dash spans generated.")
        next
      end

      spans.each do |span|
        start_point, end_point = span
        direction = start_point.vector_to(end_point)
        next if direction.length.zero?

        horizontal_direction = Geom::Vector3d.new(direction.x, direction.y, 0)
        if horizontal_direction.length.zero?
          horizontal_direction = Geom::Vector3d.new(1, 0, 0)
        else
          horizontal_direction.normalize!
        end

        cross = Geom::Vector3d.new(-horizontal_direction.y, horizontal_direction.x, 0)
        if cross.length.zero?
          cross = Geom::Vector3d.new(1, 0, 0)
        else
          cross.normalize!
        end

        dash_points = [
          start_point.offset(cross, line_half_width),
          end_point.offset(cross, line_half_width),
          end_point.offset(cross, -line_half_width),
          start_point.offset(cross, -line_half_width)
        ]

        faces = add_quad(entities, dash_points, prefer: :up)
        faces.each do |face|
          face.material = color
          face.back_material = color
          built_faces += 1
        end
      end
    end

    if built_faces.zero?
      group.erase!
      log("Center line skipped: no dashes created.")
    end
  end

  def normalize_length(value)
    if defined?(Length) && value.is_a?(Length)
      value.to_f
    elsif value.respond_to?(:to_l)
      value.to_l.to_f
    else
      value.to_f
    end
  end

  def generate_dash_spans(points, closed, dash_length, gap_length)
    segment_count = closed ? points.length : points.length - 1
    return [] if segment_count <= 0

    spans = []
    phase = :dash
    remaining = dash_length
    tolerance = 1e-6

    index = 0
    current_point = points.first

    while index < segment_count
      start_point = current_point
      end_point = points[(index + 1) % points.length]

      vector = start_point.vector_to(end_point)
      length = vector.length

      if length <= tolerance
        current_point = end_point
        index += 1
        next
      end

      direction = vector.clone
      direction.normalize!

      remaining_along_segment = length
      cursor = start_point

      while remaining_along_segment > tolerance
        travel = [remaining, remaining_along_segment].min
        next_cursor = cursor.offset(direction, travel)

        if phase == :dash
          spans << [cursor, next_cursor]
        end

        remaining -= travel
        remaining_along_segment -= travel
        cursor = next_cursor

        if remaining <= tolerance
          phase = phase == :dash ? :gap : :dash
          remaining = phase == :dash ? dash_length : gap_length
        end
      end

      current_point = end_point
      index += 1
    end

    spans
  end

  def add_quad(entities, points, prefer: nil, soften: false)
    faces = []
    faces << entities.add_face(points[0], points[1], points[2])
    faces << entities.add_face(points[0], points[2], points[3])
    faces.compact!

    return [] if faces.empty?

    case prefer
    when :up
      faces.each { |face| face.reverse! if face.normal.z < 0 }
    when :down
      faces.each { |face| face.reverse! if face.normal.z > 0 }
    end

    if soften
      diagonal = entities.add_line(points[0], points[2])
      if diagonal
        diagonal.soft = true
        diagonal.smooth = true
      end
    end

    faces
  end

  unless file_loaded?(__FILE__)
    UI.menu("Plugins").add_item("Road Builder") do
      create_flat_road_from_selection
    end
    file_loaded(__FILE__)
  end
end
