"""US units for WORLD COMMAND (6 assets). Run: blender -b --python units_us.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from math import pi

CAT = "units"


def _us_inf_mats():
    P = us_palette()
    return {"torso": P["navy"], "limbs": P["navy"], "accent": P["hull"],
            "glow": P["glow"], "dark": P["dark"]}


def build_us_worker():
    clear_scene()
    M = _us_inf_mats()
    M["torso"] = us_palette()["hull"]  # gray work vest over navy suit
    humanoid("Worker", M, {"tool": True, "backpack": True})
    finish_asset("us_worker", CAT, [])


def build_us_ranger():
    clear_scene()
    M = _us_inf_mats()
    pts = humanoid("Ranger", M, {"rifle": True, "backpack": True})
    empty("Muzzle", pts["muzzle"])
    finish_asset("us_ranger", CAT, ["Muzzle"])


def build_us_guardian_ifv():
    clear_scene()
    P = us_palette()
    H, N, W, D, G, GL, TR = (P["hull"], P["navy"], P["white"], P["dark"],
                             P["glass"], P["glow"], P["tire"])
    # hull
    box("HullLow", 2.2, 4.5, 0.8, loc=(0, 0, 0.85), material=H)      # 0.45..1.25
    box("HullUp", 2.0, 3.6, 0.6, loc=(0, -0.2, 1.55), material=H)    # 1.25..1.85
    box("NoseWedge", 2.0, 1.3, 0.55, loc=(0, 1.85, 1.45), rot=(-0.45, 0, 0), material=N)
    box("SideSkirtL", 0.12, 4.2, 0.5, loc=(1.16, 0, 0.8), material=N)
    box("SideSkirtR", 0.12, 4.2, 0.5, loc=(-1.16, 0, 0.8), material=N)
    box("HeadlightL", 0.18, 0.08, 0.12, loc=(0.7, 2.28, 1.0), material=GL)
    box("HeadlightR", 0.18, 0.08, 0.12, loc=(-0.7, 2.28, 1.0), material=GL)
    box("RearStrip", 1.8, 0.08, 0.12, loc=(0, -2.28, 1.1), material=GL)
    box("Hatch", 0.9, 0.9, 0.12, loc=(0, -1.2, 1.9), material=D)
    # 6 wheels
    for sx in (-1, 1):
        for i, yy in enumerate((-1.4, 0.0, 1.4)):
            cyl("Wheel", 0.45, 0.35, loc=(sx * 1.12, yy, 0.45),
                rot=(0, pi / 2, 0), verts=12, material=TR)
            cyl("Hub", 0.18, 0.37, loc=(sx * 1.12, yy, 0.45),
                rot=(0, pi / 2, 0), verts=8, material=H)
    # THE turret
    pivot = (0, 0.3, 2.0)
    t1 = box("TP_Hull", 1.5, 1.7, 0.55, loc=(0, 0, 0), material=H)
    t2 = box("TP_Mantlet", 0.6, 0.4, 0.45, loc=(0, 0.85, 0.05), material=N)
    t3 = cyl("TP_Barrel", 0.08, 1.9, loc=(0, 1.75, 0.08), rot=(pi / 2, 0, 0),
             verts=10, material=D)
    t4 = box("TP_Sight", 0.3, 0.25, 0.2, loc=(-0.45, 0.1, 0.36), material=D)
    t5 = box("TP_Strip", 1.55, 0.12, 0.1, loc=(0, -0.6, 0.1), material=GL)
    turret = join("Turret", [t1, t2, t3, t4, t5], pivot=pivot)
    empty("Muzzle", (0, 2.75, 2.08), parent=turret)

    finish_asset("us_guardian_ifv", CAT, ["Turret", "Muzzle"])


def build_us_abramsx():
    clear_scene()
    P = us_palette()
    H, N, W, D, G, GL, TR = (P["hull"], P["navy"], P["white"], P["dark"],
                             P["glass"], P["glow"], P["tire"])
    # tracks
    box("TrackL", 0.7, 4.6, 0.85, loc=(1.0, 0, 0.55), material=TR)
    box("TrackR", 0.7, 4.6, 0.85, loc=(-1.0, 0, 0.55), material=TR)
    for sx in (-1, 1):
        for i, yy in enumerate((-1.5, -0.5, 0.5, 1.5)):
            cyl("RoadWheel", 0.30, 0.12, loc=(sx * 1.38, yy, 0.42),
                rot=(0, pi / 2, 0), verts=10, material=D)
    box("SkirtL", 0.1, 4.4, 0.4, loc=(1.4, 0, 1.05), material=N)
    box("SkirtR", 0.1, 4.4, 0.4, loc=(-1.4, 0, 1.05), material=N)
    # hull
    box("HullLow", 2.1, 4.4, 0.7, loc=(0, 0, 1.15), material=H)      # 0.8..1.5
    box("HullUp", 2.3, 3.8, 0.5, loc=(0, -0.2, 1.7), material=H)     # 1.45..1.95
    box("Glacis", 2.3, 1.2, 0.45, loc=(0, 1.95, 1.5), rot=(-0.5, 0, 0), material=N)
    box("RearDeck", 2.0, 1.2, 0.15, loc=(0, -1.7, 2.0), material=D)
    box("HeadlightL", 0.2, 0.08, 0.12, loc=(0.8, 2.32, 1.35), material=GL)
    box("HeadlightR", 0.2, 0.08, 0.12, loc=(-0.8, 2.32, 1.35), material=GL)
    # THE turret (angular)
    pivot = (0, -0.3, 2.15)
    t1 = box("TP_Hull", 2.0, 2.4, 0.7, loc=(0, 0, 0.1), material=H)
    t2 = box("TP_Front", 1.8, 0.9, 0.6, loc=(0, 1.25, 0.05), rot=(-0.35, 0, 0), material=N)
    t3 = cyl("TP_Barrel", 0.11, 2.8, loc=(0, 2.4, 0.15), rot=(pi / 2, 0, 0),
             verts=12, material=D)
    t4 = box("TP_Mantlet", 0.6, 0.5, 0.5, loc=(0, 1.0, 0.15), material=N)
    t5 = cyl("TP_Hatch", 0.3, 0.12, loc=(-0.5, -0.5, 0.5), verts=10, material=D)
    t6 = box("TP_MG", 0.12, 0.9, 0.12, loc=(0.5, -0.3, 0.65), material=D)
    t7 = box("TP_Strip", 1.6, 0.1, 0.12, loc=(0, -1.22, 0.15), material=GL)
    turret = join("Turret", [t1, t2, t3, t4, t5, t6, t7], pivot=pivot)
    empty("Muzzle", (0, 3.5, 2.3), parent=turret)

    finish_asset("us_abramsx", CAT, ["Turret", "Muzzle"])


def build_us_reaper_drone():
    clear_scene()
    P = us_palette()
    H, N, W, D, G, GL = P["hull"], P["navy"], P["white"], P["dark"], P["glass"], P["glow"]

    # landing skids (sits at z=0; engine hovers it)
    box("SkidL", 0.07, 0.6, 0.07, loc=(0.28, 0, 0.15), material=D)
    box("SkidR", 0.07, 0.6, 0.07, loc=(-0.28, 0, 0.15), material=D)
    box("LegL", 0.06, 0.06, 0.3, loc=(0.28, 0, 0.32), material=D)
    box("LegR", 0.06, 0.06, 0.3, loc=(-0.28, 0, 0.32), material=D)
    # body
    box("Body", 0.52, 0.42, 0.24, loc=(0, 0, 0.55), material=H)
    box("Belly", 0.4, 0.3, 0.1, loc=(0, 0, 0.40), material=N)
    sphere("Eye", 0.075, loc=(0, 0.22, 0.57), material=GL)
    box("TopPlate", 0.3, 0.25, 0.06, loc=(0, 0, 0.70), material=N)
    # arms + motor pods
    box("ArmX", 1.15, 0.10, 0.08, loc=(0, 0, 0.62), material=D)
    box("ArmZ", 0.10, 1.15, 0.08, loc=(0, 0, 0.62), material=D)
    for i, (sx, sy) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1))):
        cyl("Motor%d" % i, 0.09, 0.14, loc=(sx * 0.5, sy * 0.5, 0.64),
            verts=10, material=N)
        r1 = cyl("RotorHub%d" % i, 0.05, 0.06, loc=(0, 0, 0), verts=8, material=D)
        r2 = box("RotorBlade%d" % i, 0.62, 0.09, 0.025, loc=(0, 0, 0.02), material=H)
        r3 = cyl("RotorDisc%d" % i, 0.30, 0.015, loc=(0, 0, 0.035), verts=12,
                 material=D)
        rotor = join("Rotor_%d" % (i + 1), [r1, r2, r3])
        rotor.location = (sx * 0.5, sy * 0.5, 0.74)

    finish_asset("us_reaper_drone", CAT, ["Rotor_1", "Rotor_2", "Rotor_3", "Rotor_4"])


def build_us_paladin():
    clear_scene()
    P = us_palette()
    H, N, W, D, G, GL, TR = (P["hull"], P["navy"], P["white"], P["dark"],
                             P["glass"], P["glow"], P["tire"])
    # cab (front, +Y)
    box("Cab", 2.2, 1.5, 1.5, loc=(0, 1.75, 1.35), material=H)       # 0.6..2.1
    box("Windshield", 1.9, 0.12, 0.6, loc=(0, 2.52, 1.75), material=G)
    box("Bumper", 2.3, 0.3, 0.35, loc=(0, 2.6, 0.55), material=D)
    box("Grill", 1.6, 0.1, 0.4, loc=(0, 2.52, 1.0), material=D)
    box("HeadlightL", 0.25, 0.08, 0.15, loc=(0.85, 2.52, 1.25), material=GL)
    box("HeadlightR", 0.25, 0.08, 0.15, loc=(-0.85, 2.52, 1.25), material=GL)
    # chassis + bed
    box("Chassis", 2.0, 3.6, 0.4, loc=(0, -0.5, 0.75), material=D)
    box("Bed", 2.2, 2.6, 0.25, loc=(0, -1.0, 1.05), material=N)
    # 6 wheels
    for sx in (-1, 1):
        for i, yy in enumerate((1.6, -0.6, -1.7)):
            cyl("Wheel", 0.45, 0.35, loc=(sx * 1.12, yy, 0.45),
                rot=(0, pi / 2, 0), verts=12, material=TR)
    # launcher: turntable + angled tube cluster
    cyl("Turntable", 0.9, 0.35, loc=(0, -1.0, 1.35), verts=12, material=D)
    box("LauncherBase", 1.7, 1.5, 0.4, loc=(0, -1.0, 1.65), material=N)
    for ix, xx in enumerate((-0.55, 0.0, 0.55)):
        for iy, yy in enumerate((-1.35, -0.65)):
            cyl("Tube", 0.17, 2.3, loc=(xx, yy + 0.35, 2.95),
                rot=(-0.9, 0, 0), verts=10, material=H)
            cyl("TubeRim", 0.19, 0.12, loc=(xx, yy + 1.22, 3.62),
                rot=(-0.9, 0, 0), verts=10, material=D)
    box("LauncherStrip", 1.75, 0.1, 0.12, loc=(0, -1.78, 1.65), material=GL)
    # muzzle at the tube cluster mouth
    empty("Muzzle", (0, 0.75, 3.75))

    finish_asset("us_paladin", CAT, ["Muzzle"])


build_us_worker()
build_us_ranger()
build_us_guardian_ifv()
build_us_abramsx()
build_us_reaper_drone()
build_us_paladin()
print("UNITS_US DONE")
