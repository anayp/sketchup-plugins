require "sketchup.rb"

module APDropToMesh
  extend self

  OFFSET = 1000.0 # extra height for the ray start in model units (inches by default)

  def drop_selected_to_mesh
    model = Sketchup.active_model
    selection = model.selection.to_a
    targets = selection.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }

    if targets.empty?
      UI.messagebox('Select groups or components to drop onto the mesh.')
      return
    end

    path_tr = active_path_transform(model)
    op_started = model.start_operation('Drop Selection to Mesh', true)
    hidden_state = remember_and_hide(targets)

    dropped = []
    skipped = []

    targets.each do |entity|
      result = drop_entity(entity, model, path_tr)
      if result
        dropped << entity
      else
        skipped << entity
      end
    end

    restore_hidden_state(hidden_state)
    model.commit_operation if op_started

    if skipped.any?
      UI.messagebox("Dropped #{dropped.size} items. Skipped #{skipped.size} (no mesh hit beneath them).")
    else
      model.status_text = "Dropped #{dropped.size} items onto mesh."
    end
  rescue => e
    restore_hidden_state(hidden_state)
    model.abort_operation if op_started
    UI.messagebox("Drop to mesh failed: #{e.message}")
    raise e
  end

  private

  def active_path_transform(model)
    path = model.active_path
    return Geom::Transformation.new unless path && !path.empty?

    path.reduce(Geom::Transformation.new) do |tr, inst|
      tr * inst.transformation
    end
  end

  def remember_and_hide(entities)
    states = {}
    entities.each do |e|
      states[e] = e.hidden?
      e.hidden = true unless states[e]
    end
    states
  end

  def restore_hidden_state(states)
    return unless states

    states.each do |entity, was_hidden|
      next if entity.deleted?
      entity.hidden = was_hidden
    end
  end

  def drop_entity(entity, model, path_tr)
    world_corners = bounding_corners_in_world(entity, path_tr)
    return false if world_corners.empty?

    min_z = world_corners.map(&:z).min
    max_z = world_corners.map(&:z).max
    center_parent = entity.bounds.center
    center_world = center_parent.transform(path_tr)

    start_point = Geom::Point3d.new(center_world.x, center_world.y, max_z + OFFSET)
    vector = Geom::Vector3d.new(0, 0, -1)

    hit = model.raytest(start_point, vector)
    hit ||= model.raytest(start_point, vector, true)
    return false unless hit && hit[0]

    hit_point = hit[0]
    delta_z = hit_point.z - min_z

    move_world = Geom::Transformation.translation([0, 0, delta_z])
    move_in_parent = path_tr.inverse * move_world * path_tr

    entity.transform!(move_in_parent)
    true
  end

  def bounding_corners_in_world(entity, path_tr)
    bb = entity.bounds
    (0..7).map { |i| bb.corner(i).transform(path_tr) }
  end

  unless file_loaded?(__FILE__)
    UI.menu('Plugins').add_item('Drop Selection to Mesh') { drop_selected_to_mesh }
    file_loaded(__FILE__)
  end
end
