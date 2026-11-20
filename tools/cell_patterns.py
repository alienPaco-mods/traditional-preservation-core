"""The patterns an info window's cells are drawn in (user, session 65; approved preview:
WIP/TPCore/art/all_cells_mock.png, palette B darker): one texture a kind of thing held, drawn into each full cell in
place of a flat colour. Each is one family, a base with its marks a light and a dark tint of it, no shine, the same
contrast for all. Fish, meat and sausage share a dark tan, told apart by their marks (big scales, marbling, long links: small ones read as a mesh at game
size, user); wood is
vanilla's red-brown; one jar a cell, on its side. Built at 8x and shrunk to a cell inside a five-cell column (30 x 17).

Each texture goes in the mod whose window draws it: wood in Core (the Stone Hearth), the rest in their own mod.

Usage: python3 tools/cell_patterns.py    (writes <mod>/42/media/textures/TPCell_<Name>.png for every mod below)
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

MODS = Path(__file__).resolve().parents[2]
SS = 8
W, H = 30, 17   # inside a cell of Holds.lua's five-cell column (34 x 96)


def blank(base):
    img = Image.new("RGBA", (W * SS, H * SS), base + (255,))
    return img, ImageDraw.Draw(img)


def done(img):
    return img.resize((W, H), Image.LANCZOS)


def scales(base, scale, edge, r=5, rim=1.4):
    """Scalloped scales: discs in rows half a scale apart, the bottom row drawn first so each shows its lower half."""
    img, d = blank(base)
    w, h = img.size
    r = r * SS
    rows, y, row = [], -r, 0
    while y < h + r:
        rows.append((y, row))
        y += r * 0.95
        row += 1
    for y, row in reversed(rows):
        x = -r + (r if row % 2 else 0)
        while x < w + 2 * r:
            d.ellipse((x - r, y - r, x + r, y + r), fill=edge)
            d.ellipse((x - r + SS * rim, y - r + SS * 0.4, x + r - SS * rim, y + r - SS * rim), fill=scale)
            x += 2 * r
    return done(img)


def marbled(base, fat, light, dark, seed=4):
    """Meat marbled with fat: pale streaks and flecks (user: long fibres read as wood's grain at game size)."""
    img, d = blank(base)
    rng = random.Random(seed)
    w, h = img.size
    for _ in range(9):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        pts = []
        for _ in range(rng.randint(3, 6)):
            pts.append((x, y))
            x += rng.uniform(1.5, 4) * SS
            y += rng.uniform(-1.5, 1.5) * SS
        d.line(pts, fill=fat, width=int(SS * rng.uniform(0.6, 1.1)), joint="curve")
    for _ in range(18):
        x, y, r = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(0.4, 0.9) * SS
        d.ellipse((x - r, y - r, x + r, y + r), fill=rng.choice([fat, light, dark]))
    return done(img)


def links(base, skin, edge, link=18, rows=2):
    """Rows of long sausage links, every other row half a link along."""
    img, d = blank(base)
    w, h = img.size
    link, gap = link * SS, SS
    row_h = (h - gap * (rows + 1)) / rows
    for row in range(rows):
        y = gap + row * (row_h + gap)
        for x in range(int(-link + (link // 2 if row % 2 else 0)), w + link, link + gap):
            d.rounded_rectangle((x, y, x + link, y + row_h), radius=min(row_h, link) * 0.45, fill=skin, outline=edge,
                                width=SS)
    return done(img)


def wood(base, light, dark):
    """Plank grain along the cell with a knot."""
    img, d = blank(base)
    rng = random.Random(1)
    w, h = img.size
    y = 0
    while y < h:
        d.line([(x, y + math.sin(x / (9 * SS) + y) * SS * 0.8) for x in range(0, w + 1, SS)],
               fill=light if rng.random() < 0.5 else dark, width=SS)
        y += SS * rng.uniform(1.8, 2.8)
    d.ellipse((w * 0.6, h * 0.3, w * 0.6 + 4 * SS, h * 0.3 + 3 * SS), outline=dark, width=SS)
    return done(img)


def speckle(base, colours, seed=2, count=140):
    """Crumbs of soil, light and dark."""
    img, d = blank(base)
    rng = random.Random(seed)
    w, h = img.size
    for _ in range(count):
        x, y, r = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(0.4, 1.2) * SS
        d.ellipse((x - r, y - r, x + r, y + r), fill=rng.choice(colours))
    return done(img)


def kernels(base, kernel, crease, seed=3, count=26, rx=2.0, ry=1.1):
    """Grains lying every way."""
    img, d = blank(base)
    rng = random.Random(seed)
    w, h = img.size
    for _ in range(count):
        x, y, a = rng.uniform(-SS, w + SS), rng.uniform(-SS, h + SS), rng.uniform(0, math.pi)
        pts = [(x + math.cos(t) * rx * SS * math.cos(a) - math.sin(t) * ry * SS * math.sin(a),
                y + math.cos(t) * rx * SS * math.sin(a) + math.sin(t) * ry * SS * math.cos(a))
               for t in [i * math.pi / 8 for i in range(16)]]
        d.polygon(pts, fill=kernel, outline=crease)
    return done(img)


def jar(base, glass, lid, dark):
    """One jar a cell (each cell is a jar on the shelf), lying on its side: the body left, the lid right."""
    img, d = blank(base)
    w, h = img.size
    x0, x1, y0, y1 = SS * 3, w - SS * 7, SS * 2.5, h - SS * 2.5
    d.rounded_rectangle((x0, y0, x1, y1), radius=SS * 3, fill=glass, outline=dark, width=SS)
    d.rectangle((x1 - SS, y0 + SS * 1.5, x1 + SS * 3, y1 - SS * 1.5), fill=lid, outline=dark, width=SS)
    d.line([(x0 + (x1 - x0) * 0.55, y0 + SS * 1.5), (x0 + (x1 - x0) * 0.55, y1 - SS * 1.5)], fill=dark, width=SS)
    return done(img)


# The cakes as Yeast's Item_YeastCakes icon lays them (two behind, one in front), at twice its size and cut to the
# cell (user): each (x, y) centre in the cell, in px; ovals CAKE_RX x CAKE_RY. CAKE_SCALE grows them about the cell's
# middle (user: "a bit larger", they may overlap).
CAKE_LAYOUT = [(4, 4), (26, 4), (15, 11.5)]   # the back two high, the third laid on top of them (user)
CAKE_RX, CAKE_RY = 11, 8.5
CAKE_SCALE = 1.0


def cakes(base, cake, edge):
    """Yeast cakes in the item icon's layout at 2x (CAKE_SCALE grows it), the ends cut off by the cell, drawn as the series' patterns: the
    cake's tan, a rim and a cross cut in each in the border colour."""
    img, d = blank(base)
    rx, ry = CAKE_RX * CAKE_SCALE * SS, CAKE_RY * CAKE_SCALE * SS
    for x, y in CAKE_LAYOUT:
        cx, cy = (W / 2 + (x - W / 2) * CAKE_SCALE) * SS, (H / 2 + (y - H / 2) * CAKE_SCALE) * SS
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=cake, outline=edge, width=SS)
        arm = ry * 0.4
        d.line([(cx - arm, cy - arm), (cx + arm, cy + arm)], fill=edge, width=SS)
        d.line([(cx - arm, cy + arm), (cx + arm, cy - arm)], fill=edge, width=SS)
    return done(img)


def blobs(base, blob, edge, seed=5):
    """Lumpy grains, a few round lumps each."""
    img, d = blank(base)
    rng = random.Random(seed)
    w, h = img.size
    for _ in range(30):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        for _ in range(4):
            r = rng.uniform(1.0, 1.8) * SS
            ox, oy = rng.uniform(-1.4, 1.4) * SS, rng.uniform(-1.2, 1.2) * SS
            d.ellipse((x + ox - r, y + oy - r, x + ox + r, y + oy + r), fill=blob, outline=edge)
    return done(img)


def shred(base, strand, dark, seed):
    """Shredded leaves or root, short wavy strands."""
    img, d = blank(base)
    rng = random.Random(seed)
    w, h = img.size
    for _ in range(40):
        x, y = rng.uniform(-w * 0.2, w), rng.uniform(0, h)
        length, a = rng.uniform(5, 12) * SS, rng.uniform(-0.5, 0.5)
        pts = [(x + t * math.cos(a), y + t * math.sin(a) + math.sin(t / (2 * SS)) * SS * 0.6)
               for t in range(0, int(length), SS)]
        if len(pts) > 1:
            d.line(pts, fill=strand if rng.random() < 0.7 else dark, width=SS)
    return done(img)


# mod folder: { name: texture }
PATTERNS = {
    "TraditionalPreservationCore": {
        "Wood": lambda: wood((92, 48, 32), (112, 62, 42), (72, 36, 24)),
    },
    "TraditionalPreservationFishMeat": {
        "Fish": lambda: scales((100, 86, 66), (130, 114, 90), (96, 82, 62), r=9, rim=2.2),
        "Meat": lambda: marbled((116, 78, 66), (176, 150, 128), (142, 100, 88), (94, 60, 50)),
        "Sausage": lambda: links((92, 74, 56), (120, 96, 72), (82, 64, 48)),
    },
    "TraditionalPreservationSalt": {
        "Soil": lambda: speckle((80, 62, 46), [(98, 78, 58), (66, 50, 36)]),
    },
    "TraditionalPreservationVinegar": {
        "Malt": lambda: kernels((124, 100, 58), (148, 122, 76), (108, 86, 48)),
    },
    "TraditionalPreservationYeast": {
        "Jar": lambda: jar((70, 68, 58), (150, 144, 118), (110, 104, 84), (96, 92, 74)),
        "YeastCakes": lambda: cakes((122, 100, 64), (138, 114, 74), (110, 90, 58)),   # soft: sharp at game size (user)
    },
    "TraditionalPreservationDairy": {
        "KefirGrains": lambda: blobs((140, 136, 122), (170, 166, 150), (128, 124, 110)),
    },
    "TraditionalPreservationFruitVegetables": {
        "Cabbage": lambda: shred((112, 122, 78), (140, 150, 100), (96, 104, 64), 7),
        "Turnip": lambda: shred((138, 126, 138), (164, 154, 164), (116, 100, 118), 8),
    },
}


def main():
    for mod, patterns in PATTERNS.items():
        folder = MODS / mod / "42/media/textures"
        for name, make in patterns.items():
            out = folder / f"TPCell_{name}.png"
            make().save(out)
            print(out)


if __name__ == "__main__":
    main()
