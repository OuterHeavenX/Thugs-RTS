"""Shared helpers for the WORLD COMMAND Blender art pipeline.

Blender 4.5 LTS, headless. Conventions:
- Z-up, meters. Model origin at bottom-center, geometry at z >= 0.
- Primitives are created then fully baked (location/rotation/scale applied),
  so exported meshes carry identity object transforms. Special nodes
  (Turret / Rotor / Dish) keep a translation-only transform with their
  origin exactly on the pivot/spin axis.
- Materials: Principled BSDF only (Base Color, Metallic, Roughness,
  Emission Color/Strength).
"""
import bpy
import os
import json
import math

ROOT = os.path.expanduser("~/workspace/world-command")
MANIFEST_PATH = os.path.join(ROOT, "assets", "manifest.json")

# ------------------------------------------------------------------ scene
def clear_scene():
    if bpy.ops.object.mode_set.poll():
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.object.select_all(action='DESELECT')
    for col in (bpy.data.meshes, bpy.data.materials):
        for x in list(col):
            if x.users == 0:
                col.remove(x)


def deselect_all():
    bpy.ops.object.select_all(action='DESELECT')


def select(obj):
    deselect_all()
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)


def update():
    bpy.context.view_layer.update()


# -------------------------------------------------------------- materials
def mat(name, base=(0.8, 0.8, 0.8, 1), metallic=0.0, roughness=0.5,
        emission=(0, 0, 0, 1), emission_strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = base
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission_strength > 0.0:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return m


def us_palette():
    return {
        "hull":  mat("US_Hull",  base=(0.42, 0.44, 0.47, 1), metallic=0.55, roughness=0.50),
        "navy":  mat("US_Navy",  base=(0.07, 0.11, 0.22, 1), metallic=0.35, roughness=0.60),
        "white": mat("US_White", base=(0.82, 0.84, 0.87, 1), metallic=0.15, roughness=0.45),
        "dark":  mat("US_Dark",  base=(0.10, 0.10, 0.12, 1), metallic=0.60, roughness=0.50),
        "glass": mat("US_Glass", base=(0.08, 0.18, 0.32, 1), metallic=0.20, roughness=0.25,
                     emission=(0.15, 0.45, 1.0, 1), emission_strength=1.5),
        "glow":  mat("US_Glow",  base=(0.02, 0.05, 0.10, 1), metallic=0.00, roughness=0.40,
                     emission=(0.20, 0.55, 1.0, 1), emission_strength=3.0),
        "tire":  mat("US_Tire",  base=(0.05, 0.05, 0.06, 1), metallic=0.00, roughness=0.90),
    }


def jp_palette():
    return {
        "white":    mat("JP_White",    base=(0.90, 0.90, 0.92, 1), metallic=0.05, roughness=0.35),
        "graphite": mat("JP_Graphite", base=(0.14, 0.14, 0.16, 1), metallic=0.75, roughness=0.40),
        "gray":     mat("JP_Gray",     base=(0.45, 0.46, 0.49, 1), metallic=0.50, roughness=0.50),
        "glass":    mat("JP_Glass",    base=(0.25, 0.06, 0.08, 1), metallic=0.20, roughness=0.25,
                        emission=(0.90, 0.15, 0.12, 1), emission_strength=1.2),
        "glow":     mat("JP_Glow",     base=(0.10, 0.02, 0.02, 1), metallic=0.00, roughness=0.40,
                        emission=(1.00, 0.12, 0.08, 1), emission_strength=3.0),
    }


def env_palette():
    return {
        "wood":     mat("ENV_Wood",     base=(0.45, 0.32, 0.20, 1), metallic=0.00, roughness=0.85),
        "metal":    mat("ENV_Metal",    base=(0.50, 0.52, 0.52, 1), metallic=0.70, roughness=0.45),
        "hazard":   mat("ENV_Hazard",   base=(0.95, 0.70, 0.05, 1), metallic=0.00, roughness=0.60),
        "crystal":  mat("ENV_Crystal",  base=(0.10, 0.50, 0.60, 1), metallic=0.00, roughness=0.20,
                        emission=(0.25, 0.90, 1.00, 1), emission_strength=2.5),
        "rock":     mat("ENV_Rock",     base=(0.35, 0.33, 0.32, 1), metallic=0.00, roughness=0.95),
        "rockdark": mat("ENV_RockDark", base=(0.22, 0.21, 0.20, 1), metallic=0.00, roughness=0.95),
        "trunk":    mat("ENV_Trunk",    base=(0.30, 0.20, 0.12, 1), metallic=0.00, roughness=0.90),
        "leaf":     mat("ENV_Leaf",     base=(0.12, 0.35, 0.16, 1), metallic=0.00, roughness=0.80),
        "concrete": mat("ENV_Concrete", base=(0.50, 0.50, 0.52, 1), metallic=0.00, roughness=0.90),
        "rust":     mat("ENV_Rust",     base=(0.45, 0.25, 0.12, 1), metallic=0.30, roughness=0.85),
        "pile":     mat("ENV_Pile",     base=(0.40, 0.38, 0.35, 1), metallic=0.10, roughness=0.90),
    }


# -------------------------------------------------------------- primitives
def _finish(o, name, material):
    o.name = name
    select(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    deselect_all()
    if material is not None:
        o.data.materials.append(material)
    return o


def box(name, sx, sy, sz, loc=(0, 0, 0), rot=(0, 0, 0), material=None):
    deselect_all()
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    o.rotation_euler = rot
    o.location = loc
    return _finish(o, name, material)


def cyl(name, r, h, loc=(0, 0, 0), rot=(0, 0, 0), verts=12, material=None):
    deselect_all()
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=verts,
                                       location=(0, 0, 0))
    o = bpy.context.active_object
    o.rotation_euler = rot
    o.location = loc
    return _finish(o, name, material)


def cone(name, r_bottom, r_top, h, loc=(0, 0, 0), rot=(0, 0, 0), verts=12,
         material=None):
    deselect_all()
    bpy.ops.mesh.primitive_cone_add(radius1=r_bottom, radius2=r_top, depth=h,
                                   vertices=verts, location=(0, 0, 0))
    o = bpy.context.active_object
    o.rotation_euler = rot
    o.location = loc
    return _finish(o, name, material)


def sphere(name, r, loc=(0, 0, 0), rot=(0, 0, 0), seg=12, rings=8,
           material=None, scale=None):
    deselect_all()
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=seg,
                                        ring_count=rings, location=(0, 0, 0))
    o = bpy.context.active_object
    if scale is not None:
        o.scale = scale
    o.rotation_euler = rot
    o.location = loc
    return _finish(o, name, material)


def ico(name, r, loc=(0, 0, 0), rot=(0, 0, 0), subdiv=1, material=None,
        scale=None):
    deselect_all()
    bpy.ops.mesh.primitive_ico_sphere_add(radius=r, subdivisions=subdiv,
                                         location=(0, 0, 0))
    o = bpy.context.active_object
    if scale is not None:
        o.scale = scale
    o.rotation_euler = rot
    o.location = loc
    return _finish(o, name, material)


def torus(name, R, r, loc=(0, 0, 0), rot=(0, 0, 0), material=None,
          major_seg=16, minor_seg=8):
    deselect_all()
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r,
                                     major_segments=major_seg,
                                     minor_segments=minor_seg,
                                     location=(0, 0, 0))
    o = bpy.context.active_object
    o.rotation_euler = rot
    o.location = loc
    return _finish(o, name, material)


def empty(name, loc, parent=None, size=0.3):
    deselect_all()
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=loc)
    o = bpy.context.active_object
    o.name = name
    o.empty_display_size = size
    if parent is not None:
        update()
        o.parent = parent
        o.matrix_parent_inverse = parent.matrix_world.inverted()
    deselect_all()
    return o


def join(new_name, parts, pivot=None):
    """Join baked mesh parts; optionally move origin to pivot (keeps placement)."""
    deselect_all()
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = new_name
    deselect_all()
    if pivot is not None:
        # Parts are modeled around the local origin (= the pivot point), so
        # just translate the object: origin lands on the pivot and the
        # engine can rotate the node around its own origin.
        o.location = tuple(pivot)
    return o


# ---------------------------------------------------------------- pipeline
def triangle_count():
    total = 0
    for o in bpy.data.objects:
        if o.type == 'MESH':
            me = o.data
            me.calc_loop_triangles()
            total += len(me.loop_triangles)
    return total


def thumb(name, size=192):
    """Cycles CPU thumbnail from a fixed 3/4 angle. Best-effort; never fails.

    (BLENDER_WORKBENCH render aborts headless here - no libEGL. Cycles CPU
    works fine, so thumbnails use Cycles with 2 samples + sun rig.)
    """
    try:
        import mathutils
        update()
        lo = mathutils.Vector((1e9, 1e9, 1e9))
        hi = mathutils.Vector((-1e9, -1e9, -1e9))
        found = False
        for o in bpy.data.objects:
            if o.type == 'MESH':
                found = True
                for c in o.bound_box:
                    w = o.matrix_world @ mathutils.Vector(c)
                    lo.x, lo.y, lo.z = min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)
                    hi.x, hi.y, hi.z = max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)
        if not found:
            return
        center = (lo + hi) * 0.5
        span = hi - lo
        radius = max(span.x, span.y, span.z, 0.5)
        dist = radius * 2.2
        off = mathutils.Vector((1, 1, 0.55)).normalized() * dist
        rig = []
        deselect_all()
        bpy.ops.object.camera_add(location=center + off)
        cam = bpy.context.active_object
        rig.append(cam)
        bpy.ops.object.empty_add(location=center)
        tgt = bpy.context.active_object
        rig.append(tgt)
        con = cam.constraints.new(type='TRACK_TO')
        con.target = tgt
        con.track_axis = 'TRACK_NEGATIVE_Z'
        con.up_axis = 'UP_Y'
        # sun rig: key + fill so shadow sides are readable
        bpy.ops.object.light_add(type='SUN', location=center + mathutils.Vector((6, -4, 9)))
        key = bpy.context.active_object
        key.data.energy = 3.0
        rig.append(key)
        bpy.ops.object.light_add(type='SUN', location=center + mathutils.Vector((-7, 5, 4)))
        fill = bpy.context.active_object
        fill.data.energy = 0.9
        rig.append(fill)
        sc = bpy.context.scene
        sc.camera = cam
        sc.render.engine = 'CYCLES'
        sc.cycles.device = 'CPU'
        sc.cycles.samples = 2
        sc.cycles.use_denoising = False
        sc.render.resolution_x = size
        sc.render.resolution_y = size
        sc.render.resolution_percentage = 100
        sc.render.film_transparent = True
        tdir = os.path.join(ROOT, "assets", "thumbs")
        os.makedirs(tdir, exist_ok=True)
        sc.render.filepath = os.path.join(tdir, name + ".png")
        sc.render.image_settings.file_format = 'PNG'
        bpy.ops.render.render(write_still=True)
        deselect_all()
        for o in rig:
            bpy.data.objects.remove(o, do_unlink=True)
        print("THUMB", name)
    except Exception as e:  # noqa: BLE001 - thumbnails are a bonus
        print("THUMB FAILED", name, repr(e))


def export_glb(name, category):
    outdir = os.path.join(ROOT, "assets", "models", category)
    os.makedirs(outdir, exist_ok=True)
    path = os.path.join(outdir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB',
                              export_materials='EXPORT',
                              export_cameras=False, export_lights=False)
    print("EXPORTED", path, os.path.getsize(path), "bytes")


def save_blend(name):
    d = os.path.join(ROOT, "assets", "blender", "source")
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, name + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=path)
    print("BLEND", path)


def record(category, name, named_nodes):
    tris = triangle_count()
    entry = {"file": "assets/models/%s/%s.glb" % (category, name),
             "category": category, "name": name, "triangles": tris,
             "named_nodes": named_nodes}
    data = []
    if os.path.exists(MANIFEST_PATH):
        with open(MANIFEST_PATH) as f:
            data = json.load(f)
    data = [e for e in data if e["name"] != name]
    data.append(entry)
    with open(MANIFEST_PATH, "w") as f:
        json.dump(data, f, indent=1)
    print("RECORD %s: %d tris nodes=%s" % (name, tris, named_nodes))


def finish_asset(name, category, named_nodes):
    thumb(name)
    export_glb(name, category)
    save_blend(name)
    record(category, name, named_nodes)


# --------------------------------------------------------------- humanoid
def humanoid(prefix, M, style):
    """~1.8m infantry figure from primitives. M keys: torso/limbs/accent/glow/dark.

    style keys: slim (width scale), rifle (bool), rail (long rail rifle),
    backpack (bool, default True), tool (hand tool), blade (melee blade).
    Returns dict of interesting world points (e.g. 'muzzle').
    """
    from math import pi
    T, L, A, GL, D = M["torso"], M["limbs"], M["accent"], M["glow"], M["dark"]
    s = style.get("slim", 1.0)
    pts = {}
    # legs + boots
    cyl(prefix + "_LegL", 0.075 * s, 0.85, loc=(-0.11 * s, 0, 0.425), material=L)
    cyl(prefix + "_LegR", 0.075 * s, 0.85, loc=(0.11 * s, 0, 0.425), material=L)
    box(prefix + "_BootL", 0.16 * s, 0.28, 0.12, loc=(-0.11 * s, 0.04, 0.06), material=D)
    box(prefix + "_BootR", 0.16 * s, 0.28, 0.12, loc=(0.11 * s, 0.04, 0.06), material=D)
    # torso
    box(prefix + "_Torso", 0.44 * s, 0.28, 0.62, loc=(0, 0, 1.12), material=T)
    box(prefix + "_Chest", 0.46 * s, 0.10, 0.40, loc=(0, 0.15, 1.18), material=A)
    box(prefix + "_Belt", 0.46 * s, 0.30, 0.10, loc=(0, 0, 0.82), material=D)
    # arms + shoulder pads
    cyl(prefix + "_ArmL", 0.06 * s, 0.62, loc=(-0.29 * s, 0, 1.12), material=L)
    cyl(prefix + "_ArmR", 0.06 * s, 0.62, loc=(0.29 * s, 0, 1.12), material=L)
    box(prefix + "_PadL", 0.17 * s, 0.20, 0.12, loc=(-0.29 * s, 0, 1.42), material=A)
    box(prefix + "_PadR", 0.17 * s, 0.20, 0.12, loc=(0.29 * s, 0, 1.42), material=A)
    # head + helmet + visor glow
    sphere(prefix + "_Head", 0.13, loc=(0, 0, 1.62), material=L)
    sphere(prefix + "_Helmet", 0.155, loc=(0, -0.01, 1.65), material=A,
           scale=(1, 1.05, 0.85))
    box(prefix + "_Visor", 0.20, 0.06, 0.07, loc=(0, 0.12, 1.63), material=GL)
    if style.get("backpack", True):
        box(prefix + "_Pack", 0.36 * s, 0.20, 0.46, loc=(0, -0.24, 1.12), material=A)
        box(prefix + "_PackLight", 0.10, 0.05, 0.10, loc=(0.10, -0.36, 1.20), material=GL)
    if style.get("tool"):
        cyl(prefix + "_ToolHandle", 0.03, 0.50, loc=(0.33 * s, 0.10, 0.90),
            rot=(0.3, 0, 0), verts=8, material=D)
        box(prefix + "_ToolHead", 0.08, 0.20, 0.08, loc=(0.33 * s, 0.24, 1.12),
            material=A)
    if style.get("rifle"):
        box(prefix + "_RifleBody", 0.10, 0.62, 0.16, loc=(0.24, 0.30, 1.18), material=D)
        cyl(prefix + "_RifleBarrel", 0.032, 0.55, loc=(0.24, 0.85, 1.20),
            rot=(pi / 2, 0, 0), verts=8, material=D)
        box(prefix + "_RifleStock", 0.09, 0.25, 0.14, loc=(0.24, -0.05, 1.16), material=A)
        box(prefix + "_RifleGrip", 0.07, 0.08, 0.18, loc=(0.24, 0.12, 1.05), material=D)
        box(prefix + "_RifleSight", 0.05, 0.12, 0.06, loc=(0.24, 0.35, 1.30), material=GL)
        pts["muzzle"] = (0.24, 1.16, 1.20)
    if style.get("rail"):
        box(prefix + "_RailBody", 0.12, 0.95, 0.18, loc=(0.24, 0.35, 1.18), material=D)
        cyl(prefix + "_RailBarrel", 0.035, 1.15, loc=(0.24, 1.15, 1.20),
            rot=(pi / 2, 0, 0), verts=8, material=A)
        for i, yy in enumerate((0.85, 1.10, 1.35)):
            torus(prefix + "_Coil%d" % i, 0.075, 0.022, loc=(0.24, yy, 1.20),
                  rot=(pi / 2, 0, 0), material=GL, major_seg=8, minor_seg=6)
        box(prefix + "_RailStock", 0.10, 0.28, 0.15, loc=(0.24, -0.18, 1.16), material=A)
        box(prefix + "_RailCell", 0.08, 0.10, 0.12, loc=(0.24, 0.30, 1.34), material=GL)
        pts["muzzle"] = (0.24, 1.75, 1.20)
    if style.get("blade"):
        box(prefix + "_Blade", 0.07, 0.85, 0.16, loc=(0.30 * s, 0.45, 1.05),
            rot=(0.25, 0, 0), material=A)
        box(prefix + "_BladeEdge", 0.075, 0.80, 0.03, loc=(0.30 * s, 0.47, 1.02),
            rot=(0.25, 0, 0), material=GL)
    return pts
