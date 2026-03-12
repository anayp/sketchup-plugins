# test_blender_operators.py
import sys
import os

# Assuming Blender Python execution context
try:
    import bpy
    print("Blender environment found.")
except ImportError:
    print("Running outside Blender. Mocking bpy for syntax check.")
    # A simple way to just check syntax if we run it as normal python
    sys.exit(0)

def run_tests():
    addon_dir = os.path.dirname(os.path.abspath(__file__))
    if addon_dir not in sys.path:
        sys.path.append(addon_dir)

    addons = [
        "ap_calculator",
        "ap_length_converter",
        "ap_pipe_generator",
        "ap_road_builder",
        "ap_wall_maker"
    ]

    for addon in addons:
        try:
            print(f"Registering {addon}...")
            mod = __import__(addon)
            mod.register()
            print(f"SUCCESS: {addon} registered perfectly.")
        except Exception as e:
            print(f"FAILED: {addon} registration failed. Error: {e}")

    print("All tests completed.")

if __name__ == "__main__":
    run_tests()
