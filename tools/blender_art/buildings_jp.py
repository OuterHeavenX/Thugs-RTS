"""Japanese buildings for WORLD COMMAND (6 assets). Run: blender -b --python buildings_jp.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from math import pi

CAT = "buildings"


def build_jp_command_center():
    clear_scene()
    P = jp_palette()
    WH, GR, GY, GS, GL = P["white"], P["graphite"], P["gray"], P["glass"], P["glow"]

    box("Pad", 12.5, 10.5, 0.3, loc=(0, 0, 0.15), material=GR)
    # tiered silhouette
    box("Tier1", 11, 9, 2.4, loc=(0, 0, 1.5), material=WH)      # 0.3..2.7
    box("Strip1", 11.12, 9.12, 0.14, loc=(0, 0, 2.55), material=GL)
    box("Tier2", 8, 6.5, 2.0, loc=(0, 0, 3.85), material=WH)    # 2.85..4.85
    box("Strip2", 8.12, 6.62, 0.14, loc=(0, 0, 4.7), material=GL)
    box("Tier3", 5.5, 4.5, 1.6, loc=(0, 0, 5.6), material=WH)   # 4.8..6.4
    box("RoofSlab", 5.9, 4.9, 0.25, loc=(0, 0, 6.5), material=GR)
    box("Trim1", 11.2, 9.2, 0.18, loc=(0, 0, 2.78), material=GR)
    box("Trim2", 8.2, 6.7, 0.18, loc=(0, 0, 4.92), material=GR)
    # window bands
    box("WinF", 10.9, 0.1, 0.5, loc=(0, 4.52, 1.8), material=GS)
    box("WinB", 10.9, 0.1, 0.5, loc=(0, -4.52, 1.8), material=GS)
    box("WinL", 0.1, 8.9, 0.5, loc=(5.52, 0, 1.8), material=GS)
    box("WinR", 0.1, 8.9, 0.5, loc=(-5.52, 0, 1.8), material=GS)
    # entrance canopy (+Y)
    box("Entry", 2.4, 0.5, 2.4, loc=(0, 4.4, 1.5), material=GR)
    box("Door", 1.8, 0.14, 2.2, loc=(0, 4.6, 1.4), material=GS)
    box("Canopy", 3.2, 1.8, 0.18, loc=(0, 5.2, 2.9), material=WH)
    box("CanopyStrip", 3.25, 0.14, 0.1, loc=(0, 6.05, 2.82), material=GL)
    box("Step", 3.0, 1.0, 0.16, loc=(0, 4.9, 0.38), material=GR)
    # graphite corner fins on tier1
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("Fin", 0.4, 0.4, 2.6, loc=(sx * 5.4, sy * 4.4, 1.6), material=GR)
    # antenna
    cyl("Mast", 0.07, 3.4, loc=(1.8, -1.2, 8.3), material=GR)
    sphere("MastTip", 0.12, loc=(1.8, -1.2, 10.05), material=GL)
    # roof sensors
    box("SensorA", 0.8, 0.8, 0.5, loc=(-1.5, 1.0, 6.85), material=GY)
    cyl("SensorB", 0.3, 0.7, loc=(0.5, -1.2, 6.95), verts=10, material=GR)

    finish_asset("jp_command_center", CAT, [])


def build_jp_power_generator():
    clear_scene()
    P = jp_palette()
    WH, GR, GY, GS, GL = P["white"], P["graphite"], P["gray"], P["glass"], P["glow"]

    box("Base", 4.5, 4.5, 1.0, loc=(0, 0, 0.5), material=GR)
    box("BaseTrim", 4.6, 4.6, 0.14, loc=(0, 0, 1.05), material=GL)
    # tapered white spire
    cone("Spire", 1.5, 0.7, 3.2, loc=(0, 0, 2.9), verts=8, material=WH)  # 1.3..4.5
    box("SpireBand", 1.9, 1.9, 0.16, loc=(0, 0, 4.4), material=GR)
    # open cage section with the glowing core
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("Pillar", 0.22, 0.22, 2.2, loc=(sx * 0.62, sy * 0.62, 5.6), material=GR)
    torus("RingLow", 0.95, 0.09, loc=(0, 0, 5.0), material=GY)
    torus("RingHigh", 0.95, 0.09, loc=(0, 0, 6.2), material=GY)
    core = cyl("Core", 0.5, 2.0, loc=(0, 0, 5.6), verts=16, material=GL)
    cyl("CoreSeat", 0.65, 0.3, loc=(0, 0, 4.6), verts=12, material=GR)
    cone("Cap", 0.8, 0.08, 0.9, loc=(0, 0, 7.15), verts=8, material=WH)
    sphere("CapTip", 0.1, loc=(0, 0, 7.65), material=GL)

    finish_asset("jp_power_generator", CAT, ["Core"])


def build_jp_barracks():
    clear_scene()
    P = jp_palette()
    WH, GR, GY, GS, GL = P["white"], P["graphite"], P["gray"], P["glass"], P["glow"]

    box("Pad", 13.5, 7.5, 0.3, loc=(1, 0, 0.15), material=GR)
    box("BaseBand", 10.15, 6.15, 0.5, loc=(0, 0, 0.55), material=GR)
    box("Main", 10, 6, 3.0, loc=(0, 0, 2.3), material=WH)       # 0.8..3.8
    box("Strip", 10.12, 6.12, 0.14, loc=(0, 0, 3.55), material=GL)
    box("RoofSlab", 10.4, 6.4, 0.25, loc=(0, 0, 3.95), material=GR)
    # side module (graphite)
    box("Module", 2.6, 4.0, 2.6, loc=(6.2, 0, 1.6), material=GR)
    box("ModuleWin", 0.12, 3.0, 0.5, loc=(7.55, 0, 2.0), material=GS)
    # entrance (+Y)
    box("Entry", 2.4, 0.5, 2.6, loc=(-2, 2.9, 1.6), material=GR)
    box("Door", 1.8, 0.14, 2.3, loc=(-2, 3.1, 1.45), material=GS)
    box("Canopy", 3.0, 1.3, 0.16, loc=(-2, 3.5, 3.0), material=WH)
    box("CanopyStrip", 3.05, 0.12, 0.1, loc=(-2, 4.1, 2.92), material=GL)
    box("Step", 2.8, 0.9, 0.16, loc=(-2, 3.35, 0.38), material=GR)
    # windows
    box("WinF", 9.9, 0.1, 0.45, loc=(1.0, 3.02, 2.4), material=GS)
    box("WinB", 9.9, 0.1, 0.45, loc=(0, -3.02, 2.4), material=GS)
    # roof clutter
    box("VentBox", 1.2, 0.9, 0.6, loc=(3.0, -1.5, 4.35), material=GY)
    cyl("VentPipe", 0.22, 0.9, loc=(-3.5, 1.0, 4.5), verts=10, material=GR)
    cyl("Antenna", 0.05, 2.0, loc=(4.2, 2.0, 5.0), material=GR)

    finish_asset("jp_barracks", CAT, [])


def build_jp_vehicle_factory():
    clear_scene()
    P = jp_palette()
    WH, GR, GY, GS, GL = P["white"], P["graphite"], P["gray"], P["glass"], P["glow"]

    box("Pad", 15.5, 11.5, 0.3, loc=(1, 0, 0.15), material=GR)
    box("Hall", 12, 9, 4.5, loc=(0, 0, 2.55), material=WH)       # 0.3..4.8
    box("Strip", 12.12, 9.12, 0.14, loc=(0, 0, 4.6), material=GL)
    box("RoofSlab", 12.5, 9.5, 0.3, loc=(0, 0, 4.95), material=GR)
    # front door panel (+Y), graphite
    box("DoorPanel", 6.5, 0.5, 3.8, loc=(0, 4.4, 2.2), material=GR)
    box("DoorSplit", 0.12, 0.14, 3.8, loc=(0, 4.62, 2.2), material=GL)
    box("DoorFrameT", 7.1, 0.6, 0.35, loc=(0, 4.4, 4.25), material=GR)
    box("DoorFrameL", 0.35, 0.6, 4.1, loc=(-3.45, 4.4, 2.35), material=GR)
    box("DoorFrameR", 0.35, 0.6, 4.1, loc=(3.45, 4.4, 2.35), material=GR)
    # side annex
    box("Annex", 4.0, 6.0, 3.2, loc=(-8.0, 0, 1.9), material=WH)
    box("AnnexBand", 4.1, 6.1, 0.14, loc=(-8.0, 0, 3.3), material=GL)
    box("AnnexWin", 0.12, 4.5, 0.5, loc=(-6.0, 0, 2.2), material=GS)
    # windows + roof units
    box("WinL", 0.1, 7.5, 0.5, loc=(6.02, 0, 3.4), material=GS)
    box("WinR", 0.1, 7.5, 0.5, loc=(-6.02, 0, 3.4), material=GS)
    box("VentA", 1.5, 1.1, 0.7, loc=(-4.0, -2.0, 5.45), material=GY)
    box("VentB", 1.5, 1.1, 0.7, loc=(4.0, -2.0, 5.45), material=GR)
    box("Skylight", 3.0, 2.0, 0.25, loc=(0, 1.5, 5.2), material=GS)

    finish_asset("jp_vehicle_factory", CAT, [])


def build_jp_research_lab():
    clear_scene()
    P = jp_palette()
    WH, GR, GY, GS, GL = P["white"], P["graphite"], P["gray"], P["glass"], P["glow"]

    box("Pad", 11.5, 8.5, 0.3, loc=(1, 0, 0.15), material=GR)
    box("Lab", 8, 6, 4.0, loc=(0, 0, 2.3), material=WH)          # 0.3..4.3
    box("GlassBand", 8.12, 6.12, 0.9, loc=(0, 0, 3.2), material=GS)
    box("RoofSlab", 8.5, 6.5, 0.3, loc=(0, 0, 4.45), material=GR)
    box("RoofStrip", 8.55, 6.55, 0.12, loc=(0, 0, 4.22), material=GL)
    # side wing
    box("Wing", 4.0, 3.0, 2.5, loc=(6.0, 0, 1.55), material=GR)
    box("WingWin", 3.5, 0.12, 0.5, loc=(6.0, 1.52, 1.9), material=GS)
    # entrance
    box("Entry", 2.2, 0.5, 2.6, loc=(-2.5, 2.9, 1.6), material=GR)
    box("Door", 1.6, 0.14, 2.3, loc=(-2.5, 3.1, 1.45), material=GS)
    box("Canopy", 2.8, 1.2, 0.16, loc=(-2.5, 3.5, 3.0), material=WH)
    # roof platform + dish
    box("Platform", 3.4, 3.4, 0.25, loc=(1.5, -0.8, 4.72), material=GR)
    cyl("DishPole", 0.13, 1.2, loc=(1.5, -0.8, 5.45), verts=10, material=GY)
    d1 = cone("DishBowl", 0.12, 1.2, 0.5, loc=(0, 0, 0.32), rot=(-0.5, 0, 0),
              verts=16, material=WH)
    d2 = cyl("DishArm", 0.05, 1.0, loc=(0, 0.4, 0.78), rot=(-0.5, 0, 0), verts=8,
             material=GR)
    d3 = box("DishFeed", 0.26, 0.26, 0.2, loc=(0, 0.62, 1.18), rot=(-0.5, 0, 0),
             material=GR)
    d4 = cyl("DishHub", 0.18, 0.28, loc=(0, 0, 0.05), verts=10, material=GR)
    dish = join("Dish", [d1, d2, d3, d4], pivot=(1.5, -0.8, 5.95))
    # sensor mast
    cyl("Mast", 0.06, 2.4, loc=(-3.0, 2.0, 5.8), material=GR)
    sphere("MastTip", 0.11, loc=(-3.0, 2.0, 7.05), material=GL)
    box("TankFarm", 1.0, 1.0, 1.5, loc=(2.8, 1.8, 5.35), material=GY)

    finish_asset("jp_research_lab", CAT, ["Dish"])


def build_jp_defense_tower():
    clear_scene()
    P = jp_palette()
    WH, GR, GY, GS, GL = P["white"], P["graphite"], P["gray"], P["glass"], P["glow"]

    cyl("Pad", 2.3, 0.4, loc=(0, 0, 0.2), verts=6, material=GR)
    cyl("Base", 1.7, 0.8, loc=(0, 0, 0.8), verts=6, material=WH)
    # elegant tapered column
    cone("Column", 1.05, 0.62, 4.6, loc=(0, 0, 3.5), verts=8, material=WH)  # 1.2..5.8
    box("ColTrim", 1.5, 1.5, 0.16, loc=(0, 0, 5.75), material=GR)
    torus("GlowRing", 0.85, 0.08, loc=(0, 0, 5.45), material=GL)
    cyl("HeadBase", 1.15, 0.9, loc=(0, 0, 6.25), verts=6, material=GR)
    # THE turret (origin on yaw axis)
    pivot = (0, 0, 6.85)
    t1 = box("TP_Housing", 1.7, 1.5, 0.7, loc=(0, 0, 0), material=WH)
    t2 = box("TP_Top", 1.2, 1.0, 0.25, loc=(0, -0.1, 0.45), material=GR)
    t3 = cyl("TP_Barrel", 0.09, 2.2, loc=(0, 1.7, 0.05), rot=(pi / 2, 0, 0),
             verts=10, material=GR)
    t4 = box("TP_Mantlet", 0.5, 0.4, 0.45, loc=(0, 0.7, 0.05), material=GR)
    t5 = sphere("TP_Sensor", 0.12, loc=(0.5, -0.3, 0.4), material=GL)
    t6 = box("TP_Strip", 1.75, 0.1, 0.1, loc=(0, -0.78, 0.1), material=GL)
    turret = join("Turret", [t1, t2, t3, t4, t5, t6], pivot=pivot)
    empty("Muzzle", (0, 2.85, 6.9), parent=turret)

    finish_asset("jp_defense_tower", CAT, ["Turret", "Muzzle"])


build_jp_command_center()
build_jp_power_generator()
build_jp_barracks()
build_jp_vehicle_factory()
build_jp_research_lab()
build_jp_defense_tower()
print("BUILDINGS_JP DONE")
