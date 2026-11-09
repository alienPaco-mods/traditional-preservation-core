#!/usr/bin/env python3
"""Builds the __STATION__ tileset (42/media/*.tiles and texturepacks/*.pack), its icons and the generated Tiles.lua.

Made by `tp new`: the station is a placeholder crate. TEMPLATE: paint the real station (and any attached sprites
for its stages) here, with the helpers in _tpcore/tools/pzart.py; see the other mods' builders.

Usage: python3 tools/build_tileset.py
Needs Pillow. Deterministic: a rerun with no change gives byte-identical files.
"""
import os
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(os.environ.get("TPCORE", Path(__file__).resolve().parents[2] / "_tpcore")) / "tools"))
import pzart  # noqa: E402

MOD = "__MOD__"
NAME = "__LOWER__"
TILESET = NAME + "_01"
COLUMNS, ROWS = 8, 8
PAGE_SIZE = 512
SS = 8
SEED = 1

# Tile index -> facing. S and E, as the entity script's faces.
FACES = ["S", "E"]
GROUP, CUSTOM = "__GROUP__", "__CUSTOM__"

HALF = 0.36  # the crate's half width, in tiles
HEIGHT = 46  # pixels
WOOD = (150, 112, 70)
PLANKS = 4

TILE_PROPS = {}
for index, facing in enumerate(FACES):
    # The engine only links the facings of tiles with a GroupName, and that link lets a moved station rotate.
    TILE_PROPS[index] = [("BlocksPlacement", ""), ("CustomName", CUSTOM), ("Facing", facing), ("GroupName", GROUP),
                         ("IsMoveAble", ""), ("PickUpWeight", "100"), ("solidtrans", "")]


def corner(x, y, z=0.0):
    px, py = pzart.project(x, y, z)
    return (px * SS, py * SS)


def paint_crate(facing):
    """A plank crate. The E face is the S face mirrored, so the two read as turned."""
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    h = HALF
    sides = [
        # (polygon, shade): the side facing down-left (+y), the side facing down-right (+x), the lid.
        ([corner(-h, h), corner(h, h), corner(h, h, HEIGHT), corner(-h, h, HEIGHT)], 0.85),
        ([corner(h, -h), corner(h, h), corner(h, h, HEIGHT), corner(h, -h, HEIGHT)], 0.62),
        ([corner(-h, -h, HEIGHT), corner(h, -h, HEIGHT), corner(h, h, HEIGHT), corner(-h, h, HEIGHT)], 1.0),
    ]
    for polygon, shade in sides:
        draw.polygon(polygon, fill=pzart.tint(WOOD, shade))
    # Plank seams on the two sides, and an edge round every face.
    for step in range(1, PLANKS):
        z = HEIGHT * step / PLANKS
        draw.line([corner(-h, h, z), corner(h, h, z)], fill=pzart.tint(WOOD, 0.55), width=SS)
        draw.line([corner(h, -h, z), corner(h, h, z)], fill=pzart.tint(WOOD, 0.4), width=SS)
    for polygon, _ in sides:
        draw.line(polygon + polygon[:1], fill=pzart.tint(WOOD, 0.35), width=SS)
    tile = pzart.weather(pzart.shrink(layer), random.Random(SEED), 0.35)
    return tile.transpose(Image.FLIP_LEFT_RIGHT) if facing == "E" else tile


def lua_tiles():
    prefix = TILESET + "_"
    return {
        "PREFIX": prefix,
        "SHEETS": [{"prefix": prefix, "tiles": COLUMNS * ROWS}],
        "FACE_COUNT": len(FACES),
        "STATIONS": [prefix + str(index) for index in range(len(FACES))],
    }


def main():
    media = Path(__file__).resolve().parent.parent / "42" / "media"
    pzart.write_lua_tiles(media, MOD, lua_tiles(), "tools/build_tileset.py")
    (media / "texturepacks").mkdir(parents=True, exist_ok=True)
    tiles = {index: paint_crate(facing) for index, facing in enumerate(FACES)}
    pzart.write_pack(media / "texturepacks" / f"{NAME}.pack", tiles, NAME, TILESET, PAGE_SIZE)
    pzart.write_tiles(media / f"{NAME}.tiles", [(TILESET, COLUMNS, ROWS)], TILE_PROPS)
    pzart.write_build_icon(tiles[0], media / "textures" / "Item___STATION_TAG__.png")
    pzart.write_mod_icon(tiles[0], media.parent / "icon.png")
    print(f"wrote {NAME}.pack and {NAME}.tiles to {media}")


if __name__ == "__main__":
    main()
