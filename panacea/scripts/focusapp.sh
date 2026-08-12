#!/bin/bash
# Переводит фокус на окно приложения; если окна нет — запускает приложение.
#
#   focusapp.sh <hint>
#
# hint — либо desktop entry из уведомления (org.telegram.desktop), либо имя
# приложения (Telegram Desktop). Нужен для нажатия на уведомление: сам чат
# открывает уже приложение (действие «default»), а наша задача — оказаться
# на том рабочем столе, где оно живёт.

hint="$1"
[ -n "$hint" ] || exit 0
base="${hint%.desktop}"

# Ищем окно по class/initialClass/заголовку, не глядя на регистр. Заодно
# пробуем последнюю часть entry: у Telegram class = org.telegram.desktop,
# а приложение может назваться и просто «telegram».
addr=$(hyprctl -j clients 2>/dev/null | jq -r --arg h "$base" '
    ($h | ascii_downcase) as $l
    | ($l | split(".") | last) as $short
    | map(select(
          ((.class // "") | ascii_downcase | contains($l))
          or ((.initialClass // "") | ascii_downcase | contains($l))
          or ((.class // "") | ascii_downcase | contains($short))
          or ((.initialClass // "") | ascii_downcase | contains($short))
          or ((.title // "") | ascii_downcase | contains($short))
      ))
    | .[0].address // empty')

if [ -n "$addr" ]; then
    # focus сам перелистывает на стол, где лежит окно.
    #
    # Новый парсер конфига принимает только Lua-форму диспетчеров, а старый —
    # только прежнюю; и тот и другой при отказе выходят с нулевым кодом,
    # поэтому смотрим на сам ответ, а не на код возврата.
    out=$(hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" 2>&1)
    case "$out" in
        ok*) ;;
        *) hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 ;;
    esac
    exit 0
fi

# Окна нет — запускаем по desktop-файлу
for d in "$HOME/.local/share/applications" /usr/share/applications \
         /var/lib/flatpak/exports/share/applications \
         "$HOME/.local/share/flatpak/exports/share/applications"; do
    f="$d/$base.desktop"
    if [ -f "$f" ]; then
        gio launch "$f" >/dev/null 2>&1 &
        exit 0
    fi
done

# Последняя попытка: команда с таким именем
short="${base##*.}"
for c in "$base" "$short"; do
    if command -v "$c" >/dev/null 2>&1; then
        setsid "$c" >/dev/null 2>&1 &
        exit 0
    fi
done
exit 0
