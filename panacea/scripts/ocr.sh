#!/bin/bash
# Распознавание текста с изображения или его части (OCR).
#
# Использование:
#   ocr.sh "путь/к/картинке" [x y w h] [--copy]
#
# Возвращает:
#   stdout: распознанный текст (обрезанный от лишних пустых строк)
#   exit code:
#     0: успешно (текст найден и выведен)
#     1: текст не найден (пустой результат)
#     2: tesseract не установлен
#     3: ошибка аргументов или файла

IMG="$1"
shift || { echo "ERROR: missing image path" >&2; exit 3; }

if [ ! -f "$IMG" ]; then
    echo "ERROR: file not found: $IMG" >&2
    exit 3
fi

# Проверяем наличие tesseract
if ! command -v tesseract >/dev/null 2>&1; then
    echo "ERROR_NOT_INSTALLED"
    exit 2
fi

X=""
Y=""
W=""
H=""
DO_COPY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --copy)
            DO_COPY=1
            shift
            ;;
        *)
            if [ -z "$X" ]; then X="$1"
            elif [ -z "$Y" ]; then Y="$1"
            elif [ -z "$W" ]; then W="$1"
            elif [ -z "$H" ]; then H="$1"
            fi
            shift
            ;;
    esac
done

TMP_CROP=""
TMP_PREP=""
cleanup() {
    [ -n "$TMP_CROP" ] && rm -f "$TMP_CROP"
    [ -n "$TMP_PREP" ] && rm -f "$TMP_PREP"
}
trap cleanup EXIT INT TERM HUP

# Если задана область кропа — вырезаем её во временный файл
if [ -n "$X" ] && [ -n "$Y" ] && [ -n "$W" ] && [ -n "$H" ]; then
    TMP_CROP=$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}" ocr-crop.XXXXXX.png) || exit 3
    if python3 - "$IMG" "$X" "$Y" "$W" "$H" "$TMP_CROP" <<'PYCODE'
import sys
from PIL import Image
im = Image.open(sys.argv[1])
x, y, w, h = map(int, sys.argv[2:6])
im.crop((x, y, x + w, y + h)).save(sys.argv[6])
PYCODE
    then
        IMG="$TMP_CROP"
    else
        echo "ERROR: failed to crop image" >&2
        exit 3
    fi
fi

# Подбираем языки tesseract
AVAILABLE_LANGS=$(tesseract --list-langs 2>/dev/null)
LANG_ARG=()
if echo "$AVAILABLE_LANGS" | grep -qx "rus" && echo "$AVAILABLE_LANGS" | grep -qx "eng"; then
    LANG_ARG=(-l "rus+eng")
elif echo "$AVAILABLE_LANGS" | grep -qx "rus"; then
    LANG_ARG=(-l "rus")
elif echo "$AVAILABLE_LANGS" | grep -qx "eng"; then
    LANG_ARG=(-l "eng")
fi

# Интерфейсные скриншоты часто содержат очень мелкий и бледный текст.
# Увеличиваем его с ограничением по памяти и усиливаем контраст. Для обычных
# страниц оставляем автоматическое определение колонок Tesseract.
PSM=3
TMP_PREP=$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}" ocr-prep.XXXXXX.png) || exit 3
if mode=$(python3 - "$IMG" "$TMP_PREP" <<'PYCODE'
import math
import sys
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

with Image.open(sys.argv[1]) as source:
    source = ImageOps.exif_transpose(source)
    width, height = source.size
    rgba = source.convert("RGBA")
    image = Image.new("RGB", rgba.size, "white")
    image.paste(rgba, mask=rgba.getchannel("A"))
    scale = min(3.0, max(1.0, math.sqrt(12_000_000 / (width * height))))
    if scale > 1.05:
        image = image.resize((round(width * scale), round(height * scale)), Image.Resampling.LANCZOS)
    image = ImageEnhance.Contrast(ImageOps.grayscale(image)).enhance(1.5)
    image = image.filter(ImageFilter.UnsharpMask(radius=1.5, percent=100, threshold=3))
    image.save(sys.argv[2], dpi=(300, 300))
    print(6 if height <= 500 and width >= 2 * height else 3)
PYCODE
); then
    IMG="$TMP_PREP"
    PSM="$mode"
fi
TEXT=$(tesseract "$IMG" stdout "${LANG_ARG[@]}" --psm "$PSM" 2>/dev/null)

# Убираем пробелы и пустые строки по краям
TEXT=$(printf '%s\n' "$TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')

if [ -z "$TEXT" ]; then
    exit 1
fi

if [ "$DO_COPY" -eq 1 ]; then
    if command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$TEXT" | wl-copy
    fi
fi

printf '%s\n' "$TEXT"
exit 0
