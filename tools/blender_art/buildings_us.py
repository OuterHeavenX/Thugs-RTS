"""US buildings for WORLD COMMAND (6 assets). Run: blender -b --python buildings_us.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from math import pi

CAT = "buildings"


def build_us_command_center():
    clear_scene()
    P = us_palette()
    H, N, W, D, G, GL = P["hull"], P["navy"], P["white"], P["dark"], P["glass"], P["glow"]

    box("Pad", 13.5, 11.5, 0.3, loc=(0, 0, 0.15), material=D)
    box("Main", 12, 8, 4, loc=(0, 0, 2.3), material=H)          # 0.3..4.3
    box("MidTier", 9, 6.5, 2, loc=(0, 0, 5.3), material=N)     # 4.3..6.3
    box("RoofSlab", 9.6, 7.1, 0.3, loc=(0, 0, 6.45), material=H)
    box("ParapetF", 9.6, 0.25, 0.5, loc=(0, 3.45, 6.85), material=N)
    box("ParapetB", 9.6, 0.25, 0.5, loc=(0, -3.45, 6.85), material=N)
    box("ParapetL", 0.25, 7.1, 0.5, loc=(4.7, 0, 6.85), material=N)
    box("ParapetR", 0.25, 7.1, 0.5, loc=(-4.7, 0, 6.85), material=N)
    # blue-lit window band around main block
    box("WinF", 11.9, 0.12, 0.6, loc=(0, 4.02, 3.5), material=G)
    box("WinB", 11.9, 0.12, 0.6, loc=(0, -4.02, 3.5), material=G)
    box("WinL", 0.12, 7.9, 0.6, loc=(6.02, 0, 3.5), material=G)
    box("WinR", 0.12, 7.9, 0.6, loc=(-6.02, 0, 3.5), material=G)
    # blue strip between tiers
    box("Strip", 9.15, 6.65, 0.18, loc=(0, 0, 4.42), material=GL)
    # recessed entrance (+Y front)
    box("Entry", 2.6, 0.5, 2.8, loc=(0, 3.9, 1.7), material=D)
    box("Door", 1.8, 0.15, 2.4, loc=(0, 4.05, 1.5), material=N)
    box("DoorLight", 1.9, 0.06, 0.12, loc=(0, 4.12, 2.85), material=GL)
    box("Canopy", 3.4, 1.4, 0.2, loc=(0, 4.5, 3.2), material=H)
    box("Step", 3.0, 0.9, 0.16, loc=(0, 4.35, 0.38), material=D)
    # corner armor pillars
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("Pillar", 0.55, 0.55, 4.4, loc=(sx * 5.85, sy * 3.85, 2.5), material=N)
    # white side panels
    box("PanelL", 0.12, 2.2, 1.8, loc=(6.03, -1.5, 2.0), material=W)
    box("PanelR", 0.12, 2.2, 1.8, loc=(-6.03, 1.5, 2.0), material=W)
    # antenna mast + tip light
    cyl("Mast", 0.09, 5.0, loc=(3.2, -2.0, 9.1), material=D)
    sphere("MastTip", 0.16, loc=(3.2, -2.0, 11.68), material=GL)
    box("CrossArm", 1.4, 0.08, 0.08, loc=(3.2, -2.0, 10.2), material=D)
    # roof clutter
    box("AC1", 1.2, 0.9, 0.7, loc=(-2.5, 1.5, 6.95), material=D)
    box("AC2", 0.9, 0.9, 0.6, loc=(-1.0, -2.0, 6.9), material=H)
    cyl("Vent", 0.3, 0.9, loc=(2.0, 2.2, 7.05), material=N)

    finish_asset("us_command_center", CAT, [])


def build_us_power_generator():
    clear_scene()
    P = us_palette()
    H, N, W, D, G, GL = P["hull"], P["navy"], P["white"], P["dark"], P["glass"], P["glow"]

    box("Base", 7.5, 7.5, 1.2, loc=(0, 0, 0.6), material=D)
    # two side reactor blocks
    box("BlockL", 2.0, 5.0, 2.4, loc=(-2.5, 0, 2.4), material=H)
    box("BlockR", 2.0, 5.0, 2.4, loc=(2.5, 0, 2.4), material=H)
    box("BlockLTop", 2.2, 5.2, 0.4, loc=(-2.5, 0, 3.8), material=N)
    box("BlockRTop", 2.2, 5.2, 0.4, loc=(2.5, 0, 3.8), material=N)
    # cooling fins on side blocks
    for i in range(5):
        box("FinL", 1.8, 0.14, 1.0, loc=(-2.5, -1.8 + i * 0.9, 4.4), material=N)
        box("FinR", 1.8, 0.14, 1.0, loc=(2.5, -1.8 + i * 0.9, 4.4), material=N)
    # open core frame: 4 posts + top cap
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("Post", 0.35, 0.35, 3.6, loc=(sx * 1.35, sy * 1.35, 3.0), material=H)
    box("TopCap", 3.4, 3.4, 0.4, loc=(0, 0, 5.0), material=N)
    box("CapStrip", 3.45, 3.45, 0.12, loc=(0, 0, 4.75), material=GL)
    # THE glowing core
    core = cyl("Core", 0.9, 3.0, loc=(0, 0, 3.3), verts=16, material=GL)
    cyl("CoreBase", 1.1, 0.5, loc=(0, 0, 1.45), verts=16, material=D)
    # pipes between blocks
    cyl("Pipe1", 0.22, 3.0, loc=(0, 1.8, 2.2), rot=(0, pi / 2, 0), material=D)
    cyl("Pipe2", 0.22, 3.0, loc=(0, -1.8, 2.2), rot=(0, pi / 2, 0), material=D)
    # control kiosk + light strip
    box("Kiosk", 1.2, 0.8, 1.6, loc=(0, 3.4, 2.0), material=N)
    box("KioskGlass", 1.0, 0.1, 0.5, loc=(0, 3.85, 2.5), material=G)
    box("BaseStrip", 7.55, 7.55, 0.14, loc=(0, 0, 1.28), material=GL)

    finish_asset("us_power_generator", CAT, ["Core"])


def build_us_barracks():
    clear_scene()
    P = us_palette()
    H, N, W, D, G, GL = P["hull"], P["navy"], P["white"], P["dark"], P["glass"], P["glow"]

    box("Pad", 11.5, 7.5, 0.3, loc=(0, 0, 0.15), material=D)
    box("Main", 10, 6, 3.4, loc=(0, 0, 2.0), material=H)       # 0.3..3.7
    box("RoofSlab", 10.6, 6.6, 0.3, loc=(0, 0, 3.85), material=N)
    box("RoofTrim", 10.65, 6.65, 0.12, loc=(0, 0, 3.62), material=GL)
    # recessed entrance (+Y)
    box("Entry", 2.6, 0.6, 2.8, loc=(-2, 2.85, 1.7), material=D)
    box("Door", 1.9, 0.15, 2.5, loc=(-2, 3.05, 1.55), material=N)
    box("Awning", 3.2, 1.3, 0.15, loc=(-2, 3.4, 3.15), material=H)
    box("Step", 3.0, 0.8, 0.16, loc=(-2, 3.3, 0.38), material=D)
    # blue window strips
    box("WinF", 9.9, 0.12, 0.45, loc=(0.8, 3.02, 2.6), material=G)
    box("WinB", 9.9, 0.12, 0.45, loc=(0, -3.02, 2.6), material=G)
    box("WinL", 0.12, 5.9, 0.45, loc=(5.02, 0, 2.6), material=G)
    box("WinR", 0.12, 5.9, 0.45, loc=(-5.02, 0, 2.6), material=G)
    # white unit panels + roof clutter
    box("PanelA", 1.6, 0.12, 1.2, loc=(2.5, 3.02, 1.4), material=W)
    box("PanelB", 1.6, 0.12, 1.2, loc=(-4.0, 3.02, 1.4), material=W)
    box("VentBox", 1.4, 1.0, 0.7, loc=(3.0, -1.5, 4.35), material=D)
    cyl("VentPipe", 0.25, 1.0, loc=(-3.5, 1.0, 4.5), material=N)
    box("AntennaBase", 0.3, 0.3, 0.5, loc=(4.0, 2.0, 4.25), material=D)
    cyl("Antenna", 0.05, 2.2, loc=(4.0, 2.0, 5.5), material=D)

    finish_asset("us_barracks", CAT, [])


def build_us_vehicle_factory():
    clear_scene()
    P = us_palette()
    H, N, W, D, G, GL = P["hull"], P["navy"], P["white"], P["dark"], P["glass"], P["glow"]

    box("Pad", 13.5, 11.5, 0.3, loc=(0, 0, 0.15), material=D)
    box("Hall", 12, 10, 5.0, loc=(0, 0, 2.8), material=H)       # 0.3..5.3
    box("RoofSlab", 12.6, 10.6, 0.35, loc=(0, 0, 5.45), material=N)
    box("RoofStrip", 12.65, 10.65, 0.12, loc=(0, 0, 5.2), material=GL)
    # big front door panel (+Y)
    box("DoorPanel", 7.0, 0.5, 4.2, loc=(0, 4.9, 2.4), material=D)
    box("DoorFrameT", 7.6, 0.6, 0.4, loc=(0, 4.9, 4.7), material=N)
    box("DoorFrameL", 0.4, 0.6, 4.6, loc=(-3.8, 4.9, 2.6), material=N)
    box("DoorFrameR", 0.4, 0.6, 4.6, loc=(3.8, 4.9, 2.6), material=N)
    for i in range(4):  # door ribs
        box("DoorRib", 0.18, 0.14, 4.0, loc=(-2.6 + i * 1.75, 5.18, 2.4), material=N)
    box("DoorLight", 7.1, 0.1, 0.14, loc=(0, 5.05, 4.35), material=GL)
    # side office block
    box("Office", 3.6, 4.0, 3.2, loc=(7.4, -2.0, 1.9), material=N)
    box("OfficeWin", 3.5, 0.12, 0.6, loc=(7.4, 0.02, 2.6), material=G)
    box("OfficeDoor", 1.2, 0.15, 2.2, loc=(7.4, -0.5, 1.4), material=D)
    # crane rail + vents on roof
    box("CraneRail", 11.0, 0.5, 0.4, loc=(0, -3.0, 5.85), material=D)
    box("VentA", 1.6, 1.2, 0.8, loc=(-4.0, 2.0, 6.0), material=D)
    box("VentB", 1.6, 1.2, 0.8, loc=(4.0, 2.0, 6.0), material=H)
    # side windows
    box("WinL", 0.12, 8.0, 0.5, loc=(6.02, 0, 3.8), material=G)
    box("WinR", 0.12, 8.0, 0.5, loc=(-6.02, 0, 3.8), material=G)

    finish_asset("us_vehicle_factory", CAT, [])


def build_us_research_lab():
    clear_scene()
    P = us_palette()
    H, N, W, D, G, GL = P["hull"], P["navy"], P["white"], P["dark"], P["glass"], P["glow"]

    box("Pad", 10.5, 8.5, 0.3, loc=(0, 0, 0.15), material=D)
    box("Lab", 9, 7, 4.0, loc=(0, 0, 2.3), material=H)          # 0.3..4.3
    box("GlassBand", 9.15, 7.15, 0.9, loc=(0, 0, 3.3), material=G)
    box("RoofSlab", 9.5, 7.5, 0.3, loc=(0, 0, 4.45), material=N)
    box("RoofStrip", 9.55, 7.55, 0.12, loc=(0, 0, 4.22), material=GL)
    # entrance
    box("Entry", 2.2, 0.5, 2.6, loc=(2.5, 3.4, 1.6), material=D)
    box("Door", 1.6, 0.15, 2.3, loc=(2.5, 3.6, 1.45), material=N)
    box("Canopy", 2.8, 1.2, 0.18, loc=(2.5, 3.9, 3.0), material=W)
    # roof platform for the dish
    box("Platform", 3.6, 3.6, 0.25, loc=(-1.5, -1.0, 4.72), material=D)
    cyl("DishPole", 0.14, 1.3, loc=(-1.5, -1.0, 5.5), verts=10, material=H)
    # THE dish (origin on mount pivot so the engine can rotate it)
    d1 = cone("DishBowl", 0.12, 1.25, 0.55, loc=(0, 0, 0.35), rot=(-0.45, 0, 0),
              verts=16, material=W)
    d2 = cyl("DishArm", 0.05, 1.1, loc=(0, 0.42, 0.85), rot=(-0.45, 0, 0), verts=8,
             material=D)
    d3 = box("DishFeed", 0.28, 0.28, 0.22, loc=(0, 0.66, 1.28), rot=(-0.45, 0, 0),
             material=N)
    d4 = cyl("DishHub", 0.2, 0.3, loc=(0, 0, 0.05), verts=10, material=D)
    dish = join("Dish", [d1, d2, d3, d4], pivot=(-1.5, -1.0, 6.05))
    # sensor mast + blinking tip
    cyl("Mast", 0.07, 2.6, loc=(3.0, 2.0, 5.9), material=D)
    sphere("MastTip", 0.13, loc=(3.0, 2.0, 7.25), material=GL)
    # lab equipment boxes
    box("TankA", 1.1, 1.1, 1.6, loc=(2.8, -2.2, 5.4), material=H)
    cyl("TankB", 0.55, 1.4, loc=(1.4, -2.4, 5.3), verts=12, material=N)
    box("Panel", 1.4, 0.12, 1.0, loc=(-3.5, 3.52, 1.6), material=W)

    finish_asset("us_research_lab", CAT, ["Dish"])


def build_us_defense_tower():
    clear_scene()
    P = us_palette()
    H, N, W, D, G, GL = P["hull"], P["navy"], P["white"], P["dark"], P["glass"], P["glow"]

    box("Pad", 4.6, 4.6, 0.4, loc=(0, 0, 0.2), material=D)
    box("Plinth", 3.0, 3.0, 1.2, loc=(0, 0, 1.0), material=H)
    box("Column", 2.0, 2.0, 3.5, loc=(0, 0, 3.35), material=N)
    box("StripX1", 0.12, 0.35, 2.8, loc=(1.03, 0, 3.35), material=GL)
    box("StripX2", 0.12, 0.35, 2.8, loc=(-1.03, 0, 3.35), material=GL)
    box("Collar", 2.6, 2.6, 0.4, loc=(0, 0, 5.3), material=H)
    cyl("Ring", 1.35, 0.35, loc=(0, 0, 5.65), verts=16, material=D)
    # THE turret (origin on yaw axis)
    pivot = (0, 0, 6.0)
    t1 = box("TP_Housing", 2.2, 1.8, 1.0, loc=(0, 0, 0), material=H)
    t2 = box("TP_Mantlet", 0.9, 0.6, 0.7, loc=(0, 0.8, 0.1), material=N)
    t3 = cyl("TP_Barrel", 0.12, 2.4, loc=(0, 2.0, 0.15), rot=(pi / 2, 0, 0),
             verts=10, material=D)
    t4 = box("TP_Sight", 0.4, 0.3, 0.25, loc=(-0.6, 0.2, 0.62), material=D)
    t5 = box("TP_Strip", 2.25, 0.16, 0.12, loc=(0, -0.55, 0.3), material=GL)
    turret = join("Turret", [t1, t2, t3, t4, t5], pivot=pivot)
    empty("Muzzle", (0, 3.25, 6.15), parent=turret)

    finish_asset("us_defense_tower", CAT, ["Turret", "Muzzle"])


build_us_command_center()
build_us_power_generator()
build_us_barracks()
build_us_vehicle_factory()
build_us_research_lab()
build_us_defense_tower()
print("BUILDINGS_US DONE")
