bl_info = {
    "name": "AP Road Builder",
    "author": "Antigravity",
    "version": (1, 1),
    "blender": (3, 0, 0),
    "location": "View3D > Sidebar > AP Tools",
    "description": "Build roads from selected edges",
    "category": "Object",
}

import bpy
import bmesh
from mathutils import Vector

def get_edge_paths(edges):
    paths = []
    visited_edges = set()
    
    edge_map = {}
    for e in edges:
        for v in e.verts:
            if v not in edge_map:
                edge_map[v] = []
            edge_map[v].append(e)
            
    # Branching check
    for v, connected_edges in edge_map.items():
        if len(connected_edges) > 2:
            return None # Branching detected
            
    for e in edges:
        if e in visited_edges:
            continue
            
        path_verts = [e.verts[0], e.verts[1]]
        visited_edges.add(e)
        
        # Walk forward
        curr_v = e.verts[1]
        while True:
            connected = [ce for ce in edge_map[curr_v] if ce not in visited_edges]
            if not connected:
                break
            next_e = connected[0]
            visited_edges.add(next_e)
            curr_v = next_e.other_vert(curr_v)
            path_verts.append(curr_v)
            
        # Walk backward
        curr_v = e.verts[0]
        while True:
            connected = [ce for ce in edge_map[curr_v] if ce not in visited_edges]
            if not connected:
                break
            next_e = connected[0]
            visited_edges.add(next_e)
            curr_v = next_e.other_vert(curr_v)
            path_verts.insert(0, curr_v)
            
        closed = path_verts[0] == path_verts[-1]
        if closed:
            path_verts.pop()
            
        paths.append({'verts': path_verts, 'closed': closed})
        
    return paths

class AP_OT_RoadBuilder(bpy.types.Operator):
    bl_idname = "ap.road_builder"
    bl_label = "Build Road"
    bl_description = "Creates a road along selected edges"
    bl_options = {'REGISTER', 'UNDO'}
    
    width: bpy.props.FloatProperty(
        name="Width",
        default=6.096,  # 20 feet in meters (Blender's default unit)
        min=0.1,
        subtype='DISTANCE'
    )
    thickness: bpy.props.FloatProperty(
        name="Thickness",
        default=0.3048,  # 1 foot
        min=0.0,
        subtype='DISTANCE'
    )
    center_line: bpy.props.BoolProperty(
        name="Add Center Line",
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
        
        paths = get_edge_paths(edges)
        if paths is None:
            self.report({'WARNING'}, "Branching paths detected. Select a single contiguous path.")
            return {'CANCELLED'}
        if not paths:
            self.report({'WARNING'}, "Could not form continuous paths")
            return {'CANCELLED'}
            
        bpy.ops.object.mode_set(mode='OBJECT')
        
        mesh = bpy.data.meshes.new("AP_Road")
        road_obj = bpy.data.objects.new("AP_Road", mesh)
        context.collection.objects.link(road_obj)
        road_obj.matrix_world = obj.matrix_world
        
        rbm = bmesh.new()
        uv_layer = rbm.loops.layers.uv.verify()
        
        half_width = self.width / 2.0
        up = Vector((0, 0, 1))
        
        for path in paths:
            verts = path['verts']
            closed = path['closed']
            
            if len(verts) < 2:
                continue
            
            left_points = []
            right_points = []
            distances = []
            current_distance = 0.0
            
            num_v = len(verts)
            for i, v in enumerate(verts):
                if i > 0:
                    current_distance += (v.co - verts[i-1].co).length
                distances.append(current_distance)
                
                if closed:
                    prev_v = verts[(i - 1) % num_v]
                    next_v = verts[(i + 1) % num_v]
                else:
                    prev_v = verts[i - 1] if i > 0 else None
                    next_v = verts[i + 1] if i < num_v - 1 else None
                
                v_dir = Vector()
                if prev_v:
                    v_dir += (v.co - prev_v.co).normalized()
                if next_v:
                    v_dir += (next_v.co - v.co).normalized()
                
                if v_dir.length < 1e-5:
                    v_dir = Vector((1, 0, 0))
                else:
                    v_dir.normalize()
                
                cross = up.cross(v_dir)
                if cross.length < 1e-5:
                    # Fallback for vertical lines
                    cross = Vector((0, 1, 0)).cross(v_dir)
                    if cross.length < 1e-5:
                        cross = Vector((1, 0, 0)).cross(v_dir)
                cross.normalize()
                
                left_points.append(v.co + cross * half_width)
                right_points.append(v.co - cross * half_width)
            
            created_verts_left = [rbm.verts.new(p) for p in left_points]
            created_verts_right = [rbm.verts.new(p) for p in right_points]
            
            top_faces = []
            segments = num_v if closed else num_v - 1
            
            for i in range(segments):
                next_i = (i + 1) % num_v
                
                vl1 = created_verts_left[i]
                vl2 = created_verts_left[next_i]
                vr2 = created_verts_right[next_i]
                vr1 = created_verts_right[i]
                
                try:
                    f = rbm.faces.new([vl1, vl2, vr2, vr1])
                    top_faces.append(f)
                    
                    # Basic UV mapping
                    f.loops[0][uv_layer].uv = (0.0, distances[i])
                    f.loops[1][uv_layer].uv = (0.0, distances[next_i])
                    f.loops[2][uv_layer].uv = (1.0, distances[next_i])
                    f.loops[3][uv_layer].uv = (1.0, distances[i])
                except ValueError:
                    pass
            
            bmesh.ops.recalc_face_normals(rbm, faces=top_faces)
            
            if self.thickness > 0:
                bmesh.ops.solidify(rbm, geom=top_faces, thickness=self.thickness)
                
        rbm.to_mesh(mesh)
        mesh.update()
        rbm.free()
        
        context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode='EDIT')
        
        return {'FINISHED'}

class AP_PT_RoadBuilder(bpy.types.Panel):
    bl_label = "Road Builder"
    bl_idname = "AP_PT_RoadBuilder"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'AP Tools'

    def draw(self, context):
        layout = self.layout
        layout.operator("ap.road_builder")

classes = (
    AP_OT_RoadBuilder,
    AP_PT_RoadBuilder,
)

def register():
    for cls in classes:
        bpy.utils.register_class(cls)

def unregister():
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)

if __name__ == "__main__":
    register()
