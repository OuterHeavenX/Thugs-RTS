"""Japanese units for WORLD COMMAND (6 assets). Run: blender -b --python units_jp.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from math import pi

CAT = "units"


def _jp_inf_mats():
    P = jp_palette()
    return {"torso": P["white"], "limbs": P["graphite"], "accent": P["gray"],
            "glow": P["glow"], "dark": P["graphite"]}


def build_jp_worker():
    clear_scene()
    M = _jp_inf_mats()
    humanoid("Worker", M, {"tool": True, "backpack": True})
    finish_asset("jp_worker", CAT, [])


def build_jp_raiden():
    clear_scene()
    M = _jp_inf_mats()
    M["accent"] = jp_palette()["white"]
    pts = humanoid("Raiden", M, {"rail": True, "backpack": True})
    empty("Muzzle", pts["muzzle"])
    finish_asset("jp_raiden", CAT, ["Muzzle"])


def build_jp_shinobi():
    clear_scene()
    M = _jp_inf_mats()
    M["torso"] = jp_palette()["graphite"]
    M["accent"] = jp_palette()["white"]
    humanoid("Shinobi", M, {"slim": 0.85, "blade": True, "backpack": False})
    finish_asset("jp_shinobi", CAT, [])


def build_jp_tora():
    """Hover tank: skirt + hover pads, fixed casemate gun (no turret)."""
    clear_scene()
    P = jp_palette()
    WH, GR, GY, GS, GL = P["white"], P["graphite"], P["gray"], P["glass"], P["glow"]

    # skirt + hull
    box("Skirt", 3.2, 4.0, 0.55, loc=(0, 0, 0.55), material=GR)      # 0.275..0.825
    box("SkirtTrim", 3.25, 4.05, 0.12, loc=(0, 0, 0.85), material=GL)
    box("Hull", 2.6, 3.6, 0.7, loc=(0, 0, 1.15), material=WH)        # 0.8..1.5
    box("Deck", 2.2, 2.6, 0.25, loc=(0, -0.3, 1.6), material=GR)
    box("NosePlate", 2.4, 0.9, 0.5, loc=(0, 1.95, 1.0), rot=(-0.4, 0, 0), material=GY)
    # hover pads with red glow
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl("Pad%d" % (sx * sy), 0.55, 0.18, loc=(sx * 1.25, sy * 1.45, 0.18),
                verts=12, material=GR)
            cyl("PadGlow", 0.40, 0.06, loc=(sx * 1.25, sy * 1.45, 0.07),
                verts=12, material=GL)
    # fixed gun: mantlet + barrel
    box("Mantlet", 0.8, 0.6, 0.55, loc=(0, 1.75, 1.35), material=GR)
    cyl("Barrel", 0.10, 2.2, loc=(0, 2.9, 1.40), rot=(pi / 2, 0, 0),
        verts=10, material=GR)
    box("BarrelShroud", 0.24, 0.9, 0.24, loc=(0, 2.2, 1.40), material=GY)
    # red light strips + sensor
    box("StripL", 0.1, 3.2, 0.1, loc=(1.33, 0, 1.15), material=GL)
    box("StripR", 0.1, 3.2, 0.1, loc=(-1.33, 0, 1.15), material=GL)
    sphere("Sensor", 0.12, loc=(0.8, 1.2, 1.62), material=GL)
    box("Hatch", 0.8, 0.8, 0.12, loc=(-0.5, -0.8, 1.76), material=GR)
    empty("Muzzle", (0, 4.05, 1.40))

    finish_asset("jp_tora", CAT, ["Muzzle"])


def build_jp_kitsune():
    """Small recon drone: sensor eye + single top rotor."""
    clear_scene()
    P = jp_palette()
    WH, GR, GY, GS, GL = P["white"], P["graphite"], P["gray"], P["glass"], P["glow"]

    # skids (sits at z=0; engine hovers it)
    box("SkidL", 0.06, 0.5, 0.06, loc=(0.22, 0, 0.12), material=GR)
    box("SkidR", 0.06, 0.5, 0.06, loc=(-0.22, 0, 0.12), material=GR)
    box("LegL", 0.05, 0.05, 0.25, loc=(0.22, 0, 0.26), material=GR)
    box("LegR", 0.05, 0.05, 0.25, loc=(-0.22, 0, 0.26), material=GR)
    # body
    sphere("Body", 0.32, loc=(0, 0, 0.55), scale=(1, 1.15, 0.75), material=WH)
    box("BellyBand", 0.5, 0.55, 0.08, loc=(0, 0, 0.42), material=GR)
    sphere("Eye", 0.11, loc=(0, 0.33, 0.60), material=GL)   # sensor eye, red
    box("EyeRing", 0.2, 0.06, 0.2, loc=(0, 0.30, 0.60), material=GR)
    # tail fin
    box("Tail", 0.06, 0.35, 0.28, loc=(0, -0.45, 0.62), material=GR)
    box("TailTip", 0.065, 0.1, 0.1, loc=(0, -0.60, 0.72), material=GL)
    # mast + THE rotor
    cyl("Mast", 0.04, 0.30, loc=(0, 0, 0.90), verts=8, material=GR)
    r1 = cyl("RotorHub", 0.05, 0.07, loc=(0, 0, 0), verts=8, material=GR)
    r2 = box("RotorBlade", 0.95, 0.09, 0.03, loc=(0, 0, 0.02), material=WH)
    r3 = box("RotorBlade2", 0.09, 0.95, 0.03, loc=(0, 0, 0.045), material=GY)
    rotor = join("Rotor", [r1, r2, r3])
    rotor.location = (0, 0, 1.06)

    finish_asset("jp_kitsune", CAT, ["Rotor"])


def build_jp_ronin():
    """Humanoid combat mech ~4.2m. Torso is the yawing Turret; arm cannon Muzzle."""
    clear_scene()
    P = jp_palette()
    WH, GR, GY, GS, GL = P["white"], P["graphite"], P["gray"], P["glass"], P["glow"]

    # legs (static)
    for sx in (-1, 1):
        box("Foot", 0.52, 0.72, 0.28, loc=(sx * 0.32, 0.06, 0.14), material=GR)
        box("Shin", 0.30, 0.34, 1.00, loc=(sx * 0.32, 0, 0.80), material=WH)
        box("ShinPlate", 0.34, 0.12, 0.80, loc=(sx * 0.32, 0.20, 0.85), material=GY)
        box("Thigh", 0.38, 0.42, 0.90, loc=(sx * 0.32, 0, 1.75), material=WH)
        box("Knee", 0.30, 0.18, 0.30, loc=(sx * 0.32, 0.24, 1.35), material=GR)
        box("HipJoint", 0.30, 0.30, 0.25, loc=(sx * 0.32, 0, 2.28), material=GR)
    box("Pelvis", 0.95, 0.60, 0.45, loc=(0, 0, 2.50), material=GR)
    box("PelvisTrim", 1.0, 0.65, 0.10, loc=(0, 0, 2.72), material=GL)
    # THE torso turret (yawing upper body)
    pivot = (0, 0, 2.85)
    u1 = box("TP_Chest", 1.15, 0.75, 0.85, loc=(0, 0, 0.45), material=WH)
    u2 = box("TP_ChestPlate", 0.90, 0.14, 0.60, loc=(0, 0.40, 0.50), material=GY)
    u3 = box("TP_Head", 0.40, 0.36, 0.32, loc=(0, 0.10, 1.05), material=GR)
    u4 = box("TP_Visor", 0.30, 0.06, 0.12, loc=(0, 0.29, 1.06), material=GL)
    u5 = box("TP_PadR", 0.45, 0.55, 0.42, loc=(0.80, 0, 0.72), material=WH)
    u6 = box("TP_PadL", 0.45, 0.55, 0.42, loc=(-0.80, 0, 0.72), material=WH)
    u7 = box("TP_Backpack", 0.70, 0.35, 0.70, loc=(0, -0.52, 0.55), material=GR)
    u8 = cyl("TP_ExhaustR", 0.10, 0.25, loc=(0.20, -0.55, 0.30), verts=8, material=GR)
    u9 = cyl("TP_ExhaustL", 0.10, 0.25, loc=(-0.20, -0.55, 0.30), verts=8, material=GR)
    u10 = cyl("TP_ExhGlowR", 0.07, 0.06, loc=(0.20, -0.55, 0.16), verts=8, material=GL)
    u11 = cyl("TP_ExhGlowL", 0.07, 0.06, loc=(-0.20, -0.55, 0.16), verts=8, material=GL)
    # right arm: cannon arm
    u12 = box("TP_ArmR_Up", 0.28, 0.28, 0.55, loc=(0.80, 0, 0.25), material=WH)
    u13 = box("TP_ArmR_Fore", 0.30, 0.75, 0.30, loc=(0.80, 0.45, 0.25), material=GR)
    u14 = cyl("TP_Cannon", 0.14, 1.05, loc=(0.80, 1.15, 0.25), rot=(pi / 2, 0, 0),
              verts=12, material=GR)
    u15 = cyl("TP_CannonRing", 0.17, 0.15, loc=(0.80, 1.55, 0.25), rot=(pi / 2, 0, 0),
              verts=12, material=GY)
    u16 = box("TP_CannonGlow", 0.10, 0.30, 0.06, loc=(0.80, 1.0, 0.42), material=GL)
    # left arm: manipulator + blade
    u17 = box("TP_ArmL_Up", 0.28, 0.28, 0.55, loc=(-0.80, 0, 0.25), material=WH)
    u18 = box("TP_ArmL_Fore", 0.28, 0.60, 0.28, loc=(-0.80, 0.35, 0.10), material=GR)
    u19 = box("TP_Blade", 0.08, 0.95, 0.22, loc=(-0.80, 0.85, -0.05),
              rot=(0.2, 0, 0), material=GY)
    turret = join("Turret", [u1, u2, u3, u4, u5, u6, u7, u8, u9, u10, u11,
                             u12, u13, u14, u15, u16, u17, u18, u19],
                  pivot=pivot)
    # cannon tip: local (0.80, 1.675, 0.25) -> world (0.80, 1.675, 3.10)
    empty("Muzzle", (0.80, 1.70, 3.10), parent=turret)

    finish_asset("jp_ronin", CAT, ["Turret", "Muzzle"])


build_jp_worker()
build_jp_raiden()
build_jp_shinobi()
build_jp_tora()
build_jp_kitsune()
build_jp_ronin()
print("UNITS_JP DONE")
