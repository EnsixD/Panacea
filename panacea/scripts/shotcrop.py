#!/usr/bin/env python3
"""Вырезает область из снимка экрана и кодирует её в PNG.

    shotcrop.py СНИМОК.ppm "X,Y WxH" ФАЙЛ.png

Пишет PNG в ФАЙЛ. В буфер обмена его кладёт shot.sh, читая тот же файл:
скриншот и так должен остаться на диске, а код возврата тогда принадлежит
обрезке, а не wl-copy, которому пустой ввод сошёл бы за успешную работу.

Зачем вообще резать самим. Скриншот области можно снять и вторым вызовом
grim — по замершему кадру, который уже висит на экране. Но тогда картинка
второй раз проходит через композитор, и её качество начинает зависеть от
того, что он делает с выводом: ночная температура (hyprsunset), цифровая
насыщенность, дизеринг под 10 бит. Сегодня захват идёт до всего этого и
кадр возвращается пиксель в пиксель — проверено, но это свойство чужой
реализации, а не обещание. Здесь же режется тот самый файл, который сняли
в начале: ни цветовых преобразований, ни округлений, ни второго кадра.

Отсюда и PPM вместо PNG для исходного снимка: он нужен ровно двум людям —
слою, который показывает стоп-кадр, и этому скрипту. Оба читают его сразу,
а не жмут и разжимают ради временного файла в памяти.

Своя возня с PNG, а не ImageMagick, потому что тянуть его ради одной
обрезки не за чем: python3 в зависимостях и так есть, а zlib — в его
стандартной поставке.
"""

import json
import struct
import subprocess
import sys
import zlib


def die(msg):
    print("shotcrop: " + msg, file=sys.stderr)
    sys.exit(1)


def read_ppm(path):
    """P6, 8 бит на канал — единственное, что печатает grim -t ppm."""
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError as e:
        die(str(e))
    if data[:2] != b"P6":
        die("снимок не в формате P6")

    # Заголовок — три числа, между ними любые пробелы и комментарии с «#».
    nums = []
    i = 2
    while len(nums) < 3:
        if i >= len(data):
            die("обрезанный заголовок")
        c = data[i:i + 1]
        if c.isspace():
            i += 1
            continue
        if c == b"#":
            while i < len(data) and data[i:i + 1] != b"\n":
                i += 1
            continue
        j = i
        while j < len(data) and not data[j:j + 1].isspace():
            j += 1
        nums.append(int(data[i:j]))
        i = j
    # После последнего числа стоит ровно один пробельный символ, дальше пиксели.
    i += 1

    w, h, maxval = nums
    if maxval != 255:
        die("ожидалось 8 бит на канал, получено maxval=%d" % maxval)
    return w, h, data[i:i + w * h * 3]


def layout_frame(img_w):
    """Начало раскладки и множитель «логическая точка → пиксель снимка».

    grim снимает все мониторы одной картинкой, а slurp отдаёт координаты в
    логических точках раскладки, начало которой не обязано быть нулевым:
    монитор слева от главного живёт в отрицательных x. Считаем по самому
    снимку — его ширина и есть раскладка в пикселях.
    """
    try:
        out = subprocess.run(["hyprctl", "monitors", "-j"],
                             capture_output=True, text=True, check=True).stdout
        mons = json.loads(out)
        if not mons:
            raise ValueError("пустой список мониторов")
    except Exception:
        # Без композитора под рукой считаем раскладку одним экраном 1:1.
        return 0, 0, 1.0

    min_x = min(m["x"] for m in mons)
    min_y = min(m["y"] for m in mons)
    max_x = max(m["x"] + m["width"] / m["scale"] for m in mons)
    span = max_x - min_x
    scale = img_w / span if span > 0 else 1.0
    return min_x, min_y, scale


def parse_geom(text):
    """«X,Y WxH» — то, что печатает slurp."""
    try:
        pos, size = text.strip().split(" ")
        x, y = (int(v) for v in pos.split(","))
        w, h = (int(v) for v in size.split("x"))
    except ValueError:
        die("не разобрать область: %r" % text)
    return x, y, w, h


def encode_png(w, h, rows):
    def chunk(tag, payload):
        body = tag + payload
        return (struct.pack(">I", len(payload)) + body
                + struct.pack(">I", zlib.crc32(body)))

    # Фильтр 0 на каждой строке: жать сильнее незачем, файл живёт секунды.
    raw = b"".join(b"\x00" + r for r in rows)
    header = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)  # 8 бит, truecolor
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(raw, 6))
            + chunk(b"IEND", b""))


def main():
    if len(sys.argv) != 4:
        die("использование: shotcrop.py СНИМОК.ppm \"X,Y WxH\" ФАЙЛ.png")
    src, geom, dst = sys.argv[1:4]

    img_w, img_h, pixels = read_ppm(src)
    if len(pixels) < img_w * img_h * 3:
        die("снимок короче своего заголовка")

    off_x, off_y, scale = layout_frame(img_w)
    gx, gy, gw, gh = parse_geom(geom)

    x = int(round((gx - off_x) * scale))
    y = int(round((gy - off_y) * scale))
    w = int(round(gw * scale))
    h = int(round(gh * scale))

    # Выделение краем уходит за экран, если тянуть рамку за границу монитора.
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(img_w, x + w), min(img_h, y + h)
    if x1 <= x0 or y1 <= y0:
        die("выделение вне снимка")

    rows = []
    for row in range(y0, y1):
        start = (row * img_w + x0) * 3
        rows.append(pixels[start:start + (x1 - x0) * 3])

    try:
        with open(dst, "wb") as f:
            f.write(encode_png(x1 - x0, y1 - y0, rows))
    except OSError as e:
        die(str(e))


if __name__ == "__main__":
    main()
