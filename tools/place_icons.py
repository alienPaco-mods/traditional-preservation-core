"""The places' icons for an info window's Place row (user, session 64): white outlines of our own, drawn at 64 px and
shrunk to the 16 px the row draws them at. Approved preview: WIP/TPCore/art/place_icons_mock.png.
  Open: the sun. Covered: a roof on two posts, four lines. Sheltered (indoors): a house, its door shut. AiredRoom: a
  gust, three lines of air curling at their ends, in a ring. Basement: the ground line, steps going down under the house.
  Smokehouse: a small shed, a chimney, smoke swaying up. Fireside: a flame. Embers: coals heaped on a hearth floor,
  a wisp over them.

Usage: python3 tools/place_icons.py    (writes 42/media/textures/TPPlace_<place>.png)
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

S, LW = 64, 6
INK = (255, 255, 255, 255)


def blank():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def wave(d, x0, x1, y, amp=3, waves=1.5):
    pts = [(x, y + amp * math.sin((x - x0) / (x1 - x0) * waves * 2 * math.pi)) for x in range(int(x0), int(x1) + 1)]
    d.line(pts, fill=INK, width=LW - 2, joint="curve")


def sun():
    img, d = blank()
    d.ellipse([20, 20, 44, 44], outline=INK, width=LW)
    for i in range(8):
        a = i * math.pi / 4
        d.line([32 + 18 * math.cos(a), 32 + 18 * math.sin(a), 32 + 28 * math.cos(a), 32 + 28 * math.sin(a)],
               fill=INK, width=LW)
    return img


def roof():
    img, d = blank()
    d.line([(2, 28), (32, 6)], fill=INK, width=LW)     # four lines: the roof's two slopes
    d.line([(32, 6), (62, 28)], fill=INK, width=LW)
    d.line([(12, 21), (12, 60)], fill=INK, width=LW)   # and two posts, open below
    d.line([(52, 21), (52, 60)], fill=INK, width=LW)
    return img


def house():
    img, d = blank()
    d.line([(6, 30), (32, 8), (58, 30)], fill=INK, width=LW, joint="curve")
    d.rectangle([12, 27, 52, 58], outline=INK, width=LW)
    d.rectangle([27, 40, 37, 58], outline=INK, width=LW - 1)
    return img


def aired():
    img, d = blank()
    # an aired room (user): a gust of air inside a ring, the room it moves through. Two lines (three blur at 16 px), the top
    # curling up at its end, the bottom one down, each curl open at its left (the user's reference).
    d.ellipse([3, 3, 61, 61], outline=INK, width=LW - 2)
    w = LW - 1
    for y, x0, x1, r, up in ((28, 12, 36, 9, True), (40, 16, 40, 8, False)):
        d.line([(x0, y), (x1, y)], fill=INK, width=w)
        if up:
            d.arc([x1 - r, y - 2 * r, x1 + r, y], 180, 90, fill=INK, width=w)
        else:
            d.arc([x1 - r, y, x1 + r, y + 2 * r], 270, 180, fill=INK, width=w)
    return img


def basement():
    img, d = blank()
    d.line([(4, 22), (32, 4), (60, 22)], fill=INK, width=LW - 1, joint="curve")
    d.line([(2, 28), (62, 28)], fill=INK, width=LW)       # the ground
    steps = [(14, 28), (14, 36), (24, 36), (24, 44), (34, 44), (34, 52), (44, 52), (44, 60)]
    d.line(steps, fill=INK, width=LW - 1, joint="curve")
    d.line([(8, 60), (56, 60)], fill=INK, width=LW - 1)   # the floor below
    d.line([(56, 28), (56, 60)], fill=INK, width=LW - 1)
    return img


def smokehouse():
    img, d = blank()
    d.line([(10, 40), (30, 26), (50, 40)], fill=INK, width=LW, joint="curve")
    d.rectangle([14, 38, 46, 62], outline=INK, width=LW)
    d.rectangle([26, 49, 34, 62], outline=INK, width=LW - 2)
    d.rectangle([38, 24, 44, 34], fill=INK)            # its chimney
    # smoke rising from it: a column that sways as it climbs
    pts = [(41 + 6 * math.sin((22 - y) / 6), y) for y in range(22, 0, -1)]
    d.line(pts, fill=INK, width=LW - 1, joint="curve")
    return img


def flame():
    img, d = blank()
    outer = [(32, 4), (40, 18), (48, 30), (50, 42), (46, 52), (38, 58), (26, 58), (18, 52), (14, 42), (18, 30),
             (24, 34), (26, 22)]
    d.line(outer + [outer[0]], fill=INK, width=LW, joint="curve")
    inner = [(32, 32), (38, 42), (36, 52), (28, 52), (26, 44), (32, 32)]
    d.line(inner, fill=INK, width=LW - 1, joint="curve")
    return img


def embers():
    img, d = blank()
    d.line([(4, 58), (60, 58)], fill=INK, width=LW)                # the hearth's floor
    for box in ([8, 40, 26, 58], [22, 34, 42, 58], [38, 40, 56, 58]):   # coals heaped on it
        d.chord(box, 180, 360, outline=INK, width=LW - 2)
    wave(d, 26, 38, 22, amp=3, waves=1)                            # a wisp of smoke
    return img


ICONS = {"Open": sun, "Covered": roof, "Sheltered": house, "AiredRoom": aired, "Basement": basement,
         "Smokehouse": smokehouse, "Fireside": flame, "Embers": embers}
SIZE = 16


def main():
    out = Path(__file__).resolve().parent.parent / "42/media/textures"
    for place, draw in ICONS.items():
        path = out / f"TPPlace_{place}.png"
        draw().resize((SIZE, SIZE), Image.LANCZOS).save(path)
        print(path)


if __name__ == "__main__":
    main()
