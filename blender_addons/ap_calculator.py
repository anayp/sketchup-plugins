bl_info = {
    "name": "AP Calculator",
    "author": "Antigravity",
    "version": (1, 1),
    "blender": (3, 0, 0),
    "location": "View3D > Sidebar > AP Tools",
    "description": "Simple expression calculator",
    "category": "Interface",
}

import bpy
import math

class AP_CalcProps(bpy.types.PropertyGroup):
    expression: bpy.props.StringProperty(
        name="Expression",
        default="",
        description="Enter math expression"
    )
    result: bpy.props.StringProperty(
        name="Result",
        default=""
    )

class AP_OT_Calculate(bpy.types.Operator):
    bl_idname = "ap.calculate"
    bl_label = "Calculate"
    bl_description = "Evaluate the expression"
    
    def execute(self, context):
        props = context.scene.ap_calc_props
        expr = props.expression
        try:
            # Basic sanity check
            if len(expr) > 100:
                raise ValueError("Expression too long")
                
            allowed_names = {
                "math": math,
                "sin": math.sin, "cos": math.cos, "tan": math.tan,
                "asin": math.asin, "acos": math.acos, "atan": math.atan,
                "sqrt": math.sqrt, "pi": math.pi, "e": math.e,
                "pow": pow, "abs": abs
            }
            # Remove __builtins__ to make it safe from arbitrary code execution
            result = eval(expr, {"__builtins__": {}}, allowed_names)
            props.result = str(result)
        except Exception as e:
            props.result = "Error"
            self.report({'ERROR'}, f"Invalid expression: {str(e)}")
        return {'FINISHED'}

class AP_PT_Calculator(bpy.types.Panel):
    bl_label = "Calculator"
    bl_idname = "AP_PT_Calculator"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'AP Tools'

    def draw(self, context):
        layout = self.layout
        props = context.scene.ap_calc_props

        col = layout.column(align=True)
        col.prop(props, "expression", text="")
        
        row = col.row(align=True)
        row.operator("ap.calculate")
        row.operator("ap.calc_clear", icon='X', text="")

        layout.label(text=f"Result: {props.result}")

class AP_OT_CalcClear(bpy.types.Operator):
    bl_idname = "ap.calc_clear"
    bl_label = "Clear"
    
    def execute(self, context):
        props = context.scene.ap_calc_props
        props.expression = ""
        props.result = ""
        return {'FINISHED'}

classes = (
    AP_CalcProps,
    AP_OT_Calculate,
    AP_OT_CalcClear,
    AP_PT_Calculator,
)

def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.ap_calc_props = bpy.props.PointerProperty(type=AP_CalcProps)

def unregister():
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
    del bpy.types.Scene.ap_calc_props

if __name__ == "__main__":
    register()
