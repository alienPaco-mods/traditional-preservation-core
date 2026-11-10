#!/usr/bin/env python3
"""Builds the TP Core art: the shared stations' tileset (42/media/*.tiles and texturepacks/*.pack), their build icons,
the mod icon, the Hearth's menu icons and the generated Tiles.lua.

The Hearth: a farmhouse copper. A block of split fieldstone, as vanilla's kilns are built, waist high with a lime
render on top, and a copper pan set into it over its own firebox, whose arched mouth is on the side it faces. The
game turns it into a vanilla fireplace when it is built. Vanilla draws the fireplace's flames and fuel as attached
sprites, so HearthWorld swaps the hearth's own sprite among whole-hearth tiles, the copper empty, full or steaming
(HEARTH_LOOKS), and every one of them carries the fireplace's tile properties. The fire mouth's glow is the object's
overlay sprite (GLOWS), the way vanilla lights its kilns: a bright one while it burns, a few embers when banked.

The stone and the copper have hard edges (pzart.hard_edges); the steam and the glow are soft.

Usage: python3 tools/build_tileset.py [contact-sheet.png]
Needs Pillow. Deterministic: a rerun with no change gives byte-identical files.
"""
import math
import random
import sys
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
PAGE_SIZE = 512
SS = 4  # supersampling

# Facings, S and E, as the entity scripts' faces. Each look takes len(FACES) tiles from its number.
FACES = ["S", "E"]
HEARTH_LOOKS = {"Empty": 0, "Full": 2, "Hot": 4}
HEARTH = HEARTH_LOOKS["Empty"]
# The fire mouth's glow, an overlay: lit, and banked (embers under ash, almost no light).
GLOWS = {"Lit": 6, "Banked": 8}

# Colours.
STONE = (158, 132, 104)
MORTAR = (92, 78, 64)
ARCH = (128, 106, 84)
RENDER = (196, 186, 166)       # lime render on the top
BED = (64, 54, 46)             # the mortar the copper is bedded in
METAL = (150, 82, 50)          # tarnished copper
METAL_LIT = (196, 112, 78)     # the copper's lit inside
HAMMER = (230, 150, 110)
SPECULAR = (255, 226, 196)
VERDIGRIS = (92, 140, 118)
MILK = (226, 220, 200)
DARK = (22, 15, 11)
GRATE = (60, 56, 52)
STEAM = (244, 244, 240)
WEATHER = 0.2
FOOT_SHADE = 0.8               # the stone darkens this far towards the ground

# The hearth: about waist high (a cask is 85 px), most of a tile across, with a copper of about 10 L.
H = 0.40                       # half the footprint, in tiles
TOP = 60                       # stone, px high
CAP = 4                        # the rendered top
CAP_OVER = 0.015               # how far the top overhangs, in tiles
CU_R = 0.27                    # the copper's radius, in tiles
LIP = 2                        # how far its rolled lip stands above the top, px
MOUTH_W, MOUTH_SILL, MOUTH_SPRING = 0.17, 1.5, 13.0   # half width in tiles; sill and springing height, px
ARCH_RISE = 0.55               # the arch's height for its width
FACE_LEN = math.hypot(pzart.DIAMOND_HALF_W, pzart.DIAMOND_HALF_H)   # px along a face per tile

TILE_PROPS = {}
for look, base in HEARTH_LOOKS.items():
    for offset, facing in enumerate(FACES):
        # IsoType and the woodstove container make the game load it as a fireplace with a firebox to cook in. The
        # engine only links the facings of tiles with a GroupName, and that link lets a moved hearth rotate.
        TILE_PROPS[base + offset] = [("BlocksPlacement", ""), ("ContainerCapacity", "15"), ("ContainerPosition", "Low"),
                                     ("CustomName", "Hearth"), ("Facing", facing), ("GroupName", "Stone"),
                                     ("IsMoveAble", ""), ("IsoType", "IsoFireplace"), ("PickUpWeight", "100"),
                                     ("container", "woodstove"), ("solidtrans", "")]


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
    """A hammered copper pan bedded in the top: a rolled lip that catches the light, tarnished metal with rivets on
    its seam and a little verdigris, the bowl lit on its far wall. Full, a skin of milk; hot, wrinkles in the skin."""
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


def steam():
    """Three wisps rising off the copper, soft."""
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    cx, cy = pzart.project(0, 0, TOP + CAP + 2)
    for dx, height, phase in ((-9, 34, 0.0), (1, 44, 1.7), (10, 28, 3.1)):
        for i in range(26):
            t = i / 25
            x = cx + dx + 4 * math.sin(phase + t * 5) * t
            draw.ellipse(box(x, cy - height * t, 2.2 + 3.5 * t, 1.8 + 2.6 * t), fill=STEAM + (int(120 * (1 - t) ** 1.2),))
    return layer.filter(ImageFilter.GaussianBlur(1.2 * SS))


def paint_hearth(look, face):
    rng = random.Random(60 + face)
    side = FACES[face]
    light = {"S": 1.0, "E": 0.72}
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    for name in ("S", "E"):
        fieldstone(draw, name, random.Random(70 + (name == "E")), light[name])
    soot(layer, side)
    draw = ImageDraw.Draw(layer)
    mouth(draw, side, rng, light[side])
    render_top(draw)
    layer = pzart.darken_down(layer, pzart.FOOT[1] - TOP * 0.5, pzart.FOOT[1] + 30, FOOT_SHADE, SS)
    paint_copper(layer, look, random.Random(80 + face))
    tile = pzart.hard_edges(pzart.weather(shrink(layer), random.Random(90 + face), WEATHER).convert("RGBA"))
    if look == "Hot":
        tile.alpha_composite(shrink(steam()))
    return tile


# --- The fire's glow ---------------------------------------------------------------------------------------------

def paint_glow(kind, face):
    """Firelight in the mouth, brightest on the bed of embers and fading up into the arch, a warm halo on the stone
    round it and a little light spilt on the floor in front. Banked: a few embers glowing through the ash, no more."""
    side = FACES[face]
    rng = random.Random(100 + face + (10 if kind == "Banked" else 0))
    lit = kind == "Lit"
    layer = pzart.new_layer(SS)
    inner = pzart.new_layer(SS)
    draw = ImageDraw.Draw(inner)
    draw.polygon(arch_points(side, MOUTH_W - 0.01), fill=(255, 120, 30, 255) if lit else (120, 30, 10, 255))
    for _ in range(40 if lit else 14):
        x, y = face_px(side, H + rng.uniform(-MOUTH_W * 0.9, MOUTH_W * 0.9), MOUTH_SILL + rng.uniform(0, 3.5 if lit else 1.8))
        colours = [(255, 214, 90, 255), (255, 170, 50, 255), (200, 60, 20, 255)] if lit else [(230, 90, 30, 255), (160, 40, 15, 255)]
        draw.ellipse([x - 0.75 * SS, y - 0.5 * SS, x + 0.75 * SS, y + 0.5 * SS], fill=rng.choice(colours))
    top = face_px(side, H, MOUTH_SPRING + MOUTH_W * FACE_LEN * ARCH_RISE)[1]
    bottom = face_px(side, H, MOUTH_SILL)[1]
    fade = Image.new("L", inner.size, 0)
    fade_draw = ImageDraw.Draw(fade)
    for i in range(32):
        t = i / 31
        y = top + (bottom - top) * t
        reach = 60 + 195 * t ** 0.8 if lit else 255 * t ** 2.5
        fade_draw.rectangle([0, y, inner.width, y + (bottom - top) / 31 + 1], fill=int(reach))
    fade_draw.rectangle([0, bottom, inner.width, inner.height], fill=255)
    inner.putalpha(ImageChops.multiply(inner.getchannel("A"), fade))
    if lit:
        spill = pzart.new_layer(SS)
        sx, sy = face_px(side, H, 0)
        ImageDraw.Draw(spill).ellipse(box(sx / SS + (-8 if side == "S" else 8), sy / SS + 6, 16, 7), fill=(255, 150, 60, 70))
        layer.alpha_composite(spill.filter(ImageFilter.GaussianBlur(4 * SS)))
    halo = pzart.new_layer(SS)
    hx, hy = face_px(side, H, (MOUTH_SILL + MOUTH_SPRING) / 2)
    ImageDraw.Draw(halo).ellipse(box(hx / SS, hy / SS, 13 if lit else 8, 11 if lit else 5),
                                 fill=(255, 130, 50, 60 if lit else 30))
    layer.alpha_composite(halo.filter(ImageFilter.GaussianBlur(3 * SS)))
    layer.alpha_composite(inner)
    return shrink(layer)


# --- Menu icons --------------------------------------------------------------------------------------------------

MENU_ICON = 32
ICON_SS = 8
ICON_METAL = (176, 92, 52)     # brighter than the tile's copper: a menu icon is seen small and on its own
ICON_OUTLINE = (40, 20, 12)


def icon_box(cx, cy, rx, ry):
    return [cx - rx, cy - ry, cx + rx, cy + ry]


def copper_icon(full):
    """The copper seen from the side, for the Hearth's menus: a hammered bowl with a riveted seam, a rolled lip
    catching the light from the left and a touch of verdigris; full, a skin of milk inside. Drawn at ICON_SS times
    the size, shrunk, then given a dark one-pixel outline so it reads on the menu's dark strip."""
    n, s = MENU_ICON * ICON_SS, ICON_SS
    icon = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    cx, rx, top, ry, depth = n / 2, 14.2 * s, 11 * s, 4.2 * s, 15 * s
    for x in range(int(cx - rx), int(cx + rx) + 1):
        u = (x - cx) / rx
        if abs(u) > 1:
            continue
        across = math.sqrt(1 - u * u)
        light = 0.55 + 0.75 * max(0.0, math.cos((u + 0.45) * 1.6)) ** 1.5
        draw.line([(x, top + ry * across - 2), (x, top + depth * across ** 0.8 + ry * 0.6 * across)],
                  fill=shade(ICON_METAL, light))
    rng = random.Random(3)
    for _ in range(26):
        u, v = rng.uniform(-0.85, 0.85), rng.uniform(0.25, 0.85)
        x, y = cx + u * rx, top + ry + v * depth * math.sqrt(1 - u * u) * 0.8
        draw.ellipse(icon_box(x, y, 1.2 * s, 0.7 * s), fill=shade(ICON_METAL, rng.uniform(0.85, 1.25)))
    for i in range(7):
        u = -0.8 + i * 0.27
        x, y = cx + u * rx, top + ry * 0.4 + depth * 0.42 * math.sqrt(1 - u * u)
        draw.ellipse(icon_box(x, y, 0.9 * s, 0.8 * s), fill=shade(ICON_METAL, 0.5))
        draw.ellipse(icon_box(x - 0.2 * s, y - 0.25 * s, 0.4 * s, 0.35 * s), fill=shade(METAL_LIT, 1.3))
    for _ in range(6):
        u = rng.uniform(-0.9, 0.9)
        x, y = cx + u * rx, top + ry * math.sqrt(1 - u * u) + rng.uniform(0.8, 2.0) * s
        draw.ellipse(icon_box(x, y, 0.9 * s, 0.45 * s), fill=VERDIGRIS + (150,))
    draw.ellipse(icon_box(cx, top, rx, ry), fill=shade(ICON_METAL, 0.35))
    draw.ellipse(icon_box(cx, top + 0.2 * s, rx - 1.6 * s, ry - 0.8 * s), fill=shade(ICON_METAL, 0.55))
    if full:
        draw.ellipse(icon_box(cx, top + 0.45 * s, rx - 2.4 * s, ry - 1.35 * s), fill=MILK + (255,))
    else:
        draw.ellipse(icon_box(cx - s, top + 0.7 * s, rx - 4 * s, ry - 1.5 * s), fill=shade(ICON_METAL, 0.3))
    for i in range(160):
        a = 2 * math.pi * i / 160
        light = 0.7 + 0.8 * max(0.0, math.cos(a - 2.4)) ** 2
        draw.ellipse(icon_box(cx + (rx - 0.6 * s) * math.cos(a), top + (ry - 0.3 * s) * math.sin(a), 1.3 * s, 0.9 * s),
                     fill=shade(ICON_METAL, light))
    for i in range(30):
        a = 2.3 + 0.9 * i / 29
        draw.ellipse(icon_box(cx + (rx - 0.6 * s) * math.cos(a), top + (ry - 0.3 * s) * math.sin(a) - 0.3 * s,
                         0.7 * s, 0.35 * s), fill=SPECULAR + (255,))
    shine = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(shine).ellipse([cx - rx * 0.62, top + ry + s, cx - rx * 0.38, top + ry + 9 * s], fill=SPECULAR + (110,))
    icon.alpha_composite(shine.filter(ImageFilter.GaussianBlur(1.5 * s)))
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

def lua_tiles():
    prefix = TILESET + "_"
    return {
        "PREFIX": prefix,
        "SHEETS": [{"prefix": prefix, "tiles": COLUMNS * ROWS}],
        "FACE_COUNT": len(FACES),
        "HEARTH_LOOKS": HEARTH_LOOKS,
        "HEARTHS": [prefix + str(base + offset) for base in HEARTH_LOOKS.values() for offset in range(len(FACES))],
        "GLOWS": GLOWS,
    }


def contact_sheet(tiles, path):
    """Every hearth tile in a row, then each face lit and banked, for checking the art by eye; kept out of the mod."""
    cells = [(index + face, None) for index in HEARTH_LOOKS.values() for face in range(len(FACES))]
    cells += [(HEARTH + face, GLOWS[kind] + face) for kind in GLOWS for face in range(len(FACES))]
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
    # The mod list shows the copper steaming.
    pzart.write_mod_icon(tiles[HEARTH_LOOKS["Hot"]], media.parent / "icon.png")
    if len(sys.argv) > 1:
        contact_sheet(tiles, sys.argv[1])
    print(f"wrote {NAME}.pack and {NAME}.tiles to {media}")


if __name__ == "__main__":
    main()
