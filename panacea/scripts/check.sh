#!/bin/bash
# Синтаксическая проверка QML пилюли — до того, как её запустят.
#
# Опечатка в QML роняет оболочку целиком, и узнать об этом на живой системе,
# оставшись без панели, неприятно. qmllint читает файлы, не запуская их.
#
# Проверяется только синтаксис. Глубокий режим (-U) здесь бесполезен: типов
# Quickshell в qmltypes нет, и он выдаёт сотни «Process was not found» —
# в таком шуме настоящая ошибка теряется.
#
# qmllint из Qt 6.11.1 сообщает об ошибке только кодом возврата: ни строки,
# ни текста он больше не печатает (в 6.9 печатал). Поэтому скрипт называет
# файл, а за строкой идти к самой оболочке — `qs -c panacea` выведет её
# с позицией.
#
# Два файла Qt 6.11 не осиливает вовсе: qmllint и qmlformat спотыкаются об
# аннотацию `function foo(): void`, хотя она законна и обязательна — без
# указания типа Quickshell не выставляет функцию наружу, а через IPC ходят
# все сочетания Hyprland. Это баг инструментов, а не кода, поэтому такие
# файлы пропускаются с явной отметкой, а не правятся под парсер.
#
#   check.sh            проверить ~/.config/panacea
#   check.sh DIR        проверить другой каталог

DIR="${1:-$HOME/.config/panacea}"
cd "$DIR" 2>/dev/null || { echo "нет каталога $DIR" >&2; exit 2; }

command -v qmllint >/dev/null || { echo "qmllint не установлен" >&2; exit 2; }

fail=0
skipped=()

for f in *.qml; do
    [ -e "$f" ] || continue
    # `): void` и `): var` — то, на чём падает парсер Qt 6.11
    if grep -qE '\): (void|var)\b' "$f"; then
        skipped+=("$f")
        continue
    fi
    if ! out=$(qmllint "$f" 2>&1); then
        echo "✗ $f"
        [ -n "$out" ] && printf '%s\n' "$out"
        fail=1
    fi
done

if [ "${#skipped[@]}" -gt 0 ]; then
    printf '· пропущено (Qt не разбирает «: void»): %s\n' "${skipped[*]}"
fi

if [ "$fail" -eq 0 ]; then
    echo "✓ синтаксис в порядке"
fi

# ------------------------------------------------------------- переводы
# Экран «что нового» показывает заголовки коммитов, а история ведётся
# по-английски: без строки в словаре WhatsNewView заголовок покажется не на
# языке интерфейса. Забыть её легко — коммит и словарь лежат в разных местах,
# поэтому сверяем здесь, пока не запушено.
#
# Проверяется только запуск из клона: в ~/.config/panacea истории нет.
if [ -d .git ] && command -v git >/dev/null && [ -f panacea/WhatsNewView.qml ]; then
    # Только то, что ещё не уехало: у выпущенных коммитов экран уже показан,
    # и переводить их задним числом незачем. Без upstream берём всё после
    # последнего поднятия версии — это и есть последний выпуск.
    range="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
    if [ -n "$range" ]; then
        range="$range..HEAD"
    else
        last_rel="$(git log --format='%H %s' -200 \
                    | grep -im1 '^[0-9a-f]* shell: bump version' | cut -d' ' -f1)"
        range="${last_rel:+$last_rel..HEAD}"
    fi

    missing=0
    while IFS= read -r subject; do
        [ -n "$subject" ] || continue
        grep -qF "\"$subject\":" panacea/WhatsNewView.qml || {
            [ "$missing" -eq 0 ] && echo "нет перевода в WhatsNewView.qml:"
            echo "    $subject"
            missing=$((missing + 1))
        }
    done < <(git log --format=%s $range 2>/dev/null \
             | grep -v '^Merge ' \
             | grep -viE '^(shell: bump version|gitignore|readme|docs|ci)\b' \
             | grep -viE '^(update|bump) (the )?(readme|docs|version)\b')

    if [ "$missing" -gt 0 ]; then
        fail=1
    else
        echo "✓ у всех невыпущенных коммитов есть перевод"
    fi

    # Обратная сторона: словарь не должен копить перевод к тому, что уже
    # никогда не покажут. Дальше сорока значимых коммитов не заглянет никто —
    # ровно на них update.sh обрезает список (changelog_filter, head -40),
    # сколько бы версий человек ни пропустил.
    stale=0
    window="$(git log --format=%s -300 \
              | grep -v '^Merge ' \
              | grep -viE '^(shell: bump version|gitignore|readme|docs|ci)\b' \
              | grep -viE '^(update|bump) (the )?(readme|docs|version)\b' \
              | head -40)"
    while IFS= read -r entry; do
        [ -n "$entry" ] || continue
        printf '%s\n' "$window" | grep -qxF "$entry" || {
            [ "$stale" -eq 0 ] && echo "устарело в WhatsNewView.qml (можно убрать):"
            echo "    $entry"
            stale=$((stale + 1))
        }
    done < <(grep -oP '^\s+"\K[^"]+(?=":$)' panacea/WhatsNewView.qml)

    [ "$stale" -eq 0 ] && echo "✓ в словаре нет устаревших записей"

    # Список ненужных пакетов держат ради тех, кто ставил оболочку до того,
    # как они перестали быть нужны. Через несколько версий таких копий не
    # остаётся, и список сам становится тем мусором, ради уборки которого
    # заведён. Напоминаем — удалять за автора не наше дело.
    ver="$(grep -oP 'property string version: "\K[^"]+' panacea/shell.qml)"
    if [ -n "$ver" ] && [ -f install.sh ]; then
        cur_patch="${ver##*.}"
        rot=0
        while IFS='|' read -r pkg since; do
            [ -n "$since" ] || continue
            # сравниваем только последнюю цифру: версия растёт на 0.0.1
            age=$(( cur_patch - ${since##*.} ))
            if [ "$age" -ge 5 ]; then
                [ "$rot" -eq 0 ] && echo "устарел список ненужных пакетов в install.sh:"
                echo "    $pkg (не нужен с $since, сейчас $ver — прошло $age выпусков)"
                rot=$((rot + 1))
            fi
        done < <(sed -n '/^OBSOLETE_PKGS=(/,/^)/p' install.sh \
                 | grep -oP '^\s+"\K[^"]+')
        [ "$rot" -eq 0 ] && echo "✓ список ненужных пакетов ещё в силе"
    fi
fi

exit "$fail"
