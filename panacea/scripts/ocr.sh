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
cleanup() {
    [ -n "$TMP_CROP" ] && rm -f "$TMP_CROP"
}
trap cleanup EXIT INT TERM HUP

# Если задана область кропа — вырезаем её во временный файл
if [ -n "$X" ] && [ -n "$Y" ] && [ -n "$W" ] && [ -n "$H" ]; then
    TMP_CROP=$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}" ocr-crop.XXXXXX.png)
    if python3 -c "
import sys
from PIL import Image
try:
    im = Image.open('$IMG')
    x, y, w, h = int('$X'), int('$Y'), int('$W'), int('$H')
    cr = im.crop((x, y, x + w, y + h))
    cr.save('$TMP_CROP')
except Exception as e:
    sys.exit(1)
" 2>/dev/null; then
        IMG="$TMP_CROP"
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

TEXT=$(tesseract "$IMG" stdout "${LANG_ARG[@]}" 2>/dev/null)

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
