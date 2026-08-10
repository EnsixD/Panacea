#!/bin/bash
# Хранилище паролей пилюли.
#
# Всё лежит в одном файле, зашифрованном AES-256 на пароле пользователя —
# том самом, что спрашивает sudo. Ключ нигде не сохраняется: пилюля держит
# его в памяти, пока хранилище открыто, и забывает через 15 минут простоя.
# Если файл утащат, без пароля из него ничего не достать.
#
#   vault.sh load          stdin: пароль            stdout: JSON-массив
#   vault.sh save          stdin: пароль, затем JSON
#   vault.sh wipe          удалить хранилище целиком
#
# Коды возврата: 0 — успех, 1 — ошибка, 2 — неверный пароль.

set -u

DIR="$HOME/.local/share/panacea"
STORE="$DIR/vault.enc"
ITER=240000

mkdir -p "$DIR"
chmod 700 "$DIR" 2>/dev/null

# Пароль передаём openssl через файл в tmpfs, а не аргументом и не через
# окружение: аргументы видны в списке процессов.
PWFILE=""
cleanup() { [ -n "$PWFILE" ] && rm -f "$PWFILE"; }
trap cleanup EXIT

read_pw() {
    PWFILE="$(mktemp "${XDG_RUNTIME_DIR:-/dev/shm}/panacea-vault.XXXXXX")"
    chmod 600 "$PWFILE"
    IFS= read -r pw || return 1
    printf '%s' "$pw" > "$PWFILE"
    unset pw
}

case "${1:-}" in
load)
    read_pw || exit 1
    if [ ! -s "$STORE" ]; then
        # хранилища ещё нет — это не ошибка, просто пусто
        echo "[]"
        exit 0
    fi
    out="$(openssl enc -d -aes-256-cbc -pbkdf2 -iter "$ITER" \
            -in "$STORE" -pass file:"$PWFILE" 2>/dev/null)" || exit 2
    # расшифровалось, но мусором — тоже считаем неверным паролем
    printf '%s' "$out" | jq -e 'type == "array"' >/dev/null 2>&1 || exit 2
    printf '%s' "$out"
    ;;

save)
    read_pw || exit 1
    body="$(cat)"
    printf '%s' "$body" | jq -e 'type == "array"' >/dev/null 2>&1 || exit 1
    tmp="$STORE.new"
    printf '%s' "$body" | openssl enc -aes-256-cbc -pbkdf2 -iter "$ITER" \
        -salt -out "$tmp" -pass file:"$PWFILE" || { rm -f "$tmp"; exit 1; }
    chmod 600 "$tmp"
    mv "$tmp" "$STORE"
    ;;

wipe)
    rm -f "$STORE"
    ;;

*)
    echo "usage: vault.sh load|save|wipe" >&2
    exit 1
    ;;
esac
