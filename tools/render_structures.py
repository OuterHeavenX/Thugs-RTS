"""Render the 4 Thugs RTS structure sprites headless.

Isometric look: orthographic camera, azimuth 45 deg, elevation 30 deg
(matches the game's 2:1 tile projection), transparent background, 256x256.
Building footprint base sits centered at the bottom-center of the image.

Outputs:
  assets/structures/{hq,barracks}_{america,asia}.png
  assets/blender/{hq,barracks}_{america,asia}.blend   (sources)
"""
import bpy
import math
import os

ROOT = os.path.expanduser("~/workspace/thugs-rts")
OUT = os.path.join(ROOT, "assets", "structures")
BLEND_OUT = os.path.join(ROOT, "assets", "blender")
os.makedirs(OUT, exist_ok=True)
os.makedirs(BLEND_OUT, exist_ok=True)

BLUE = (0.16, 0.38, 0.95, 1.0)   # america
RED = (0.92, 0.16, 0.14, 1.0)    # asia
WALL = (0.80, 0.80, 0.84, 1.0)
ROOF = (0.36, 0.37, 0.42, 1.0)
DARK = (0.15, 0.15, 0.19, 1.0)

_mats = {}


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras):
        for x in list(coll):
            coll.remove(x)
    _mats.clear()


def mat(name, color):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = color
    b.inputs["Emission Color"].default_value = color
    b.inputs["Emission Strength"].default_value = 0.85
    b.inputs["Roughness"].default_value = 0.9
    _mats[name] = m
    return m


def box(name, dims, loc, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.dimensions = dims
    # dimensions assignment updates scale; apply visual only
    o.data.materials.append(material)
    return o


def cone4(name, radius, depth, loc, material, scale_xy=(1.0, 1.0)):
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=radius, radius2=0.0, depth=depth,
        location=loc, rotation=(0.0, 0.0, math.pi / 4.0))
    o = bpy.context.active_object
    o.name = name
    o.scale.x *= scale_xy[0]
    o.scale.y *= scale_xy[1]
    o.data.materials.append(material)
    return o


def cylinder(name, radius, depth, loc, material):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    return o


def plane(name, w, h, loc, material):
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (w, h, 1.0)
    o.data.materials.append(material)
    return o


def flag_pole(x, y, base_z, height, accent_mat, dark_mat, flag_w=0.6, flag_h=0.36):
    cylinder("pole", 0.035, height, (x, y, base_z + height / 2.0), dark_mat)
    plane("flag", flag_w, flag_h,
          (x + flag_w / 2.0 + 0.03, y, base_z + height - flag_h / 2.0 - 0.05),
          accent_mat)


def build_hq(accent):
    wall = mat("wall", WALL)
    dark = mat("dark", DARK)
    acc = mat("accent", accent)
    box("hq_base", (2.3, 2.3, 1.0), (0, 0, 0.5), wall)
    box("hq_trim", (2.38, 2.38, 0.18), (0, 0, 1.02), acc)
    box("hq_mid", (1.6, 1.6, 0.8), (0, 0, 1.5), wall)
    cone4("hq_roof", 1.35, 0.9, (0, 0, 2.35), acc)
    box("hq_door", (0.55, 0.12, 0.85), (0, 1.16, 0.43), dark)
    box("hq_win1", (0.42, 0.10, 0.42), (-0.70, 1.14, 0.62), dark)
    box("hq_win2", (0.42, 0.10, 0.42), (0.70, 1.14, 0.62), dark)
    flag_pole(0.95, 0.95, 1.0, 1.7, acc, dark)


def build_barracks(accent):
    wall = mat("wall", WALL)
    dark = mat("dark", DARK)
    acc = mat("accent", accent)
    roofm = mat("roof", ROOF)
    box("bx_base", (2.7, 1.9, 0.95), (0, 0, 0.475), wall)
    box("bx_trim", (2.78, 1.98, 0.16), (0, 0, 0.99), acc)
    cone4("bx_roof", 1.05, 0.75, (0, 0, 1.45), roofm, scale_xy=(1.55, 1.10))
    box("bx_door", (0.62, 0.12, 0.80), (0, 0.96, 0.40), dark)
    box("bx_win1", (0.45, 0.10, 0.40), (-0.85, 0.94, 0.55), dark)
    box("bx_win2", (0.45, 0.10, 0.40), (0.85, 0.94, 0.55), dark)
    flag_pole(1.15, 0.75, 0.9, 1.5, acc, dark, flag_w=0.55, flag_h=0.34)


def setup_camera():
    az = math.radians(45.0)
    el = math.radians(30.0)
    d = (math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el))
    u = (-math.sin(el) * math.cos(az), -math.sin(el) * math.sin(az), math.cos(el))
    t = 1.30  # shift so the building base lands near bottom-center
    target = (u[0] * t, u[1] * t, u[2] * t)

    bpy.ops.object.empty_add(location=target)
    tgt = bpy.context.active_object
    tgt.name = "CamTarget"

    cd = bpy.data.cameras.new("IsoCam")
    cd.type = "ORTHO"
    cd.ortho_scale = 5.2
    co = bpy.data.objects.new("IsoCam", cd)
    bpy.context.scene.collection.objects.link(co)
    co.location = (target[0] + d[0] * 10.0,
                   target[1] + d[1] * 10.0,
                   target[2] + d[2] * 10.0)
    con = co.constraints.new("TRACK_TO")
    con.target = tgt
    con.track_axis = "TRACK_NEGATIVE_Z"
    con.up_axis = "UP_Y"
    bpy.context.scene.camera = co


def configure_render():
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.samples = 1
    s.cycles.device = "CPU"
    s.render.resolution_x = 256
    s.render.resolution_y = 256
    s.render.resolution_percentage = 100
    s.render.film_transparent = True
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA"


BUILDERS = {"hq": build_hq, "barracks": build_barracks}
FACTIONS = {"america": BLUE, "asia": RED}

configure_render()
for btype, builder in BUILDERS.items():
    for fname, fcolor in FACTIONS.items():
        clear_scene()
        setup_camera()
        builder(fcolor)
        bpy.ops.wm.save_as_mainfile(
            filepath=os.path.join(BLEND_OUT, "%s_%s.blend" % (btype, fname)))
        bpy.context.scene.render.filepath = os.path.join(
            OUT, "%s_%s.png" % (btype, fname))
        bpy.ops.render.render(write_still=True)
        print("RENDERED %s_%s" % (btype, fname), flush=True)

print("ALL RENDERS DONE", flush=True)
