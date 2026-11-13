#!/usr/bin/env python3
"""Builds the Forged Cauldron's ground model (42/media/Models_X/ForgedCauldron.glb) and its texture.

The kettle alone, as the Stone Hearth's tiles draw it (build_tileset's PROFILE and soot_share): an Alpine cheese
kettle of dark forged iron, greased and blacked, grey where the soot hasn't reached, black below the shoulder; a
rolled lip, two lugs and its bail dropped over the rim. Units are metres, Y up, base on the ground; its in-game size is
the `scale` of the ForgedCauldronGround model in 42/media/scripts/TraditionalPreservationCore_Cauldron.txt. The glb
writer is Fish & Meat's (tools/build_model.py there).

The texture: the outside in the left three quarters (u round the kettle, v down from the lip), then the inside, the
lip (u round the ring) and the bail and lugs, in vanilla's forged pot's greys.

Usage: python3 tools/build_model.py [preview.png]
Needs Pillow and numpy. Rerun after editing the tables below.
"""
import json
import math
import random
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import build_tileset as B
import pzart

KETTLE_R = 0.33                # the belly's radius, m: the tiles' 100-120 L kettle (it holds 60 L), matched to them
KETTLE_H = 0.6                # bottom to lip, m: taller than true, as the camera squashes a model's height
WALL = 0.006
LIP_TUBE = 0.032               # the rolled lip's radius: thick, as the tiles draw it
BAIL_TUBE = 0.01
BAIL_DROP = 75                 # degrees the bail has fallen over from upright
SIDES = 40
RINGS = 24

OUT_U, IN_U, LIP_U, IRON_U = (0.0, 0.74), (0.76, 0.84), (0.86, 0.92), (0.94, 1.0)
TEXTURE_SIZE, SAVED_TEXTURE_SIZE = 256, 128
# Greys from vanilla's forged pot texture: its light iron about 115-138, its dark 54-74.
LIGHT_IRON = 118               # above the soot, and the lip
SOOT = 50                      # the sooted belly
DARK_IRON = 66                 # the inside, the bail and the lugs


class Mesh:
    def __init__(self):
        self.positions, self.normals, self.uvs, self.indices = [], [], [], []

    def vertex(self, position, normal, uv):
        self.positions.append(tuple(float(c) for c in position))
        n = np.array(normal, dtype=float)
        self.normals.append(tuple((n / (np.linalg.norm(n) or 1)).tolist()))
        self.uvs.append(uv)
        return len(self.positions) - 1

    def tri(self, a, b, c):
        self.indices += [a, b, c]

    def quad(self, a, b, c, d):
        self.indices += [a, b, c, a, c, d]


def radius(t):
    return KETTLE_R * B.kettle_radius(t) / B.KETTLE_R


def lathe(mesh, rings, u_range, inward=False):
    """rings: [(y, r, t)], bottom to top; a smooth surface of revolution, v down from the lip (t 1 at v 0)."""
    grid = []
    for k, (y, r, t) in enumerate(rings):
        lo, hi = rings[max(0, k - 1)], rings[min(len(rings) - 1, k + 1)]
        dy, dr = hi[0] - lo[0], hi[1] - lo[1]
        row = []
        for i in range(SIDES + 1):
            a = 2 * math.pi * i / SIDES
            normal = (dy * math.cos(a), -dr, dy * math.sin(a))
            if inward:
                normal = tuple(-c for c in normal)
            u = u_range[0] + (u_range[1] - u_range[0]) * i / SIDES
            row.append(mesh.vertex((r * math.cos(a), y, r * math.sin(a)), normal, (u, 1 - t)))
        grid.append(row)
    for r0, r1 in zip(grid, grid[1:]):
        for i in range(SIDES):
            if inward:
                mesh.quad(r0[i], r1[i], r1[i + 1], r0[i + 1])
            else:
                mesh.quad(r0[i], r0[i + 1], r1[i + 1], r1[i])


def disc(mesh, y, r, up, uv):
    centre = mesh.vertex((0, y, 0), (0, 1 if up else -1, 0), uv)
    ring = [mesh.vertex((r * math.cos(2 * math.pi * i / SIDES), y, r * math.sin(2 * math.pi * i / SIDES)),
                        (0, 1 if up else -1, 0), uv) for i in range(SIDES)]
    for i in range(SIDES):
        j = (i + 1) % SIDES
        mesh.tri(centre, ring[j], ring[i]) if up else mesh.tri(centre, ring[i], ring[j])


def tube(mesh, path, r, uv, sides=8):
    """A round bar along path, its normals out from the bar."""
    for p0, p1 in zip(path, path[1:]):
        p0, p1 = np.array(p0, dtype=float), np.array(p1, dtype=float)
        d = p1 - p0
        d /= np.linalg.norm(d)
        up = np.array([0, 1, 0]) if abs(d[1]) < 0.9 else np.array([1, 0, 0])
        u = np.cross(d, up)
        u /= np.linalg.norm(u)
        w = np.cross(d, u)
        ring0, ring1 = [], []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            o = math.cos(a) * u + math.sin(a) * w
            ring0.append(mesh.vertex(p0 + r * o, o, uv))
            ring1.append(mesh.vertex(p1 + r * o, o, uv))
        for i in range(sides):
            j = (i + 1) % sides
            mesh.quad(ring0[i], ring1[i], ring1[j], ring0[j])


def block(mesh, centre, size, uv):
    """A small box (a lug)."""
    c, h = np.array(centre, dtype=float), np.array(size, dtype=float) / 2
    for axis in range(3):
        for sign in (-1, 1):
            n = np.zeros(3)
            n[axis] = sign
            a, b = [k for k in range(3) if k != axis]
            corners = []
            for sa, sb in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                p = c.copy()
                p[axis] += sign * h[axis]
                p[a] += sa * h[a]
                p[b] += sb * h[b]
                corners.append(mesh.vertex(p, n, uv))
            if sign * (1 if (axis, a, b) in ((0, 1, 2), (1, 0, 2), (2, 0, 1)) else -1) > 0:
                corners = corners[::-1]
            mesh.quad(*corners)


def build_mesh():
    mesh = Mesh()
    outer = [(KETTLE_H * k / RINGS, radius(k / RINGS), k / RINGS) for k in range(RINGS + 1)]
    lathe(mesh, outer, OUT_U)
    inner = [(KETTLE_H * k / RINGS + 0.01, radius(k / RINGS) - WALL, k / RINGS) for k in range(1, RINGS + 1)]
    lathe(mesh, inner, IN_U, inward=True)
    disc(mesh, 0.001, radius(0), False, (OUT_U[0] + 0.01, 0.99))
    disc(mesh, inner[0][0], inner[0][1], True, ((IN_U[0] + IN_U[1]) / 2, 0.9))
    iron = ((IRON_U[0] + IRON_U[1]) / 2, 0.5)
    lip = radius(1)
    # The lip a segment at a time, each its own column of the lip's strip (u round the ring), for its soot marks.
    ring = [(lip * math.cos(a), KETTLE_H, lip * math.sin(a)) for a in np.linspace(0, 2 * math.pi, SIDES + 1)]
    for i, (p0, p1) in enumerate(zip(ring, ring[1:])):
        tube(mesh, [p0, p1], LIP_TUBE, (LIP_U[0] + (LIP_U[1] - LIP_U[0]) * (i + 0.5) / SIDES, 0.5))
    # The lugs on the x axis and the bail fallen over towards -z.
    drop = math.radians(BAIL_DROP)
    lug_y = KETTLE_H - 0.04
    for side in (-1, 1):
        block(mesh, (side * (lip + 0.008), lug_y, 0), (0.016, 0.045, 0.034), iron)
    path = []
    for i in range(25):
        a = math.pi * i / 24
        x, h = (lip + 0.018) * math.cos(a), (lip + 0.03) * math.sin(a)
        path.append((x, lug_y + h * math.cos(drop), -h * math.sin(drop)))
    tube(mesh, path, BAIL_TUBE, iron)
    return mesh


def paint_texture():
    """In vanilla's forged pot's greys (WorldItems/CookingPot_Forged.png, used as painted): neutral grey with cloudy
    mottling, light iron above the soot and dark below it (soot_share, as the tiles), the lip light iron blotched with
    soot, the inside and the bail dark iron."""
    size = TEXTURE_SIZE
    rng = random.Random("cauldron")
    cloud = Image.blend(pzart.soft_noise(rng, (size, size), 10, 10), pzart.soft_noise(rng, (size, size), 4, 4), 0.4).load()
    image = Image.new("RGBA", (size, size))
    pixels = image.load()

    def grey(value, x, y):
        v = int(value * (0.8 + 0.4 * cloud[x, y] / 255))
        return (v, v, v, 255)

    x0, x1 = int(OUT_U[0] * size), int(OUT_U[1] * size)
    lx0, lx1 = int(LIP_U[0] * size), int(LIP_U[1] * size)
    for x in range(size):
        a = 2 * math.pi * (x - x0) / (x1 - x0)
        la = 2 * math.pi * (x - lx0) / max(1, lx1 - lx0)
        for y in range(size):
            if x < x1:
                sooted = B.soot_share(1 - y / (size - 1), a, 1.3)
                pixels[x, y] = grey(LIGHT_IRON * (1 - sooted) + SOOT * sooted, x, y)
            elif lx0 <= x < lx1:
                sooted = max(0.0, min(1.0, 0.25 + 0.45 * math.sin(la * 3 + 1.1) * math.sin(la * 7 + 0.4)))
                pixels[x, y] = grey(LIGHT_IRON * 1.05 * (1 - sooted) + SOOT * sooted, x, y)
            else:
                pixels[x, y] = grey(DARK_IRON, x, y)
    return image.resize((SAVED_TEXTURE_SIZE, SAVED_TEXTURE_SIZE), Image.BOX)


def write_glb(path, mesh):
    positions = np.array(mesh.positions, dtype="<f4")
    normals = np.array(mesh.normals, dtype="<f4")
    uvs = np.array(mesh.uvs, dtype="<f4")
    indices = np.array(mesh.indices, dtype="<u2")

    chunks, views, accessors = bytearray(), [], []

    def add(array, kind, component, target, bounds=False):
        offset = len(chunks)
        chunks.extend(array.tobytes())
        chunks.extend(b"\0" * (-len(chunks) % 4))
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": array.nbytes, "target": target})
        accessor = {"bufferView": len(views) - 1, "componentType": component, "count": len(array), "type": kind}
        if bounds:
            accessor["min"] = array.min(axis=0).tolist()
            accessor["max"] = array.max(axis=0).tolist()
        accessors.append(accessor)
        return len(accessors) - 1

    primitive = {
        "attributes": {
            "POSITION": add(positions, "VEC3", 5126, 34962, bounds=True),
            "NORMAL": add(normals, "VEC3", 5126, 34962),
            "TEXCOORD_0": add(uvs, "VEC2", 5126, 34962),
        },
        "indices": add(indices, "SCALAR", 5123, 34963),
    }
    document = {
        "asset": {"version": "2.0", "generator": "TraditionalPreservationCore build_model.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": "ForgedCauldron"}],
        "meshes": [{"name": "ForgedCauldron", "primitives": [primitive]}],
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(chunks)}],
    }
    text = json.dumps(document, separators=(",", ":")).encode("utf8")
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(chunks)
    with open(path, "wb") as out:
        out.write(struct.pack("<4sII", b"glTF", 2, total))
        out.write(struct.pack("<I4s", len(text), b"JSON") + text)
        out.write(struct.pack("<I4s", len(chunks), b"BIN\0") + bytes(chunks))


def preview(mesh, texture, path, size=360):
    """Four views from the game's camera (down at 30 degrees, a quarter turn apart), flat shaded by the texture at
    each triangle's middle, for checking by eye; kept out of the mod."""
    tex = texture.convert("RGB")
    light = np.array([-0.6, 0.7, 0.4])
    light /= np.linalg.norm(light)
    pos, nor, uv = np.array(mesh.positions), np.array(mesh.normals), np.array(mesh.uvs)
    sheet = Image.new("RGBA", (size * 4, size), (96, 110, 88, 255))
    for turn in range(4):
        image = Image.new("RGBA", (size * 4, size * 4), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        yaw, pitch = math.radians(45 + 90 * turn), math.radians(30)
        cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)
        items = []
        for k in range(0, len(mesh.indices), 3):
            ids = mesh.indices[k:k + 3]
            p = pos[ids]
            x = p[:, 0] * cy - p[:, 2] * sy
            z = -(p[:, 0] * sy + p[:, 2] * cy)
            syy = -p[:, 1] * cp + z * sp
            depth = z * cp + p[:, 1] * sp
            n = nor[ids].mean(axis=0)
            u, v = uv[ids].mean(axis=0)
            c = np.array(tex.getpixel((min(tex.width - 1, int(u * tex.width)), min(tex.height - 1, int(v * tex.height)))))
            c = c * (0.55 + 0.75 * max(0.0, float(np.dot(n, light))))
            pts = [(size * 2 + 1300 * a, size * 2.6 + 1300 * b) for a, b in zip(x, syy)]
            items.append((depth.mean(), pts, tuple(int(min(255, q)) for q in c) + (255,)))
        for _, pts, c in sorted(items, key=lambda i: i[0]):
            draw.polygon(pts, fill=c, outline=c)
        sheet.alpha_composite(image.resize((size, size), Image.LANCZOS), (turn * size, 0))
    sheet.save(path)


def main():
    media = Path(__file__).resolve().parent.parent / "42" / "media"
    (media / "Models_X").mkdir(parents=True, exist_ok=True)
    mesh = build_mesh()
    texture = paint_texture()
    write_glb(media / "Models_X" / "ForgedCauldron.glb", mesh)
    texture.save(media / "textures" / "ForgedCauldronModel.png")
    if len(sys.argv) > 1:
        preview(mesh, texture, sys.argv[1])
    print(f"wrote the cauldron's model ({len(mesh.indices) // 3} triangles, {len(mesh.positions)} vertices) and texture to {media}")


if __name__ == "__main__":
    main()
