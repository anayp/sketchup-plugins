require 'sketchup.rb'

module AP
  module Plugins
    module StairBuilder
      module_function

      def build_stairs
        prompts = [
          'Total rise (inches)',
          'Total run (inches)',
          'Width (inches)',
          'Number of steps',
          'Tread thickness (inches)',
          'Railing side (None/Left/Right/Both)',
          'Post height (inches)'
        ]
        defaults = [108.0, 144.0, 36.0, 12, 1.5, 'None', 36.0]
        list = ['', '', '', '', '', 'None|Left|Right|Both', '']

        input = UI.inputbox(prompts, defaults, list, 'Stair Builder')
        return unless input

        total_rise, total_run, width, steps, tread_thickness, rail_side, post_height = input
        total_rise = total_rise.to_f
        total_run = total_run.to_f
        width = width.to_f
        tread_thickness = tread_thickness.to_f
        post_height = post_height.to_f
        steps = steps.to_i
        if steps <= 0 || total_rise <= 0 || total_run <= 0 || width <= 0 || tread_thickness <= 0
          UI.messagebox('Enter positive values for rise, run, width, steps, and tread thickness.')
          return
        end

        step_height = total_rise.to_f / steps
        tread_depth = total_run.to_f / steps

        model = Sketchup.active_model
        model.start_operation('Build Stairs', true)

        group = model.active_entities.add_group
        group.name = 'Stairs'
        ents = group.entities

        steps.times do |i|
          origin = Geom::Point3d.new(i * tread_depth, 0, i * step_height)
          pts = [
            origin,
            origin + [tread_depth, 0, 0],
            origin + [tread_depth, width, 0],
            origin + [0, width, 0]
          ]
          face = ents.add_face(pts)
          face.pushpull(tread_thickness)
        end

        add_posts(ents, tread_depth, step_height, steps, width, rail_side, post_height)

        model.commit_operation
      rescue StandardError => e
        model.abort_operation if model
        UI.messagebox("Stair Builder failed: #{e.message}")
        raise e
      end

      def add_posts(ents, tread_depth, step_height, steps, width, rail_side, post_height)
        return if rail_side.to_s.strip.downcase == 'none'

        post_size = [width * 0.05, 1.0].max
        positions = []
        (steps + 1).times do |i|
          x = i * tread_depth
          z = i * step_height
          positions << [x, z]
        end

        sides = []
        sides << 0.0 if rail_side.to_s.downcase == 'left' || rail_side.to_s.downcase == 'both'
        sides << (width - post_size) if rail_side.to_s.downcase == 'right' || rail_side.to_s.downcase == 'both'

        sides.each do |y|
          positions.each do |x, z|
            origin = Geom::Point3d.new(x, y, z)
            pts = [
              origin,
              origin + [post_size, 0, 0],
              origin + [post_size, post_size, 0],
              origin + [0, post_size, 0]
            ]
            face = ents.add_face(pts)
            face.pushpull(post_height)
          end
        end
      end

      unless file_loaded?(__FILE__)
        UI.menu('Plugins').add_item('Stair Builder') { build_stairs }
        file_loaded(__FILE__)
      end
    end
  end
end
