"""The fire band's own buttons (user, session 67): Stoke the Fire, a flame on two logs, and Bank the Fire, a mound of
dark coals glowing between them (B1 with darker coals). Vanilla has no fire or ember icon. Drawn at 256 px and shrunk
to 64; the band draws them at 20. Approved previews: WIP/TPCore/art/fire_toggle_mock.png and
fire_icon_options_mock.png. Put Out keeps a vanilla icon, the Bucket of Water (P1).

Usage: python3 tools/fire_icons.py    (writes 42/media/textures/TPIcon_Stoke.png and TPIcon_Bank.png)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

S, SIZE = 256, 64
OUT = Path(__file__).resolve().parent.parent / "42/media/textures"


def stoke():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([40, 196, 216, 226], 14, fill=(95, 60, 35), outline=(40, 25, 15), width=6)
    d.rounded_rectangle([64, 178, 192, 204], 12, fill=(120, 78, 45), outline=(40, 25, 15), width=6)
    d.polygon([(128, 18), (162, 70), (190, 112), (196, 150), (180, 182), (128, 196), (76, 182), (60, 150), (68, 116),
               (92, 92), (100, 120), (112, 70)], fill=(235, 95, 25), outline=(120, 35, 10))
    d.polygon([(132, 78), (156, 120), (162, 152), (146, 180), (128, 186), (108, 178), (96, 152), (106, 124),
               (118, 140)], fill=(255, 205, 60))
    return img


def bank():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([10, 70, 246, 250], fill=(255, 120, 30, 230))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(18)))
    d = ImageDraw.Draw(img)
    for box in ([14, 140, 112, 234], [84, 92, 176, 190], [146, 132, 242, 234], [62, 172, 160, 250],
                [124, 176, 214, 250]):
        d.ellipse(box, fill=(34, 22, 18), outline=(8, 4, 3), width=8)
    for line in ([(40, 186), (70, 176), (92, 196)], [(110, 132), (132, 146), (156, 128)],
                 [(170, 182), (196, 170), (220, 190)], [(92, 214), (118, 206), (140, 222)]):
        d.line(line, fill=(255, 160, 45), width=12, joint="curve")
    return img


def main():
    for name, draw in (("Stoke", stoke), ("Bank", bank)):
        path = OUT / f"TPIcon_{name}.png"
        draw().resize((SIZE, SIZE), Image.LANCZOS).save(path)
        print(path)


if __name__ == "__main__":
    main()
