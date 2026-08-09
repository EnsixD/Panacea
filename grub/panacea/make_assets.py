#!/usr/bin/env python3
"""Генерация картинок для темы GRUB «Panacea».

Обои намеренно не берутся из темы Hyprland: загрузчик живёт своей жизнью,
и картинка тут своя — чёрный космос с двумя мягкими пятнами света и
тонкими концентрическими кольцами. Всё рисуется кодом, файлов-исходников
не требуется.

    python3 make_assets.py [ширина] [высота]
"""
import math
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

W = int(sys.argv[1]) if len(sys.argv) > 1 else 1920
H = int(sys.argv[2]) if len(sys.argv) > 2 else 1080

ACCENT = (198, 90, 71)      # тёплый — как $accent_color темы line
COOL = (43, 106, 143)       # холодный контрапункт
BASE = (5, 5, 6)


def glow_layer(cx, cy, rad, color, strength):
    """Мягкое круглое пятно света на чёрном холсте во весь экран."""
    layer = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(layer)
    dim = tuple(int(c * strength) for c in color)
    d.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), fill=dim)
    return layer.filter(ImageFilter.GaussianBlur(rad * 0.45))


def build_background():
    img = Image.new("RGB", (W, H), BASE)

    # два пятна света: тёплое снизу слева, холодное сверху справа.
    # складываем аддитивно — так свет ложится поверх чёрного, а не смешивается
    # с ним в серую муть
    for cx, cy, rad, color, strength in (
        (int(W * 0.22), int(H * 0.78), int(W * 0.30), ACCENT, 0.42),
        (int(W * 0.82), int(H * 0.20), int(W * 0.26), COOL, 0.34),
    ):
        img = ImageChops.add(img, glow_layer(cx, cy, rad, color, strength))

    # тонкие концентрические кольца — «топография» вокруг центра меню
    rings = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rings)
    cx, cy = int(W * 0.5), int(H * 0.52)
    for i in range(14):
        r = int(W * 0.10) + i * int(W * 0.035)
        a = max(0, 26 - i * 2)
        rd.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 255, 255, a), width=1)
    img = Image.alpha_composite(img.convert("RGBA"), rings).convert("RGB")

    # виньетка: собираем внимание к центру
    vign = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vign)
    maxd = math.hypot(W / 2, H / 2)
    for y in range(0, H, 4):
        for x in range(0, W, 4):
            d = math.hypot(x - W / 2, y - H / 2) / maxd
            vd.rectangle((x, y, x + 3, y + 3), fill=int(min(255, 255 * d ** 2 * 1.15)))
    img = Image.composite(Image.new("RGB", (W, H), (0, 0, 0)), img, vign)

    img.save("background.png")


def rounded(size, radius, fill, border, width=1):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius,
                        fill=fill, outline=border, width=width)
    return img


def slice9(img, name, corner):
    """Режем картинку на 9 частей для styled box GRUB."""
    w, h = img.size
    parts = {
        "nw": (0, 0, corner, corner),
        "n": (corner, 0, w - corner, corner),
        "ne": (w - corner, 0, w, corner),
        "w": (0, corner, corner, h - corner),
        "c": (corner, corner, w - corner, h - corner),
        "e": (w - corner, corner, w, h - corner),
        "sw": (0, h - corner, corner, h),
        "s": (corner, h - corner, w - corner, h),
        "se": (w - corner, h - corner, w, h),
    }
    for key, box in parts.items():
        img.crop(box).save(f"{name}_{key}.png")


def build_boxes():
    # Выделенный пункт — чёрная капсула, как сама пилюля.
    # Углы держим меньше половины item_height из theme.txt (36), иначе
    # GRUB растягивает уголки и подсветка налезает на соседний пункт —
    # соседние строки визуально слипаются в один блок.
    corner = 14
    sel = rounded((corner * 2 + 4, corner * 2 + 4), corner,
                  (8, 8, 10, 242), (255, 255, 255, 46))
    slice9(sel, "select", corner)

    # коробка консоли (клавиша C) — тот же чёрный, углы крупнее
    box = 18
    menu = rounded((box * 2 + 4, box * 2 + 4), box,
                   (8, 8, 10, 224), (255, 255, 255, 26))
    slice9(menu, "menu", box)


if __name__ == "__main__":
    build_background()
    build_boxes()
    print("готово")
