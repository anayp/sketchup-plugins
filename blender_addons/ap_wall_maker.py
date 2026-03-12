bl_info = {
    "name": "AP Wall Maker",
    "author": "Antigravity",
    "version": (1, 1),
    "blender": (3, 0, 0),
    "location": "View3D > Sidebar > AP Tools",
    "description": "Generate walls and mojos from selected edges",
    "category": "Object",
}

import bpy
import bmesh
from mathutils import Vector

def check_branching(edges):
    edge_map = {}
    for e in edges:
        for v in e.verts:
            if v not in edge_map:
                edge_map[v] = []
            edge_map[v].append(e)
    for v, connected_edges in edge_map.items():
        if len(connected_edges) > 2:
            return True
    return False

class AP_OT_WallMaker(bpy.types.Operator):
    bl_idname = "ap.wall_maker"
    bl_label = "Build Wall"
    bl_description = "Creates a wall along selected edges"
    bl_options = {'REGISTER', 'UNDO'}
    
    height: bpy.props.FloatProperty(
        name="Height",
        default=3.048,  # 10 feet
        min=0.1,
        subtype='DISTANCE'
    )
    thickness: bpy.props.FloatProperty(
        name="Thickness",
        default=0.2032,  # 8 inches
        min=0.01,
        subtype='DISTANCE'
    )
    is_mojo: bpy.props.BoolProperty(
        name="Mojo Barricade",
        default=False
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
            
        if check_branching(edges):
            self.report({'WARNING'}, "Branching paths detected. Select a single contiguous path.")
            return {'CANCELLED'}
        
        bpy.ops.object.mode_set(mode='OBJECT')
        
        mesh = bpy.data.meshes.new("AP_Wall")
        wall_obj = bpy.data.objects.new("AP_Wall", mesh)
        context.collection.objects.link(wall_obj)
        wall_obj.matrix_world = obj.matrix_world
        
        rbm = bmesh.new()
        uv_layer = rbm.loops.layers.uv.verify()
        
        up = Vector((0, 0, 1))
        
        all_faces = []
        
        for e in edges:
            v1 = e.verts[0].co
            v2 = e.verts[1].co
            
            vec = v2 - v1
            vec_xy = Vector((vec.x, vec.y, 0))
            if vec_xy.length < 1e-4:
                # Vertical edge, compute arbitrary perpendicular
                cross = Vector((0, 1, 0)).cross(vec)
                if cross.length < 1e-4:
                    cross = Vector((1, 0, 0)).cross(vec)
                cross.normalize()
                right_vec = cross
                left_vec = -cross
            else:
                vec_xy.normalize()
                left_vec = up.cross(vec_xy)
                right_vec = vec_xy.cross(up)
            
            if self.is_mojo:
                # Base footprint
                base_height = 0.508 # ~20 inches
                base_half_width = 0.4572 # ~18 inches
                
                left_vec_base = left_vec * base_half_width
                right_vec_base = right_vec * base_half_width
                
                p1 = v1 + left_vec_base
                p2 = v1 + right_vec_base
                p3 = v2 + right_vec_base
                p4 = v2 + left_vec_base
                
                bv1 = rbm.verts.new(p1)
                bv2 = rbm.verts.new(p2)
                bv3 = rbm.verts.new(p3)
                bv4 = rbm.verts.new(p4)
                
                f_base = rbm.faces.new([bv1, bv2, bv3, bv4])
                all_faces.append(f_base)
                
                ret = bmesh.ops.extrude_face_region(rbm, geom=[f_base])
                moved_verts = [ele for ele in ret['geom'] if isinstance(ele, bmesh.types.BMVert)]
                for v in moved_verts:
                    v.co.z += base_height
                    
                # We could create a complex stem, but keeping geometry contiguous means
                # we'd normally inset and extrude again. For simplification, we just use a box base.
                
            else:
                half_thickness = self.thickness / 2.0
                p_left = left_vec * half_thickness
                p_right = right_vec * half_thickness
                
                p1 = v1 + p_left
                p2 = v1 + p_right
                p3 = v2 + p_right
                p4 = v2 + p_left
                
                bv1 = rbm.verts.new(p1)
                bv2 = rbm.verts.new(p2)
                bv3 = rbm.verts.new(p3)
                bv4 = rbm.verts.new(p4)
                
                try:
                    f = rbm.faces.new([bv1, bv2, bv3, bv4])
                    all_faces.append(f)
                    
                    ret = bmesh.ops.extrude_face_region(rbm, geom=[f])
                    moved_verts = [ele for ele in ret['geom'] if isinstance(ele, bmesh.types.BMVert)]
                    for v in moved_verts:
                        v.co.z += self.height
                        
                except Exception:
                    pass

        # Recalculate normals to handle flip issues implicitly during bulk creation
        bmesh.ops.recalc_face_normals(rbm, faces=rbm.faces)
        
        rbm.to_mesh(mesh)
        rbm.free()
        
        context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode='EDIT')
        
        return {'FINISHED'}

class AP_PT_WallMaker(bpy.types.Panel):
    bl_label = "Wall Maker"
    bl_idname = "AP_PT_WallMaker"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'AP Tools'

    def draw(self, context):
        layout = self.layout
        
        col = layout.column(align=True)
        op_10 = col.operator("ap.wall_maker", text="10ft Wall")
        op_10.height = 3.048
        op_10.is_mojo = False
        
        op_3_5 = col.operator("ap.wall_maker", text="3.5ft Wall")
        op_3_5.height = 1.0668
        op_3_5.is_mojo = False
        
        op_mojo = col.operator("ap.wall_maker", text="Mojo Barricade")
        op_mojo.height = 1.0668
        op_mojo.is_mojo = True

classes = (
    AP_OT_WallMaker,
    AP_PT_WallMaker,
)

def register():
    for cls in classes:
        bpy.utils.register_class(cls)

def unregister():
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)

if __name__ == "__main__":
    register()
