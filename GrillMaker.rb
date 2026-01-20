module GrillMaker
  # Simple logger to the Ruby console.
  def self.log(msg)
    puts "[GrillMaker] #{msg}"
  end

  def self.create_cylinders_from_lines
    model = Sketchup.active_model
    selection = model.selection
    edges = selection.grep(Sketchup::Edge)

    log("Starting cylinder creation via push-pull.")
    log("Number of selected edges: #{edges.size}")

    if edges.empty?
      UI.messagebox("Please select some edges first.")
      log("No edges selected. Aborting.")
      return
    end

    model.start_operation("Create Cylinders", true)

    # The circle’s radius is half of 0.025".
    radius       = 0.025
    num_segments = 24  # Smoother circle

    edges.each_with_index do |edge, index|
      log("Processing edge #{index + 1}")

      start_pt = edge.start.position
      end_pt   = edge.end.position
      vector   = start_pt.vector_to(end_pt)

      length = vector.length
      if length.zero?
        log("  Edge length is 0. Skipping.")
        next
      end

      direction = vector.normalize
      log("  Edge start: #{start_pt.to_a.inspect}, end: #{end_pt.to_a.inspect}")
      log("  Length: #{length}, Direction: #{direction.to_a.inspect}")

      # Create a new group to hold the circle & extrusion in local coordinates.
      group = model.entities.add_group
      ents  = group.entities

      # 1) Draw a circle in XY plane (local coords), radius 0.125"
      center  = Geom::Point3d.new(0, 0, 0)
      normal  = Z_AXIS
      circle  = ents.add_circle(center, normal, radius, num_segments)
      face    = ents.add_face(circle)
      unless face
        log("  Failed to create face. Skipping edge.")
        group.erase!
        next
      end

      # 2) Ensure the face normal points “up” (along +Z in local coords)
      #    so pushpull is positive.
      if face.normal.z < 0
        face.reverse!
        log("  Reversed face to make normal face +Z.")
      end

      # 3) Push-pull the face to create a cylinder the same length as the edge.
      face.pushpull(length)
      log("  Push-pulled face by #{length} to form cylinder.")

      # 4) Compute a transform that orients local Z to the edge direction
      #    and moves bottom of cylinder to start_pt.
      #
      #    - t2 rotates local Z to 'direction'
      #    - t1 translates the origin to 'start_pt'
      #
      #    Final transform = t1 * t2 (rotate then translate).
      new_z = direction
      new_x = new_z.parallel?(X_AXIS) ? Y_AXIS : X_AXIS
      new_y = new_z * new_x
      new_x = new_y * new_z  # re-orthogonalize

      log("  Building orientation axes:")
      log("    new_x = #{new_x.to_a.inspect}")
      log("    new_y = #{new_y.to_a.inspect}")
      log("    new_z = #{new_z.to_a.inspect}")

      t2 = Geom::Transformation.axes(ORIGIN, new_x, new_y, new_z)
      t1 = Geom::Transformation.translation(start_pt)
      transform = t1 * t2

      # 5) Transform the group
      group.transform!(transform)
      log("  Transformed group to line orientation.")
    end

    model.commit_operation
    UI.messagebox("Cylinders created for each line.")
    log("All cylinders created successfully.")
  end

  unless file_loaded?(__FILE__)
    UI.menu("Plugins").add_item("GrillMaker0.25inch") {
      self.create_cylinders_from_lines
    }
    file_loaded(__FILE__)
  end
end
