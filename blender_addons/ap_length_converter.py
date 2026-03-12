bl_info = {
    "name": "AP Length Converter",
    "author": "Antigravity",
    "version": (1, 1),
    "blender": (3, 0, 0),
    "location": "View3D > Sidebar > AP Tools",
    "description": "Convert between length and area units",
    "category": "Interface",
}

import bpy

def update_unit(self, context, source_key):
    if getattr(self, "is_converting", False):
        return
        
    self.is_converting = True
    
    val = getattr(self, f"unit_{source_key}")
    is_area = self.conv_mode == 'AREA'
    
    factors = {
        'feet': 0.3048,
        'meters': 1.0,
        'inches': 0.0254,
        'cm': 0.01,
        'yards': 0.9144,
        'km': 1000.0,
        'miles': 1609.344
    }
    
    base_factor = factors[source_key]
    if is_area:
        base_val_meters = val * (base_factor ** 2)
    else:
        base_val_meters = val * base_factor
        
    for key, factor in factors.items():
        if key == source_key:
            continue
        if is_area:
            new_val = base_val_meters / (factor ** 2)
        else:
            new_val = base_val_meters / factor
        setattr(self, f"unit_{key}", new_val)
        
    self.is_converting = False

def make_update(key):
    return lambda self, context: update_unit(self, context, key)

class AP_LengthProps(bpy.types.PropertyGroup):
    conv_mode: bpy.props.EnumProperty(
        items=[('LENGTH', 'Length', ''), ('AREA', 'Area', '')],
        name="Mode",
        default='LENGTH'
    )
    is_converting: bpy.props.BoolProperty(default=False)
    
    # We dynamically create these props but it's cleaner to define them explicitly
    # so Blender's annotation parser catches them correctly.
    unit_feet: bpy.props.FloatProperty(name="Feet", precision=4, update=make_update('feet'))
    unit_meters: bpy.props.FloatProperty(name="Meters", precision=4, update=make_update('meters'))
    unit_inches: bpy.props.FloatProperty(name="Inches", precision=4, update=make_update('inches'))
    unit_cm: bpy.props.FloatProperty(name="Centimeters", precision=4, update=make_update('cm'))
    unit_yards: bpy.props.FloatProperty(name="Yards", precision=4, update=make_update('yards'))
    unit_km: bpy.props.FloatProperty(name="Kilometers", precision=4, update=make_update('km'))
    unit_miles: bpy.props.FloatProperty(name="Miles", precision=4, update=make_update('miles'))

class AP_PT_LengthConverter(bpy.types.Panel):
    bl_label = "Length Converter"
    bl_idname = "AP_PT_LengthConverter"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'AP Tools'

    def draw(self, context):
        layout = self.layout
        props = context.scene.ap_length_props

        layout.prop(props, "conv_mode", expand=True)
        
        col = layout.column(align=True)
        is_area = props.conv_mode == 'AREA'
        
        units = [
            ("feet", "Feet"),
            ("meters", "Meters"),
            ("inches", "Inches"),
            ("cm", "Centimeters"),
            ("yards", "Yards"),
            ("km", "Kilometers"),
            ("miles", "Miles")
        ]
        
        for attr, label in units:
            row = col.row()
            if is_area:
                row.label(text=f"{label}²")
            else:
                row.label(text=label)
            row.prop(props, f"unit_{attr}", text="")

classes = (
    AP_LengthProps,
    AP_PT_LengthConverter,
)

def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.ap_length_props = bpy.props.PointerProperty(type=AP_LengthProps)

def unregister():
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
    del bpy.types.Scene.ap_length_props

if __name__ == "__main__":
    register()
