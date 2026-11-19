"""The Drying Cloth: a Sheet spread on the floor, one corner turned up, two Stones holding the other corners down.

Core's build_tileset.py paints the cloth itself (paint_cloth). What lies on it is each mod's: a mod's own tileset draws
its lots at lot_spot(face, lot), the five spots of a die, so they sit on Core's cloth (Yeast's cakes, Dairy's kefir
grains). Approved preview: WIP/TPCore/art/drying_cloth_mock.png.
"""
import random

from PIL import Image, ImageDraw, ImageFilter

import pzart

CLOTH_HALF = 0.42             # the cloth's half size, in tiles
FOLD = 0.15                   # how far back the turned-up corner reaches, in tiles
LINEN = (226, 220, 204)
LINEN_SHADE = (196, 188, 170)
LINEN_UNDER = (188, 178, 156)  # the turned-up corner's underside
HEM = (182, 172, 150)
STONE = (128, 126, 120)
STONE_LIGHT = (168, 166, 158)
STONE_DARK = (88, 86, 82)
# By face: the corners the stones hold and the corner turned up, as signs of x and y.
STONE_CORNERS = {"S": [(-1, 1), (1, -1)], "E": [(-1, -1), (1, 1)]}
FOLDED_CORNER = {"S": (1, 1), "E": (1, -1)}
# Five lots, as a die's five: four towards the corners, one in the middle (in tiles from the cloth's middle).
LOTS = [(-0.23, -0.23), (0.23, -0.23), (0.0, 0.0), (-0.23, 0.23), (0.23, 0.23)]


def point(x, y, z, ss):
    cx, cy = pzart.project(x, y, z)
    return cx * ss, cy * ss


def lot_spot(lot):
    """Where lot (0 to 4) lies, in tiles from the cloth's middle. The same on either face: the die's five is symmetric."""
    return LOTS[lot]


def outline(face):
    """The cloth's corners, in tiles, with the turned-up one cut off (two points where the fold starts)."""
    h = CLOTH_HALF
    fx, fy = FOLDED_CORNER[face]
    corners = []
    for sx, sy in [(-1, -1), (1, -1), (1, 1), (-1, 1)]:
        if (sx, sy) == (fx, fy):
            corners.append((sx * h, sy * (h - FOLD)) if sx == 1 and sy == 1 else (sx * (h - FOLD), sy * h))
            corners.append((sx * (h - FOLD), sy * h) if sx == 1 and sy == 1 else (sx * h, sy * (h - FOLD)))
        else:
            corners.append((sx * h, sy * h))
    return corners


def paint_cloth(face, ss=8, seed=3):
    rng = random.Random(seed)
    layer = pzart.new_layer(ss)
    d = ImageDraw.Draw(layer)
    h = CLOTH_HALF
    corners = [point(x, y, 0, ss) for x, y in outline(face)]
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon([(x + 2 * ss, y + ss) for x, y in corners], fill=(20, 16, 10, 70))
    layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(ss)))
    d.polygon(corners, fill=LINEN + (255,))
    inner = h - 0.03
    d.polygon([point(-inner, -inner, 0, ss), point(inner, -inner, 0, ss), point(inner, inner, 0, ss), point(-inner, inner, 0, ss)],
              outline=HEM + (255,), width=ss)
    # Soft folds across the cloth, kept inside it.
    folds = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(folds)
    for _ in range(4):
        t = rng.uniform(-h * 0.8, h * 0.8)
        fd.line([point(-h, t, 0, ss), point(h, t + rng.uniform(-0.05, 0.05), 0, ss)], fill=LINEN_SHADE + (120,), width=2 * ss)
    folds = folds.filter(ImageFilter.GaussianBlur(1.5 * ss))
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).polygon(corners, fill=255)
    clipped = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    clipped.paste(folds, (0, 0), mask)
    layer.alpha_composite(clipped)
    # Wipe the hem where the corner is turned up, then the corner itself, lying back over the cloth, a little raised.
    fx, fy = FOLDED_CORNER[face]
    a = (fx * h, fy * (h - FOLD))
    b = (fx * (h - FOLD), fy * h)
    tip = (fx * (h - FOLD * 1.5), fy * (h - FOLD * 1.5))
    d.polygon([point(*a, 1, ss), point(*b, 1, ss), point(*tip, 2.5, ss)], fill=LINEN_UNDER + (255,))
    d.line([point(*a, 1, ss), point(*b, 1, ss)], fill=LINEN_SHADE + (255,), width=ss)
    paint_stones(layer, face, ss)
    return pzart.shrink(layer)


def paint_stones(layer, face, ss):
    d = ImageDraw.Draw(layer)
    h = CLOTH_HALF - 0.04
    for sx, sy in STONE_CORNERS[face]:
        cx, cy = point(sx * h, sy * h, 2, ss)
        rx, ry = 4.5 * ss, 3.0 * ss
        d.ellipse([cx - rx + ss, cy - ry + 2 * ss, cx + rx + ss, cy + ry + 2 * ss], fill=(20, 16, 10, 90))
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=STONE_DARK + (255,))
        d.ellipse([cx - rx + ss, cy - ry, cx + rx - ss * 0.5, cy + ry - ss], fill=STONE + (255,))
        d.ellipse([cx - rx * 0.5, cy - ry * 0.8, cx + rx * 0.1, cy - ry * 0.1], fill=STONE_LIGHT + (255,))
