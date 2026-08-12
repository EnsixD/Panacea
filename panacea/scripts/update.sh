#!/usr/bin/env bash
# Обновление Panacea из репозитория.
#
#   update.sh check   — есть ли новая версия; печатает строки key=value
#   update.sh apply   — скачать, поставить поверх и перезапустить оболочку
#   update.sh version — какая версия стоит сейчас
#
# Установленная версия хранится в ~/.config/panacea/.version — это хеш
# коммита, с которого ставили. Сравниваем его с концом ветки на GitHub.
#
# Установщик уносит старые каталоги в .bak и кладёт свежие целиком. Для
# обновления так нельзя: вместе со старым каталогом уехали бы настройки,
# сочетания клавиш и обои, которые человек копил. Поэтому своё состояние мы
# уносим в сторону до установки и возвращаем после.
set -u

# Проверочный прогон: ставим в свой каталог и НЕ перезапускаем оболочку.
# Без этого установщик убивал бы рабочую оболочку той системы, на которой
# идёт проверка, — что однажды и произошло.
DRY="${PANACEA_DRYRUN:-0}"

REPO="${PANACEA_REPO:-EnsixD/Panacea}"
BRANCH="${PANACEA_BRANCH:-main}"
# Откуда тянуть. По умолчанию GitHub; переменной можно подставить локальный
# путь — на нём же и проверяется вся цепочка, не трогая рабочую систему.
GIT_URL="${PANACEA_GIT:-https://github.com/$REPO.git}"
# у локального пути истории API нет, там всё берётся самим git
IS_GITHUB=0
case "$GIT_URL" in https://github.com/*) IS_GITHUB=1 ;; esac
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$CONF/panacea/.version"

# Что принадлежит человеку, а не репозиторию: пережить обновление обязано.
KEEP=(
    "$CONF/panacea/settings.json"
    "$CONF/hypr/lua/binds_data.lua"
)
KEEP_DIRS=(
    "$CONF/hypr/wallpaper"
    "$CONF/panacea/assets"
)

have() { command -v "$1" >/dev/null 2>&1; }

current() { [ -f "$STATE" ] && cat "$STATE" || echo ""; }

# Хеш и заголовок последнего коммита. Через API — одним запросом получаем и
# то, и другое; без него остаётся ls-remote, который отдаёт только хеш.
remote_info() {
    local sha="" subject=""
    if [ "$IS_GITHUB" != "1" ]; then
        # локальный репозиторий: и хеш, и заголовок отдаёт сам git
        sha="$(git ls-remote "$GIT_URL" "$BRANCH" 2>/dev/null | cut -f1)"
        subject="$(git --git-dir="$GIT_URL/.git" log -1 --format=%s "$BRANCH" 2>/dev/null \
                   || git -C "$GIT_URL" log -1 --format=%s "$BRANCH" 2>/dev/null)"
        printf '%s\t%s\n' "$sha" "$subject"
        return
    fi
    if have curl; then
        local json
        json="$(curl -fsSL --max-time 8 \
            "https://api.github.com/repos/$REPO/commits/$BRANCH" 2>/dev/null)"
        if [ -n "$json" ]; then
            sha="$(printf '%s' "$json" | sed -n 's/.*"sha": *"\([0-9a-f]\{40\}\)".*/\1/p' | head -1)"
            # В сообщении коммита заголовок отделён от тела парой \n —
            # в уведомление годится только он.
            subject="$(printf '%s' "$json" \
                | tr '\n' ' ' \
                | sed -n 's/.*"message": *"\([^"]*\)".*/\1/p' | head -1 \
                | sed 's/\\n.*//')"
        fi
    fi
    if [ -z "$sha" ] && have git; then
        sha="$(git ls-remote "$GIT_URL" "$BRANCH" 2>/dev/null | cut -f1)"
    fi
    printf '%s\t%s\n' "$sha" "$subject"
}

cmd_check() {
    local cur info sha subject
    cur="$(current)"
    IFS=$'\t' read -r sha subject <<<"$(remote_info)"

    if [ -z "$sha" ]; then
        echo "status=offline"
        echo "current=$cur"
        exit 2
    fi
    echo "current=$cur"
    echo "latest=$sha"
    echo "subject=$subject"
    # Версия неизвестна (ставили не установщиком) — предлагать обновление
    # наугад нельзя: человек не поймёт, с чего на что.
    if [ -z "$cur" ]; then
        echo "status=unknown"
    elif [ "$cur" = "$sha" ]; then
        echo "status=current"
    else
        echo "status=behind"
    fi
}

stash_user_state() {
    STASH="$(mktemp -d)"
    local f
    for f in "${KEEP[@]}"; do
        [ -f "$f" ] && { mkdir -p "$STASH/$(dirname "${f#$HOME/}")"; cp "$f" "$STASH/${f#$HOME/}"; }
    done
    for f in "${KEEP_DIRS[@]}"; do
        [ -d "$f" ] && { mkdir -p "$STASH/$(dirname "${f#$HOME/}")"; cp -r "$f" "$STASH/${f#$HOME/}"; }
    done
}

restore_user_state() {
    [ -n "${STASH:-}" ] && [ -d "$STASH" ] || return 0
    local f
    for f in "${KEEP[@]}"; do
        if [ -f "$STASH/${f#$HOME/}" ]; then
            mkdir -p "$(dirname "$f")"
            cp "$STASH/${f#$HOME/}" "$f"
        fi
    done
    # Каталоги возвращаем содержимым, а не целиком: установщик уже создал
    # пустой каталог с тем же именем, и `cp -r dir dst` положил бы наши файлы
    # внутрь него вторым уровнем — обои человека уезжали в wallpaper/wallpaper.
    # Файлы из свежей установки при этом остаются: своё кладём поверх.
    for f in "${KEEP_DIRS[@]}"; do
        if [ -d "$STASH/${f#$HOME/}" ]; then
            mkdir -p "$f"
            cp -r "$STASH/${f#$HOME/}/." "$f/"
        fi
    done
    rm -rf "$STASH"
}

# Заголовки коммитов между двумя версиями — по одному в строке.
# Что человеку показать после обновления. На вход идут заголовки коммитов, и
# не все из них — новости: поднятие версии, правки README и .gitignore меняют
# для него ровно ничего. Их отсеиваем, а заодно убираем повторы: после
# перебазирования один и тот же заголовок попадает в сравнение дважды.
changelog_filter() {
    grep -v '^Merge ' \
        | grep -viE '^(shell: bump version|gitignore|readme|docs|ci)\b' \
        | grep -viE '^(update|bump) (the )?(readme|docs|version)\b' \
        | awk '!seen[$0]++' \
        | head -40
}

write_changelog() {
    local from="$1" to="$2" out="$CONF/panacea/.whatsnew"
    [ -n "$from" ] || return 0
    if [ "$IS_GITHUB" != "1" ]; then
        {
            printf '%s\n' "$to"
            git -C "$GIT_URL" log --format=%s "$from..$to" 2>/dev/null | changelog_filter
        } > "$out"
        return 0
    fi
    have curl || return 0
    local json
    json="$(curl -fsSL --max-time 10 \
        "https://api.github.com/repos/$REPO/compare/$from...$to" 2>/dev/null)" || return 0
    [ -n "$json" ] || return 0
    {
        printf '%s\n' "$to"
        # из каждого коммита берём только первую строку сообщения
        printf '%s' "$json" \
            | grep -o '"message": *"[^"]*"' \
            | sed 's/"message": *"//; s/"$//; s/\\n.*//' \
            | changelog_filter
    } > "$out"
}

cmd_apply() {
    have git || { echo "status=error"; echo "error=nogit"; exit 1; }

    local sha subject
    IFS=$'\t' read -r sha subject <<<"$(remote_info)"
    [ -n "$sha" ] || { echo "status=error"; echo "error=offline"; exit 1; }

    # переменная нарочно не local: trap срабатывает при выходе из скрипта,
    # когда область видимости функции уже закрыта
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp:-}"' EXIT

    echo "step=download"
    git clone --depth 1 --branch "$BRANCH" \
        "$GIT_URL" "$tmp/src" >/dev/null 2>&1 \
        || { echo "status=error"; echo "error=download"; exit 1; }

    # Скрипт обновляет сам себя.
    #
    # Всё, что дальше — сохранение настроек, список изменений, перезапуск —
    # делает та копия, которая уже лежит у человека, то есть СТАРАЯ. Значит
    # любая правка в самом обновлении вступала бы в силу только со следующего
    # раза, а до тех пор чинилось бы вручную. Поэтому, если в свежем клоне
    # скрипт другой, передаём работу ему — один раз, по флагу, чтобы не
    # закольцеваться.
    if [ "${PANACEA_SELFEXEC:-0}" != "1" ] && [ -f "$0" ] \
       && [ -f "$tmp/src/panacea/scripts/update.sh" ] \
       && ! cmp -s "$tmp/src/panacea/scripts/update.sh" "$0"; then
        echo "step=selfupdate"
        fresh="$(mktemp)"
        cp "$tmp/src/panacea/scripts/update.sh" "$fresh"
        # свой временный каталог убираем сами: свежий скрипт склонирует свой
        rm -rf "$tmp"
        trap - EXIT
        PANACEA_SELFEXEC=1 bash "$fresh" apply
        rc=$?
        rm -f "$fresh"
        return $rc
    fi

    echo "step=backup"
    # Прежнюю версию читаем сейчас: установщик проштампует .version заново,
    # и после него сравнивать будет уже не с чем.
    local was
    was="$(current)"
    stash_user_state

    # Ставим тем же установщиком, что и с нуля: одна логика на установку и
    # обновление — значит, обновлённая машина ничем не отличается от свежей.
    # Пакеты, тема входа и загрузчик не трогаются: их ставят один раз.
    # --no-restart обязателен, а не только в проверочном прогоне.
    #
    # Установщик перезапускает оболочку сам: pkill -x qs. Но этот скрипт
    # запущен ИЗ оболочки и умирал вместе с ней прямо здесь — до восстановления
    # настроек, до списка изменений и до отметки версии. Со стороны обновление
    # выглядело сорвавшимся и предлагалось снова при каждом запуске. Поэтому
    # установщик оболочку не трогает, а перезапуск делаем сами и в самом конце.
    echo "step=install"
    if ! (cd "$tmp/src" && bash ./install.sh --no-deps --no-sddm --no-grub \
            --no-services --no-wallpapers --no-restart --yes >"$tmp/log" 2>&1); then
        restore_user_state
        echo "status=error"
        echo "error=install"
        echo "log=$tmp/log"
        exit 1
    fi

    echo "step=restore"
    restore_user_state

    # Список изменений между тем, что стояло, и тем, что встало. Оболочка
    # покажет его один раз после перезапуска и файл сотрёт. История берётся
    # с GitHub: клон делается мелкий, в нём её нет.
    write_changelog "$was" "$sha"
    printf '%s\n' "$sha" > "$STATE"

    echo "step=restart"
    if [ "$DRY" = "1" ]; then
        echo "status=done"
        echo "version=$sha"
        return 0
    fi
    # Печатаем итог ДО перезапуска: оболочка читает вывод этого скрипта, и
    # после pkill читать его будет уже некому.
    echo "status=done"
    echo "version=$sha"

    # Перезапуск отдельным сеансом: он переживёт смерть и оболочки, и нас
    # самих. Пауза даёт оболочке дочитать вывод и закрыться по-человечески.
    if have hyprctl && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        setsid sh -c '
            sleep 1
            hyprctl reload >/dev/null 2>&1
            [ -x "'"$CONF"'/hypr/scripts/switch_theme.sh" ] \
                && "'"$CONF"'/hypr/scripts/switch_theme.sh" --restore >/dev/null 2>&1
            pkill -x qs >/dev/null 2>&1
            sleep 1
            exec qs -c "'"$CONF"'/panacea"
        ' >/dev/null 2>&1 &
    fi
}

case "${1:-check}" in
    check)   cmd_check ;;
    apply)   cmd_apply ;;
    version) current ;;
    *) echo "usage: update.sh [check|apply|version]" >&2; exit 1 ;;
esac
