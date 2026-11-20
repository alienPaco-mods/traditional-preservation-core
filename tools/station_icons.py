"""The stations' icons for an info window's Station block (user, session 66): white outlines of our own in the place
icons' style (tools/place_icons.py), drawn at 128 px and shrunk to the 64 px the block draws them at. Info windows
only: menus keep the stations' item icons (user). Approved preview: WIP/TPCore/art/station_icons_mock.png.
Each shape follows its station's item icon. Each icon goes in the mod whose station it is, as
42/media/textures/TPStation_<Name>.png.

Usage: python3 tools/station_icons.py    (writes every mod's icons; a mod not beside this one is skipped)
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

S, LW = 128, 6
INK = (255, 255, 255, 255)


def blank():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def ln(d, pts, w=LW):
    d.line(pts, fill=INK, width=w, joint="curve")


def ring(d, box, w=LW):
    d.ellipse(box, outline=INK, width=w)


def fish(d, x, top, length=34, w=LW - 2):
    """A fish hung by its tail from top, head down: the forked tail, a slim oval body narrowing to the tail."""
    half = length * 0.2
    tail = length * 0.22
    ln(d, [(x - half * 0.7, top), (x, top + tail), (x + half * 0.7, top)], w)          # the tail's fork
    pts = []
    for i in range(41):                                                              # the body, widest near the head
        t = i / 40 * math.pi
        y = top + tail + (length - tail) * (1 - math.cos(t)) / 2
        width = half * math.sin(t) ** 0.8 * (0.55 + 0.45 * (y - top - tail) / (length - tail))
        pts.append((x + width, y))
    ln(d, [(x, top + tail)] + pts + [(x - px + x, py) for px, py in reversed(pts)], w)


def stave_barrel(d, x0, y0, x1, y1, hoops, bulge=6):
    """A standing barrel: bulging sides, an elliptical mouth, hoops across."""
    mid = (y0 + y1) / 2
    left = [(x0 + bulge, y0), (x0, mid), (x0 + bulge, y1)]
    right = [(x1 - bulge, y0), (x1, mid), (x1 - bulge, y1)]
    ln(d, left)
    ln(d, right)
    ring(d, [x0 + bulge, y0 - 8, x1 - bulge, y0 + 8])
    d.arc([x0 + bulge, y1 - 8, x1 - bulge, y1 + 8], 0, 180, fill=INK, width=LW)
    for hy in hoops:
        t = abs(hy - mid) / (mid - y0)
        inset = bulge * t
        d.arc([x0 + inset, hy - 7, x1 - inset, hy + 7], 0, 180, fill=INK, width=LW - 2)


def drying_cloth():
    img, d = blank()
    ln(d, [(4, 100), (44, 40), (124, 40), (84, 100), (4, 100)])        # the cloth, laid flat
    for x, y in ((6, 100), (122, 40)):                                    # its weights at two corners
        d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=INK)
    for cx, cy in ((40, 84), (58, 70), (76, 56), (66, 88), (84, 74), (102, 58)):   # lots drying on it
        d.ellipse([cx - 8, cy - 5, cx + 8, cy + 5], outline=INK, width=LW - 2)
    return img


def stone_hearth():
    img, d = blank()
    d.rectangle([16, 44, 112, 116], outline=INK, width=LW)                # the stone block
    for y in (68, 92):                                                    # its courses
        ln(d, [(16, y), (112, y)], LW - 2)
    for x, y0, y1 in ((48, 44, 68), (80, 44, 68), (36, 68, 92), (92, 68, 92)):
        ln(d, [(x, y0), (x, y1)], LW - 2)
    d.chord([46, 86, 82, 122], 180, 360, fill=(0, 0, 0, 0), outline=INK, width=LW)   # the firebox's arch
    d.rectangle([46, 104, 82, 116], fill=(0, 0, 0, 0))
    ring(d, [44, 30, 84, 44], LW - 1)                                     # the hole on top
    pts = [(64 + 6 * math.sin((30 - y) / 6), y) for y in range(28, 6, -1)]   # smoke from it
    ln(d, pts, LW - 2)
    return img


def smokehouse():
    img, d = blank()
    ln(d, [(10, 54), (64, 16), (118, 54)])                                # the roof
    d.rectangle([20, 48, 108, 118], outline=INK, width=LW)                # the shed
    for x in (42, 86):                                                    # planks
        ln(d, [(x, 54), (x, 118)], LW - 3)
    d.rectangle([50, 70, 78, 118], outline=INK, width=LW - 1)             # the door, open
    ln(d, [(64, 70), (64, 78)], LW - 3)                                    # a ham hanging in it
    ham = []
    for i in range(41):
        a = i / 40 * 2 * math.pi
        y = 95 - 17 * math.cos(a)
        ham.append((64 + (3 + 6 * ((y - 78) / 34) ** 0.7) * math.sin(a), y))
    ln(d, ham, LW - 3)
    ln(d, [(84, 30), (84, 14), (94, 14), (94, 37)], LW - 1)               # a vent on the ridge
    pts = [(89 + 6 * math.sin((12 - y) / 5), y) for y in range(12, -2, -1)]
    ln(d, pts, LW - 2)
    return img


def salting_tub():
    img, d = blank()
    ln(d, [(18, 50), (30, 118), (98, 118), (110, 50)])                     # a tapered tub
    for y, inset in ((72, 4), (98, 8)):                                   # hoops
        ln(d, [(18 + inset, y), (110 - inset, y)], LW - 2)
    d.rectangle([8, 40, 120, 50], outline=INK, width=LW - 1)               # the plank across its mouth
    ln(d, [(34, 40), (38, 30), (54, 24), (78, 26), (92, 32), (96, 40)])     # the flat stone on it
    return img


def drying_frame():
    img, d = blank()
    for x in (18, 110):                                                   # A legs
        ln(d, [(x - 12, 124), (x, 10), (x + 12, 124)])
    for y in (14, 66):                                                    # two poles, a tier of fish on each
        ln(d, [(6, y), (122, y)])
        for x in (40, 64, 88):
            fish(d, x, y + 3, 40)
    return img


def hanging_beam():
    img, d = blank()
    for x in (14, 114):                                                   # two posts, a beam across
        ln(d, [(x, 12), (x, 124)])
    ln(d, [(4, 16), (124, 16)])
    for x, length in ((38, 50), (64, 56), (90, 50)):                      # middling fish
        fish(d, x, 18, length, LW - 1)
    return img


def gantry():
    img, d = blank()
    for x in (14, 114):                                                   # tall posts, braced
        ln(d, [(x, 8), (x, 124)])
    ln(d, [(4, 12), (124, 12)])
    ln(d, [(14, 36), (36, 12)], LW - 2)
    ln(d, [(114, 36), (92, 12)], LW - 2)
    ln(d, [(64, 12), (64, 30)], LW - 2)                                    # one heavy piece: a ham on a rope
    ham = []
    for i in range(61):                                                    # a pear: narrow at the knuckle
        a = i / 60 * 2 * math.pi
        y = 70 - 38 * math.cos(a)
        r = 8 + 20 * ((y - 32) / 76) ** 0.7
        ham.append((64 + r * math.sin(a), y))
    ln(d, ham)
    ln(d, [(58, 30), (70, 30)], LW - 1)                                    # its knuckle tied off
    ring(d, [56, 52, 72, 68], LW - 2)                                      # the bone's end
    return img


def pot(d, mouth_y=34):
    """A clay pot: a round belly, a narrow neck."""
    ln(d, [(44, mouth_y), (40, mouth_y + 12), (22, mouth_y + 36), (18, 82), (30, 112), (98, 112), (110, 82),
           (106, mouth_y + 36), (88, mouth_y + 12), (84, mouth_y)])


def yogurt_incubator():
    img, d = blank()
    pot(d, 40)
    ring(d, [38, 30, 90, 46])                                              # its lid
    d.ellipse([58, 22, 70, 32], fill=INK)                                  # the lid's knob
    for y in (66, 86):                                                    # a blanket wrapped round it
        pts = [(x, y + 5 * math.sin((x - 20) / 14)) for x in range(20, 110)]
        ln(d, pts, LW - 2)
    return img


def starter_crock():
    img, d = blank()
    pot(d, 30)
    ring(d, [42, 22, 86, 38])                                              # its open mouth
    zig = [(26 + i * 9.5, 74 if i % 2 == 0 else 62) for i in range(9)]    # the zigzag band
    ln(d, [(22, 58), (106, 58)], LW - 3)
    ln(d, zig, LW - 2)
    ln(d, [(20, 80), (108, 80)], LW - 3)
    return img


def kraut_barrel():
    img, d = blank()
    stave_barrel(d, 18, 34, 110, 118, (58, 96))
    ln(d, [(36, 34), (92, 34)], LW - 2)                                    # the lid's boards
    d.chord([48, 10, 80, 42], 180, 360, outline=INK, width=LW)            # the stone weight on it
    return img


def fermenting_shelf():
    img, d = blank()
    ln(d, [(4, 82), (124, 82)])                                            # the board
    ln(d, [(4, 90), (124, 90)], LW - 2)
    for x in (18, 110):                                                   # brackets
        ln(d, [(x, 90), (x, 118), (x + (14 if x < 64 else -14), 90)], LW - 2)
    for x, h in ((24, 40), (56, 46), (88, 40)):                           # three jars
        d.rounded_rectangle([x, 80 - h, x + 24, 80], 5, outline=INK, width=LW - 1)
        ln(d, [(x + 3, 80 - h + 8), (x + 21, 80 - h + 8)], LW - 3)        # a cloth tied over each mouth
    return img


def leaching_vat():
    img, d = blank()
    ln(d, [(14, 18), (114, 18), (76, 78), (52, 78), (14, 18)])            # the hopper of soil
    for y, x0, x1 in ((34, 24, 104), (52, 36, 92)):
        ln(d, [(x0, y), (x1, y)], LW - 3)
    for x0, x1 in ((14, 22), (114, 106)):                                 # legs
        ln(d, [(x0, 18), (x1, 124)], LW - 2)
    for y in (86, 96):                                                    # brine dripping
        d.ellipse([60, y, 68, y + 8], fill=INK)
    d.rectangle([44, 106, 84, 124], outline=INK, width=LW - 1)            # the tub catching it
    return img


def malting_floor():
    img, d = blank()
    ln(d, [(4, 90), (44, 44), (124, 44), (84, 90), (4, 90)])              # a shallow tray
    ln(d, [(4, 90), (4, 108), (84, 108), (124, 62), (124, 44)])
    ln(d, [(84, 90), (84, 108)])
    for cx, cy in ((40, 80), (64, 66), (88, 54)):                         # heaps of grain, sprouting
        d.chord([cx - 18, cy - 14, cx + 18, cy + 14], 180, 360, outline=INK, width=LW - 2)
        for dx in (-6, 6):
            ln(d, [(cx + dx, cy - 13), (cx + dx * 1.6, cy - 24)], 3)
    return img


def fermentation_vessel():
    img, d = blank()
    stave_barrel(d, 22, 30, 104, 118, (54, 94))
    ln(d, [(63, 22), (63, 10), (114, 10), (114, 60)], LW - 2)              # the hose from its lid
    d.rectangle([104, 60, 124, 80], outline=INK, width=LW - 2)            # the jar the air bubbles through
    ln(d, [(56, 104), (44, 104), (44, 112)], LW - 1)                       # the tap
    return img


def vinegar_cask():
    img, d = blank()
    # an Orleans cask lies on its side on a cradle: the round head facing, the bung hole on top, a hole for air
    ring(d, [8, 26, 58, 106])                                              # the head
    ln(d, [(33, 26), (110, 30)])                                           # its staves, bulging away
    ln(d, [(33, 106), (110, 102)])
    d.arc([92, 30, 126, 102], 270, 90, fill=INK, width=LW)                # the far head
    for x in (60, 88):                                                    # hoops
        d.arc([x - 8, 28, x + 8, 104], 270, 90, fill=INK, width=LW - 2)
    ring(d, [22, 56, 38, 72], LW - 2)                                      # the hole in the head the air comes in
    d.ellipse([66, 22, 78, 32], fill=INK)                                  # the bung
    ln(d, [(16, 122), (30, 104)], LW - 1)                                   # the cradle's chocks
    ln(d, [(110, 122), (96, 102)], LW - 1)
    ln(d, [(10, 122), (118, 122)], LW - 1)
    return img


# Each station: its icon's name, the mod it belongs to, and its drawing.
STATIONS = [
    ("DryingCloth", "Core", drying_cloth), ("StoneHearth", "Core", stone_hearth), ("Smokehouse", "Core", smokehouse),
    ("SaltingTub", "FishMeat", salting_tub), ("DryingFrame", "FishMeat", drying_frame),
    ("HangingBeam", "FishMeat", hanging_beam), ("Gantry", "FishMeat", gantry),
    ("YogurtIncubator", "Dairy", yogurt_incubator), ("StarterCultureCrock", "Dairy", starter_crock),
    ("KrautBarrel", "FruitVegetables", kraut_barrel), ("FermentingShelf", "Yeast", fermenting_shelf),
    ("LeachingVat", "Salt", leaching_vat), ("MaltingFloor", "Vinegar", malting_floor),
    ("FermentationVessel", "Vinegar", fermentation_vessel), ("OrleansVinegarCask", "Vinegar", vinegar_cask),
]
SIZE = 64


def main():
    mods = Path(__file__).resolve().parent.parent.parent
    for name, mod, draw in STATIONS:
        out = mods / f"TraditionalPreservation{mod}/42/media/textures"
        if not out.is_dir():
            print(f"skipped {name}: no {out}")
            continue
        path = out / f"TPStation_{name}.png"
        draw().resize((SIZE, SIZE), Image.LANCZOS).save(path)
        print(path)


if __name__ == "__main__":
    main()
