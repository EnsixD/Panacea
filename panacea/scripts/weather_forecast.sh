#!/bin/bash
# Детальный прогноз погоды (почасовой + на 7 дней) для Panacea
#
#   weather_forecast.sh KEY CITY UNITS LANG
#
#   UNITS  metric | imperial
#   LANG   ru | en

KEY="$1"
CITY="$2"
UNITS="${3:-metric}"
LANG_="${4:-ru}"

fail() { printf '{"err":"%s"}\n' "$1"; exit 0; }

[ -n "$CITY" ] || fail "no-city"

command -v curl >/dev/null 2>&1 || fail "no-curl"
command -v jq   >/dev/null 2>&1 || fail "no-jq"

lat=""
lon=""
res_name=""
admin1=""

# 1. Попытка точных координат через OpenWeatherMap
if [ -n "$KEY" ]; then
    case "$CITY" in
        [0-9]*)
            case "$CITY" in
                *,*) OW_FIELD="zip=$CITY" ;;
                *)   OW_FIELD="zip=$CITY,RU" ;;
            esac
            ;;
        *) OW_FIELD="q=$CITY" ;;
    esac

    ow_data=$(curl -sS --connect-timeout 5 --max-time 10 --get \
        --data-urlencode "$OW_FIELD" \
        --data-urlencode "appid=$KEY" \
        --data-urlencode "units=$UNITS" \
        --data-urlencode "lang=$LANG_" \
        "https://api.openweathermap.org/data/2.5/weather" 2>/dev/null)

    if [ "$(printf '%s' "$ow_data" | jq -r '.cod // empty' 2>/dev/null)" = "200" ]; then
        lat=$(printf '%s' "$ow_data" | jq -r '.coord.lat // empty')
        lon=$(printf '%s' "$ow_data" | jq -r '.coord.lon // empty')
        res_name=$(printf '%s' "$ow_data" | jq -r '.name // empty')
        ow_country=$(printf '%s' "$ow_data" | jq -r '.sys.country // empty')
        if [ "$ow_country" = "RU" ] && { [ "$res_name" = "Гусев" ] || [ "$res_name" = "Gusev" ]; }; then
            admin1="Калининградская область"
        fi
    fi
fi

# 2. Поиск через Open-Meteo Geocoding с фильтрацией по населению
if [ -z "$lat" ] || [ -z "$lon" ]; then
    city_clean="${CITY%%,*}"
    geo=$(curl -sS --connect-timeout 5 --max-time 10 --get \
        --data-urlencode "name=$city_clean" \
        --data-urlencode "count=10" \
        --data-urlencode "language=ru" \
        --data-urlencode "format=json" \
        "https://geocoding-api.open-meteo.com/v1/search" 2>/dev/null)

    best=$(printf '%s' "$geo" | jq -r '
        .results // [] |
        (map(select(.name == "Гусев" or .name == "Gusev")) | sort_by(-(.population // 0)) | .[0]) //
        (sort_by(-(.population // 0)) | .[0]) // empty
    ' 2>/dev/null)

    if [ -n "$best" ] && [ "$best" != "null" ]; then
        lat=$(printf '%s' "$best" | jq -r '.latitude // empty')
        lon=$(printf '%s' "$best" | jq -r '.longitude // empty')
        res_name=$(printf '%s' "$best" | jq -r '.name // empty')
        admin1=$(printf '%s' "$best" | jq -r '.admin1 // empty')
    fi
fi

[ -n "$lat" ] && [ -n "$lon" ] || fail "no-such-city"
[ -n "$res_name" ] || res_name="${CITY%%,*}"

if [ -n "$admin1" ] && [ "$admin1" != "$res_name" ]; then
    display_city="$res_name, $admin1"
else
    display_city="$res_name"
fi

temp_unit=""
[ "$UNITS" = "imperial" ] && { temp_unit="&temperature_unit=fahrenheit&wind_speed_unit=mph"; }

raw=$(curl -sS --connect-timeout 5 --max-time 12 \
    "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,surface_pressure,wind_speed_10m,cloud_cover&hourly=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,precipitation_probability,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_probability_max,wind_speed_10m_max,uv_index_max,sunrise,sunset&timezone=auto&forecast_days=7$temp_unit" 2>/dev/null)

[ -n "$raw" ] || fail "network"

printf '%s' "$raw" | jq --arg city "$display_city" --arg lang "$LANG_" --arg units "$UNITS" '
def wmo_desc(c):
    if c == 0 then (if $lang == "ru" then "Ясно" else "Clear sky" end)
    elif c == 1 then (if $lang == "ru" then "В основном ясно" else "Mainly clear" end)
    elif c == 2 then (if $lang == "ru" then "Переменная облачность" else "Partly cloudy" end)
    elif c == 3 then (if $lang == "ru" then "Пасмурно" else "Overcast" end)
    elif c == 45 or c == 48 then (if $lang == "ru" then "Туман" else "Fog" end)
    elif c == 51 or c == 53 or c == 55 then (if $lang == "ru" then "Морось" else "Drizzle" end)
    elif c == 61 or c == 63 or c == 65 then (if $lang == "ru" then "Дождь" else "Rain" end)
    elif c == 71 or c == 73 or c == 75 or c == 77 then (if $lang == "ru" then "Снег" else "Snow" end)
    elif c == 80 or c == 81 or c == 82 then (if $lang == "ru" then "Ливень" else "Rain showers" end)
    elif c == 85 or c == 86 then (if $lang == "ru" then "Снегопад" else "Snow showers" end)
    elif c == 95 or c == 96 or c == 99 then (if $lang == "ru" then "Гроза" else "Thunderstorm" end)
    else (if $lang == "ru" then "Облачно" else "Cloudy" end)
    end;

def wmo_icon(c):
    if c == 0 then "01d"
    elif c == 1 then "02d"
    elif c == 2 then "03d"
    elif c == 3 then "04d"
    elif c == 45 or c == 48 then "50d"
    elif c == 51 or c == 53 or c == 55 then "09d"
    elif c == 61 or c == 63 or c == 65 then "10d"
    elif c == 71 or c == 73 or c == 75 or c == 77 then "13d"
    elif c == 80 or c == 81 or c == 82 then "09d"
    elif c == 85 or c == 86 then "13d"
    elif c == 95 or c == 96 or c == 99 then "11d"
    else "03d"
    end;

# Index of current hour
def current_hour_idx:
    .current.time as $now |
    ([.hourly.time[] | select(. <= $now)] | length - 1) | if . < 0 then 0 else . end;

(current_hour_idx) as $start_idx |

{
    "city": $city,
    "units": $units,
    "current": {
        "temp": (.current.temperature_2m | round),
        "feels": (.current.apparent_temperature | round),
        "humidity": (.current.relative_humidity_2m | round),
        "pressure": (.current.surface_pressure | round),
        "wind": ((.current.wind_speed_10m * 10 | round) / 10),
        "clouds": (.current.cloud_cover | round),
        "desc": wmo_desc(.current.weather_code),
        "icon": wmo_icon(.current.weather_code),
        "time": (.current.time | split("T")[1])
    },
    "hourly": [
        range($start_idx; ($start_idx + 24)) as $i |
        if $i < (.hourly.time | length) then {
            "time": (.hourly.time[$i] | split("T")[1]),
            "date": (.hourly.time[$i] | split("T")[0]),
            "temp": (.hourly.temperature_2m[$i] | round),
            "feels": (.hourly.apparent_temperature[$i] | round),
            "humidity": (.hourly.relative_humidity_2m[$i] | round),
            "wind": ((.hourly.wind_speed_10m[$i] * 10 | round) / 10),
            "pop": (.hourly.precipitation_probability[$i] // 0),
            "icon": wmo_icon(.hourly.weather_code[$i]),
            "desc": wmo_desc(.hourly.weather_code[$i])
        } else empty end
    ],
    "daily": [
        range(0; (.daily.time | length)) as $i | {
            "date": .daily.time[$i],
            "dayIndex": $i,
            "tempMax": (.daily.temperature_2m_max[$i] | round),
            "tempMin": (.daily.temperature_2m_min[$i] | round),
            "feelsMax": (.daily.apparent_temperature_max[$i] | round),
            "feelsMin": (.daily.apparent_temperature_min[$i] | round),
            "pop": (.daily.precipitation_probability_max[$i] // 0),
            "wind": ((.daily.wind_speed_10m_max[$i] * 10 | round) / 10),
            "uv": ((.daily.uv_index_max[$i] * 10 | round) / 10),
            "sunrise": (.daily.sunrise[$i] | split("T")[1]),
            "sunset": (.daily.sunset[$i] | split("T")[1]),
            "icon": wmo_icon(.daily.weather_code[$i]),
            "desc": wmo_desc(.daily.weather_code[$i])
        }
    ]
}
' 2>/dev/null || fail "bad-answer"
