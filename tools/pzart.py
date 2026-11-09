"""Shared helpers for the Traditional Preservation art builders.

A builder imports it from _tpcore (TPCORE, or ../_tpcore next to the mod):

    sys.path.insert(0, str(Path(os.environ.get("TPCORE", Path(__file__).resolve().parents[2] / "_tpcore")) / "tools"))
    import pzart

Builders must stay deterministic: everything random here takes the caller's rng, so a rebuild is byte-identical.
What lives here is what two or more builders share word for word. A mod's own shapes (Fish's tub, Vinegar's barrel)
stay in its builder and use the pieces below (light_at, stave_edges, hoop_bands).
"""
import io
import math
import re
import struct
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

# A vanilla floor tile is drawn in a 128 x 256 image; the floor diamond's middle is at FOOT.
TILE_W, TILE_H = 128, 256
FOOT = (64, 226)
DIAMOND_HALF_W, DIAMOND_HALF_H = 62, 31
MAX_SHEET_TILES = 512  # per tileset sheet, as the tile definitions number them

BUILD_ICON_SIZE = 64
# The mod list icon: a station on a pale sky with rounded corners, the same across the series.
MOD_ICON_SIZE, MOD_ICON_MARGIN, MOD_ICON_CORNER, MOD_ICON_BADGE = 128, 8, 16, 52
MOD_ICON_SKY = (176, 196, 204, 255)


# --- Pack and tile definition files ---------------------------------------------------------------------------

def read_string(f):
    (length,) = struct.unpack("<I", f.read(4))
    return f.read(length).decode("utf8", "replace")


def write_string(out, value):
    data = value.encode("utf8")
    out.write(struct.pack("<I", len(data)))
    out.write(data)


def write_pack(path, tiles, pack, tile_name, page_size):
    """Writes a one-page PZPK texture pack. tiles maps tile index -> full-size RGBA image, each cropped to its art
    and placed in rows. pack is the page's name without the trailing 0; tile_name is a tileset name (tiles are
    "<tileset>_<index>") or a function of the index, for a mod whose tiles span several sheets."""
    if isinstance(tile_name, str):
        tileset = tile_name
        tile_name = lambda index: f"{tileset}_{index}"  # noqa: E731
    page = Image.new("RGBA", (page_size, page_size), (0, 0, 0, 0))
    entries = []
    x = y = row_height = 0
    for index, tile in sorted(tiles.items()):
        ox, oy, right, bottom = tile.getbbox()
        image = tile.crop((ox, oy, right, bottom))
        if x + image.width > page_size:
            x, y, row_height = 0, y + row_height, 0
        if y + image.height > page_size:
            raise SystemExit(f"tiles do not fit on one {page_size} page; raise the page size")
        page.paste(image, (x, y))
        entries.append((tile_name(index), (x, y, image.width, image.height, ox, oy, tile.width, tile.height)))
        x += image.width
        row_height = max(row_height, image.height)

    png = io.BytesIO()
    page.save(png, "PNG")
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as out:
        out.write(b"PZPK")
        out.write(struct.pack("<II", 1, 1))
        write_string(out, pack + "0")
        out.write(struct.pack("<II", len(entries), 1))
        for name, values in entries:
            write_string(out, name)
            out.write(struct.pack("<8I", *values))
        out.write(struct.pack("<I", len(png.getvalue())))
        out.write(png.getvalue())


def write_tiles(path, sheets, props):
    """Writes a .tiles definition file. sheets lists (tileset, columns, rows); tile indexes run on from one sheet to
    the next. props maps tile index -> [(key, value), ...]."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as out:
        out.write(b"tdef")
        out.write(struct.pack("<II", 1, len(sheets)))
        first = 0
        for number, (tileset, columns, rows) in enumerate(sheets, 1):
            count = columns * rows
            assert count <= MAX_SHEET_TILES, f"{tileset} has {count} tiles"
            out.write(f"{tileset}\n{tileset}.png\n".encode("utf8"))
            out.write(struct.pack("<IIII", columns, rows, number, count))
            for index in range(first, first + count):
                tile_props = props.get(index, [])
                out.write(struct.pack("<I", len(tile_props)))
                for key, value in tile_props:
                    out.write(f"{key}\n{value}\n".encode("utf8"))
            first += count


def cut_tile(page, x, y, w, h, ox, oy, full_w, full_h):
    tile = Image.new("RGBA", (full_w, full_h), (0, 0, 0, 0))
    tile.paste(page.crop((x, y, x + w, y + h)), (ox, oy))
    return tile


def extract_sprites(pack_path, wanted):
    """Returns {sprite name: full-size RGBA image} from a vanilla pack. Stops the build if one is missing."""
    found = {}
    with open(pack_path, "rb") as f:
        if f.read(4) != b"PZPK":
            raise SystemExit(f"{pack_path}: not a PZPK pack")
        _version, pages = struct.unpack("<II", f.read(8))
        for _ in range(pages):
            read_string(f)
            count, _alpha = struct.unpack("<II", f.read(8))
            entries = []
            for _ in range(count):
                name = read_string(f)
                entries.append((name, struct.unpack("<8I", f.read(32))))
            (size,) = struct.unpack("<I", f.read(4))
            hits = [entry for entry in entries if entry[0] in wanted]
            if not hits:
                f.seek(size, 1)
                continue
            page = Image.open(io.BytesIO(f.read(size))).convert("RGBA")
            for name, values in hits:
                found[name] = cut_tile(page, *values)
    missing = wanted - found.keys()
    if missing:
        raise SystemExit(f"sprites not found in {pack_path}: {sorted(missing)}")
    return found


def extract_old_sprite(pack_path, wanted):
    """Returns one full-size sprite from a pack in the older format, which has no magic or page sizes."""
    data = Path(pack_path).read_bytes()
    position = 0

    def read_int():
        nonlocal position
        position += 4
        return struct.unpack_from("<I", data, position - 4)[0]

    def read_name():
        nonlocal position
        length = read_int()
        position += length
        return data[position - length:position].decode("utf8", "replace")

    for _ in range(read_int()):
        read_name()
        count = read_int()
        read_int()
        entries = {}
        for _ in range(count):
            name = read_name()
            entries[name] = struct.unpack_from("<8I", data, position)
            position += 32
        end = data.index(b"IEND", position) + 8
        if wanted in entries:
            return cut_tile(Image.open(io.BytesIO(data[position:end])).convert("RGBA"), *entries[wanted])
        position = end + (4 if data[end:end + 4] == b"\xef\xbe\xad\xde" else 0)
    raise SystemExit(f"sprite not found in {pack_path}: {wanted}")


# --- Icons ----------------------------------------------------------------------------------------------------

def write_build_icon(tile, path, size=BUILD_ICON_SIZE):
    """Crops a station to its art and centres it in a square, for the build menu."""
    art = tile.crop(tile.getbbox())
    scale = size / max(art.size)
    art = art.resize((max(1, round(art.width * scale)), max(1, round(art.height * scale))), Image.LANCZOS)
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.alpha_composite(art, ((size - art.width) // 2, (size - art.height) // 2))
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    icon.save(path)


def write_mod_icon(art, path, badge=None, keep=None):
    """The station on the series' pale sky with rounded corners, so the mods match in the mod list.
    badge is an item icon set in the bottom right corner. keep crops a tall station to its top part, which then
    fills the icon's height and runs off the bottom (Fish's beam, whose posts would make the art too small)."""
    size, margin = MOD_ICON_SIZE, MOD_ICON_MARGIN
    art = art.crop(art.getbbox())
    if keep is not None:
        art = art.crop((0, 0, art.width, round(art.height * keep)))
    scale = (size - margin) / (art.height if keep is not None else max(art.size))
    art = art.resize((max(1, round(art.width * scale)), max(1, round(art.height * scale))), Image.LANCZOS)
    icon = Image.new("RGBA", (size, size), MOD_ICON_SKY)
    bottom = size - art.height - (0 if keep is not None else margin // 2)
    icon.alpha_composite(art, ((size - art.width) // 2, bottom))
    if badge is not None:
        badge = badge.crop(badge.getbbox())
        badge = badge.resize((MOD_ICON_BADGE * badge.width // max(badge.size), MOD_ICON_BADGE * badge.height // max(badge.size)), Image.NEAREST)
        icon.alpha_composite(badge, (size - badge.width - margin // 2, size - badge.height - margin // 2))
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, mask.width - 1, mask.height - 1), MOD_ICON_CORNER * 4, fill=255)
    icon.putalpha(mask.resize(icon.size, Image.LANCZOS))
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    icon.save(path)


def recolour(image, is_fluid, colour, solid, rng, specks):
    """Repaints the fluid pixels of a vanilla icon or texture in colour, keeping their light and dark, or in random
    specks (a range of brightness) when the contents are solid."""
    result = image.copy()
    pixels = result.load()
    fluid = [(x, y) for y in range(image.height) for x in range(image.width) if is_fluid(x, y)]
    brightness = [sum(pixels[point][:3]) / 3 for point in fluid]
    average = sum(brightness) / len(brightness)
    for point, value in zip(fluid, brightness):
        amount = rng.uniform(*specks) if solid else 0.9 + 0.1 * value / average
        pixels[point] = tint(colour, amount)[:3] + (pixels[point][3],)
    return result


# --- Painting -------------------------------------------------------------------------------------------------
# Tiles are painted supersampled (ss times the tile size) on a new_layer, then shrunk.

def new_layer(ss):
    return Image.new("RGBA", (TILE_W * ss, TILE_H * ss), (0, 0, 0, 0))


def shrink(layer):
    return layer.resize((TILE_W, TILE_H), Image.LANCZOS)


def project(x, y, z=0.0, foot=FOOT):
    """x and y are in tiles from the middle of the floor (+x runs down-right, +y down-left), z in pixels.
    Returns tile pixels; multiply by the supersampling to draw on a layer."""
    return (foot[0] + (x - y) * DIAMOND_HALF_W, foot[1] + (x + y) * DIAMOND_HALF_H - z)


def tint(colour, amount):
    """colour (RGB or RGBA) times amount, as an opaque RGBA."""
    return tuple(max(0, min(255, int(c * amount))) for c in colour[:3]) + (255,)


def soft_noise(rng, size, cell_w, cell_h):
    """Smooth random greys, with blobs about cell_w by cell_h pixels."""
    small = Image.new("L", (max(2, size[0] // cell_w + 2), max(2, size[1] // cell_h + 2)))
    small.putdata([rng.randrange(256) for _ in range(small.width * small.height)])
    return small.resize(size, Image.BICUBIC)


def weather(tile, rng, depth, streaks=False, finish=None):
    """Mottles a finished tile with dirt and grain, and water stains running down it when streaks is set.
    Vanilla art is hand painted and never flat, so everything goes through this. finish(rgb, rng) may rework the
    colours before the alpha goes back on (Vinegar's pixel grain)."""
    dirt = Image.blend(soft_noise(rng, tile.size, 13, 13), soft_noise(rng, tile.size, 3, 3), 0.5)
    dirt = Image.blend(dirt, soft_noise(rng, tile.size, 1, 1), 0.35)
    if streaks:
        dirt = ImageChops.multiply(dirt, soft_noise(rng, tile.size, 3, 44).point(lambda v: 150 + v * 105 // 255))
        dirt = dirt.point(lambda v: min(255, v * 3 // 2))
    grime = dirt.point(lambda v: max(0, min(255, int(255 * (1 - depth * (1 - v / 150))))))
    rgb = ImageChops.multiply(tile.convert("RGB"), Image.merge("RGB", (grime, grime, grime)))
    if finish is not None:
        rgb = finish(rgb, rng)
    rgb.putalpha(tile.getchannel("A"))
    return rgb


def darken_down(layer, top_y, bottom_y, lowest, ss):
    """Fades a layer towards lowest brightness between two heights (tile pixels), so it sinks into the ground."""
    ramp = Image.new("L", layer.size, 255)
    top, bottom = int(top_y * ss), int(bottom_y * ss)
    fade = Image.linear_gradient("L").resize((layer.width, bottom - top)).point(lambda v: 255 - int(v * (1 - lowest)))
    ramp.paste(fade, (0, top))
    ramp.paste(int(255 * lowest), (0, bottom, layer.width, layer.height))
    rgb = ImageChops.multiply(layer.convert("RGB"), Image.merge("RGB", (ramp, ramp, ramp)))
    rgb.putalpha(layer.getchannel("A"))
    return rgb


# --- Staves and hoops -----------------------------------------------------------------------------------------
# Angles run round an ellipse: 0 is the right-hand side, pi/2 the front, pi the left, 3pi/2 the back.

def light_at(angle):
    """A curved front (staves, hoops) lit from the left and falling away hard on the right, like vanilla's barrels."""
    return 0.72 + 0.3 * max(0.0, math.cos(angle - 2.2)) ** 1.4


def inside_light(angle):
    """The far wall inside a tub or cask: the light from the left lands on the right-hand side."""
    return 0.72 + 0.34 * max(0.0, math.cos(angle))


def stave_edges(rng, count, low, high, start=0.0):
    """The angles between count staves across half the ring from start, each stave's width varied by a random
    factor between low and high; the last stave takes up the slack."""
    end = start + math.pi
    edges = [start]
    while edges[-1] < end:
        edges.append(edges[-1] + math.pi / count * rng.uniform(low, high))
    edges[-1] = end
    return edges


def hoop_bands(rng, rust_chance, iron, rust, steps=40):
    """The segments of an iron hoop round the front, patched with rust: yields (first, second, colour, tone) for
    each, angles in radians, tone its brightness. Each mod draws the segment on its own shape."""
    rust_left = 0
    for i in range(steps):
        first, second = math.pi * i / steps, math.pi * (i + 1) / steps
        if rust_left == 0 and rng.random() < rust_chance:
            rust_left = rng.randint(1, 5)
        colour = tuple(int(a + (b - a) * rng.uniform(0.25, 0.6)) for a, b in zip(iron, rust)) if rust_left else iron
        rust_left = max(0, rust_left - 1)
        yield first, second, colour, light_at((first + second) / 2) * rng.uniform(0.9, 1.08)

IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def lua_value(value, indent=""):
    """value as Lua source. Dicts keep their order, so a table reads as the builder lists it."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(value, (list, tuple)):
        items = [lua_value(item, indent) for item in value]
        if all("\n" not in item for item in items):
            return "{ " + ", ".join(items) + " }" if items else "{}"
        inner = indent + "    "
        return "{\n" + "".join(f"{inner}{lua_value(item, inner)},\n" for item in value) + indent + "}"
    if isinstance(value, dict):
        if not value:
            return "{}"
        inner = indent + "    "
        lines = []
        for key, item in value.items():
            if isinstance(key, str) and IDENTIFIER.match(key):
                name = key
            else:
                name = f"[{lua_value(key)}]"
            lines.append(f"{inner}{name} = {lua_value(item, inner)},\n")
        return "{\n" + "".join(lines) + indent + "}"
    raise TypeError(f"no Lua form for {value!r}")


def write_lua_tiles(media, mod, values, builder):
    """Writes media/lua/shared/<mod>/Tiles.lua: the tile numbers the mod's Lua reads, required as "<mod>/Tiles".

    values is a dict of the builder's own numbers. The file is generated: the builder is the one place to change them.
    """
    path = Path(media) / "lua" / "shared" / mod / "Tiles.lua"
    path.parent.mkdir(parents=True, exist_ok=True)
    text = (f"-- Generated by {builder}: don't edit, change the numbers there and rerun it.\n"
            f"-- The tile numbers of {mod}'s art, required as \"{mod}/Tiles\".\n"
            f"return {lua_value(values)}\n")
    path.write_text(text, encoding="utf8")
    return path
