"""Environment props for WORLD COMMAND (5 assets). Run: blender -b --python environment.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from math import pi

CAT = "environment"


def build_supply_depot():
    clear_scene()
    P = env_palette()
    WD, MT, HZ, PL, RK, RS = P["wood"], P["metal"], P["hazard"], P["pile"], P["rock"], P["rust"]

    box("Pallet", 3.0, 2.2, 0.15, loc=(0, 0, 0.08), material=WD)
    # stacked crates
    box("CrateA", 1.15, 1.15, 1.15, loc=(-0.7, 0.2, 0.73), material=WD)
    box("CrateB", 1.05, 1.05, 1.05, loc=(0.75, -0.35, 0.68), material=MT)
    box("CrateC", 0.95, 0.95, 0.95, loc=(-0.65, 0.15, 1.78), material=MT)
    box("CrateD", 0.80, 0.80, 0.80, loc=(0.80, 0.55, 1.55), material=WD)
    # yellow hazard markings on crate edges
    box("HzA1", 1.17, 0.14, 0.14, loc=(-0.7, 0.2, 1.24), material=HZ)
    box("HzA2", 0.14, 1.17, 0.14, loc=(-0.7, 0.2, 0.30), material=HZ)
    box("HzB1", 1.07, 0.14, 0.14, loc=(0.75, -0.35, 1.14), material=HZ)
    box("HzC1", 0.14, 0.97, 0.14, loc=(-0.65, 0.15, 2.20), material=HZ)
    # raw material pile + scattered rocks
    ico("Pile", 0.75, loc=(1.55, 1.15, 0.30), scale=(1.0, 0.85, 0.55), material=PL)
    ico("Rock1", 0.28, loc=(1.05, 1.55, 0.14), scale=(1, 0.8, 0.6), material=RK)
    ico("Rock2", 0.22, loc=(2.05, 0.75, 0.11), scale=(1, 1, 0.6), material=RK)
    # rust barrel
    cyl("Barrel", 0.32, 0.95, loc=(-1.55, -0.85, 0.48), verts=12, material=RS)
    cyl("BarrelRim", 0.34, 0.08, loc=(-1.55, -0.85, 0.92), verts=12, material=MT)

    finish_asset("supply_deposit", CAT, [])


def build_helios_crystal():
    clear_scene()
    P = env_palette()
    CR, RD = P["crystal"], P["rockdark"]

    # dark rock base
    ico("Base", 1.05, loc=(0, 0, 0.25), scale=(1.25, 1.0, 0.5), material=RD)
    ico("Base2", 0.6, loc=(0.7, -0.4, 0.15), scale=(1, 0.9, 0.5), material=RD)
    # main crystal -> named Glow
    main = cone("Glow", 0.30, 0.0, 2.3, loc=(0.05, 0.05, 1.55),
                rot=(0.06, 0.0, 0.04), verts=6, material=CR)
    # satellite crystals
    cone("Crystal2", 0.20, 0.0, 1.5, loc=(-0.65, 0.35, 1.0),
         rot=(0.0, 0.0, -0.28), verts=6, material=CR)
    cone("Crystal3", 0.22, 0.0, 1.7, loc=(0.70, -0.30, 1.1),
         rot=(0.0, 0.22, 0.0), verts=6, material=CR)
    cone("Crystal4", 0.16, 0.0, 1.1, loc=(-0.15, -0.65, 0.8),
         rot=(0.30, 0.0, 0.0), verts=6, material=CR)
    cone("Crystal5", 0.18, 0.0, 1.3, loc=(0.45, 0.60, 0.9),
         rot=(-0.25, 0.0, 0.10), verts=6, material=CR)
    cone("Crystal6", 0.13, 0.0, 0.8, loc=(-0.85, -0.35, 0.6),
         rot=(0.0, 0.0, -0.35), verts=6, material=CR)
    # tiny shards at the base
    cone("Shard1", 0.08, 0.0, 0.45, loc=(1.05, 0.35, 0.35),
         rot=(0.0, 0.0, -0.2), verts=5, material=CR)
    cone("Shard2", 0.07, 0.0, 0.38, loc=(-1.05, 0.15, 0.30),
         rot=(0.15, 0.0, 0.0), verts=5, material=CR)

    finish_asset("helios_crystal", CAT, ["Glow"])


def build_tree():
    clear_scene()
    P = env_palette()
    TR, LF = P["trunk"], P["leaf"]

    cyl("Trunk", 0.16, 1.4, loc=(0, 0, 0.7), verts=8, material=TR)
    cone("Tier1", 1.50, 0.0, 1.6, loc=(0, 0, 1.9), verts=8, material=LF)
    cone("Tier2", 1.15, 0.0, 1.4, loc=(0, 0, 2.8), verts=8, material=LF)
    cone("Tier3", 0.75, 0.0, 1.2, loc=(0, 0, 3.6), verts=8, material=LF)

    finish_asset("tree", CAT, [])


def build_rock():
    clear_scene()
    P = env_palette()
    RK, RD = P["rock"], P["rockdark"]

    ico("Boulder", 1.0, loc=(0, 0, 0.55), scale=(1.25, 0.95, 0.72),
        rot=(0.2, 0.0, 0.5), material=RK)
    ico("Boulder2", 0.62, loc=(0.85, 0.35, 0.32), scale=(1.0, 1.0, 0.75),
        rot=(0.0, 0.3, 0.2), material=RD)
    ico("Pebble", 0.30, loc=(-0.75, 0.55, 0.15), scale=(1.1, 0.9, 0.6), material=RK)

    finish_asset("rock", CAT, [])


def build_abandoned_facility():
    clear_scene()
    P = env_palette()
    CC, RS, MT, RK = P["concrete"], P["rust"], P["metal"], P["rock"]

    box("Pad", 8.5, 6.5, 0.3, loc=(0, 0, 0.15), material=CC)
    # back wall, broken into two heights
    box("WallBackA", 4.2, 0.4, 3.0, loc=(-2.0, -2.8, 1.8), material=CC)
    box("WallBackB", 3.6, 0.4, 1.7, loc=(2.2, -2.8, 1.15), material=CC)
    # side walls, partial
    box("WallSideL", 0.4, 4.2, 2.2, loc=(-3.8, -0.7, 1.4), material=CC)
    box("WallSideR", 0.4, 2.6, 1.4, loc=(3.8, -1.5, 1.0), material=CC)
    # front stub walls
    box("StubL", 2.2, 0.4, 0.9, loc=(-2.5, 2.8, 0.75), material=CC)
    box("StubR", 2.2, 0.4, 1.1, loc=(1.5, 2.8, 0.85), material=CC)
    # collapsed roof slab leaning on the back wall
    box("RoofSlab", 5.5, 4.2, 0.25, loc=(0.3, -0.6, 2.3), rot=(0.5, 0.08, 0.0),
        material=CC)
    box("RoofBeam", 5.0, 0.25, 0.25, loc=(-0.2, 0.8, 1.6), rot=(0.5, 0.0, 0.15),
        material=RS)
    # toppled pillar
    cyl("Pillar", 0.25, 3.2, loc=(1.6, 1.6, 0.45), rot=(1.35, 0.0, 0.35),
        verts=8, material=CC)
    # exposed rebar on broken wall tops
    for i, xx in enumerate((-3.2, -1.6, 1.4, 2.8)):
        cyl("Rebar%d" % i, 0.03, 0.8, loc=(xx, -2.8, 3.4), rot=(0.15, 0.0, 0.1),
            verts=6, material=RS)
    # rust patches on walls
    box("RustA", 1.4, 0.06, 0.9, loc=(-2.0, -2.58, 1.2), material=RS)
    box("RustB", 0.06, 1.6, 0.7, loc=(-3.58, -0.7, 1.0), material=RS)
    box("RustC", 1.0, 0.06, 0.6, loc=(2.2, -2.58, 0.8), material=RS)
    # rubble
    box("Rubble1", 0.7, 0.5, 0.4, loc=(-1.0, 0.5, 0.5), rot=(0.2, 0.0, 0.6), material=RK)
    box("Rubble2", 0.5, 0.6, 0.35, loc=(0.8, -1.2, 0.45), rot=(0.0, 0.3, 0.2), material=RK)
    ico("Rubble3", 0.35, loc=(2.5, 1.0, 0.3), scale=(1, 0.8, 0.7), material=RK)
    box("Rubble4", 0.9, 0.4, 0.3, loc=(-2.8, 1.4, 0.42), rot=(0.1, 0.2, 0.9), material=CC)
    # dead terminal (dark screen, no glow)
    box("Terminal", 0.7, 0.5, 1.1, loc=(-3.0, 1.8, 0.85), rot=(0.0, 0.0, 0.4), material=MT)

    finish_asset("abandoned_facility", CAT, [])


build_supply_depot()
build_helios_crystal()
build_tree()
build_rock()
build_abandoned_facility()
print("ENVIRONMENT DONE")
