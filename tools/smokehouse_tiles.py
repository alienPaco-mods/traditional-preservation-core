"""The Smokehouse's art, for build_tileset.py (2 x 2, 2026-11-19; preview WIP/TPCore/art/smokehouse_2x2_mock.py,
approved by the user): a plank shed on a square of four tiles under a low pitched roof whose ridge runs from the door
to the back, so both slopes show from the camera. The door's end is a gable: a galvanised louvre vent under its peak,
sooted by the smoke, a lintel beam and a pair of plank doors (ledged, braced, strap hinges, ring pulls) across its
middle. The long wall in view and the door's end stand where they stood on the 2-tile shed's tiles, so the flue's
entry overlays (build_tileset's paint_chamber_entry) are unchanged.

The shed is painted whole on one canvas, a surface at a time (each wall, each roof slope, the trim), then each tile
is cut out of it by its own footprint: a wall by its stretch on that tile, a roof slope by its stretch over it, so a
tile holds only what stands on its square (the game sorts tiles by square). The back and left tiles run JOIN under
their neighbours, so no seam shows.

Overlays: what hangs by the door while finished stacks wait, one piece for every two stacks (a country ham on the
front-left tile, then a smoked chicken and a smoked rabbit on the front-right one), each casting a shadow on the
boards; and the vent's smoke while the joined Stone Hearth burns, a plume stoked, a wisp banked, soft as the cauldron's
steam and carried by the front-right tile (drawn last of the four) wherever its image reaches.
"""
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_tileset as B  # noqa: E402
import pzart  # noqa: E402
from pzart import tint as shade  # noqa: E402

SS = B.SS
HW, HH = pzart.DIAMOND_HALF_W, pzart.DIAMOND_HALF_H
H = B.CHAMBER_HALF            # the walls stand this far from the outer tiles' middles
O = 0.12                      # the roof past the long walls (eaves)
OG = 0.06                     # the roof past the gables
RIDGE_A = -0.5                # the ridge runs along the middle, over the seam between the two columns
EAVE = 124                    # px up to the eaves
RIDGE = 152                   # px up to the ridge: about 29 px a tile, so the far slope shows (it turns away from 62)
DOOR_HALF = 0.5               # the pair of doors together, half their width
DOOR_TOP = 102
LINTEL = 6                    # the beam over the doors, px high
VENT = (0.17, DOOR_TOP + LINTEL + 6, RIDGE - 8)   # the vent's half width, bottom and top
METAL = (150, 154, 152)       # galvanised steel
METAL_DARK = (58, 60, 62)
JOIN = 0.02                   # the back and left tiles run this far under the front and right ones
CANVAS = (420, 420)
ORIGIN = (150, 120)           # where the front-right tile's (0, 0) sits on the canvas, px


def world(face, a, b):
    return B.chamber_world(face, a, b)


def cpx(face, a, b, z):
    """A shed point on the canvas, supersampled. a across (+a the long wall in view), b along (+b the door's end);
    the front-right tile's middle is (0, 0), the shed spans a and b from -1 - H to H."""
    x, y = world(face, a, b)
    sx, sy = pzart.project(x, y, z)
    return ((sx + ORIGIN[0]) * SS, (sy + ORIGIN[1]) * SS)


def roof_z(a):
    run = 0.5 + H
    return RIDGE - (RIDGE - EAVE) * abs(a - RIDGE_A) / run


def new_canvas():
    return Image.new("RGBA", (CANVAS[0] * SS, CANVAS[1] * SS), (0, 0, 0, 0))


def nails(draw, points, light):
    for x, y in points:
        draw.ellipse([x - 0.7 * SS, y - 0.6 * SS, x + 0.7 * SS, y + 0.6 * SS], fill=shade(B.CHAMBER_DARK, light * 1.6))


def sink(layer, face, plane):
    """Darkens a wall towards the ground, by each pixel's height on its plane (plane(u) -> (a, b) on the ground)."""
    (x0, y0), (x1, y1) = cpx(face, *plane(0.0), 0), cpx(face, *plane(1.0), 0)
    w, h = layer.size
    sx = np.arange(w)[None, :]
    sy = np.arange(h)[:, None]
    ground = y0 + (sx - x0) * (y1 - y0) / (x1 - x0)
    z = (ground - sy) / SS
    f = 1 - (1 - B.CHAMBER_FOOT_SHADE) * np.clip((60 - z) / 90, 0, 1)
    arr = np.asarray(layer).astype(np.float32)
    arr[..., :3] *= f[..., None]
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")


def lights(face):
    """door end, long wall in view, left slope, right slope."""
    return (1.0, 0.72, 1.0, 0.84) if face == "S" else (0.72, 1.0, 0.8, 1.04)


def paint_side(face):
    """The long wall in view (a = H): boards, the stone sill, two battens nailed, a corner board at the door's end."""
    _, light, _, _ = lights(face)
    layer = new_canvas()
    draw = ImageDraw.Draw(layer)
    lo, hi = -1 - H, H
    top = EAVE - 2
    side = lambda u0, u1: [cpx(face, H, u0, 0), cpx(face, H, u1, 0), cpx(face, H, u1, top), cpx(face, H, u0, top)]
    B.chamber_planks(draw, random.Random(310 + FACES(face)), side, lo, hi, B.CHAMBER_PLANK, B.CHAMBER_WOOD, light,
                     gaps=B.CHAMBER_WALL_GAP)
    draw.polygon([cpx(face, H, lo, 0), cpx(face, H, hi, 0), cpx(face, H, hi, B.CHAMBER_SILL), cpx(face, H, lo, B.CHAMBER_SILL)],
                 fill=shade(B.CHAMBER_STONE, light * 0.8))
    for z in (B.CHAMBER_SILL + 6, top - 14):
        a = H + 0.004
        draw.polygon([cpx(face, a, lo, z), cpx(face, a, hi, z), cpx(face, a, hi, z + 5), cpx(face, a, lo, z + 5)],
                     fill=shade(B.CHAMBER_WOOD, light * 0.8))
        draw.line([cpx(face, a + 0.001, lo, z + 5), cpx(face, a + 0.001, hi, z + 5)], fill=shade(B.CHAMBER_EDGE, light), width=SS)
        u = lo + B.CHAMBER_PLANK / 2
        while u < hi:
            nails(draw, [cpx(face, a + 0.002, u, z + 2.5)], light)
            u += B.CHAMBER_PLANK
    # Corner boards, front and back, standing proud.
    for b0, b1 in ((hi - 0.07, hi), (lo, lo + 0.07)):
        draw.polygon([cpx(face, H + 0.008, b0, B.CHAMBER_SILL), cpx(face, H + 0.008, b1, B.CHAMBER_SILL),
                      cpx(face, H + 0.008, b1, top), cpx(face, H + 0.008, b0, top)], fill=shade(B.CHAMBER_WOOD, light * 0.9))
        draw.line([cpx(face, H + 0.009, b0, B.CHAMBER_SILL), cpx(face, H + 0.009, b0, top)], fill=shade(B.CHAMBER_EDGE, light), width=SS)
    return sink(layer, face, lambda u: (H, u))


def paint_gable(face):
    """The door's end (b = H): boards up under the roof's slopes, the sill, a tie beam at the eaves, the smoke vent
    under the peak and the pair of doors in the middle."""
    light, _, _, _ = lights(face)
    layer = new_canvas()
    draw = ImageDraw.Draw(layer)
    lo, hi = -1 - H, H
    end = lambda u0, u1: [cpx(face, u0, H, 0), cpx(face, u1, H, 0), cpx(face, u1, H, roof_z(u1) - 2), cpx(face, u0, H, roof_z(u0) - 2)]
    # The peak sits between two boards' ends, so lay them in two runs out from the ridge.
    B.chamber_planks(draw, random.Random(320 + FACES(face)), end, lo, RIDGE_A, B.CHAMBER_PLANK, B.CHAMBER_WOOD, light, gaps=B.CHAMBER_WALL_GAP)
    B.chamber_planks(draw, random.Random(321 + FACES(face)), end, RIDGE_A, hi, B.CHAMBER_PLANK, B.CHAMBER_WOOD, light, gaps=B.CHAMBER_WALL_GAP)
    draw.polygon([cpx(face, lo, H, 0), cpx(face, hi, H, 0), cpx(face, hi, H, B.CHAMBER_SILL), cpx(face, lo, H, B.CHAMBER_SILL)],
                 fill=shade(B.CHAMBER_STONE, light * 0.8))
    # A tie beam across at the eaves, nailed, either side of the vent.
    z = EAVE - 8
    draw.polygon([cpx(face, lo, H + 0.004, z), cpx(face, hi, H + 0.004, z), cpx(face, hi, H + 0.004, z + 6), cpx(face, lo, H + 0.004, z + 6)],
                 fill=shade(B.CHAMBER_WOOD, light * 0.78))
    draw.line([cpx(face, lo, H + 0.005, z), cpx(face, hi, H + 0.005, z)], fill=shade(B.CHAMBER_EDGE, light), width=SS)
    nails(draw, [cpx(face, u, H + 0.006, z + 3) for u in (lo + 0.05, -1.0, 0.0, hi - 0.05)], light)
    # The smoke vent: a galvanised louvre in a pressed frame, its slats angled down, dark between.
    vh, vz0, vz1 = VENT
    v0, v1 = RIDGE_A - vh, RIDGE_A + vh
    q = lambda a0, a1, z0, z1, out: [cpx(face, a0, H + out, z0), cpx(face, a1, H + out, z0), cpx(face, a1, H + out, z1),
                                     cpx(face, a0, H + out, z1)]
    draw.polygon(q(v0 - 0.015, v1 + 0.015, vz0 - 2, vz1 + 2, 0.004), fill=shade(METAL, light * 0.7))
    draw.polygon(q(v0, v1, vz0, vz1, 0.006), fill=shade(METAL, light * 1.08))
    draw.polygon(q(v0 + 0.03, v1 - 0.03, vz0 + 2, vz1 - 2, 0.007), fill=shade(METAL_DARK, 1))
    slats = 5
    for k in range(slats):
        sz = vz0 + 3 + k * (vz1 - vz0 - 5) / slats
        draw.polygon(q(v0 + 0.03, v1 - 0.03, sz, sz + 2, 0.009), fill=shade(METAL, light * 0.95))
        draw.line([cpx(face, v0 + 0.03, H + 0.009, sz + 2), cpx(face, v1 - 0.03, H + 0.009, sz + 2)], fill=shade(METAL, light * 1.2), width=SS)
    nails(draw, [cpx(face, u, H + 0.008, z) for u in (v0 + 0.012, v1 - 0.012) for z in (vz0 - 0.5, vz1 + 0.5)], light * 0.6)
    paint_door(draw, face, light)
    layer = soot_vent(layer, face)
    return sink(layer, face, lambda u: (u, H))


def soot_vent(layer, face):
    """Smoke leaving the vent has sooted it: the slats and frame dark at the top, black streaks climbing the boards above
    to the roof, a smudge spreading either side. Soft, then cut to the wall so no faint edge is left."""
    vh, vz0, vz1 = VENT
    v0, v1 = RIDGE_A - vh, RIDGE_A + vh
    rng = random.Random(380 + FACES(face))
    soot = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(soot)
    q = lambda a0, a1, z0, z1: [cpx(face, a0, H + 0.01, z0), cpx(face, a1, H + 0.01, z0), cpx(face, a1, H + 0.01, z1), cpx(face, a0, H + 0.01, z1)]
    dark = B.CHAMBER_DARK
    # Across the louvre: heavier towards its top, where the smoke leaves.
    for k in range(10):
        z0 = vz0 + (vz1 - vz0) * k / 10
        draw.polygon(q(v0 - 0.01, v1 + 0.01, z0, z0 + (vz1 - vz0) / 10 + 0.5), fill=dark + (int(70 + 175 * k / 9),))
    # Streaks up from the vent's top to the roof, uneven.
    a = v0 - 0.02
    while a < v1 + 0.02:
        w = rng.uniform(0.02, 0.05)
        top = roof_z(a + w / 2) - rng.uniform(0, 6)
        draw.polygon(q(a, a + w, vz1 - 2, top), fill=dark + (rng.randint(170, 245),))
        a += w + rng.uniform(0.0, 0.03)
    # A smudge round the frame's top corners.
    for side in (v0, v1):
        x, y = cpx(face, side, H + 0.01, vz1)
        r = 6 * SS
        draw.ellipse([x - r, y - r * 0.8, x + r, y + r * 0.8], fill=dark + (200,))
    soot = soot.filter(ImageFilter.GaussianBlur(1.6 * SS))
    alpha = np.minimum(np.asarray(soot.getchannel("A")), np.asarray(layer.getchannel("A")))
    soot.putalpha(Image.fromarray(alpha.astype(np.uint8), "L"))
    out = layer.copy()
    out.alpha_composite(soot)
    # The specks: hard dots of soot on the slats and frame.
    draw = ImageDraw.Draw(out)
    for _ in range(26):
        a, z = rng.uniform(v0, v1), rng.uniform(vz0 + (vz1 - vz0) * 0.3, vz1 + 3)
        x, y = cpx(face, a, H + 0.012, z)
        draw.ellipse([x - 0.6 * SS, y - 0.5 * SS, x + 0.6 * SS, y + 0.5 * SS], fill=shade(dark, 1.3))
    return out


def paint_door(draw, face, light):
    """A pair of plank doors across the middle of the gable end, meeting at the ridge's line: a frame of posts and a
    lintel beam over them, each leaf ledged and braced (the brace rising from the hinge side), long strap hinges
    on the outer edges, an iron ring pull by the middle, a dark crack where the leaves meet and along the top."""
    c, d, h = RIDGE_A, DOOR_HALF, H
    sill, top = B.CHAMBER_SILL, DOOR_TOP
    p = lambda u, out, z: cpx(face, c + u, h + out, z)
    quad = lambda u0, u1, out, z0, z1: [p(u0, out, z0), p(u1, out, z0), p(u1, out, z1), p(u0, out, z1)]
    # Posts, then the lintel over the opening and past it.
    for u0, u1 in ((-d - 0.06, -d), (d, d + 0.06)):
        draw.polygon(quad(u0, u1, 0.004, sill, top + LINTEL), fill=shade(B.CHAMBER_WOOD, light * 0.86))
        draw.line([p(u1, 0.005, sill), p(u1, 0.005, top)], fill=shade(B.CHAMBER_EDGE, light), width=SS)
    draw.polygon(quad(-d - 0.12, d + 0.12, 0.006, top, top + LINTEL), fill=shade(B.CHAMBER_WOOD, light * 0.8))
    draw.line([p(-d - 0.12, 0.007, top), p(d + 0.12, 0.007, top)], fill=shade(B.CHAMBER_EDGE, light), width=SS)
    nails(draw, [p(u, 0.008, top + LINTEL / 2) for u in (-d - 0.09, -d + 0.03, d - 0.03, d + 0.09)], light)
    draw.polygon(quad(-d, d, 0.004, sill, top), fill=shade(B.CHAMBER_DARK, 1))
    crack = random.Random(335 + FACES(face))
    for side in (-1, 1):
        o0, o1 = (-d, -0.012) if side < 0 else (0.012, d)
        hinge = o0 if side < 0 else o1
        free = o1 if side < 0 else o0
        leaf = lambda u0, u1, o0=o0, o1=o1: [p(max(u0, o0), 0.006, sill + 1), p(min(u1, o1), 0.006, sill + 1),
                                             p(min(u1, o1), 0.006, top - 1.5), p(max(u0, o0), 0.006, top - 1.5)]
        B.chamber_planks(draw, random.Random(330 + 2 * FACES(face) + (side > 0)), leaf, o0, o1, B.CHAMBER_PLANK * 0.8,
                         B.CHAMBER_WOOD, light * 1.1, gaps=0.1)
        # A dark line round the leaf, so the pair reads against the wall's boards.
        edge = [p(o0, 0.0075, sill + 1), p(o1, 0.0075, sill + 1), p(o1, 0.0075, top - 1.5), p(o0, 0.0075, top - 1.5)]
        draw.line(edge + [edge[0]], fill=shade(B.CHAMBER_DARK, 1.2), width=SS)
        ledges = (sill + 12, top - 16)
        for z0 in ledges:
            draw.polygon(quad(o0, o1, 0.008, z0, z0 + 6), fill=shade(B.CHAMBER_WOOD, light * 0.82))
            nails(draw, [p(o0 + (o1 - o0) * f, 0.009, z0 + 3) for f in (0.12, 0.5, 0.88)], light)
        # The brace climbs from the hinge side's bottom ledge to the free side's top one.
        b = 0.05
        lo_u, hi_u = (hinge, free) if side < 0 else (hinge, free)
        sgn = 1 if free > hinge else -1
        draw.polygon([p(lo_u, 0.008, ledges[0] + 6), p(lo_u + sgn * b, 0.008, ledges[0] + 6),
                      p(hi_u, 0.008, ledges[1]), p(hi_u - sgn * b, 0.008, ledges[1])], fill=shade(B.CHAMBER_WOOD, light * 0.86))
        # Strap hinges from the outer edge, a pintle on the post.
        for z0 in (ledges[0] + 1, ledges[1] + 1):
            reach = hinge + sgn * 0.26
            draw.polygon([p(hinge - sgn * 0.02, 0.011, z0), p(reach, 0.011, z0 + 1), p(reach, 0.011, z0 + 3), p(hinge - sgn * 0.02, 0.011, z0 + 4)],
                         fill=shade(B.CHAMBER_IRON, 1.0))
            nails(draw, [p(hinge + sgn * f, 0.012, z0 + 2) for f in (0.07, 0.18)], 0.5)
        # A ring pull by the middle.
        x, y = p(free - sgn * 0.06, 0.012, top * 0.5)
        r = 2.2 * SS
        draw.ellipse([x - 0.9 * SS, y - 0.9 * SS, x + 0.9 * SS, y + 0.9 * SS], fill=shade(B.CHAMBER_IRON, 0.8))
        draw.arc([x - r * 0.8, y, x + r * 0.8, y + r * 1.8], 0, 360, fill=shade(B.CHAMBER_IRON, 1.15), width=int(0.9 * SS))
    # Uneven cracks where the leaves meet and under the lintel.
    zs = [sill + 1 + (top - sill - 2) * k / 8 for k in range(9)]
    widths = [crack.uniform(0.006, 0.02) for _ in zs]
    draw.polygon([p(-w, 0.007, z) for z, w in zip(zs, widths)] + [p(w * 0.6, 0.007, z) for z, w in reversed(list(zip(zs, widths)))],
                 fill=shade(B.CHAMBER_DARK, 1))


def slope_ends(right):
    return (RIDGE_A, H + O) if right else (RIDGE_A, -1 - H - O)


def paint_slope(face, right):
    """One roof slope: boards running down it from the ridge, laid side by side along the shed, and the ridge board's
    half on this side."""
    _, _, left_light, right_light = lights(face)
    light = right_light if right else left_light
    layer = new_canvas()
    draw = ImageDraw.Draw(layer)
    ar, ae = slope_ends(right)
    roof = lambda u0, u1: [cpx(face, ar, u0, roof_z(ar)), cpx(face, ar, u1, roof_z(ar)), cpx(face, ae, u1, roof_z(ae)), cpx(face, ae, u0, roof_z(ae))]
    B.chamber_planks(draw, random.Random(340 + 2 * FACES(face) + right), roof, -1 - H - OG, H + OG, B.CHAMBER_PLANK, B.CHAMBER_ROOF, light)
    # The ridge board: a strip along the top, standing a little proud.
    rb = 0.07 if right else -0.07
    cap = lambda z: [cpx(face, ar, -1 - H - OG, roof_z(ar) + z), cpx(face, ar, H + OG, roof_z(ar) + z),
                     cpx(face, ar + rb, H + OG, roof_z(ar + rb) + z), cpx(face, ar + rb, -1 - H - OG, roof_z(ar + rb) + z)]
    draw.polygon(cap(2), fill=shade(B.CHAMBER_EDGE, light * 1.05))
    draw.line([cpx(face, ar + rb, -1 - H - OG, roof_z(ar + rb) + 2), cpx(face, ar + rb, H + OG, roof_z(ar + rb) + 2)],
              fill=shade(B.CHAMBER_DARK, 1.4), width=SS)
    return layer


def paint_trim(face):
    """The barge boards up the gable's edge and the fascia along the eave in view."""
    door_light, side_light, _, _ = lights(face)
    gable = new_canvas()
    draw = ImageDraw.Draw(gable)
    f = H + OG
    for ae in (-1 - H - O, H + O):
        draw.polygon([cpx(face, RIDGE_A, f, roof_z(RIDGE_A) + 1), cpx(face, ae, f, roof_z(ae) + 1),
                      cpx(face, ae, f, roof_z(ae) - 5), cpx(face, RIDGE_A, f, roof_z(RIDGE_A) - 5)], fill=shade(B.CHAMBER_EDGE, door_light * 0.9))
    eave = new_canvas()
    draw = ImageDraw.Draw(eave)
    a, z = H + O, roof_z(H + O)
    draw.polygon([cpx(face, a, -1 - H - OG, z), cpx(face, a, f, z), cpx(face, a, f, z - 5), cpx(face, a, -1 - H - OG, z - 5)],
                 fill=shade(B.CHAMBER_EDGE, side_light * 0.9))
    return gable, eave


def FACES(face):
    """A facing's number, for the seeds."""
    return B.FACES.index(face)


# --- Cutting the tiles -----------------------------------------------------------------------------------------

def spans(col, row):
    """The tile's footprint in shed a and b, the left and back ones running JOIN under their neighbours."""
    a = (-3, RIDGE_A + JOIN) if col == 0 else (RIDGE_A, 3)
    b = (-1.5 + JOIN, ) if False else ((-3, -0.5 + JOIN) if row == 0 else (-0.5, 3))
    return a, b


def masks(face, col, row):
    """Each surface's mask for this tile, in draw order: (surface name, polygon on the canvas) or None."""
    (a0, a1), (b0, b1) = spans(col, row)
    out = []
    wall = lambda pts: [cpx(face, a, b, z) for a, b, z in pts]
    if col == 1:
        out.append(("side", wall([(H, b0, -20), (H, b1, -20), (H, b1, 400), (H, b0, 400)])))
    if row == 1:
        out.append(("gable", wall([(a0, H, -20), (a1, H, -20), (a1, H, 400), (a0, H, 400)])))
    for right in (False, True):
        ar, ae = slope_ends(right)
        lo, hi = (min(ar, ae), max(ar, ae))
        lo, hi = max(lo, a0), min(hi, a1)
        if lo >= hi:
            continue
        out.append(("right" if right else "left",
                    [cpx(face, lo, b0, roof_z(lo)), cpx(face, lo, b1, roof_z(lo)), cpx(face, hi, b1, roof_z(hi)), cpx(face, hi, b0, roof_z(hi))]))
    if col == 1:
        out.append(("eave", wall([(H + O, b0, -20), (H + O, b1, -20), (H + O, b1, 400), (H + O, b0, 400)])))
    if row == 1:
        out.append(("barge", wall([(a0, H + OG, -20), (a1, H + OG, -20), (a1, H + OG, 400), (a0, H + OG, 400)])))
    return out


def tile_offset(face, col, row):
    """The tile's corner on the 1x canvas."""
    x, y = world(face, col - 1, row - 1)
    return ORIGIN[0] + round((x - y) * HW), ORIGIN[1] + round((x + y) * HH)


def paint_shed(face):
    """The four tiles of a facing: {(col, row): tile}."""
    surfaces = {"side": paint_side(face), "gable": paint_gable(face), "left": paint_slope(face, False),
                "right": paint_slope(face, True)}
    surfaces["barge"], surfaces["eave"] = paint_trim(face)
    small = {}
    for n, (name, layer) in enumerate(surfaces.items()):
        layer = layer.resize(CANVAS, Image.LANCZOS)
        streaks = name in ("side", "gable")
        small[name] = pzart.weather(layer, random.Random(370 + 10 * FACES(face) + n), B.CHAMBER_WEATHER, streaks).convert("RGBA")
    tiles = {}
    for col in (0, 1):
        for row in (0, 1):
            ox, oy = tile_offset(face, col, row)
            tile = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
            for name, poly in masks(face, col, row):
                mask = Image.new("L", (CANVAS[0] * SS, CANVAS[1] * SS), 0)
                ImageDraw.Draw(mask).polygon(poly, fill=255)
                mask = mask.resize(CANVAS, Image.LANCZOS)
                piece = small[name].copy()
                alpha = np.minimum(np.asarray(piece.getchannel("A")), np.asarray(mask))
                piece.putalpha(Image.fromarray(alpha.astype(np.uint8), "L"))
                tile.alpha_composite(piece)
            tiles[(col, row)] = pzart.hard_edges(tile.crop((ox, oy, ox + pzart.TILE_W, oy + pzart.TILE_H)))
    return tiles


def assemble(face, tiles, overlays=None):
    """The tiles put down as the game sorts them, on one image, each followed by its overlays (the build icon, previews)."""
    out = Image.new("RGBA", (pzart.TILE_W * 3, pzart.TILE_H + 70), (0, 0, 0, 0))
    order = sorted(tiles, key=lambda cr: (sum(world(face, cr[0], cr[1])), world(face, cr[0], cr[1])[0]))
    for cr in order:
        x, y = world(face, cr[0] - 1, cr[1] - 1)
        px, py = pzart.TILE_W + round((x - y) * HW), 64 + round((x + y) * HH)
        out.alpha_composite(tiles[cr], (px, py))
        for over in (overlays or {}).get(cr, []):
            out.alpha_composite(over, (px, py))
    return out


# --- The hanging pieces ---------------------------------------------------------------------------------------
# One for the first finished stack or two, another for every two more, at most three: a country ham, a smoked chicken
# and a smoked rabbit, each on a cord from a nail on the door's end, inside the wall's ends (no overhang). They stand on
# the front row's tiles, so each is drawn in that tile's own coordinates (a across it, b = H the wall).
PIECE_TOP = 98                # px up to where each hangs from its cord
HANG = {"ham": (0, B.HAM_A), "chicken": (1, 0.2), "rabbit": (1, 0.39)}   # the front row tile (column) and a on it
CHICKEN_TONES = [(84, 40, 20), (116, 58, 26), (148, 82, 36), (178, 110, 50), (206, 142, 72)]
RABBIT_TONES = [(62, 32, 22), (86, 46, 30), (110, 62, 38), (134, 82, 50), (158, 104, 66)]


def paint_ham(face):
    """The country ham: build_tileset's, on the front-left tile (HAM_A)."""
    return B.paint_chamber_ham(face)


CHICKEN_SCALE = 0.85


def scaled(shape, k, a, t, face):
    """A shape shrunk by k about the cord's foot (da 0, z t)."""
    if shape[0] == "ellipse":
        _, da, z, rw, rh = shape
        return ("ellipse", da * k, t - (t - z) * k, rw * k, rh * k)
    # Polygons were built through px: go back to (da, z) by solving on the wall's plane.
    return ("poly", [shrink_point(pt, k, a, t, face) for pt in shape[1]])


def shrink_point(pt, k, a, t, face):
    x0, y0 = B.chamber_px(face, 1, a, H + 0.012, t)
    return (x0 + (pt[0] - x0) * k, y0 + (pt[1] - y0) * k)


def paint_piece(face, kind):
    """A smoked chicken hung by its feet (drumsticks up, the plump body, wings tucked, the neck's stub below) or a smoked
    rabbit hung by its hind legs (the legs, the body, the forelegs and head below), painted as the ham is: a few flat
    tones in patches, rounded (lit a third of the way across from the upper left), a gloss on the smoked skin and a
    dark line round it."""
    a = HANG[kind][1]
    light = 1.0 if face == "S" else 0.78

    def px(da, z, out=0.012):
        return B.chamber_px(face, 1, a + da, H + out, z)

    shapes = []          # ("poly", points) or ("ellipse", da, z, half width in tiles, half height px)
    t = PIECE_TOP
    if kind == "chicken":
        tones = CHICKEN_TONES
        # Drumsticks in a V from the cord, the knuckles at the top, the thighs meeting the body.
        for side in (-1, 1):
            shapes.append(("poly", [px(side * 0.018, t), px(side * 0.04, t), px(side * 0.085, t - 16), px(side * 0.02, t - 16)]))
            shapes.append(("ellipse", side * 0.052, t - 16, 0.042, 6))
        # The body, fullest at the thighs and tapering to the breast's point, then the neck's stub.
        body = [(0.1, 16), (0.108, 20), (0.104, 26), (0.088, 32), (0.06, 37), (0.03, 40)]
        shapes.append(("poly", [px(-w, t - z) for w, z in body] + [px(w, t - z) for w, z in reversed(body)]))
        for side in (-1, 1):
            shapes.append(("ellipse", side * 0.098, t - 29, 0.03, 8))
        shapes.append(("ellipse", 0, t - 42, 0.024, 4))
    else:
        tones = RABBIT_TONES
        # Hind legs from the cord, the haunches, the body, the forelegs folded and the head.
        for side in (-1, 1):
            shapes.append(("poly", [px(side * 0.012, t), px(side * 0.03, t), px(side * 0.04, t - 13), px(side * 0.008, t - 13)]))
        body = [(0.054, 13), (0.064, 18), (0.06, 25), (0.05, 32), (0.036, 37)]
        shapes.append(("poly", [px(-w, t - z) for w, z in body] + [px(w, t - z) for w, z in reversed(body)]))
        for side in (-1, 1):
            shapes.append(("poly", [px(side * 0.02, t - 33), px(side * 0.044, t - 33), px(side * 0.036, t - 41), px(side * 0.018, t - 41)]))
        shapes.append(("ellipse", 0, t - 41, 0.032, 5.5))
        for side in (-1, 1):
            shapes.append(("ellipse", side * 0.014, t - 47, 0.009, 3.5))

    if kind == "chicken":
        # 15% smaller than first drawn (user): about two thirds of the ham, as a bird beside a country ham.
        k = CHICKEN_SCALE
        shapes = [scaled(shape, k, a, t, face) for shape in shapes]

    def mask(only=None):
        layer = Image.new("L", (pzart.TILE_W * SS, pzart.TILE_H * SS), 0)
        d = ImageDraw.Draw(layer)
        for n, shape in enumerate(shapes):
            if only is not None and n not in only:
                continue
            if shape[0] == "poly":
                d.polygon(shape[1], fill=255)
            else:
                _, da, z, rw, rh = shape
                d.polygon([px(da + rw * math.cos(k / 24 * math.pi), z + rh * math.sin(k / 24 * math.pi)) for k in range(48)], fill=255)
        return layer.resize((pzart.TILE_W, pzart.TILE_H), Image.LANCZOS).point(lambda v: 255 if v >= 128 else 0)

    body = mask()
    box = body.getbbox()
    rng = random.Random(390 + 2 * FACES(face) + (kind == "rabbit"))
    noise = Image.blend(pzart.soft_noise(rng, (pzart.TILE_W, pzart.TILE_H), 3, 3), pzart.soft_noise(rng, (pzart.TILE_W, pzart.TILE_H), 1, 2), 0.45).load()
    tile = Image.new("RGBA", (pzart.TILE_W, pzart.TILE_H), (0, 0, 0, 0))
    out, body_px = tile.load(), body.load()
    for y in range(box[1], box[3]):
        row = [x for x in range(box[0], box[2]) if body_px[x, y]]
        if not row:
            continue
        left, right = row[0], row[-1]
        for x in row:
            across = (x - left) / max(right - left, 1)
            down = (y - box[1]) / (box[3] - box[1])
            # Round: lit a third of the way across from the left, falling away to a dark far edge.
            lit = max(0.0, 1 - abs(across - 0.3) * 1.45)
            level = 0.1 + 0.8 * lit - down * 0.12 + (noise[x, y] / 255 - 0.5) * 0.35
            colour = B.ham_tone(tones, level)
            if lit > 0.93 and noise[x, y] > 150:
                colour = shade(tones[-1], 1.18)          # the smoked skin's gloss
            out[x, y] = tuple(shade(colour, light))[:3] + (255,)
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            if body_px[x, y] and any(not (0 <= nx < pzart.TILE_W and 0 <= ny < pzart.TILE_H) or not body_px[nx, ny]
                                     for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                out[x, y] = tuple(shade(B.HAM_LINE, light))[:3] + (255,)
    # The cord from a nail, round the feet.
    over = pzart.new_layer(SS)
    draw = ImageDraw.Draw(over)
    nail = t + 9
    spread = 0.03 if kind == "chicken" else 0.022
    for side in (-1, 1):
        draw.line([px(0, nail), px(side * spread, t + 1)], fill=shade(B.HAM_CORD, light), width=SS)
    x, y = px(0, nail)
    draw.ellipse([x - 1.2 * SS, y - 1.2 * SS, x + 1.2 * SS, y + 1.2 * SS], fill=shade(B.CHAMBER_IRON, 1.0))
    tile.alpha_composite(pzart.hard_edges(pzart.shrink(over).convert("RGBA")))
    return tile


SMOKE = (196, 198, 202)


def paint_smoke(face, kind):
    """Wood smoke out of the vent while a joined Stone Hearth burns: stoked, a full plume curling up past the ridge;
    banked, a thin wisp. Soft, as the cauldron's steam. Painted on the canvas and split between the front row's two
    tiles at the vent's middle: {(col, 1): tile}."""
    vh, vz0, vz1 = VENT
    layer = new_canvas()
    draw = ImageDraw.Draw(layer)
    rng = random.Random(400 + FACES(face) * 2 + (kind == "Banked"))
    plumes = ((-0.06, 84, 0.0), (0.03, 100, 1.9), (0.12, 76, 3.3), (0.0, 64, 5.0)) if kind == "Lit" else ((-0.03, 56, 0.8), (0.05, 44, 2.6))
    strength = 210 if kind == "Lit" else 140
    for da, height, phase in plumes:
        for i in range(40):
            t = i / 39
            # Out of the louvre's face, then up, drifting a little and widening.
            # Leaning towards the long side in view: the front-right tile's image, drawn after the other three.
            a = RIDGE_A + da + 0.4 * t ** 1.3 + 0.07 * math.sin(phase + t * 4) * t
            out = 0.03 + 0.08 * min(t * 3, 1)
            x, y = cpx(face, a, H + out, vz0 + (vz1 - vz0) * 0.6 + height * t)
            r = (3.2 + 9 * t) * SS * (1.0 if kind == "Lit" else 0.65)
            draw.ellipse([x - r, y - r * 0.8, x + r, y + r * 0.8], fill=SMOKE + (int(strength * (1 - t) ** 1.1),))
    layer = layer.filter(ImageFilter.GaussianBlur(1.5 * SS)).resize(CANVAS, Image.LANCZOS)
    # The front-right tile is drawn last of the four, so it carries every part of the plume its image reaches (over
    # its own roof); the front-left tile carries the rest.
    out, left = {}, layer
    for col in (1, 0):
        ox, oy = tile_offset(face, col, 1)
        box = (ox, oy, ox + pzart.TILE_W, oy + pzart.TILE_H)
        out[(col, 1)] = left.crop(box)
        rest = left.copy()
        rest.paste((0, 0, 0, 0), box)
        left = rest
    return out


def cast_shadow(face, tile):
    """The piece's shadow on the boards behind it, down and to the right of it as the light comes from the upper left:
    the wall's wood in shade, solid (a faint edge would leave a ring in B42's depth), under the piece."""
    light = lights(face)[0]
    alpha = tile.getchannel("A")
    shadow = Image.new("RGBA", tile.size, tuple(shade(B.CHAMBER_WOOD, light * 0.42)))
    shifted = Image.new("L", tile.size, 0)
    shifted.paste(alpha, (2, 2))
    shadow.putalpha(shifted)
    out = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    out.alpha_composite(shadow)
    out.alpha_composite(tile)
    return out


def paint_pieces(face):
    """The three hanging pieces of a facing, in the order they appear (B.CHAMBER_PIECE_KINDS), each with its shadow."""
    painted = {"ham": paint_ham(face), "chicken": paint_piece(face, "chicken"), "rabbit": paint_piece(face, "rabbit")}
    return [cast_shadow(face, painted[kind]) for kind in B.CHAMBER_PIECE_KINDS]
