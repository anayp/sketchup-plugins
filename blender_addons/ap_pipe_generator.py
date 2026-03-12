bl_info = {
    "name": "AP Pipe Generator",
    "author": "Antigravity",
    "version": (1, 1),
    "blender": (3, 0, 0),
    "location": "View3D > Sidebar > AP Tools",
    "description": "Generate pipes along selected edges using Curves",
    "category": "Object",
}

import bpy
import bmesh

class AP_OT_PipeGenerator(bpy.types.Operator):
    bl_idname = "ap.pipe_generator"
    bl_label = "Generate Pipes"
    bl_description = "Creates seamless pipes along selected edges using Curves"
    bl_options = {'REGISTER', 'UNDO'}
    
    radius_type: bpy.props.EnumProperty(
        name="Radius",
        items=[
            ('INCH_1', '1 Inch', 'Radius of 1 inch (0.0254m)'),
            ('INCH_0_5', '0.5 Inch', 'Radius of 0.5 inch (0.0127m)')
        ],
        default='INCH_1'
    )
    
    segments: bpy.props.IntProperty(
        name="Segments",
        description="Resolution of the pipe",
        default=24,
        min=3,
        max=128
    )

    @classmethod
    def poll(cls, context):
        return context.active_object and context.active_object.type == 'MESH' and context.mode == 'EDIT_MESH'

    def execute(self, context):
        obj = context.active_object
        bm = bmesh.from_edit_mesh(obj.data)
        
        edges = [e for e in bm.edges if e.select]
        if not edges:
            self.report({'WARNING'}, "No edges selected")
            return {'CANCELLED'}
            
        radius = 0.0254 if self.radius_type == 'INCH_1' else 0.0127
        # Scale for scene units
        unit_scale = context.scene.unit_settings.scale_length
        scaled_radius = radius * unit_scale
        
        bpy.ops.object.mode_set(mode='OBJECT')
        
        # Duplicate the object
        bpy.ops.object.duplicate_move(OBJECT_OT_duplicate={"linked":False, "mode":'TRANSLATION'})
        dup_obj = context.active_object
        
        # Go into edit mode and delete unselected (the edges we didn't want)
        bpy.ops.object.mode_set(mode='EDIT')
        
        # We need to invert selection and delete, but duplicate_move preserves selection.
        bpy.ops.mesh.select_all(action='INVERT')
        bpy.ops.mesh.delete(type='VERT')
        
        bpy.ops.object.mode_set(mode='OBJECT')
        
        # Convert the remaining selected edges to curve
        bpy.ops.object.convert(target='CURVE')
        
        if dup_obj.type == 'CURVE':
            curve = dup_obj.data
            curve.dimensions = '3D'
            curve.fill_mode = 'FULL'
            
            curve.bevel_depth = scaled_radius
            curve.bevel_resolution = max(0, self.segments // 4)
            
            dup_obj.name = "AP_Pipes"
        else:
            self.report({'ERROR'}, "Failed to convert to Curve")
            # Cleanup on failure
            bpy.data.objects.remove(dup_obj)

        # Return to main object
        context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        
        return {'FINISHED'}

class AP_PT_PipeGenerator(bpy.types.Panel):
    bl_label = "Pipe Generator"
    bl_idname = "AP_PT_PipeGenerator"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'AP Tools'

    def draw(self, context):
        layout = self.layout
        
        col = layout.column(align=True)
        op_1 = col.operator("ap.pipe_generator", text="1 Inch Pipes")
        op_1.radius_type = 'INCH_1'
        
        op_0_5 = col.operator("ap.pipe_generator", text="0.5 Inch Pipes")
        op_0_5.radius_type = 'INCH_0_5'

classes = (
    AP_OT_PipeGenerator,
    AP_PT_PipeGenerator,
)

def register():
    for cls in classes:
        bpy.utils.register_class(cls)

def unregister():
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)

if __name__ == "__main__":
    register()
