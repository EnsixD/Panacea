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
    # Настройки экрана: разрешение, частота, масштаб. Без них после обновления
    # масштаб панели молча возвращался к 100%. monitors_data.lua читает
    # компоновщик на старте (путь Lua), monitors.conf — запасной для Hyprland
    # без Lua. Список тот же, что в install.sh.
    "$CONF/hypr/lua/monitors_data.lua"
    "$CONF/hypr/monitors.conf"
    # Прозрачность терминала и цифровая интенсивность — их производные файлы
    # тоже переживают обновление, иначе сбрасывались к заводским.
    "$CONF/hypr/lua/term_data.lua"
    "$CONF/panacea/.vibrance"
    # Шейдер насыщенности: репозиторий его не везёт, свежий hypr/ приезжает
    # без него, и компоновщик ругается «Failed to check screen shader path».
    "$CONF/hypr/shaders/vibrance.frag"
    # Выбранные обои: в репозитории свой wallpaper.conf, и без этой строки
    # он ложился поверх — после обновления стол возвращался к заводским.
    "$CONF/hypr/wallpaper.conf"
    "$CONF/hypr/hyprpaper.conf"
)
KEEP_DIRS=(
    "$CONF/hypr/wallpaper"
)

# То же, но мягко: возвращаем только то, чего нет в свежей установке. В
# panacea/assets лежат и наши файлы (логотип, desktop-запись), и всё, что
# человек положил туда сам. Возвращая каталог целиком, мы клали старый логотип
# поверх нового — оболочка обновлялась, а значок в уведомлениях оставался
# прежним.
KEEP_DIRS_SOFT=(
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

# Снимок живого состояния экранов в settings.json.
#
# Масштаб можно выставить и мимо панели Display — правкой конфига или разовым
# hyprctl. Тогда его нет ни в monOverrides, ни в monitors_data.lua, и сохранять
# нечего: обновление возвращает 100%. Здесь, до установки, дописываем в
# monOverrides текущий масштаб тех мониторов, которых там ещё нет, — и он
# уезжает в стэш вместе с settings.json, а после обновления оболочка накатит
# его сама. Трогаем только экраны с масштабом не 100%: дефолтные незачем
# прибивать к конкретному режиму.
snapshot_live_monitors() {
    have hyprctl && have jq || return 0
    local cfg="$CONF/panacea/settings.json"
    [ -f "$cfg" ] || return 0
    local live; live="$(hyprctl -j monitors 2>/dev/null)" || return 0
    [ -n "$live" ] && [ "$live" != "null" ] || return 0

    # monOverrides лежит строкой с JSON внутри; пусто — берём {}
    local cur; cur="$(jq -r '.monOverrides // ""' "$cfg")"
    case "$cur" in ""|null) cur="{}" ;; esac

    local merged
    merged="$(jq -cn --argjson cur "$cur" --argjson live "$live" '
        reduce $live[] as $m ($cur;
            if has($m.name) then .
            elif ((($m.scale * 100) | round) == 100) then .
            else . + { ($m.name): {
                w:  $m.width,
                h:  $m.height,
                rr: ($m.refreshRate | round),
                scale: $m.scale,
                transform: ($m.transform // 0),
                vrr: false,
                pos: "\($m.x)x\($m.y)"
            } } end)
    ' 2>/dev/null)" || return 0
    [ -n "$merged" ] && [ "$merged" != "$cur" ] || return 0

    local tmp; tmp="$(mktemp)"
    if jq --arg mo "$merged" '.monOverrides = $mo' "$cfg" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$cfg"
        # Пересобрать конфиг компоновщика из обновлённого settings.json, чтобы
        # свежий monitors_data.lua тоже попал в стэш и пережил установку.
        [ -x "$CONF/panacea/scripts/genmonitors.sh" ] \
            && "$CONF/panacea/scripts/genmonitors.sh" >/dev/null 2>&1
    else
        rm -f "$tmp"
    fi
}

stash_user_state() {
    # До стэша снимаем живой масштаб в settings.json — иначе выставленный мимо
    # панели пропал бы: сохранять было бы нечего.
    snapshot_live_monitors

    # Стэш рядом с конфигом, а не в /tmp: тот почти везде tmpfs, то есть
    # оперативная память. У того, кто скачал набор обоев, в hypr/wallpaper
    # лежат сотни мегабайт — они уезжали в память целиком, и на машине без
    # запаса это уходило в подкачку. Каталоги переносим: внутри одного
    # раздела это переименование и не зависит от объёма.
    STASH="$CONF/.panacea-update-stash"
    rm -rf "$STASH"; mkdir -p "$STASH"
    local f
    for f in "${KEEP[@]}"; do
        [ -f "$f" ] && { mkdir -p "$STASH/$(dirname "${f#$HOME/}")"; cp "$f" "$STASH/${f#$HOME/}"; }
    done
    for f in "${KEEP_DIRS[@]}"; do
        [ -d "$f" ] || continue
        mkdir -p "$STASH/$(dirname "${f#$HOME/}")"
        mv "$f" "$STASH/${f#$HOME/}" 2>/dev/null \
            || cp -r "$f" "$STASH/${f#$HOME/}"
    done
}

restore_user_state() {
    [ -n "${STASH:-}" ] && [ -d "$STASH" ] || return 0
    local f
    for f in "${KEEP[@]}"; do
        if [ -f "$STASH/${f#$HOME/}" ]; then
            mkdir -p "$(dirname "$f")"
            if [ "$f" = "$CONF/panacea/settings.json" ] && command -v jq >/dev/null 2>&1 && [ -f "$f" ]; then
                local tmp_json
                tmp_json="$(mktemp)"
                if jq -s '.[0] * .[1]' "$f" "$STASH/${f#$HOME/}" > "$tmp_json" 2>/dev/null; then
                    mv "$tmp_json" "$f"
                else
                    rm -f "$tmp_json"
                    cp "$STASH/${f#$HOME/}" "$f"
                fi
            else
                cp "$STASH/${f#$HOME/}" "$f"
            fi
        fi
    done
    # Каталоги возвращаем содержимым, а не целиком: установщик уже создал
    # пустой каталог с тем же именем, и `cp -r dir dst` положил бы наши файлы
    # внутрь него вторым уровнем — обои человека уезжали в wallpaper/wallpaper.
    # Файлы из свежей установки при этом остаются: своё кладём поверх.
    local item base
    for f in "${KEEP_DIRS[@]}" "${KEEP_DIRS_SOFT[@]}"; do
        [ -d "$STASH/${f#$HOME/}" ] || continue
        # мягкий каталог: свежие файлы оболочки остаются на месте
        local soft=0 d
        for d in "${KEEP_DIRS_SOFT[@]}"; do [ "$d" = "$f" ] && soft=1; done
        mkdir -p "$f"
        # По одному и переносом: набор обоев так возвращается мгновенно.
        for item in "$STASH/${f#$HOME/}"/* "$STASH/${f#$HOME/}"/.[!.]*; do
            [ -e "$item" ] || continue
            base="$(basename "$item")"
            [ "$soft" = "1" ] && [ -e "$f/$base" ] && continue
            rm -rf "$f/$base"
            mv "$item" "$f/$base" 2>/dev/null || cp -r "$item" "$f/$base"
        done
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

    # Берём последние коммиты ветки, а не сравнение with...to.
    #
    # Сравнение возвращало заодно и полные диффы каждого файла в каждом
    # коммите, поэтому ответ рос вместе с отставанием: 0.4 МБ на сорока
    # коммитах, 2 МБ на двухстах. У кого оболочка не обновлялась полгода,
    # обновление вставало на этом запросе на секунды. Хуже того, у сравнения
    # есть предел в 250 коммитов — дальше список приходил молча урезанным.
    #
    # Список изменений всё равно обрезается сорока строками, так что просить
    # больше шестидесяти коммитов незачем ни при каком отставании. Ответ на
    # такой запрос всегда одного размера — около 0.3 МБ, — и не зависит от
    # того, как давно человек обновлялся.
    local json
    json="$(curl -fsSL --max-time 10 \
        "https://api.github.com/repos/$REPO/commits?sha=$BRANCH&per_page=60" 2>/dev/null)" \
        || return 0
    [ -n "$json" ] || return 0

    # Идём от свежих к старым и останавливаемся на той версии, что стоит у
    # человека: всё, что выше неё, — и есть новое. Не нашли (отстал больше
    # чем на шестьдесят коммитов) — показываем всё, что пришло, и фильтр
    # обрежет до сорока.
    {
        printf '%s\n' "$to"
        if have jq; then
            printf '%s' "$json" \
                | jq -r '.[] | "\(.sha)\t\(.commit.message | split("\n")[0])"' 2>/dev/null \
                | awk -F'\t' -v from="$from" '$1 == from { exit } { print $2 }' \
                | changelog_filter
        else
            # Без jq — по строкам. Порядок полей в ответе постоянный: sha
            # каждого коммита идёт раньше его message.
            printf '%s' "$json" \
                | grep -oE '"sha": *"[0-9a-f]{40}"|"message": *"[^"]*"' \
                | sed 's/"sha": *"/S/; s/"message": *"/M/; s/"$//; s/\\n.*//' \
                | awk -v from="$from" '
                    /^S/ { sha = substr($0, 2); next }
                    /^M/ {
                        # у каждого коммита sha повторяется дважды подряд
                        # (сам коммит и его дерево) — берём первое
                        if (sha == from) exit
                        print substr($0, 2)
                    }' \
                | changelog_filter
        fi
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

    # Клон мог приехать от прежней копии скрипта — при самообновлении она
    # уже всё скачала. Проверяем, что это действительно наш каталог, а не
    # оставшийся от чужого запуска: без install.sh дальше делать нечего.
    if [ -n "${PANACEA_SRC:-}" ] && [ -f "$PANACEA_SRC/install.sh" ]; then
        echo "step=download"
        rm -rf "$tmp"
        tmp="$(dirname "$PANACEA_SRC")"
        trap 'rm -rf "${tmp:-}"' EXIT
    else
        echo "step=download"
        # --no-tags: метки в оболочке не используются, а тянутся вместе с
        # ветками. Один коммит без истории — всё, что нужно для установки.
        git clone --depth 1 --single-branch --no-tags --branch "$BRANCH" \
            "$GIT_URL" "$tmp/src" >/dev/null 2>&1 \
            || { echo "status=error"; echo "error=download"; exit 1; }
    fi

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
        trap - EXIT
        # Отдаём свежему скрипту уже скачанный клон, а не заставляем качать
        # второй раз. Клонирование — самый долгий шаг обновления, и при смене
        # самого update.sh оно шло дважды подряд, удваивая ожидание на ровном
        # месте. Каталог за собой убирает тот, кто им закончил.
        PANACEA_SRC="$tmp/src" PANACEA_SELFEXEC=1 bash "$fresh" apply
        rc=$?
        rm -f "$fresh"
        rm -rf "$tmp"
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
            --no-services --no-wallpapers --no-restart --no-backup --yes >"$tmp/log" 2>&1); then
        restore_user_state
        echo "status=error"
        echo "error=install"
        echo "log=$tmp/log"
        exit 1
    fi

    # Тема экрана входа живёт в /usr/share, и обновление её не трогало: она
    # ставится с sudo, а спросить пароль обновлению негде — оно идёт из
    # панели, без терминала. Выходило, что тема замирала на той версии, с
    # которой её поставили однажды, и все правки экрана входа до человека
    # просто не доезжали.
    #
    # Обновляем через pkexec: агент polkit у оболочки есть, и он покажет
    # обычное окно запроса пароля. Отказались или агента нет — пропускаем
    # молча, обновление из-за этого падать не должно.
    if [ -d /usr/share/sddm/themes/panacea ] \
       && [ -d "$tmp/src/sddm/panacea" ] \
       && ! diff -rq /usr/share/sddm/themes/panacea "$tmp/src/sddm/panacea" >/dev/null 2>&1
    then
        echo "step=greeter"
        if command -v pkexec >/dev/null 2>&1; then
            pkexec sh -c '
                rm -rf /usr/share/sddm/themes/panacea &&
                cp -r "$1" /usr/share/sddm/themes/panacea
            ' _ "$tmp/src/sddm/panacea" >/dev/null 2>&1 || true
        fi
    fi

    echo "step=restore"
    restore_user_state

    # Новая версия могла добавить зависимости, а ставим мы с --no-deps:
    # хватать пакеты без спроса, да ещё и через sudo из-под кнопки в
    # настройках, — не то, чего ждут от обновления. Поэтому только называем
    # их, а поставит человек сам. Список берём у установщика, чтобы он не
    # разошёлся с настоящим.
    #
    # Кладём в файл рядом со списком изменений: оболочка после обновления
    # перезапускается, и вывод этого скрипта читать будет уже некому. Экран
    # «что нового» покажет обе новости разом и оба файла сотрёт.
    missing="$(cd "$tmp/src" && bash ./install.sh --print-missing 2>/dev/null | tr '\n' ' ')"
    missing="${missing% }"
    if [ -n "$missing" ]; then
        printf '%s\n' "$missing" > "$CONF/panacea/.missingdeps"
        echo "missing=$missing"
    else
        rm -f "$CONF/panacea/.missingdeps"
    fi

    # И обратное: что оболочка ставила раньше, а теперь не использует. Удалять
    # сами не будем — человек мог поставить waybar или tofi для себя, и чужое
    # за него не трогают. Просто называем.
    obsolete="$(cd "$tmp/src" && bash ./install.sh --print-obsolete 2>/dev/null | tr '\n' ' ')"
    obsolete="${obsolete% }"
    if [ -n "$obsolete" ]; then
        printf '%s\n' "$obsolete" > "$CONF/panacea/.obsoletedeps"
        echo "obsolete=$obsolete"
    else
        rm -f "$CONF/panacea/.obsoletedeps"
    fi

    # voxtype (голос → текст): проверяем модели, обновляем конфиг и перезапускаем
    local vox_cmd
    vox_cmd="$(command -v voxtype 2>/dev/null || true)"
    [ -z "$vox_cmd" ] && [ -x "/usr/lib/voxtype/voxtype-vulkan" ] && vox_cmd="/usr/lib/voxtype/voxtype-vulkan"
    [ -z "$vox_cmd" ] && [ -x "/usr/bin/voxtype" ] && vox_cmd="/usr/bin/voxtype"

    if [ -n "$vox_cmd" ]; then
        local models_dir="$HOME/.local/share/voxtype/models"
        mkdir -p "$models_dir" "$CONF/voxtype"

        # Обновляем конфиг voxtype из актуального шаблона
        if [ -f "$CONF/panacea/scripts/voxtype.config.toml" ]; then
            cp "$CONF/panacea/scripts/voxtype.config.toml" "$CONF/voxtype/config.toml"
        fi

        # Vulkan GPU ускорение
        if [ -x "/usr/lib/voxtype/voxtype-vulkan" ]; then
            mkdir -p "$HOME/.local/bin" "$CONF/systemd/user/voxtype.service.d"
            ln -sf /usr/lib/voxtype/voxtype-vulkan "$HOME/.local/bin/voxtype"
            cat << 'EOF' > "$CONF/systemd/user/voxtype.service.d/override.conf"
[Service]
ExecStart=
ExecStart=/usr/lib/voxtype/voxtype-vulkan -q daemon
Environment="VOXTYPE_VULKAN_DEVICE=amd"
EOF
            systemctl --user daemon-reload >/dev/null 2>&1 || true
        fi

        # Проверка и скачивание модели Medium, если её ещё нет
        if [ ! -f "$models_dir/ggml-medium.bin" ]; then
            echo "step=voxtype_model"
            if command -v curl >/dev/null 2>&1; then
                curl -sL "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin" -o "$models_dir/ggml-medium.bin" 2>/dev/null || true
            else
                "$vox_cmd" setup --download --model medium >/dev/null 2>&1 || true
            fi
        fi

        # Silero VAD
        if [ ! -f "$models_dir/ggml-silero-vad.bin" ]; then
            if command -v curl >/dev/null 2>&1; then
                curl -sL "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-silero-vad.bin" -o "$models_dir/ggml-silero-vad.bin" 2>/dev/null || true
            fi
        fi

        systemctl --user enable --now voxtype.service >/dev/null 2>&1 || true
        systemctl --user restart voxtype.service >/dev/null 2>&1 || true
    fi

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
