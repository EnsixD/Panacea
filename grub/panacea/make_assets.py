#!/usr/bin/env python3
"""Генерация картинок для темы GRUB «Panacea».

Фон — обои темы Fav (тёмный монохромный кадр с цветком). Загрузчик читать
конфиг Hyprland не может, поэтому картинку кладём рядом с темой и только
затемняем/виньетируем здесь, чтобы текст меню читался.

    python3 make_assets.py [ширина] [высота] [путь_к_обоям]
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

W = int(sys.argv[1]) if len(sys.argv) > 1 else 1920
H = int(sys.argv[2]) if len(sys.argv) > 2 else 1080
HERE = os.path.dirname(os.path.abspath(__file__))
WALL = sys.argv[3] if len(sys.argv) > 3 else os.path.join(HERE, "wallpaper.jpg")


def cover(img, w, h):
    """Масштаб «cover»: заполнить w×h без полей, лишнее обрезать по центру."""
    iw, ih = img.size
    scale = max(w / iw, h / ih)
    nw, nh = int(iw * scale + 0.5), int(ih * scale + 0.5)
    img = img.resize((nw, nh), Image.LANCZOS)
    x = (nw - w) // 2
    y = (nh - h) // 2
    return img.crop((x, y, x + w, y + h))


def build_background():
    base = Image.open(WALL).convert("RGB")
    img = cover(base, W, H)

    # Обои и так тёмные — приглушаем ещё немного, чтобы белый текст меню
    # уверенно читался поверх любой их части.
    img = ImageEnhance.Brightness(img).enhance(0.62)
    img = ImageEnhance.Contrast(img).enhance(0.96)

    # Мягкая виньетка: собирает внимание к центру, где стоит меню, и топит
    # края в чёрный — там подсказки набраны приглушённым серым.
    vign = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vign)
    maxd = math.hypot(W / 2, H / 2)
    step = 4
    for y in range(0, H, step):
        for x in range(0, W, step):
            d = math.hypot(x - W / 2, y - H / 2) / maxd
            vd.rectangle((x, y, x + step - 1, y + step - 1),
                         fill=int(min(255, 255 * d ** 2 * 1.1)))
    vign = vign.filter(ImageFilter.GaussianBlur(40))
    img = Image.composite(Image.new("RGB", (W, H), (3, 3, 4)), img, vign)

    # Лёгкая горизонтальная «подложка» под колонкой меню: ровная тёмная
    # полоса по центру, чтобы строки не тонули в светлых пятнах боке.
    band = Image.new("L", (W, H), 0)
    bd = ImageDraw.Draw(band)
    bx0, bx1 = int(W * 0.30), int(W * 0.70)
    by0, by1 = int(H * 0.26), int(H * 0.80)
    bd.rectangle((bx0, by0, bx1, by1), fill=150)
    band = band.filter(ImageFilter.GaussianBlur(90))
    dark = Image.new("RGB", (W, H), (0, 0, 0))
    img = Image.composite(dark, img, band.point(lambda v: int(v * 0.55)))

    img.save(os.path.join(HERE, "background.png"))


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
        img.crop(box).save(os.path.join(HERE, f"{name}_{key}.png"))


def build_boxes():
    # Выделенный пункт — тёмная капсула со стеклянной обводкой.
    #
    # Углы держим заметно меньше половины строки (item_height=44 в theme.txt):
    # если радиус ≥ половины высоты, GRUB тянет угловые части и подсветка
    # налезает на соседний пункт — строки слипаются. corner=16 при высоте 44
    # оставляет ровную прямую серединку сверху и снизу, поэтому капсула
    # строго в своей строке и не «перетекает» на вкладку выше/ниже.
    corner = 16
    side = corner * 2 + 6
    sel = rounded((side, side), corner,
                  (10, 10, 12, 235), (255, 255, 255, 60))
    slice9(sel, "select", corner)

    # Коробка консоли (клавиша C) — тот же тёмный, углы чуть крупнее.
    box = 18
    menu = rounded((box * 2 + 6, box * 2 + 6), box,
                   (8, 8, 10, 220), (255, 255, 255, 26))
    slice9(menu, "menu", box)


if __name__ == "__main__":
    build_background()
    build_boxes()
    print("готово")
