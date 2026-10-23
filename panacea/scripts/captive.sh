#!/bin/bash
# Проверка «страницы входа» в сети (кафе, гостиницы, вокзалы).
#
# Такая сеть отвечает на любой http-запрос своей страницей вместо ответа
# сервера. Спрашиваем адрес, который заведомо отдаёт пустой 204: пришло что-то
# другое — нас перехватили, и адрес перехвата и есть страница входа.
#
#   captive.sh [SSID]   печатает URL страницы входа или ничего
#
# Найдя портал, сам показывает уведомление с кнопкой «Войти» и открывает
# страницу в браузере по умолчанию.

ssid="$1"
# DHCP и DNS после подключения поднимаются не сразу — несколько попыток
for i in 1 2 3 4; do
    out=$(curl -s -m 5 -o /dev/null -w '%{http_code} %{redirect_url}' \
          http://connectivitycheck.gstatic.com/generate_204 2>/dev/null)
    code=${out%% *}
    [ "$code" = "204" ] && exit 0
    [ -n "$code" ] && [ "$code" != "000" ] && break
    sleep 3
done
[ -z "$code" ] || [ "$code" = "000" ] && exit 0

url=${out#* }
# Портал без перенаправления (отдаёт страницу сразу) — открываем сам адрес
# проверки: браузер увидит ту же страницу входа.
[ -n "$url" ] || url="http://connectivitycheck.gstatic.com/generate_204"
printf '%s\n' "$url"

title="${PANACEA_CAPTIVE_TITLE:-Требуется вход в сеть}"
body="${PANACEA_CAPTIVE_BODY:-Откройте страницу входа, чтобы получить доступ к интернету}"
[ -n "$ssid" ] && body="$ssid — $body"
btn="${PANACEA_CAPTIVE_BTN:-Войти}"
act=$(notify-send -a "Wi-Fi" -i network-wireless -u critical \
        -A "open=$btn" "$title" "$body" 2>/dev/null)
[ "$act" = "open" ] && setsid xdg-open "$url" >/dev/null 2>&1 &
wait
