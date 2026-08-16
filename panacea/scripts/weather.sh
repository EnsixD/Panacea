#!/bin/bash
# Погода с OpenWeatherMap — для настольных виджетов.
#
#   weather.sh KEY CITY UNITS LANG
#
#   UNITS  metric | imperial
#   LANG   ru | en   — язык словесного описания
#
# Отдаёт строки key=value, по одной на значение. Разбирать их проще, чем
# JSON: в QML нет ничего готового для выборки полей, а ключ со значением
# читается парой строк.
#
# При любой беде печатает err= с причиной и больше ничего. Виджет тогда
# показывает, что связи нет, а не нули: ноль градусов — законная погода, и
# отличить его от «не дозвонились» было бы нельзя.

KEY="$1"
CITY="$2"
UNITS="${3:-metric}"
LANG_="${4:-en}"

fail() { printf 'err=%s\n' "$1"; exit 0; }

[ -n "$KEY" ]  || fail "no-key"
[ -n "$CITY" ] || fail "no-city"

command -v curl >/dev/null 2>&1 || fail "no-curl"
command -v jq   >/dev/null 2>&1 || fail "no-jq"

# --max-time, а не только --connect-timeout: сервер умеет принять соединение
# и замолчать, и без общего предела опрос висел бы до следующего.
#
# Без -f намеренно: с ним curl на отказ отдаёт пустоту, и причина — «ключ не
# подошёл» или «города нет» — теряется вместе с телом ответа. Она нужна:
# иначе неверный ключ выглядит как оборванная сеть.
body=$(curl -sS --connect-timeout 5 --max-time 12 --get \
    --data-urlencode "q=$CITY" \
    --data-urlencode "appid=$KEY" \
    --data-urlencode "units=$UNITS" \
    --data-urlencode "lang=$LANG_" \
    "https://api.openweathermap.org/data/2.5/weather" 2>/dev/null)

[ -n "$body" ] || fail "network"

# Свою беду сервис объясняет в поле message и отдаёт её же кодом: 401 —
# ключ не подошёл, 404 — города нет. Пересказываем причину как есть, иначе
# «не работает» пришлось бы выяснять из журнала.
code=$(printf '%s' "$body" | jq -r '.cod // empty' 2>/dev/null)
case "$code" in
    200) ;;
    401) fail "bad-key" ;;
    404) fail "no-such-city" ;;
    429) fail "rate-limit" ;;
    "")  fail "bad-answer" ;;
    *)   fail "http-$code" ;;
esac

printf '%s' "$body" | jq -r '
    "temp="     + ((.main.temp        // 0) | round | tostring),
    "feels="    + ((.main.feels_like  // 0) | round | tostring),
    "humidity=" + ((.main.humidity    // 0) | round | tostring),
    "pressure=" + ((.main.pressure    // 0) | round | tostring),
    "wind="     + ((.wind.speed       // 0) * 10 | round / 10 | tostring),
    "clouds="   + ((.clouds.all       // 0) | round | tostring),
    "cond="     + (.weather[0].main        // ""),
    "desc="     + (.weather[0].description // ""),
    "icon="     + (.weather[0].icon        // ""),
    "city="     + (.name                   // "")
' 2>/dev/null || fail "bad-answer"
