#!/usr/bin/env python3
"""Builds the TP Core art: the shared stations' tileset (42/media/*.tiles and texturepacks/*.pack), their build icons,
the mod icon and the generated Tiles.lua.

The Hearth: a low stone oven with a copper set into its top, which the game turns into a vanilla fireplace when it is
built. Vanilla draws the fireplace's flames and fuel as attached sprites, so the hearth gets no overlays: HearthWorld
swaps its own sprite among whole-hearth tiles, the copper empty, full or steaming (HEARTH_LOOKS), and every one of
them carries the fireplace's tile properties. Painted as it was in Dairy, where it began.

Usage: python3 tools/build_tileset.py [contact-sheet.png]
Needs Pillow. Deterministic: a rerun with no change gives byte-identical files.
"""
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

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
SQUASH = 0.5

# Facings, S and E, as the entity scripts' faces. Each look takes len(FACES) tiles from its number.
FACES = ["S", "E"]
HEARTH_LOOKS = {"Empty": 0, "Full": 2, "Hot": 4}
HEARTH = HEARTH_LOOKS["Empty"]

# Colours.
STONE = (132, 122, 110)
COPPER = (168, 96, 56)
MILK = (226, 220, 200)
FIREBOX = (26, 18, 14, 255)
STEAM = (240, 240, 240)
WEATHER = 0.22

# The hearth: a stone block most of a tile across, the copper standing proud of its top, the firebox mouth on the
# side it faces.
OVEN_H = 30                    # pixels high
OVEN_HALF = 0.42               # half the footprint, in tiles
COPPER_R, COPPER_UP = 21, 9    # the copper's radius across and how far it stands above the stone

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


def paint_oven(draw, facing):
    h, half = OVEN_H, OVEN_HALF
    draw.polygon([tile_px(-half, half), tile_px(half, half), tile_px(half, half, h), tile_px(-half, half, h)],
                 fill=shade(STONE, 0.95))
    draw.polygon([tile_px(half, -half), tile_px(half, half), tile_px(half, half, h), tile_px(half, -half, h)],
                 fill=shade(STONE, 0.7))
    draw.polygon([tile_px(-half, -half, h), tile_px(half, -half, h), tile_px(half, half, h), tile_px(-half, half, h)],
                 fill=shade(STONE, 1.15))
    # The firebox mouth: front left facing S, front right facing E.
    if facing == "S":
        mouth = [tile_px(-0.2, half, 2), tile_px(0.2, half, 2), tile_px(0.2, half, 16), tile_px(-0.2, half, 16)]
    else:
        mouth = [tile_px(half, -0.2, 2), tile_px(half, 0.2, 2), tile_px(half, 0.2, 16), tile_px(half, -0.2, 16)]
    draw.polygon(mouth, fill=FIREBOX)


def paint_copper(draw, look):
    bx, by = pzart.project(0, 0, OVEN_H)
    rx, ry = COPPER_R, COPPER_R * SQUASH
    draw.ellipse(box(bx, by, rx, ry), fill=shade(COPPER, 0.6))
    draw.rectangle([(bx - rx) * SS, (by - COPPER_UP) * SS, (bx + rx) * SS, by * SS], fill=shade(COPPER, 0.85))
    draw.rectangle([(bx - rx) * SS, (by - COPPER_UP) * SS, (bx - rx / 3) * SS, by * SS], fill=shade(COPPER, 1.05))
    cx, cy = pzart.project(0, 0, OVEN_H + COPPER_UP)
    draw.ellipse(box(cx, cy, rx, ry), fill=shade(COPPER, 1.2))
    draw.ellipse(box(cx, cy, rx - 2, ry - 1), fill=FIREBOX)
    if look == "Empty":
        return
    draw.ellipse(box(cx, cy + 1.5, rx - 3, ry - 2), fill=MILK + (255,))
    if look == "Hot":
        for dx, height in ((-8, 22), (2, 30), (10, 18)):
            for i in range(10):
                t = i / 9
                x = cx + dx + 3 * ((i % 4) - 1.5) * t
                draw.ellipse(box(x, cy - 2 - height * t, 2.5 + 2 * t, 2 + 1.5 * t), fill=STEAM + (int(110 * (1 - t)),))


def paint_hearth(look, face):
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    paint_oven(draw, FACES[face])
    paint_copper(draw, look)
    return pzart.weather(shrink(layer), random.Random(60 + face), WEATHER)


def lua_tiles():
    prefix = TILESET + "_"
    return {
        "PREFIX": prefix,
        "SHEETS": [{"prefix": prefix, "tiles": COLUMNS * ROWS}],
        "FACE_COUNT": len(FACES),
        "HEARTH_LOOKS": HEARTH_LOOKS,
        "HEARTHS": [prefix + str(base + offset) for base in HEARTH_LOOKS.values() for offset in range(len(FACES))],
    }


def contact_sheet(tiles, path):
    """Every hearth tile in a row, for checking the art by eye; kept out of the mod."""
    indexes = [index + face for index in HEARTH_LOOKS.values() for face in range(len(FACES))]
    sheet = Image.new("RGBA", (TILE_W * len(indexes), TILE_H), (96, 110, 88, 255))
    for x, index in enumerate(indexes):
        sheet.alpha_composite(tiles[index], (x * TILE_W, 0))
    sheet.save(path)


def main():
    media = Path(__file__).resolve().parent.parent / "42" / "media"
    pzart.write_lua_tiles(media, MOD, lua_tiles(), "tools/build_tileset.py")
    tiles = {}
    for face in range(len(FACES)):
        for look, index in HEARTH_LOOKS.items():
            tiles[index + face] = paint_hearth(look, face)
    (media / "texturepacks").mkdir(parents=True, exist_ok=True)
    pzart.write_pack(media / "texturepacks" / f"{NAME}.pack", tiles, NAME, TILESET, PAGE_SIZE)
    pzart.write_tiles(media / f"{NAME}.tiles", [(TILESET, COLUMNS, ROWS)], TILE_PROPS)
    (media / "textures").mkdir(parents=True, exist_ok=True)
    pzart.write_build_icon(tiles[HEARTH], media / "textures" / "Item_TPHearth.png")
    # The mod list shows the copper steaming.
    pzart.write_mod_icon(tiles[HEARTH_LOOKS["Hot"]], media.parent / "icon.png")
    if len(sys.argv) > 1:
        contact_sheet(tiles, sys.argv[1])
    print(f"wrote {NAME}.pack and {NAME}.tiles to {media}")


if __name__ == "__main__":
    main()
