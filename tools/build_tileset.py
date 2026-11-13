#!/usr/bin/env python3
"""Builds the TP Core art: the shared stations' tileset (42/media/*.tiles and texturepacks/*.pack), their build icons,
the mod icon, the Hearth's menu icons and the generated Tiles.lua. Also the Smokehouse chamber (from tile CHAMBER),
moved from Fish & Meat 2026-11-13 with its art unchanged.

The Hearth: a farmhouse cheese copper (user's design, 2026-11-13, after Alpine cheese kettles on a crane). The
Firebox's knee-high block of split fieldstone, as vanilla's kilns are built, with its iron door on the side it faces,
closed on top but for a small round hole in the centre; over it an iron gallows (two posts set in the stone and a bar
across, along the door's side) and, nearly on the hole, a round-bellied copper kettle sooted black below its shoulder,
hanging by its bail from a Large Hook. The bail runs towards the door (the user's pick, for later). The copper is
drawn as a 100-120 L kettle; it holds 60 L (Hearth.lua). The game turns it into a vanilla fireplace when it is built. Vanilla draws the fireplace's flames and fuel as attached
sprites, so HearthWorld swaps the hearth's own sprite among whole-hearth tiles, the copper empty, full or steaming
(HEARTH_LOOKS), and every one of them carries the fireplace's tile properties. The fire's glow is the object's
overlay sprite (GLOWS), the way vanilla lights its kilns: the door's vents, the hole and flames curling up round the
kettle while it burns, a dull red when banked. The game draws the overlay over the whole object, so the kettle's
outline is cut out of it.

The stone and the copper have hard edges (pzart.hard_edges); the steam and the glow are soft.

Usage: python3 tools/build_tileset.py [contact-sheet.png]
Needs Pillow. Deterministic: a rerun with no change gives byte-identical files.
"""
import math
import random
import sys
from contextlib import contextmanager
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pzart  # noqa: E402
from pzart import TILE_W, TILE_H, shrink  # noqa: E402
from pzart import tint as shade  # noqa: E402

MOD = "TraditionalPreservationCore"
NAME = "traditionalpreservationcore"
TILESET = NAME + "_01"
COLUMNS, ROWS = 8, 8
PAGE_SIZE = 1024
SS = 4  # supersampling

# Facings, S and E, as the entity scripts' faces. Each look takes len(FACES) tiles from its number.
FACES = ["S", "E"]
HEARTH_LOOKS = {"Empty": 0, "Full": 2, "Hot": 4}
HEARTH = HEARTH_LOOKS["Empty"]
# The fire mouth's glow, an overlay: lit, and banked (embers under ash, almost no light).
GLOWS = {"Lit": 6, "Banked": 8}
# The Firebox: the Hearth's stone, lower, with no copper and an iron door on its mouth. Its flue leaves its top:
# capped (nothing joined to it), a clay pipe from its top, or a trench in the ground roofed with flat stones from its
# foot, to the building on one side, never the door's (a mod
# joins it, as Fuel Barrel picks the barrel's sprite by the generator's). Sides by facing, as world steps (+x east,
# +y south), the same table as Hearth.FLUE_SIDES in Lua.
FLUE_SIDES = {"S": {"Back": (0, -1), "Left": (-1, 0), "Right": (1, 0)},
              "E": {"Back": (-1, 0), "Left": (0, -1), "Right": (0, 1)}}
FIREBOX_LOOKS = {"Capped": 10}
for _kind in ("Pipe", "Stones"):
    for _side in ("Back", "Left", "Right"):
        FIREBOX_LOOKS[f"{_kind}_{_side}"] = 10 + 2 * len(FIREBOX_LOOKS)
FIREBOX = FIREBOX_LOOKS["Capped"]
# Its glow shows through the door's vents; capped, the smoke leaks round the door.
FIREBOX_GLOWS = {"Lit": 24, "Banked": 26, "LitFlue": 28, "BankedFlue": 30}

# Colours.
STONE = (158, 132, 104)
MORTAR = (92, 78, 64)
ARCH = (128, 106, 84)
RENDER = (196, 186, 166)       # lime render on the top
BED = (64, 54, 46)             # the mortar the copper is bedded in
METAL = (150, 82, 50)          # tarnished copper
METAL_LIT = (196, 112, 78)     # the copper's lit inside
KETTLE = (168, 92, 54)         # the kettle's outside, above the soot
KETTLE_SOOT = (34, 28, 25)
HAMMER = (230, 150, 110)
SPECULAR = (255, 226, 196)
VERDIGRIS = (92, 140, 118)
MILK = (226, 220, 200)
DARK = (22, 15, 11)
GRATE = (60, 56, 52)
STEAM = (244, 244, 240)
WEATHER = 0.2
FOOT_SHADE = 0.8               # the stone darkens this far towards the ground

# The stone body, the Firebox's and the Hearth's: knee high (a cask is 85 px), a little under a tile across.
H = 0.32                       # half the footprint, in tiles
TOP = 36                       # stone, px high
CAP = 4                        # the rendered top
CAP_OVER = 0.015               # how far the top overhangs, in tiles
MOUTH_W, MOUTH_SILL, MOUTH_SPRING = 0.16, 1.5, 11.5   # half width in tiles; sill and springing height, px
ARCH_RISE = 0.55               # the arch's height for its width
FACE_LEN = math.hypot(pzart.DIAMOND_HALF_W, pzart.DIAMOND_HALF_H)   # px along a face per tile
# The copper's mouth, as paint_copper draws it: the kettle sets these to its lip (shape()).
CU_R = 0.27                    # its radius, in tiles
LIP = 2                        # how far its rolled lip stands above TOP + CAP, px

# The Hearth over the body: the hole, the kettle and the gallows.
HOLE_R = 0.075                 # the hole in the top, in tiles
KETTLE_R = 0.265               # the belly's radius, in tiles
KETTLE_GAP = 2                 # px between the stone and the kettle's bottom: nearly on the hole
KETTLE_H = 34                  # px from bottom to lip
KETTLE_BOTTOM = TOP + CAP + KETTLE_GAP
KETTLE_TOP = KETTLE_BOTTOM + KETTLE_H
BAR_Z = KETTLE_TOP + 30        # the gallows bar, px
POST_IN = 0.015                # how far in from the stone's edge the posts stand, in tiles
# The kettle's profile, bottom to lip: (height share, radius share). An Alpine cheese kettle: a rounded bottom, the
# belly low and wide, drawn in to a narrow neck, the lip flared out again.
PROFILE = [(0.0, 0.42), (0.07, 0.74), (0.18, 0.93), (0.32, 1.0), (0.46, 0.98), (0.6, 0.88), (0.72, 0.76),
           (0.82, 0.71), (0.91, 0.73), (1.0, 0.8)]

TILE_PROPS = {}


def group(look, plain):
    """The engine links the facings of tiles sharing a GroupName and CustomName, and that link lets a moved hearth
    rotate, but only with one tile a facing: a group of more is left unlinked (IsoWorld.LoadTileDefinitions). So only
    the plain look (the one that can be picked up: copper empty, flue capped) carries the GroupName."""
    return [("GroupName", "Stone")] if look == plain else []


for look, base in HEARTH_LOOKS.items():
    for offset, facing in enumerate(FACES):
        # IsoType and the woodstove container make the game load it as a fireplace with a firebox to cook in.
        TILE_PROPS[base + offset] = sorted([("BlocksPlacement", ""), ("ContainerCapacity", "15"), ("ContainerPosition", "Low"),
                                            ("CustomName", "Hearth"), ("Facing", facing),
                                            ("IsMoveAble", ""), ("IsoType", "IsoFireplace"), ("PickUpWeight", "100"),
                                            ("container", "woodstove"), ("solidtrans", "")] + group(look, "Empty"))
for look, base in FIREBOX_LOOKS.items():
    for offset, facing in enumerate(FACES):
        TILE_PROPS[base + offset] = sorted([("BlocksPlacement", ""), ("ContainerCapacity", "10"), ("ContainerPosition", "Low"),
                                            ("CustomName", "Firebox"), ("Facing", facing),
                                            ("IsMoveAble", ""), ("IsoType", "IsoFireplace"), ("PickUpWeight", "80"),
                                            ("container", "woodstove"), ("solidtrans", "")] + group(look, "Capped"))

IRON = (58, 54, 52)
CLAY_PIPE = (172, 96, 64)
DAUB = (150, 124, 98)
SMOKE = (150, 146, 140)
FIRE_GLOW = (255, 150, 60)
FLUE_R = 4.5                   # the flue's half width, px
FLUE_RISE = 16                 # how far it climbs from the top to the wall, px
FLUE_ELBOW = 9                 # of which straight up out of the top, before it turns towards the wall

# The Smokehouse chamber (moved from Fish & Meat, 2026-11-13; drawn as it was there): a plank shed two tiles long,
# the back half then the front half with the door, each face (chamber_index). Smokehouse.lua reads the numbers from
# the generated Tiles.lua.
CHAMBER = 32
CHAMBER_STACKS = 6
CHAMBER_HALF = 0.46       # half the shed's width, and how far each end wall stands from its tile's middle, in tiles
CHAMBER_OVERHANG = 0.06   # the roof past the walls
CHAMBER_FRONT = 136       # px up to the roof's high edge, over the door
CHAMBER_BACK = 108        # and its low edge at the back
CHAMBER_SILL = 7          # the stone sill under the planks
CHAMBER_DOOR = 112        # the door's top
CHAMBER_DOOR_HALF = 0.17
CHAMBER_PLANK = 0.11      # a plank's width, in tiles
CHAMBER_JOIN = 0.02       # the back tile runs this far under the front one, so no seam shows
CHAMBER_WOOD = (112, 78, 50)
CHAMBER_ROOF = (90, 64, 44)
CHAMBER_STONE = (120, 112, 100)
CHAMBER_DARK = (24, 18, 14)
CHAMBER_EDGE = (60, 42, 28)
CHAMBER_IRON = (70, 71, 75)
CHAMBER_WEATHER = 0.3
CHAMBER_FOOT_SHADE = 0.5
# Where a joined Firebox's flue enters the chamber, on the long side the camera sees: one overlay per flue kind, face
# and part (chamber_entry_index). The Firebox's pipe ends at its tile's edge this high, its trench at ground level.
CHAMBER_ENTRY = 36
FLUE_KINDS = ["Pipe", "Stones"]
CHAMBER_FLUE_Z = TOP + CAP + FLUE_RISE
# A ham hung by the door while finished stacks wait in the chamber (user's idea): one overlay per face, on the
# door's tile, on the door's end wall beside the door.
CHAMBER_HAM = 44
HAM_A = -0.37             # across the end wall, on the door's far side from the long wall in view: it overhangs the corner
HAM_TOP = 98              # px up to the bone's knob; the nail is above it
HAM_SCALE = 1.35          # its width against the first ham's
HAM_STEP = 6.6            # px between its outline's steps down (the first ham's were 5)
# Tones dark to light, taken from vanilla's Ham icon and pulled a little towards smoke: the glazed skin, and the
# cut face's pale pinks with a lighter middle.
HAM_SKIN_TONES = [(84, 42, 28), (108, 54, 32), (132, 70, 38), (158, 90, 46), (184, 112, 58)]
HAM_CUT_TONES = [(170, 112, 114), (190, 134, 134), (204, 152, 150), (216, 172, 168), (226, 194, 190)]
HAM_FAT = (212, 184, 150)  # a thin rim under the cut
HAM_LINE = (52, 28, 20)    # the dark line round it
HAM_CORD = (196, 176, 136)
HAM_BONE = (232, 222, 196)


@contextmanager
def shape(values):
    """Draws with other sizes (the kettle's mouth for paint_copper and steam): the drawing reads them as module
    globals."""
    saved = {name: globals()[name] for name in values}
    globals().update(values)
    try:
        yield
    finally:
        globals().update(saved)


def box(cx, cy, rx, ry):
    return [(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS]


def tile_px(x, y, z=0):
    sx, sy = pzart.project(x, y, z)
    return (sx * SS, sy * SS)


def face_px(face, u, z):
    """A point on a visible side, u tiles along it from its left end and z px up. Side "S" is the front left (y = +H),
    "E" the front right (x = +H), as the hearth faces."""
    if face == "S":
        return tile_px(-H + u, H, z)
    return tile_px(H, H - u, z)


def face_quad(draw, face, u0, u1, z0, z1, fill):
    draw.polygon([face_px(face, u0, z0), face_px(face, u1, z0), face_px(face, u1, z1), face_px(face, u0, z1)], fill=fill)


# --- The stone ---------------------------------------------------------------------------------------------------

def fieldstone(draw, face, rng, light):
    """Split stone in uneven courses, each stone a lumpy quad with a lit top and a shadowed foot."""
    span = 2 * H
    face_quad(draw, face, 0, span, 0, TOP, shade(MORTAR, light))
    z = 0.0
    while z < TOP - 0.5:
        top = min(TOP, z + rng.uniform(5.0, 9.0))
        u = -rng.uniform(0, 0.12)
        while u < span:
            length = rng.uniform(0.1, 0.26)
            a, b = max(0, u + 0.018), min(span, u + length - 0.018)
            if b > a:
                tone = rng.uniform(0.78, 1.12)
                warm = rng.choice([(1, 1, 1), (1.06, 1, 0.9), (0.94, 0.96, 1.0), (1.02, 0.98, 0.94)])
                colour = tuple(int(c * w) for c, w in zip(STONE, warm))
                zb, zt = z + 0.7, top - 0.5
                j = [rng.uniform(-1.1, 1.1) for _ in range(6)]
                points = [face_px(face, a + 0.01, zb + j[0]), face_px(face, b - 0.01, zb + j[1]),
                          face_px(face, b, (zb + zt) / 2 + j[2]), face_px(face, b - 0.015, zt + j[3] * 0.6),
                          face_px(face, a + 0.015, zt + j[4] * 0.6), face_px(face, a, (zb + zt) / 2 + j[5])]
                draw.polygon(points, fill=shade(colour, light * tone))
                draw.polygon([face_px(face, a + 0.02, zt - 1.6), face_px(face, b - 0.02, zt - 1.6), points[3], points[4]],
                             fill=shade(colour, light * tone * 1.14))
                draw.polygon([points[0], points[1], face_px(face, b - 0.02, zb + 1.2), face_px(face, a + 0.02, zb + 1.2)],
                             fill=shade(colour, light * tone * 0.74))
            u += length
        z = top


def soot(layer, face):
    """A fan of soot up the stone above the fire mouth."""
    fan = pzart.new_layer(SS)
    draw = ImageDraw.Draw(fan)
    z0 = MOUTH_SPRING
    for i in range(14):
        t = i / 13
        w = 0.13 * (0.8 + 0.9 * t)
        face_quad(draw, face, H - w, H + w, z0 + (TOP - z0) * t, z0 + (TOP - z0) * (t + 0.12),
                  (20, 14, 10, int(120 * (1 - t))))
    layer.alpha_composite(fan.filter(ImageFilter.GaussianBlur(3 * SS)))


def arch_points(face, w, steps=12):
    """The fire mouth's outline: straight jambs from the sill and a round arch over them."""
    cu, z0, zs = H, MOUTH_SILL, MOUTH_SPRING
    points = [face_px(face, cu - w, z0), face_px(face, cu - w, zs)]
    for i in range(steps + 1):
        t = math.pi * (1 - i / steps)
        points.append(face_px(face, cu + w * math.cos(t), zs + w * FACE_LEN * ARCH_RISE * math.sin(t)))
    return points + [face_px(face, cu + w, zs), face_px(face, cu + w, z0)]


def mouth(draw, face, rng, light):
    """The firebox's arched mouth, ringed with voussoirs, over an iron grate sill."""
    cu, w, z0, zs = H, MOUTH_W, MOUTH_SILL, MOUTH_SPRING
    draw.polygon(arch_points(face, w + 0.05), fill=shade(ARCH, light * 0.9))
    for i in range(9):
        t0, t1 = math.pi * (1 - i / 9), math.pi * (1 - (i + 1) / 9)
        r0, r1 = w + 0.005, w + 0.048
        ring = [(r0, t0), (r1, t0), (r1, t1), (r0, t1)]
        draw.polygon([face_px(face, cu + r * math.cos(t), zs + r * FACE_LEN * ARCH_RISE * math.sin(t)) for r, t in ring],
                     fill=shade(ARCH, light * rng.uniform(0.85, 1.08)))
    draw.polygon(arch_points(face, w), fill=DARK + (255,))
    # The reveal: the arch's depth, seen on its far jamb.
    face_quad(draw, face, cu + w - 0.03, cu + w, z0, zs, shade(ARCH, light * 0.5))
    face_quad(draw, face, cu - w - 0.02, cu + w + 0.02, z0 - 1.2, z0, shade(GRATE, light))


def render_top(draw):
    h, z0, z1 = H + CAP_OVER, TOP, TOP + CAP
    draw.polygon([tile_px(-h, h, z0), tile_px(h, h, z0), tile_px(h, h, z1), tile_px(-h, h, z1)], fill=shade(RENDER, 0.95))
    draw.polygon([tile_px(h, -h, z0), tile_px(h, h, z0), tile_px(h, h, z1), tile_px(h, -h, z1)], fill=shade(RENDER, 0.72))
    draw.polygon([tile_px(-h, -h, z1), tile_px(h, -h, z1), tile_px(h, h, z1), tile_px(-h, h, z1)], fill=shade(RENDER, 1.12))


# --- The copper --------------------------------------------------------------------------------------------------

def paint_copper(layer, look, rng):
    """The copper's mouth from above (the kettle's, through shape()): a rolled lip that catches the light, tarnished
    metal with rivets on its seam and a little verdigris, the bowl lit on its far wall, set on a ring of BED. Full, a
    skin of milk; hot, wrinkles in the skin."""
    draw = ImageDraw.Draw(layer)
    cx, cy = pzart.project(0, 0, TOP + CAP)
    rx = CU_R * pzart.DIAMOND_HALF_W * math.sqrt(2)
    ry = CU_R * pzart.DIAMOND_HALF_H * math.sqrt(2)
    lip = cy - LIP
    draw.ellipse(box(cx, cy + 0.6, rx + 3.2, ry + 1.8), fill=BED + (255,))
    draw.ellipse(box(cx, lip + 1.4, rx + 1.6, ry + 0.9), fill=shade(METAL, 0.45))
    for i in range(120):
        a = 2 * math.pi * i / 120
        lit = 0.75 + 0.75 * max(0.0, math.cos(a - 2.3)) ** 2   # lit from the left, as the series' barrels
        draw.ellipse(box(cx + (rx + 0.6) * math.cos(a), lip + (ry + 0.35) * math.sin(a), 1.3, 0.9), fill=shade(METAL, lit))
    for i in range(30):
        a = 2.0 + 0.9 * i / 29
        draw.ellipse(box(cx + (rx + 0.6) * math.cos(a), lip + (ry + 0.35) * math.sin(a) - 0.3, 0.7, 0.35),
                     fill=SPECULAR + (255,))
    irx, iry = rx - 1.4, ry - 0.9
    draw.ellipse(box(cx, lip, irx, iry), fill=shade(METAL, 0.35))
    for i in range(24):
        t = i / 23
        draw.ellipse(box(cx + 1.0 * t, lip - 1.4 * (1 - t) - 0.3, irx - 1 - 6 * t, iry - 0.6 - 3 * t),
                     fill=shade(METAL_LIT, 0.55 + 0.6 * (1 - t) ** 1.5 * (1 if t < 0.8 else 0.7)))
    draw.ellipse(box(cx - 1, lip + 2.2, irx - 8, iry - 4.5), fill=shade(METAL, 0.3))
    for _ in range(10):
        a, r = rng.uniform(math.pi * 1.05, math.pi * 1.95), rng.uniform(0.55, 0.9)
        draw.ellipse(box(cx + irx * r * math.cos(a), lip + iry * r * math.sin(a), 0.7, 0.4),
                     fill=shade(HAMMER, rng.uniform(0.9, 1.15)))
    for k in range(3):
        a = 0.55 + k * 0.12
        x, y = cx + (rx + 0.6) * math.cos(a), lip + (ry + 0.35) * math.sin(a)
        draw.ellipse(box(x, y, 0.75, 0.6), fill=shade(METAL, 0.5))
        draw.ellipse(box(x - 0.3, y - 0.25, 0.35, 0.3), fill=shade(METAL, 1.5))
    for _ in range(16):
        a = rng.uniform(0, 2 * math.pi)
        draw.ellipse(box(cx + (rx + 0.6) * math.cos(a), lip + (ry + 0.35) * math.sin(a) + 0.6, 1.0, 0.5),
                     fill=shade(VERDIGRIS, rng.uniform(0.8, 1.1)))
    if look == "Empty":
        return
    sy = lip + 2.0
    draw.ellipse(box(cx, sy, irx - 1.2, iry - 1.0), fill=shade(MILK, 0.9))
    draw.ellipse(box(cx - 2, sy - 0.6, irx - 5, iry - 3), fill=shade(MILK, 1.0))
    draw.arc(box(cx, sy, irx - 1.2, iry - 1.0), 190, 350, fill=shade((196, 140, 110), 0.95), width=SS)
    if look == "Hot":
        for _ in range(6):
            x, y = cx + rng.uniform(-12, 12), sy + rng.uniform(-3, 3)
            draw.arc(box(x, y, 3, 1.2), 200, 340, fill=shade(MILK, 0.8), width=SS)


def body(face, hole):
    """The stone body the Firebox and the Hearth share: split fieldstone, soot over the mouth, the iron door and the
    rendered top; with hole, a small round one in the top's centre, ringed with soot, for the Hearth's kettle."""
    rng = random.Random(160 + face)
    side = FACES[face]
    light = {"S": 1.0, "E": 0.72}
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    for name in ("S", "E"):
        fieldstone(draw, name, random.Random(170 + (name == "E")), light[name])
    soot(layer, side)
    draw = ImageDraw.Draw(layer)
    mouth(draw, side, rng, light[side])
    door(draw, side, random.Random(175 + face), light[side])
    render_top(draw)
    if hole:
        cx, cy = pzart.project(0, 0, TOP + CAP)
        rx, ry = ellipse_r(HOLE_R)
        draw.ellipse(box(cx, cy + 0.4, rx + 1.6, ry + 0.9), fill=shade(MORTAR, 0.6))
        draw.ellipse(box(cx, cy, rx, ry), fill=DARK + (255,))
    return pzart.darken_down(layer, pzart.FOOT[1] - TOP * 0.5, pzart.FOOT[1] + 30, FOOT_SHADE, SS)


def ellipse_r(r):
    """A circle of radius r tiles on the ground, as a screen ellipse's half width and height in px."""
    return r * pzart.DIAMOND_HALF_W * math.sqrt(2), r * pzart.DIAMOND_HALF_H * math.sqrt(2)


def bar_axis(face):
    """The gallows bar runs along the side the door is on: x for S, y for E, as a unit step in tiles."""
    return (1, 0) if FACES[face] == "S" else (0, 1)


def handle_axis(face):
    """The bail's plane: across the bar, towards the door (+y for S, +x for E)."""
    ax, ay = bar_axis(face)
    return ay, ax


def kettle_radius(t):
    """The kettle's radius in tiles at t, 0 at its bottom and 1 at its lip, smoothed between the PROFILE points."""
    for (t0, r0), (t1, r1) in zip(PROFILE, PROFILE[1:]):
        if t <= t1:
            u = (t - t0) / (t1 - t0)
            u = u * u * (3 - 2 * u)
            return KETTLE_R * (r0 + (r1 - r0) * u)
    return KETTLE_R * PROFILE[-1][1]


def soot_share(t, a, phase):
    """How sooted the kettle is at height t and angle a, 0 to 1: black at the bottom, thinning up the belly into the
    copper over a wide band with a mottled, uneven edge, as smoke leaves it; a few worn patches low down."""
    line = 0.76 + 0.05 * math.sin(a * 5 + phase) + 0.03 * math.sin(a * 13 + 2 * phase)
    mottle = 0.06 * math.sin(a * 23 + t * 41 + phase) * math.sin(a * 11 - t * 29)
    s = max(0.0, min(1.0, (line + 0.08 - t + mottle) / 0.32))
    share = s * s * (3 - 2 * s)
    wear = math.sin(a * 7 + t * 23 + phase) * math.sin(a * 3 - t * 17)
    if t < 0.3 and wear > 0.8:
        share *= 0.6
    return share


def paint_kettle(look, face):
    """The kettle, as stacked rings lit from the left, its front lug, and its mouth (paint_copper at its lip).
    Returns the layer and the bail's two ends, back then front, in tiles."""
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    phase = 1.3 + face
    steps = int(KETTLE_H * 2.5)
    for i in range(steps + 1):
        t = i / steps
        cx, cy = pzart.project(0, 0, KETTLE_BOTTOM + KETTLE_H * t)
        rx, ry = ellipse_r(kettle_radius(t))
        draw.ellipse(box(cx, cy, rx, ry), fill=shade(KETTLE_SOOT, 0.7))
        for k in range(64):
            a = math.pi * k / 63
            lit = 0.55 + 0.8 * max(0.0, math.cos(a - 2.3)) ** 2
            sooted = soot_share(t, a, phase)
            colour = tuple(int(c0 * (1 - sooted) + c1 * sooted)
                           for c0, c1 in zip(shade(KETTLE, lit)[:3], shade(KETTLE_SOOT, 0.6 + 0.5 * lit)[:3]))
            draw.ellipse(box(cx + rx * math.cos(a), cy + ry * math.sin(a), 1.3, 0.8), fill=colour + (255,))
    # Lugs a little under the lip, where the bail is riveted on: one towards the door, one at the back, unseen.
    ax, ay = handle_axis(face)
    lip_r = kettle_radius(1.0)
    ends = [(sign * ax * (lip_r + 0.012), sign * ay * (lip_r + 0.012)) for sign in (-1, 1)]
    x, y = pzart.project(ax * (lip_r + 0.005), ay * (lip_r + 0.005), KETTLE_TOP - 4)
    draw.rectangle(box(x, y, 1.0, 1.8), fill=shade(IRON, 0.9))
    with shape({"TOP": KETTLE_TOP - CAP, "CU_R": lip_r * 0.97, "BED": shade(KETTLE, 0.55)[:3], "LIP": 0}):
        paint_copper(layer, look, random.Random(80 + face))
    return layer, ends


def post_points(face):
    ax, ay = bar_axis(face)
    h = H - POST_IN
    return [(-ax * h, -ay * h), (ax * h, ay * h)]


def paint_post(draw, x, y, light):
    """An iron bar from the stone's top up to the gallows bar: lit on its left, set in mortar, an eye at the top."""
    bx, by = pzart.project(x, y, TOP + CAP)
    _, ty = pzart.project(x, y, BAR_Z + 2)
    draw.ellipse(box(bx, by + 0.3, 2.2, 1.1), fill=shade(MORTAR, 0.7))
    draw.rectangle([(bx - 1.1) * SS, ty * SS, (bx + 1.1) * SS, by * SS], fill=shade(IRON, 0.75 * light))
    draw.rectangle([(bx - 1.1) * SS, ty * SS, (bx - 0.2) * SS, by * SS], fill=shade(IRON, 1.35 * light))
    draw.ellipse(box(bx, ty, 1.8, 1.8), outline=shade(IRON, 1.2 * light), width=int(0.8 * SS))


def paint_bar(draw, face):
    (x0, y0), (x1, y1) = post_points(face)
    ax, ay = bar_axis(face)
    over = 0.03
    p0 = pzart.project(x0 - ax * over, y0 - ay * over, BAR_Z)
    p1 = pzart.project(x1 + ax * over, y1 + ay * over, BAR_Z)
    draw.line([(p0[0] * SS, p0[1] * SS), (p1[0] * SS, p1[1] * SS)], fill=shade(IRON, 0.8), width=int(2.0 * SS))
    draw.line([(p0[0] * SS, (p0[1] - 0.7) * SS), (p1[0] * SS, (p1[1] - 0.7) * SS)], fill=shade(IRON, 1.4),
              width=int(0.6 * SS))


def paint_bail(draw, ends):
    """The iron bail, a half hoop from the lugs up to the hook, the Large Hook and its short rod to the bar. Below
    the lip at the back the bail is behind the kettle, so it starts where it clears the lip."""
    (x0, y0), (x1, y1) = ends
    apex = KETTLE_TOP + 14
    points = []
    for i in range(41):
        t = i / 40
        z = KETTLE_TOP - 4 + (apex - KETTLE_TOP + 4) * math.sin(math.pi * t)
        if t < 0.5 and z < KETTLE_TOP + 0.5:
            continue
        px, py = pzart.project(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z)
        points.append((px * SS, py * SS))
    draw.line(points, fill=shade(IRON, 0.85), width=int(1.2 * SS), joint="curve")
    hx, hy = pzart.project(0, 0, apex)
    bx, by = pzart.project(0, 0, BAR_Z)
    draw.line([(hx * SS, (hy - 3) * SS), (bx * SS, by * SS)], fill=shade(IRON, 0.9), width=int(1.0 * SS))
    draw.arc(box(hx, hy - 1.2, 2.0, 2.0), 300, 200, fill=shade(IRON, 1.25), width=int(1.0 * SS))


def steam():
    """Three wisps rising off the kettle, soft."""
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    cx, cy = pzart.project(0, 0, KETTLE_TOP)
    for dx, height, phase in ((-9, 34, 0.0), (1, 44, 1.7), (10, 28, 3.1)):
        for i in range(26):
            t = i / 25
            x = cx + dx + 4 * math.sin(phase + t * 5) * t
            draw.ellipse(box(x, cy - height * t, 2.2 + 3.5 * t, 1.8 + 2.6 * t), fill=STEAM + (int(120 * (1 - t) ** 1.2),))
    return layer.filter(ImageFilter.GaussianBlur(1.2 * SS))


def paint_hearth(look, face):
    """The body with its hole, the far post, the kettle, then the near post, the bar and the bail in front of it."""
    light = 1.0 if FACES[face] == "S" else 0.85
    layer = body(face, True)
    back, near = post_points(face)
    paint_post(ImageDraw.Draw(layer), back[0], back[1], light)
    kettle, ends = paint_kettle(look, face)
    layer.alpha_composite(kettle)
    draw = ImageDraw.Draw(layer)
    paint_post(draw, near[0], near[1], light)
    paint_bar(draw, face)
    paint_bail(draw, ends)
    tile = pzart.hard_edges(pzart.weather(shrink(layer), random.Random(190 + face), WEATHER).convert("RGBA"))
    if look == "Hot":
        tile.alpha_composite(shrink(steam()))
    return tile


# --- The fire's glow ---------------------------------------------------------------------------------------------

def paint_glow(kind, face):
    """The Hearth's overlay, which the game draws over the whole object, so the kettle's outline is cut out of it:
    the door's vents (the Firebox's glow, with no leak: the hole is the flue), firelight on the stone round the hole,
    flames curling up round the kettle's belly and a warm rim along its bottom edge. Banked: a dull red rim, a faint
    glow, no flame."""
    lit = kind == "Lit"
    glow = paint_firebox_glow("LitFlue" if lit else "BankedFlue", face)
    kettle, _ = paint_kettle("Empty", face)
    mask = kettle.getchannel("A")
    fire = pzart.new_layer(SS)
    draw = ImageDraw.Draw(fire)
    cx, cy = pzart.project(0, 0, TOP + CAP)
    krx, kry = ellipse_r(kettle_radius(0.12))
    draw.ellipse(box(cx, cy, krx + 4, kry + 3), fill=FIRE_GLOW + (70 if lit else 30,))
    if lit:
        rng = random.Random(300 + face)
        brx, _ = ellipse_r(KETTLE_R)
        for side in (-1, 1):
            for k in range(4):
                x0 = cx + side * brx * rng.uniform(0.82, 1.0)
                y0 = cy + rng.uniform(-1.5, 1.5)
                height = rng.uniform(9, 16)
                for i in range(18):
                    t = i / 17
                    x = x0 + side * (1.5 + 3.0 * t) * t + math.sin(t * 6 + k) * 0.7
                    draw.ellipse(box(x, y0 - height * t, 2.2 * (1 - t) + 0.5, 1.5),
                                 fill=(255, 190 - int(90 * t), 70, int(245 * (1 - t) ** 0.8)))
    fire = fire.filter(ImageFilter.GaussianBlur(0.9 * SS))
    fire.putalpha(ImageChops.multiply(fire.getchannel("A"), ImageChops.invert(mask)))
    # The rim: the kettle's own pixels with no kettle a few px under them, its bottom edge.
    rim = ImageChops.subtract(mask, ImageChops.offset(mask, 0, -(3 if lit else 2) * SS))
    rim = ImageChops.multiply(rim.filter(ImageFilter.GaussianBlur(0.8 * SS)), mask)
    edge = Image.new("RGBA", fire.size, FIRE_GLOW + (0,) if lit else (170, 50, 20, 0))
    edge.putalpha(rim.point(lambda v: int(v * (0.8 if lit else 0.3))))
    fire.alpha_composite(edge)
    glow.alpha_composite(shrink(fire))
    return glow


# --- The Firebox -------------------------------------------------------------------------------------------------

def door_vents(side):
    """The door's vents: three draught holes low down and two slits under the arch, as (u, z, rx, ry) in px."""
    cu = H
    return [(cu - 0.065, MOUTH_SILL + 2.6, 0.9, 0.9), (cu, MOUTH_SILL + 2.6, 0.9, 0.9), (cu + 0.065, MOUTH_SILL + 2.6, 0.9, 0.9),
            (cu - 0.03, MOUTH_SPRING - 0.5, 0.45, 1.9), (cu + 0.03, MOUTH_SPRING - 0.5, 0.45, 1.9)]


def door(draw, side, rng, light):
    """An iron door over the arched mouth: a riveted frame, two hinge straps on the left, a latch on the right, and
    the vents (dark: the glow overlay lights them)."""
    cu = H
    draw.polygon(arch_points(side, MOUTH_W - 0.004), fill=shade(IRON, light * 1.15))
    draw.polygon(arch_points(side, MOUTH_W - 0.022), fill=shade(IRON, light * 0.92))
    for z in (MOUTH_SILL + 2.2, MOUTH_SPRING - 1.0):
        face_quad(draw, side, cu - MOUTH_W + 0.01, cu + 0.02, z - 0.8, z + 0.8, shade(IRON, light * 0.65))
        x, y = face_px(side, cu - MOUTH_W - 0.012, z)
        draw.ellipse([x - 1.0 * SS, y - 1.3 * SS, x + 1.0 * SS, y + 1.3 * SS], fill=shade(IRON, light * 0.55))
    x, y = face_px(side, cu + MOUTH_W - 0.04, (MOUTH_SILL + MOUTH_SPRING) / 2)
    draw.rectangle([x - 0.6 * SS, y - 1.6 * SS, x + 0.9 * SS, y + 1.6 * SS], fill=shade(IRON, light * 0.5))
    for i in range(8):
        t = math.pi * (1 - i / 7)
        x, y = face_px(side, cu + (MOUTH_W - 0.013) * math.cos(t),
                       MOUTH_SPRING + (MOUTH_W - 0.013) * FACE_LEN * ARCH_RISE * math.sin(t))
        draw.ellipse([x - 0.35 * SS, y - 0.35 * SS, x + 0.35 * SS, y + 0.35 * SS], fill=shade(IRON, light * 1.5))
    for _ in range(6):
        x, y = face_px(side, cu + rng.uniform(-MOUTH_W, MOUTH_W) * 0.8, rng.uniform(MOUTH_SILL, MOUTH_SPRING))
        draw.ellipse([x - 1.2 * SS, y - 0.8 * SS, x + 1.2 * SS, y + 0.8 * SS], fill=(120, 62, 34, 120))
    for u, z, rx, ry in door_vents(side):
        x, y = face_px(side, u, z)
        draw.ellipse([x - rx * SS, y - ry * SS, x + rx * SS, y + ry * SS], fill=DARK + (255,))


TRENCH_W = 0.07                # the trench's half width, in tiles


def trench(layer, face, side, rng):
    """A smoke trench from the foot of the firebox to the wall on its side: a low bank of clay along the ground,
    roofed with flat stones laid edge to edge, a dark gap between them."""
    draw = ImageDraw.Draw(layer)
    dx, dy = FLUE_SIDES[FACES[face]][side]
    px, py = -dy, dx

    def ground(along, across, z):
        return tile_px(dx * along + px * across, dy * along + py * across, z)

    a0, a1 = H - 0.01, 0.5
    draw.polygon([ground(a0, -TRENCH_W - 0.03, 0), ground(a1, -TRENCH_W - 0.03, 0), ground(a1, TRENCH_W + 0.03, 0),
                  ground(a0, TRENCH_W + 0.03, 0)], fill=shade(DAUB, 0.7))
    draw.polygon([ground(a0, -TRENCH_W - 0.02, 2.2), ground(a1, -TRENCH_W - 0.02, 2.2), ground(a1, TRENCH_W + 0.02, 2.2),
                  ground(a0, TRENCH_W + 0.02, 2.2)], fill=shade(DAUB, 0.95))
    a = a0
    while a < a1 - 0.01:
        length = min(rng.uniform(0.045, 0.07), a1 - a)
        b = a + length
        j = [rng.uniform(-0.008, 0.008) for _ in range(4)]
        tone = rng.uniform(0.85, 1.12)
        draw.polygon([ground(a + 0.004, -TRENCH_W + j[0], 2.8), ground(b - 0.004, -TRENCH_W + j[1], 3.0),
                      ground(b - 0.004, TRENCH_W + j[2], 3.0), ground(a + 0.004, TRENCH_W + j[3], 2.8)],
                     fill=shade(STONE, 1.08 * tone))
        a = b


def flue(layer, face, look, rng):
    """The flue out of the top. Capped, a flat stone over the hole at the back; a clay pipe with collars climbing to
    the wall on its side, bedded in clay where it leaves the top. A trench (Stones) leaves from the foot instead, so
    the top is bare."""
    draw = ImageDraw.Draw(layer)
    a0, z0 = H - 0.12, TOP + CAP
    kind, _, side = look.partition("_")
    if kind == "Stones":
        return
    dx, dy = FLUE_SIDES[FACES[face]][side or "Back"]

    def out_px(along, z):
        return tile_px(dx * along, dy * along, z)

    if kind == "Capped":
        x, y = out_px(a0, z0)
        draw.ellipse([x - 5.5 * SS, y - 2.4 * SS, x + 5.5 * SS, y + 2.2 * SS], fill=shade(DARK, 1))
        draw.polygon([(x - 6 * SS, y - 0.4 * SS), (x - 2 * SS, y - 3.2 * SS), (x + 5 * SS, y - 2.6 * SS),
                      (x + 6.5 * SS, y + 0.2 * SS), (x + 2 * SS, y + 2.4 * SS), (x - 4 * SS, y + 1.8 * SS)],
                     fill=shade(STONE, 1.05))
        draw.polygon([(x - 4 * SS, y - 0.6 * SS), (x - 1 * SS, y - 2.4 * SS), (x + 4 * SS, y - 1.8 * SS),
                      (x + 2 * SS, y + 0.6 * SS)], fill=shade(STONE, 1.2))
        return
    a1, z1 = 0.5, z0 + FLUE_RISE
    steps = 56
    # Straight up out of the top for the first part of the steps, then across to the wall: it reads on every side.
    up = 0.3

    def along(t):
        if t < up:
            return a0, z0 + 2 + (FLUE_ELBOW - 2) * t / up
        u = (t - up) / (1 - up)
        return a0 + (a1 - a0) * u, z0 + FLUE_ELBOW + (z1 - z0 - FLUE_ELBOW) * u

    x, y = out_px(a0, z0)
    draw.ellipse([x - (FLUE_R + 3) * SS, y - 3 * SS, x + (FLUE_R + 3) * SS, y + 2.5 * SS], fill=shade(DAUB, 0.9))
    tones = [rng.uniform(0.82, 1.1) for _ in range(5)]
    # Far end first: towards the viewer (south or east) the wall end is the near one.
    order = range(steps + 1) if dx + dy > 0 else range(steps, -1, -1)
    for i in order:
        t = i / steps
        x, y = out_px(*along(t))
        r = FLUE_R if kind == "Pipe" else FLUE_R + 1.5
        if kind == "Pipe":
            collar = any(abs(t - c) < 0.025 for c in (0.42, 0.8))
            r = r + (0.8 if collar else 0)
            tone = 0.62 if collar else 0.78
            draw.ellipse([x - r * SS, y - r * 0.85 * SS, x + r * SS, y + r * 0.85 * SS], fill=shade(CLAY_PIPE, tone))
            draw.ellipse([x - (r - 1.6) * SS, y - (r - 0.6) * 0.85 * SS, x + (r - 2.6) * SS, y + (r - 2.4) * 0.85 * SS],
                         fill=shade(CLAY_PIPE, tone + 0.38))
        else:
            tone = tones[min(int(t * 5), 4)]
            joint = any(abs(t - c) < 0.03 for c in (0.2, 0.4, 0.6, 0.8))
            colour = MORTAR if joint else STONE
            draw.rectangle([x - r * SS, y - r * SS, x + r * SS, y + r * SS], fill=shade(colour, 0.7 * tone))
            draw.rectangle([x - r * SS, y - r * SS, x + r * SS, y - (r - 2.2) * SS], fill=shade(colour, 1.12 * tone))
            draw.rectangle([x - r * SS, y - (r - 2.2) * SS, x - (r - 2.4) * SS, y + r * SS], fill=shade(colour, 0.95 * tone))
    if kind == "Pipe":
        x, y = out_px(a0, z0 + 2)
        draw.ellipse([x - (FLUE_R + 2) * SS, y - 1.5 * SS, x + (FLUE_R + 2) * SS, y + 2.5 * SS], fill=shade(DAUB, 1.0))


def paint_firebox(look, face):
    layer = body(face, False)
    flue(layer, face, look, random.Random(180 + face))
    kind, _, side = look.partition("_")
    if kind == "Stones":
        ground = pzart.new_layer(SS)
        trench(ground, face, side, random.Random(185 + face))
        dx, dy = FLUE_SIDES[FACES[face]][side]
        if dx + dy > 0:
            layer.alpha_composite(ground)      # in front of the stone
        else:
            ground.alpha_composite(layer)      # behind it
            layer = ground
    return pzart.hard_edges(pzart.weather(shrink(layer), random.Random(190 + face), WEATHER).convert("RGBA"))


def paint_firebox_glow(kind, face):
    """Firelight through the door's vents, a little round its edges and spilt under it; banked, the vents a dull red.
    With no flue joined, smoke leaks from round the door and climbs the stone."""
    side = FACES[face]
    lit = kind.startswith("Lit")
    layer = pzart.new_layer(SS)
    if not kind.endswith("Flue"):
        smoke = pzart.new_layer(SS)
        draw = ImageDraw.Draw(smoke)
        rng = random.Random(200 + face + (10 if lit else 0))
        for k in range(3):
            u0, phase = H + (k - 1) * 0.07, rng.uniform(0, 3)
            for i in range(22):
                t = i / 21
                x, y = face_px(side, u0 + 0.03 * math.sin(phase + t * 4), MOUTH_SPRING + 4 + (TOP + 34) * t)
                r = (1.6 + 4 * t) * SS
                draw.ellipse([x - r, y - r * 0.8, x + r, y + r * 0.8],
                             fill=SMOKE + (int((150 if lit else 100) * (1 - t) ** 1.1),))
        layer.alpha_composite(smoke.filter(ImageFilter.GaussianBlur(1.6 * SS)))
    halo = pzart.new_layer(SS)
    hx, hy = face_px(side, H, (MOUTH_SILL + MOUTH_SPRING) / 2)
    ImageDraw.Draw(halo).ellipse(box(hx / SS, hy / SS, 9 if lit else 6, 7 if lit else 4),
                                 fill=(255, 130, 50, 40 if lit else 18))
    layer.alpha_composite(halo.filter(ImageFilter.GaussianBlur(3 * SS)))
    draw = ImageDraw.Draw(layer)
    if lit:
        face_quad(draw, side, H - MOUTH_W + 0.02, H + MOUTH_W - 0.02, MOUTH_SILL - 0.2, MOUTH_SILL + 0.5, (255, 150, 50, 200))
    for u, z, rx, ry in door_vents(side):
        x, y = face_px(side, u, z)
        draw.ellipse([x - rx * SS, y - ry * SS, x + rx * SS, y + ry * SS],
                     fill=(255, 190, 70, 255) if lit else (170, 50, 18, 255))
    return shrink(layer)


# --- Menu icons --------------------------------------------------------------------------------------------------

MENU_ICON = 32
ICON_SS = 8
ICON_METAL = (176, 92, 52)     # brighter than the tile's copper: a menu icon is seen small and on its own
ICON_OUTLINE = (40, 20, 12)


def icon_box(cx, cy, rx, ry):
    return [cx - rx, cy - ry, cx + rx, cy + ry]


def copper_icon(full):
    """The Hearth's kettle from the side, for its menus: the Alpine belly sooted black below and blending into bright
    copper at the shoulder, a rolled lip catching the light from the left and the iron bail over it; full, a skin of
    milk in its mouth. Drawn at ICON_SS times the size, shrunk, then given a dark one-pixel outline so it reads on
    the menu's dark strip."""
    n, s = MENU_ICON * ICON_SS, ICON_SS
    icon = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    cx, bottom, height, widest = n / 2, 30 * s, 19 * s, 14.5 * s
    top = bottom - height
    for row in range(int(height) + 1):
        t = row / height
        half = widest * kettle_radius(t) / KETTLE_R
        y = bottom - row
        for x in range(int(cx - half), int(cx + half) + 1):
            u = (x - cx) / half
            light = 0.55 + 0.8 * max(0.0, math.cos((u + 0.45) * 1.6)) ** 1.5
            sooted = soot_share(t, math.pi / 2 - u, 1.3)
            colour = tuple(int(c0 * (1 - sooted) + c1 * sooted)
                           for c0, c1 in zip(shade(ICON_METAL, light)[:3], shade(KETTLE_SOOT, 0.6 + 0.5 * light)[:3]))
            draw.point((x, y), fill=colour + (255,))
    lip_half, ry = widest * PROFILE[-1][1], 3.2 * s
    draw.ellipse(icon_box(cx, top, lip_half, ry), fill=shade(ICON_METAL, 0.35))
    draw.ellipse(icon_box(cx, top + 0.2 * s, lip_half - 1.4 * s, ry - 0.8 * s),
                 fill=MILK + (255,) if full else shade(ICON_METAL, 0.3))
    for i in range(160):
        a = 2 * math.pi * i / 160
        light = 0.7 + 0.8 * max(0.0, math.cos(a - 2.4)) ** 2
        draw.ellipse(icon_box(cx + (lip_half - 0.5 * s) * math.cos(a), top + (ry - 0.3 * s) * math.sin(a), 1.2 * s, 0.8 * s),
                     fill=shade(ICON_METAL, light))
    for i in range(30):
        a = 2.3 + 0.9 * i / 29
        draw.ellipse(icon_box(cx + (lip_half - 0.5 * s) * math.cos(a), top + (ry - 0.3 * s) * math.sin(a) - 0.3 * s,
                              0.7 * s, 0.35 * s), fill=SPECULAR + (255,))
    bail = [(cx + lip_half * math.cos(math.pi * i / 40), top - 1 * s - 9 * s * math.sin(math.pi * i / 40)) for i in range(41)]
    draw.line(bail, fill=shade(IRON, 1.3), width=int(1.3 * s), joint="curve")
    for side in (-1, 1):
        draw.rectangle(icon_box(cx + side * lip_half, top + 0.5 * s, 0.9 * s, 1.6 * s), fill=shade(IRON, 1.1))
    return outlined(icon.resize((MENU_ICON, MENU_ICON), Image.LANCZOS))


def outlined(icon):
    """icon on a dark ring one pixel wider than its solid part."""
    ring = icon.getchannel("A").point(lambda v: 255 if v >= 100 else 0).filter(ImageFilter.MaxFilter(3))
    out = Image.composite(Image.new("RGBA", icon.size, ICON_OUTLINE + (255,)), Image.new("RGBA", icon.size), ring)
    out.alpha_composite(icon)
    return out


def hearth_icon(kind):
    """The Hearth with its fire lit or banked, for Stoke and Bank."""
    tile = paint_hearth("Empty", 0)
    tile.alpha_composite(paint_glow(kind, 0))
    return tile


# --- Output ------------------------------------------------------------------------------------------------------


def chamber_index(face_index, part):
    """part 0 is the back tile, 1 the front one with the door."""
    return CHAMBER + face_index * 2 + part


def chamber_entry_index(kind, face_index, part):
    """Smokehouse.entrySprite numbers them the same way."""
    return CHAMBER_ENTRY + (FLUE_KINDS.index(kind) * len(FACES) + face_index) * 2 + part


# A two-tile station names each tile's place in the grid ("x,y", as vanilla's Drying Rack and Loom): facing S the
# back tile is 0,0 and the door's 0,1; facing E 0,0 and 1,0.
for face_index, face in enumerate(FACES):
    for part in range(2):
        grid = f"0,{part}" if face == "S" else f"{part},0"
        TILE_PROPS[chamber_index(face_index, part)] = [("BlocksPlacement", ""), ("CustomName", "Chamber"), ("Facing", face),
                                                       ("GroupName", "Smokehouse"), ("IsMoveAble", ""), ("PickUpWeight", "200"),
                                                       ("solidtrans", ""), ("ForceSingleItem", ""), ("SpriteGridPos", grid)]
        for kind in FLUE_KINDS:
            TILE_PROPS[chamber_entry_index(kind, face_index, part)] = [("Facing", face)]
    TILE_PROPS[CHAMBER_HAM + face_index] = [("Facing", face)]


# --- The Smokehouse chamber ----------------------------------------------------------------------------------
# A plank hut two tiles long under one roof slope, high over the door on the front end. Drawn in the shed's own coordinates: a across
# it (+a the visible long side), b along it (+b the door's end); the front tile's middle is b = 0, the back tile's
# b = -1. Each tile paints only its half, so the two meet on screen.

def chamber_world(face, a, b):
    """World x, y of a shed point: facing S the door looks south (+y), facing E east (+x)."""
    return (a, b) if face == "S" else (b, a)


def chamber_px(face, part, a, b, z):
    """A shed point on the tile of that part (0 back, 1 front), supersampled."""
    x, y = chamber_world(face, a, b + (1 - part))
    sx, sy = pzart.project(x, y, z)
    return (sx * SS, sy * SS)


def chamber_planks(draw, rng, quad, start, stop, width, colour, light, clip=None):
    """Planks from start to stop along a wall or roof; quad(u0, u1) gives each one's polygon, each a tone of its own
    with a dark seam between. clip (u0, u1) paints only that stretch: the planks are laid from start all the same,
    so a run over both tiles matches where they meet."""
    low, high = clip or (start, stop)
    u = start
    while u < stop - 1e-6:
        u1 = min(u + width * rng.uniform(0.85, 1.15), stop)
        tone = rng.uniform(0.86, 1.1)
        if max(u, low) < min(u1, high):
            draw.polygon(quad(max(u, low), min(u1, high)), fill=shade(colour, light * tone))
        if low < u1 < min(stop, high) - 1e-6:
            draw.polygon(quad(u1 - 0.006, u1 + 0.006), fill=shade(CHAMBER_EDGE, light * 0.8))
        u = u1


def paint_chamber(face, part):
    rng = random.Random(200 + 2 * FACES.index(face) + part)
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    h, o = CHAMBER_HALF, CHAMBER_OVERHANG
    # This tile's stretch of the shed along b, and its walls' lights by the way the world face looks.
    b0, b1 = (-1 - h, -0.5 + CHAMBER_JOIN) if part == 0 else (-0.5, h)
    door_light, side_light = (1.0, 0.72) if face == "S" else (0.72, 1.0)
    back, front = -1 - h - o, h + o

    def px(a, b, z):
        return chamber_px(face, part, a, b, z)

    def roof_z(b):
        """One slope, high over the door's end and falling to the back."""
        return CHAMBER_BACK + (CHAMBER_FRONT - CHAMBER_BACK) * (b - back) / (front - back)

    # The visible long side, its top following the roof, then the stone sill and two battens along it.
    side = lambda u0, u1: [px(h, u0, 0), px(h, u1, 0), px(h, u1, roof_z(u1) - 2), px(h, u0, roof_z(u0) - 2)]
    chamber_planks(draw, random.Random(210 + FACES.index(face)), side, -1 - h, h, CHAMBER_PLANK, CHAMBER_WOOD, side_light, (b0, b1))
    draw.polygon([px(h, b0, 0), px(h, b1, 0), px(h, b1, CHAMBER_SILL), px(h, b0, CHAMBER_SILL)], fill=shade(CHAMBER_STONE, side_light * 0.8))
    for z in (CHAMBER_SILL + 4, CHAMBER_BACK - 12):
        draw.polygon([px(h + 0.004, b0, z), px(h + 0.004, b1, z), px(h + 0.004, b1, z + 4), px(h + 0.004, b0, z + 4)],
                     fill=shade(CHAMBER_WOOD, side_light * 0.78))

    if part == 1:
        # The door's end: planks up to the high eave, the smoke slot under it with two slats, a sill and the door.
        top = roof_z(h) - 2
        end = lambda u0, u1: [px(u0, h, 0), px(u1, h, 0), px(u1, h, top), px(u0, h, top)]
        chamber_planks(draw, random.Random(220 + FACES.index(face)), end, -h, h, CHAMBER_PLANK, CHAMBER_WOOD, door_light)
        slot_low, slot_high = top - 14, top - 3
        draw.polygon([px(-h + 0.05, h, slot_low), px(h - 0.05, h, slot_low), px(h - 0.05, h, slot_high), px(-h + 0.05, h, slot_high)],
                     fill=shade(CHAMBER_DARK, 1))
        for z in (slot_low + 3, slot_low + 7):
            draw.polygon([px(-h + 0.05, h + 0.004, z), px(h - 0.05, h + 0.004, z), px(h - 0.05, h + 0.004, z + 2), px(-h + 0.05, h + 0.004, z + 2)],
                         fill=shade(CHAMBER_WOOD, door_light * 0.7))
        draw.polygon([px(-h, h, 0), px(h, h, 0), px(h, h, CHAMBER_SILL), px(-h, h, CHAMBER_SILL)], fill=shade(CHAMBER_STONE, door_light * 0.8))
        # The door: darker boards in a frame, two ledges and a brace, strap hinges on its left and a wooden latch.
        d = CHAMBER_DOOR_HALF
        draw.polygon([px(-d - 0.03, h + 0.003, CHAMBER_SILL), px(d + 0.03, h + 0.003, CHAMBER_SILL),
                      px(d + 0.03, h + 0.003, CHAMBER_DOOR + 4), px(-d - 0.03, h + 0.003, CHAMBER_DOOR + 4)], fill=shade(CHAMBER_EDGE, door_light))
        door = lambda u0, u1: [px(u0, h + 0.006, CHAMBER_SILL + 1), px(u1, h + 0.006, CHAMBER_SILL + 1),
                               px(u1, h + 0.006, CHAMBER_DOOR), px(u0, h + 0.006, CHAMBER_DOOR)]
        chamber_planks(draw, random.Random(230 + FACES.index(face)), door, -d, d, CHAMBER_PLANK * 0.8, CHAMBER_WOOD, door_light * 0.82)
        for z0 in (CHAMBER_SILL + 12, CHAMBER_DOOR - 16):
            draw.polygon([px(-d, h + 0.008, z0), px(d, h + 0.008, z0), px(d, h + 0.008, z0 + 6), px(-d, h + 0.008, z0 + 6)],
                         fill=shade(CHAMBER_WOOD, door_light * 0.68))
        draw.polygon([px(-d, h + 0.008, CHAMBER_SILL + 18), px(-d + 0.05, h + 0.008, CHAMBER_SILL + 18),
                      px(d, h + 0.008, CHAMBER_DOOR - 16), px(d - 0.05, h + 0.008, CHAMBER_DOOR - 16)], fill=shade(CHAMBER_WOOD, door_light * 0.72))
        for z0 in (CHAMBER_SILL + 13, CHAMBER_DOOR - 15):
            draw.polygon([px(-d - 0.02, h + 0.01, z0), px(-d + 0.13, h + 0.01, z0 + 1), px(-d + 0.13, h + 0.01, z0 + 3),
                          px(-d - 0.02, h + 0.01, z0 + 4)], fill=shade(CHAMBER_IRON, 1.0))
        latch = CHAMBER_DOOR * 0.55
        draw.polygon([px(d - 0.06, h + 0.01, latch), px(d + 0.02, h + 0.01, latch), px(d + 0.02, h + 0.01, latch + 3),
                      px(d - 0.06, h + 0.01, latch + 3)], fill=shade(CHAMBER_WOOD, door_light * 0.6))

    # The roof: boards running down the slope, laid across the shed, over the walls and past them; a fascia board
    # on the high front edge and along the visible side.
    low, high = b0 - (o if part == 0 else 0), b1 + (o if part == 1 else 0)
    if part == 1:
        high = front
    roof = lambda u0, u1: [px(u0, low, roof_z(low)), px(u1, low, roof_z(low)), px(u1, high, roof_z(high)), px(u0, high, roof_z(high))]
    chamber_planks(draw, random.Random(240 + FACES.index(face) + 4 * part), roof, -h - o, h + o, CHAMBER_PLANK, CHAMBER_ROOF, 1.0)
    draw.polygon([px(h + o, low, roof_z(low)), px(h + o, high, roof_z(high)), px(h + o, high, roof_z(high) - 5), px(h + o, low, roof_z(low) - 5)],
                 fill=shade(CHAMBER_EDGE, side_light * 0.9))
    if part == 1:
        draw.polygon([px(-h - o, front, roof_z(front)), px(h + o, front, roof_z(front)), px(h + o, front, roof_z(front) - 5),
                      px(-h - o, front, roof_z(front) - 5)], fill=shade(CHAMBER_EDGE, door_light * 0.9))

    layer = pzart.darken_down(layer, pzart.FOOT[1] - 60, pzart.FOOT[1] + 30, CHAMBER_FOOT_SHADE, SS)
    return pzart.hard_edges(pzart.weather(shrink(layer), random.Random((250 + 2 * FACES.index(face) + part) * 31 + 7), CHAMBER_WEATHER, True).convert("RGBA"))


def paint_chamber_entry(kind, face, part):
    """Where the flue enters the visible long side, at this tile's middle: a clay pipe's last stub through a collar
    of clay on the planks, or the stone-roofed trench running in under the sill through a dark gap."""
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    h, mid = CHAMBER_HALF, part - 1
    light = 0.72 if face == "S" else 1.0

    def px(a, b, z):
        return chamber_px(face, part, a, b, z)

    def wall(b0, b1, z0, z1):
        return [px(h, mid + b0, z0), px(h, mid + b1, z0), px(h, mid + b1, z1), px(h, mid + b0, z1)]

    if kind == "Pipe":
        draw.polygon(wall(-0.075, 0.075, CHAMBER_FLUE_Z - 8, CHAMBER_FLUE_Z + 9), fill=shade(DAUB, light * 0.95))
        draw.polygon(wall(-0.06, 0.06, CHAMBER_FLUE_Z - 6, CHAMBER_FLUE_Z + 7), fill=shade(DAUB, light * 1.08))
        steps = 8
        for i in range(steps + 1):
            a = h + (0.5 - h) * i / steps
            x, y = px(a, mid, CHAMBER_FLUE_Z)
            r = FLUE_R + (0.8 if i == 0 else 0)
            draw.ellipse([x - r * SS, y - r * 0.85 * SS, x + r * SS, y + r * 0.85 * SS], fill=shade(CLAY_PIPE, 0.78))
            draw.ellipse([x - (r - 1.6) * SS, y - (r - 0.6) * 0.85 * SS, x + (r - 2.6) * SS, y + (r - 2.4) * 0.85 * SS],
                         fill=shade(CLAY_PIPE, 1.16))
    else:
        w = TRENCH_W
        draw.polygon(wall(-w - 0.03, w + 0.03, 0, CHAMBER_SILL + 2), fill=shade(DAUB, light * 0.9))
        draw.polygon(wall(-w + 0.01, w - 0.01, 0, 3), fill=shade(CHAMBER_DARK, 1))
        draw.polygon(wall(-w - 0.02, w + 0.02, 3, CHAMBER_SILL + 1), fill=shade(CHAMBER_STONE, light * 1.05))

        def ground(a, across, z):
            return px(a, mid + across, z)

        a0, a1 = h, 0.5
        draw.polygon([ground(a0, -w - 0.03, 0), ground(a1, -w - 0.03, 0), ground(a1, w + 0.03, 0), ground(a0, w + 0.03, 0)],
                     fill=shade(DAUB, 0.7))
        draw.polygon([ground(a0, -w - 0.02, 2.2), ground(a1, -w - 0.02, 2.2), ground(a1, w + 0.02, 2.2), ground(a0, w + 0.02, 2.2)],
                     fill=shade(DAUB, 0.95))
        draw.polygon([ground(a0 + 0.004, -w, 2.8), ground(a1, -w, 3.0), ground(a1, w, 3.0), ground(a0 + 0.004, w, 2.8)],
                     fill=shade(CHAMBER_STONE, 1.1))
    return pzart.hard_edges(shrink(layer).convert("RGBA"))


def ham_tone(tones, level):
    """One of a short run of tones, dark to light, for a level from 0 to 1: vanilla's food art is a few flat tones laid
    in small patches, never a smooth blend."""
    return tones[max(0, min(len(tones) - 1, int(level * len(tones))))]


def paint_chamber_ham(face):
    """A smoked ham on a cord from a nail on the door's end wall, on the side away from the long wall the camera sees:
    the shank up, the round of it at the bottom, the bone's knob at the top, and low on its face a slice taken off,
    which gives it depth. It hangs a little past the shed's corner. Painted as vanilla's Ham icon is: a few tones in
    small patches, lit from the upper left, a pale mottled cut with a lighter middle, and a dark line round it."""
    h, a = CHAMBER_HALF, HAM_A
    light = 1.0 if face == "S" else 0.78

    def px(da, z, out=0.012):
        return chamber_px(face, 1, a + da, h + out, z)

    # The outline down the ham, from the shank to the round bottom, rounded between its steps.
    steps = [0.02, 0.026, 0.042, 0.07, 0.092, 0.102, 0.1, 0.088, 0.06, 0.028]
    fine = 6
    zs, ws = [], []
    for i in range((len(steps) - 1) * fine + 1):
        low, part = min(i // fine, len(steps) - 2), 0
        part = i / fine - low
        ease = (1 - math.cos(part * math.pi)) / 2
        zs.append(HAM_TOP - 2 - HAM_STEP * min(i / fine, 8.5))
        ws.append((steps[low] + (steps[low + 1] - steps[low]) * ease) * HAM_SCALE)
    widest = max(ws)
    cut_z, cut_w, centre = HAM_TOP - 2 - HAM_STEP * 6.2, widest * 0.72, widest * 0.14

    def mask(points):
        layer = Image.new("L", (TILE_W * SS, TILE_H * SS), 0)
        ImageDraw.Draw(layer).polygon(points, fill=255)
        return layer.resize((TILE_W, TILE_H), Image.LANCZOS).point(lambda v: 255 if v >= 128 else 0)

    def oval(scale, lift=0.0):
        return [px(centre + cut_w * scale * math.cos(t / 16 * math.pi),
                   cut_z + lift + HAM_STEP * 1.7 * scale * math.sin(t / 16 * math.pi), 0.014) for t in range(32)]

    body = mask([px(-w, z) for z, w in zip(zs, ws)] + [px(w, z) for z, w in reversed(list(zip(zs, ws)))])
    cut, lip = mask(oval(1.0)), mask(oval(1.0, 2.0))
    box = body.getbbox()
    rng = random.Random(260 + FACES.index(face))
    patches = Image.blend(pzart.soft_noise(rng, (TILE_W, TILE_H), 3, 3), pzart.soft_noise(rng, (TILE_W, TILE_H), 1, 2), 0.45)
    cut_box = cut.getbbox()
    cut_mid = ((cut_box[0] + cut_box[2]) / 2, (cut_box[1] + cut_box[3]) / 2)

    tile = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    out = tile.load()
    body_px, cut_px, lip_px, noise = body.load(), cut.load(), lip.load(), patches.load()
    for y in range(box[1], box[3]):
        row = [x for x in range(box[0], box[2]) if body_px[x, y]]
        if not row:
            continue
        left, right = row[0], row[-1]
        for x in row:
            across = (x - left) / max(right - left, 1)             # 0 the lit edge, 1 the shaded one
            down = (y - box[1]) / (box[3] - box[1])
            speck = noise[x, y] / 255 - 0.5
            if cut_px[x, y]:
                near = math.hypot((x - cut_mid[0]) / max(cut_box[2] - cut_box[0], 1), (y - cut_mid[1]) / max(cut_box[3] - cut_box[1], 1))
                colour = ham_tone(HAM_CUT_TONES, 0.95 - near * 1.5 + speck * 0.45)
            elif lip_px[x, y]:
                colour = HAM_SKIN_TONES[0]                          # the skin standing proud over the cut
            else:
                colour = ham_tone(HAM_SKIN_TONES, 0.82 - across * 0.62 - down * 0.12 + speck * 0.5)
            out[x, y] = tuple(shade(colour, light))[:3] + (255,)
    # The dark line round it, as vanilla's icons have, and a thin rim of fat under the cut.
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            if not body_px[x, y]:
                continue
            edge = any(not (0 <= nx < TILE_W and 0 <= ny < TILE_H) or not body_px[nx, ny] for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
            if edge:
                out[x, y] = tuple(shade(HAM_LINE, light))[:3] + (255,)
            elif cut_px[x, y] and not cut_px[x, y + 1] and body_px[x, y + 1]:
                out[x, y] = tuple(shade(HAM_FAT, light))[:3] + (255,)

    over = pzart.new_layer(SS)
    draw = ImageDraw.Draw(over)
    nail = HAM_TOP + 9
    draw.line([px(0, nail), px(0, HAM_TOP)], fill=shade(HAM_CORD, light), width=SS)
    draw.ellipse([px(0, nail)[0] - 1.2 * SS, px(0, nail)[1] - 1.2 * SS, px(0, nail)[0] + 1.2 * SS, px(0, nail)[1] + 1.2 * SS],
                 fill=shade(CHAMBER_IRON, 1.0))
    knob = px(0, HAM_TOP)
    draw.ellipse([knob[0] - 2.2 * SS, knob[1] - 1.7 * SS, knob[0] + 2.2 * SS, knob[1] + 1.7 * SS], fill=shade(HAM_BONE, light))
    tile.alpha_composite(pzart.hard_edges(shrink(over).convert("RGBA")))
    return tile


def chamber_icon(tiles, face_index=0):
    """Both halves of the chamber as they stand, the back one drawn first, for the build menu."""
    face = FACES[face_index]
    dx, dy = chamber_world(face, 0, -1)
    sx, sy = round((dx - dy) * pzart.DIAMOND_HALF_W), round((dx + dy) * pzart.DIAMOND_HALF_H)
    canvas = Image.new("RGBA", (TILE_W + abs(sx), TILE_H + abs(sy)), (0, 0, 0, 0))
    ox, oy = max(0, -sx), max(0, -sy)
    canvas.alpha_composite(tiles[chamber_index(face_index, 0)], (ox + sx, oy + sy))
    canvas.alpha_composite(tiles[chamber_index(face_index, 1)], (ox, oy))
    return canvas


def lua_tiles():
    prefix = TILESET + "_"
    return {
        "PREFIX": prefix,
        "SHEETS": [{"prefix": prefix, "tiles": COLUMNS * ROWS}],
        "FACE_COUNT": len(FACES),
        "HEARTH_LOOKS": HEARTH_LOOKS,
        "HEARTHS": [prefix + str(base + offset) for base in HEARTH_LOOKS.values() for offset in range(len(FACES))],
        "GLOWS": GLOWS,
        "FIREBOX_LOOKS": FIREBOX_LOOKS,
        "FIREBOXES": [prefix + str(base + offset) for base in FIREBOX_LOOKS.values() for offset in range(len(FACES))],
        "FIREBOX_GLOWS": FIREBOX_GLOWS,
        # The Smokehouse chamber: both tiles of each face (back, then the door's), its stacks, the flue's entry
        # overlays (Pipe then Stones, each face, each part) and the ham by the door, one a face.
        "CHAMBER": CHAMBER,
        "CHAMBERS": [prefix + str(chamber_index(face, part)) for face in range(len(FACES)) for part in range(2)],
        "CHAMBER_STACKS": CHAMBER_STACKS,
        "CHAMBER_ENTRY": CHAMBER_ENTRY,
        "CHAMBER_HAM": CHAMBER_HAM,
    }


def contact_sheet(tiles, path):
    """Every hearth tile in a row, then each face lit and banked, then the Firebox's the same way (each flue, then
    capped and joined lit and banked), for checking the art by eye; kept out of the mod."""
    cells = [(index + face, None) for index in HEARTH_LOOKS.values() for face in range(len(FACES))]
    cells += [(HEARTH + face, GLOWS[kind] + face) for kind in GLOWS for face in range(len(FACES))]
    cells += [(index + face, None) for index in FIREBOX_LOOKS.values() for face in range(len(FACES))]
    cells += [(FIREBOX_LOOKS["Pipe_Back" if kind.endswith("Flue") else "Capped"] + face, FIREBOX_GLOWS[kind] + face)
              for kind in FIREBOX_GLOWS for face in range(len(FACES))]
    sheet = Image.new("RGBA", (TILE_W * len(cells), TILE_H), (96, 110, 88, 255))
    for x, (index, glow) in enumerate(cells):
        cell = tiles[index].copy()
        if glow is not None:
            cell.alpha_composite(tiles[glow])
        sheet.alpha_composite(cell, (x * TILE_W, 0))
    sheet.save(path)


def main():
    media = Path(__file__).resolve().parent.parent / "42" / "media"
    pzart.write_lua_tiles(media, MOD, lua_tiles(), "tools/build_tileset.py")
    tiles = {}
    for face in range(len(FACES)):
        for look, index in HEARTH_LOOKS.items():
            tiles[index + face] = paint_hearth(look, face)
        for kind, index in GLOWS.items():
            tiles[index + face] = paint_glow(kind, face)
        for look, index in FIREBOX_LOOKS.items():
            tiles[index + face] = paint_firebox(look, face)
        for kind, index in FIREBOX_GLOWS.items():
            tiles[index + face] = paint_firebox_glow(kind, face)
        for part in range(2):
            tiles[chamber_index(face, part)] = paint_chamber(FACES[face], part)
            for kind in FLUE_KINDS:
                tiles[chamber_entry_index(kind, face, part)] = paint_chamber_entry(kind, FACES[face], part)
        tiles[CHAMBER_HAM + face] = paint_chamber_ham(FACES[face])
    (media / "texturepacks").mkdir(parents=True, exist_ok=True)
    pzart.write_pack(media / "texturepacks" / f"{NAME}.pack", tiles, NAME, TILESET, PAGE_SIZE)
    pzart.write_tiles(media / f"{NAME}.tiles", [(TILESET, COLUMNS, ROWS)], TILE_PROPS)
    (media / "textures").mkdir(parents=True, exist_ok=True)
    pzart.write_build_icon(tiles[HEARTH], media / "textures" / "Item_TPHearth.png")
    # Menu icons: the copper empty and full, the Hearth lit and banked.
    copper_icon(False).save(media / "textures" / "Item_TPCopper.png")
    copper_icon(True).save(media / "textures" / "Item_TPCopperFull.png")
    for kind in GLOWS:
        pzart.write_build_icon(hearth_icon(kind), media / "textures" / f"Item_TPHearth{kind}.png", MENU_ICON)
    pzart.write_build_icon(tiles[FIREBOX], media / "textures" / "Item_TPFirebox.png")
    for kind in ("Lit", "Banked"):
        icon = tiles[FIREBOX].copy()
        icon.alpha_composite(tiles[FIREBOX_GLOWS[kind]])
        pzart.write_build_icon(icon, media / "textures" / f"Item_TPFirebox{kind}.png", MENU_ICON)
    pzart.write_build_icon(chamber_icon(tiles), media / "textures" / "Item_SmokehouseChamber.png")
    # The mod list shows the copper steaming.
    pzart.write_mod_icon(tiles[HEARTH_LOOKS["Hot"]], media.parent / "icon.png")
    if len(sys.argv) > 1:
        contact_sheet(tiles, sys.argv[1])
    print(f"wrote {NAME}.pack and {NAME}.tiles to {media}")


if __name__ == "__main__":
    main()
