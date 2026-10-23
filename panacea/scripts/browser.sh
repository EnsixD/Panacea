#!/bin/bash
# Браузер по умолчанию.
#   browser.sh list  -> desktop-файл|Название   (все установленные браузеры)
#   browser.sh get   -> desktop-файл текущего
#   browser.sh set D -> сделать D браузером по умолчанию
case "$1" in
    list)
        python3 - <<'PY'
import configparser, os
dirs = [os.path.expanduser("~/.local/share/applications"),
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
        "/var/lib/flatpak/exports/share/applications",
        "/usr/local/share/applications", "/usr/share/applications"]
seen = {}
for d in dirs:
    if not os.path.isdir(d): continue
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".desktop") or fn in seen: continue
        cp = configparser.RawConfigParser(strict=False)
        try:
            cp.read(os.path.join(d, fn), encoding="utf-8"); e = cp["Desktop Entry"]
        except Exception:
            continue
        if e.get("NoDisplay", "false").lower() == "true": continue
        cats = e.get("Categories", ""); mimes = e.get("MimeType", "")
        if "WebBrowser" in cats or "x-scheme-handler/https" in mimes:
            seen[fn] = e.get("Name", fn)
for fn, name in sorted(seen.items(), key=lambda t: t[1].lower()):
    print(f"{fn}|{name}")
PY
        ;;
    get)
        xdg-settings get default-web-browser 2>/dev/null \
            || xdg-mime query default x-scheme-handler/https 2>/dev/null
        ;;
    set)
        D="${2:?}"
        case "$D" in *.desktop) ;; *) exit 1 ;; esac
        xdg-settings set default-web-browser "$D" 2>/dev/null
        # xdg-settings на «чужом» окружении трогает не всё — дописываем сами
        for m in x-scheme-handler/http x-scheme-handler/https text/html \
                 application/xhtml+xml x-scheme-handler/about x-scheme-handler/unknown; do
            xdg-mime default "$D" "$m"
        done
        ;;
esac
