module SelectFacesSameMaterial
  # Simple logger for debugging in the Ruby console.
  def self.log(msg)
    puts "[SelectFacesSameMaterial] #{msg}"
  end

  # Main method invoked by the menu item.
  def self.select_faces_with_same_material
    model      = Sketchup.active_model
    selection  = model.selection
    sel_faces  = selection.grep(Sketchup::Face)

    if sel_faces.empty?
      UI.messagebox("Please select one or more faces to define the reference material.")
      log("No faces selected – aborting.")
      return
    end

    # Determine the reference material from the first selected face.
    ref_face = sel_faces.first
    target_material = ref_face.material || ref_face.back_material

    unless target_material
      UI.messagebox("Selected face has no material assigned. Assign a material first.")
      log("Reference face has no material – aborting.")
      return
    end

    log("Reference material: #{target_material.display_name}")

    # Collect faces only from the reference face's parent entities (current hierarchy level).
    context_entities = if ref_face.respond_to?(:parent) && ref_face.parent.respond_to?(:entities)
                         ref_face.parent.entities
                       else
                         model.active_entities
                       end

    all_faces = context_entities.grep(Sketchup::Face)
    log("Faces found in current hierarchy level: #{all_faces.size}")

    # Select faces whose front or back material matches the target.
    matching_faces = all_faces.select { |f| f.material == target_material || f.back_material == target_material }

    model.start_operation("Select Faces with Same Material", true)
    selection.clear
    matching_faces.each { |f| selection.add(f) }
    model.commit_operation

    UI.messagebox("Selected #{matching_faces.size} face(s) with material '#{target_material.display_name}'.")
    log("Selection completed – #{matching_faces.size} faces selected.")
  end

  # Add the plugin to the SketchUp Plugins menu once per session.
  unless file_loaded?(__FILE__)
    UI.menu("Plugins").add_item("Select Faces with Same Material") {
      self.select_faces_with_same_material
    }
    file_loaded(__FILE__)
  end
end
