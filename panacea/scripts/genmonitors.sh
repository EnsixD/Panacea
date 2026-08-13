#!/usr/bin/env bash
# Пересобирает ~/.config/hypr/lua/monitors_data.lua из settings.json.
#
# Зачем отдельный файл, если оболочка и так умеет применять настройки экрана
# через hyprctl: она делает это через ~400 мс после своего запуска, а до того
# монитор стоит в режиме "preferred". По HDMI предпочтительным режимом часто
# оказывается 1920x1080@60, даже если панель умеет 144.
#
# Qt привязывает таймер анимаций к частоте обновления один раз, при создании
# первого окна. Оболочка стартует раньше, чем приезжают 144 Гц, — и до конца
# сеанса крутит анимации по 60 Гц, хотя монитор давно переключился. Со стороны
# это выглядит как «после перезагрузки остров дёргается, после перезапуска
# оболочки — нет».
#
# Поэтому режим должен стоять до старта оболочки, то есть в конфиге
# компоновщика. Формат тот же, что у binds_data.lua: файл создаётся отсюда,
# monitors.lua его читает, а нет файла — берётся "preferred".
set -u

CFG="$HOME/.config/panacea/settings.json"
OUT="$HOME/.config/hypr/lua/monitors_data.lua"

[ -f "$CFG" ] || exit 1
command -v jq >/dev/null 2>&1 || exit 1

# monOverrides лежит строкой с JSON внутри: {"HDMI-A-1":{"w":..,"h":..,"rr":..}}
raw="$(jq -r '.monOverrides // ""' "$CFG")"
[ -n "$raw" ] && [ "$raw" != "null" ] || exit 0

mkdir -p "$(dirname "$OUT")"
tmp="$OUT.new"

{
    echo "-- Файл создаётся автоматически: panacea/scripts/genmonitors.sh"
    echo "-- Правки руками будут затёрты при следующей смене настроек экрана."
    echo "return {"
    printf '%s' "$raw" | jq -r '
        to_entries[]
        | "    { output = \"" + .key + "\""
        + ", mode = \"" + (.value.w|tostring) + "x" + (.value.h|tostring)
        + "@" + ((.value.rr|tonumber) | tostring) + "\""
        + ", position = \"" + (.value.pos // "auto") + "\""
        + ", scale = " + ((.value.scale // 1) | tostring)
        + ", transform = " + ((.value.transform // 0) | tostring)
        + ", vrr = " + (if .value.vrr then "1" else "0" end)
        + " },"
    ' 2>/dev/null
    echo "}"
} > "$tmp"

# Пустой список — значит jq не разобрал строку: тогда лучше остаться без
# файла и с "preferred", чем подсунуть компоновщику пустую таблицу.
if grep -q "^    {" "$tmp"; then
    mv -f "$tmp" "$OUT"
else
    rm -f "$tmp"
fi
