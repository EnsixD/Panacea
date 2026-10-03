import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Launchpad: все приложения сеткой на весь экран, поверх размытого рабочего
// стола. Живёт рядом со списком по Super+A, а не вместо него: список — чтобы
// найти по имени, сетка — чтобы найти глазами.
//
// Раскладка своя у каждого: порядок плиток и папки лежат в
// ~/.local/share/panacea/launchpad.json. Не в ~/.config/panacea — тот
// каталог обновление перезаписывает целиком, а раскладку собирают руками
// и терять её из-за обновления нельзя. Новые приложения, которых в файле
// ещё нет, встают в конец по алфавиту.
//
// Папки — как на macOS: перетащить приложение на другое — получится папка,
// на папку — приложение ляжет в неё, из папки наружу — вернётся в сетку.
// То же самое есть и в меню по правой кнопке, для тех, кто не любит
// перетаскивать.
FocusScope {
    id: view
    property var sys
    // открыт ли слой; отдаётся оболочкой
    property bool open: false
    // экран, который размываем под сеткой
    property var outputScreen: null

    focus: true

    // ------------------------------------------------------------ сетка
    readonly property int cols: 7
    readonly property int rows: 5
    readonly property int perPage: cols * rows

    // Клетка подстраивается под экран, но не раздувается на широких:
    // семь колонок по 170 px — уже почти макбучная ширина.
    readonly property real gridW: Math.min(width * 0.84, cols * 170)
    readonly property real cellW: gridW / cols
    readonly property real cellH: Math.max(60, pages.height / rows)
    readonly property real iconSize: Math.min(96, Math.min(cellW, cellH) * 0.56)

    // где на экране начинается сетка текущей страницы
    readonly property real gridX: pages.x + (pages.width - cols * cellW) / 2
    readonly property real gridY: pages.y + (pages.height - rows * cellH) / 2

    // ------------------------------------------------------------ данные
    readonly property string dataDir:
        (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share"))
        + "/panacea"

    // { order: ["app:<id>" | "folder:<fid>"], folders: { fid: {name, apps: [id]} } }
    property var layout: ({ order: [], folders: {} })

    Process {
        id: pMkdir
        command: ["mkdir", "-p", view.dataDir]
        running: true
        onExited: layoutFile.reload()
    }

    FileView {
        id: layoutFile
        path: view.dataDir + "/launchpad.json"
        printErrors: false
        // раскладку можно править и руками: подхватываем без перезапуска
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var j = JSON.parse(text());
                view.layout = {
                    order: Array.isArray(j.order) ? j.order : [],
                    folders: (j.folders && typeof j.folders === "object") ? j.folders : {}
                };
            } catch (e) {
                view.layout = { order: [], folders: {} };
            }
        }
    }

    function commit(L) {
        view.layout = L;
        layoutFile.setText(JSON.stringify(L, null, 2) + "\n");
    }

    // Тот же список недавних, что у лаунчера: запущенное отсюда наверху и
    // в списке по Super+A.
    readonly property string recentFile:
        (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
        + "/panacea/recent-apps"
    Process { id: pRecent }
    function rememberApp(id) {
        pRecent.command = ["sh", "-c",
            "f=\"$1\"; mkdir -p \"$(dirname \"$f\")\"; "
            + "{ printf '%s\\n' \"$2\"; grep -vxF \"$2\" \"$f\" 2>/dev/null | head -n 19; } > \"$f.tmp\" "
            + "&& mv \"$f.tmp\" \"$f\"",
            "_", view.recentFile, id];
        pRecent.running = true;
    }

    // Список приложений приходит по одному, и пересобирать на каждое всю
    // сетку из сотен иконок — это секунды подвисания. Собираем раз, когда
    // поток затих.
    property var appMap: ({})
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { appsSettle.restart(); }
    }
    Timer { id: appsSettle; interval: 120; onTriggered: pHidden.running = true }

    // Что на этом столе не показывать (OnlyShowIn/NotShowIn/Hidden):
    // Quickshell этих ключей не отдаёт, читаем файлы сами — см. скрипт.
    property var hiddenIds: ({})
    Process {
        id: pHidden
        command: ["sh", view.sys.scriptDir + "/desktop_hidden.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                var h = {};
                String(text).split("\n").forEach(x => { if (x.length) h[x] = true; });
                view.hiddenIds = h;
                view.rebuildApps();
            }
        }
    }

    function rebuildApps() {
        var all = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        var m = {};
        // Одна и та же программа, поставленная дважды (из пакета и
        // собранная в /usr/local), даёт две записи с одним именем и
        // командой. Оставляем одну — с обратно-доменным id, если есть: это
        // имя, под которым её ставит сам проект.
        var twin = {};
        for (var i = 0; i < all.length; i++) {
            var a = all[i];
            if (!a || a.noDisplay || !a.id) continue;
            var id = String(a.id);
            if (view.hiddenIds[id]) continue;
            var sig = String(a.name) + "\u0001" + String(a.execString || a.command || "");
            var prev = twin[sig];
            if (prev !== undefined) {
                if (prev.indexOf(".") >= 0 || id.indexOf(".") < 0) continue;
                delete m[prev];
            }
            twin[sig] = id;
            m[id] = a;
        }
        view.appMap = m;
    }

    function byName(x, y) {
        return String(x.name || "").localeCompare(String(y.name || ""));
    }

    // Плитки главной сетки по порядку: приложения и папки. Всё, чего в
    // раскладке нет, дописывается в конец, а то, чего больше нет на машине,
    // молча пропускается — файл при этом не трогаем, пока его не правят.
    readonly property var entries: {
        var map = view.appMap;
        var L = view.layout;
        var folders = L.folders || {};
        var used = {}, placed = {}, out = [];

        var folderEntry = function (fid) {
            var f = folders[fid];
            var apps = [];
            var ids = (f && Array.isArray(f.apps)) ? f.apps : [];
            for (var j = 0; j < ids.length; j++) {
                var id = String(ids[j]);
                if (map[id] && !used[id]) { used[id] = true; apps.push(map[id]); }
            }
            if (!apps.length) return null;
            return { key: "folder:" + fid, kind: "folder", fid: fid,
                     name: String(f.name || view.sys.tr("Папка")), apps: apps };
        };

        var order = L.order || [];
        for (var i = 0; i < order.length; i++) {
            var k = String(order[i]);
            if (k.indexOf("folder:") === 0) {
                var fid = k.slice(7);
                if (placed[fid] || !folders[fid]) continue;
                placed[fid] = true;
                var fe = folderEntry(fid);
                if (fe) out.push(fe);
            } else if (k.indexOf("app:") === 0) {
                var aid = k.slice(4);
                // приложение, которое лежит в папке, в сетке не дублируем
                if (!map[aid] || used[aid] || view.inSomeFolder(aid)) continue;
                used[aid] = true;
                out.push({ key: k, kind: "app", id: aid, app: map[aid], name: map[aid].name });
            }
        }
        for (var f2 in folders) {
            if (placed[f2]) continue;
            var fe2 = folderEntry(f2);
            if (fe2) out.push(fe2);
        }
        var rest = [];
        for (var id2 in map) if (!used[id2]) rest.push(map[id2]);
        rest.sort(view.byName);
        for (var r = 0; r < rest.length; r++)
            out.push({ key: "app:" + rest[r].id, kind: "app", id: String(rest[r].id),
                       app: rest[r], name: rest[r].name });
        return out;
    }

    function inSomeFolder(id) {
        var folders = view.layout.folders || {};
        for (var fid in folders) {
            var a = folders[fid].apps;
            if (Array.isArray(a) && a.indexOf(id) >= 0 && view.folderHasLive(fid)) return true;
        }
        return false;
    }
    function folderHasLive(fid) {
        var a = (view.layout.folders[fid] || {}).apps || [];
        for (var i = 0; i < a.length; i++) if (view.appMap[a[i]]) return true;
        return false;
    }

    // --------------------------------------------------------------- поиск
    property string query: ""
    readonly property bool searching: query.trim().length > 0

    readonly property var results: {
        var q = query.trim().toLowerCase();
        if (!q.length) return [];
        var starts = [], contains = [];
        for (var id in view.appMap) {
            var a = view.appMap[id];
            var n = String(a.name || "").toLowerCase();
            var pos = n.indexOf(q);
            var e = { key: "app:" + id, kind: "app", id: id, app: a, name: a.name };
            if (pos === 0) starts.push(e);
            else if (pos > 0 || String(a.genericName || "").toLowerCase().indexOf(q) >= 0
                     || String(a.keywords || "").toLowerCase().indexOf(q) >= 0)
                contains.push(e);
        }
        starts.sort(view.byName); contains.sort(view.byName);
        return starts.concat(contains);
    }

    readonly property var shown: searching ? results : entries
    readonly property int pageCount: Math.max(1, Math.ceil(shown.length / perPage))

    function pageSlice(p) {
        return view.shown.slice(p * view.perPage, (p + 1) * view.perPage);
    }

    // выделение с клавиатуры: -1 — ничего, пока не нажали стрелку
    property int sel: -1

    onQueryChanged: {
        view.sel = view.searching ? 0 : -1;
        pages.currentIndex = 0;
    }

    // ------------------------------------------------------- правка раскладки
    // Каждая правка начинается со снимка того, что сейчас на экране: так в
    // файл попадает и порядок новых приложений, а не только тронутых.
    function snapshot() {
        var src = view.layout.folders || {};
        var folders = {};
        for (var fid in src) {
            if (!view.folderHasLive(fid)) continue;
            folders[fid] = { name: String(src[fid].name || ""),
                             apps: (src[fid].apps || []).slice() };
        }
        return { order: view.entries.map(e => e.key), folders: folders };
    }

    // Вынуть приложение оттуда, где оно сейчас: из сетки или из папки.
    // Опустевшая папка исчезает вместе со своей плиткой.
    function takeApp(L, id, fromFid) {
        if (fromFid && L.folders[fromFid]) {
            var a = L.folders[fromFid].apps;
            var i = a.indexOf(id);
            if (i >= 0) a.splice(i, 1);
            if (!a.length) {
                delete L.folders[fromFid];
                var fi = L.order.indexOf("folder:" + fromFid);
                if (fi >= 0) L.order.splice(fi, 1);
            }
        } else {
            var oi = L.order.indexOf("app:" + id);
            if (oi >= 0) L.order.splice(oi, 1);
        }
    }

    function insertBefore(L, key, beforeKey) {
        var at = beforeKey ? L.order.indexOf(beforeKey) : -1;
        if (at < 0) L.order.push(key); else L.order.splice(at, 0, key);
    }

    // Переставить плитку главной сетки (приложение или папку) перед другой.
    function moveEntry(key, beforeKey) {
        if (key === beforeKey) return;
        var L = view.snapshot();
        var i = L.order.indexOf(key);
        if (i < 0) return;
        L.order.splice(i, 1);
        view.insertBefore(L, key, beforeKey);
        view.commit(L);
    }

    // Приложение из папки — обратно в сетку.
    // beforeKey: ключ плитки, перед которой встать; null — в самый конец;
    // "" — рядом с папкой (или на её место, если папка опустела).
    function moveOut(id, fromFid, beforeKey) {
        var L = view.snapshot();
        var key = "app:" + id;
        var fkey = "folder:" + fromFid;
        var fat = L.order.indexOf(fkey);
        view.takeApp(L, id, fromFid);
        if (beforeKey === null) {
            L.order.push(key);
        } else if (beforeKey === "" || beforeKey === fkey) {
            if (fat < 0) L.order.push(key);
            else L.order.splice(L.order.indexOf(fkey) >= 0 ? fat + 1 : fat, 0, key);
        } else {
            view.insertBefore(L, key, beforeKey);
        }
        view.commit(L);
    }

    function guessFolderName(a, b) {
        var names = {
            Development: "Разработка", Graphics: "Графика", Office: "Офис",
            Game: "Игры", AudioVideo: "Мультимедиа", Audio: "Мультимедиа",
            Video: "Мультимедиа", Network: "Интернет", Utility: "Утилиты",
            System: "Система", Settings: "Настройки", Education: "Образование",
            Science: "Наука"
        };
        // categories приходит списком Qt, а не массивом JS: длины у него
        // может не быть, поэтому разбираем через строку
        var cats = x => (x && x.categories) ? String(x.categories).split(",") : [];
        var ca = cats(a), cb = cats(b);
        // сперва общая категория обоих, иначе — того, на кого положили
        for (var i = 0; i < ca.length; i++)
            if (names[ca[i]] && cb.indexOf(ca[i]) >= 0) return view.sys.tr(names[ca[i]]);
        for (var j = 0; j < ca.length; j++)
            if (names[ca[j]]) return view.sys.tr(names[ca[j]]);
        return view.sys.tr("Папка");
    }

    // Положить приложение на плитку: на папку — внутрь неё, на приложение —
    // обе плитки становятся новой папкой на месте той, на которую положили.
    function mergeInto(id, fromFid, targetKey) {
        if (targetKey === "app:" + id) return;
        var L = view.snapshot();
        if (targetKey.indexOf("folder:") === 0) {
            var fid = targetKey.slice(7);
            if (fid === fromFid || !L.folders[fid]) return;
            view.takeApp(L, id, fromFid);
            L.folders[fid].apps.push(id);
        } else {
            var tid = targetKey.slice(4);
            var ti = L.order.indexOf(targetKey);
            if (ti < 0) return;
            var nf = "f" + Date.now().toString(36);
            L.folders[nf] = { name: view.guessFolderName(view.appMap[tid], view.appMap[id]),
                              apps: [tid, id] };
            L.order[ti] = "folder:" + nf;
            view.takeApp(L, id, fromFid);
        }
        view.commit(L);
    }

    function newFolderWith(id, fromFid) {
        var L = view.snapshot();
        var nf = "f" + Date.now().toString(36);
        var key = fromFid ? "folder:" + fromFid : "app:" + id;
        var at = L.order.indexOf(key);
        view.takeApp(L, id, fromFid);
        L.folders[nf] = { name: view.sys.tr("Новая папка"), apps: [id] };
        if (fromFid && L.order.indexOf(key) >= 0) at++;      // папка осталась — встаём за ней
        if (at < 0 || at > L.order.length) L.order.push("folder:" + nf);
        else L.order.splice(at, 0, "folder:" + nf);
        view.commit(L);
        view.openFolder(nf, true);
    }

    function reorderInFolder(fid, id, beforeId) {
        if (id === beforeId) return;
        var L = view.snapshot();
        var a = L.folders[fid] ? L.folders[fid].apps : null;
        if (!a) return;
        var i = a.indexOf(id);
        if (i < 0) return;
        a.splice(i, 1);
        var at = beforeId ? a.indexOf(beforeId) : -1;
        if (at < 0) a.push(id); else a.splice(at, 0, id);
        view.commit(L);
    }

    function renameFolder(fid, name) {
        var n = String(name).trim();
        if (!n.length) return;
        var L = view.snapshot();
        if (!L.folders[fid] || L.folders[fid].name === n) return;
        L.folders[fid].name = n;
        view.commit(L);
    }

    // Расформировать: приложения встают в сетку на место папки.
    function dissolveFolder(fid) {
        var L = view.snapshot();
        var f = L.folders[fid];
        if (!f) return;
        var at = L.order.indexOf("folder:" + fid);
        var keys = f.apps.map(x => "app:" + x);
        delete L.folders[fid];
        if (at < 0) L.order = L.order.concat(keys);
        else L.order.splice.apply(L.order, [at, 1].concat(keys));
        view.commit(L);
        if (view.folderId === fid) view.closeFolder();
    }

    // --------------------------------------------------------------- папка
    property string folderId: ""
    readonly property var folder: {
        if (!folderId.length) return null;
        for (var i = 0; i < view.entries.length; i++)
            if (view.entries[i].key === "folder:" + folderId) return view.entries[i];
        return null;
    }
    property int folderSel: -1
    property bool renaming: false

    function openFolder(fid, rename) {
        view.folderId = fid;
        view.folderSel = -1;
        view.renaming = !!rename;
    }
    function closeFolder() {
        if (view.renaming) folderName.commitName();
        view.folderId = "";
        view.renaming = false;
        search.forceActiveFocus();
    }
    // если папку расформировали или она опустела — закрываем
    // через callLater: закрытие меняет folderId прямо во время пересчёта
    // folder, и Qt ругался на петлю привязок
    onFolderChanged: if (folderId.length && !folder && !dragging) Qt.callLater(view.closeFolder)

    // ------------------------------------------------------------- запуск
    function launchApp(app) {
        if (!app) return;
        view.rememberApp(String(app.id));
        app.execute();
        view.sys.closeLaunchpad();
    }
    function activate(e) {
        if (!e) return;
        if (e.kind === "folder") view.openFolder(e.fid, false);
        else view.launchApp(e.app);
    }

    // --------------------------------------------------------- клавиатура
    function moveSel(dx, dy) {
        if (view.folder) {
            var n = view.folder.apps.length, c = folderGrid.fcols;
            var s = view.folderSel < 0 ? 0 : view.folderSel + dx + dy * c;
            view.folderSel = Math.max(0, Math.min(n - 1, s));
            return;
        }
        var total = view.shown.length;
        if (!total) return;
        if (view.sel < 0) {
            view.sel = Math.min(total - 1, pages.currentIndex * view.perPage);
            return;
        }
        var p = Math.floor(view.sel / view.perPage);
        var local = view.sel - p * view.perPage;
        var col = local % view.cols, row = Math.floor(local / view.cols);
        if (dx !== 0) {
            // вправо с последней колонки — на следующую страницу, как на macOS
            col += dx;
            if (col >= view.cols) { if (p + 1 < view.pageCount) { p++; col = 0; } else col = view.cols - 1; }
            if (col < 0) { if (p > 0) { p--; col = view.cols - 1; } else col = 0; }
        }
        if (dy !== 0) row = Math.max(0, Math.min(view.rows - 1, row + dy));
        view.sel = Math.max(0, Math.min(total - 1, p * view.perPage + row * view.cols + col));
        pages.currentIndex = Math.floor(view.sel / view.perPage);
    }

    function enter() {
        if (view.folder) {
            if (view.folderSel >= 0) view.launchApp(view.folder.apps[view.folderSel]);
            return;
        }
        var i = view.sel >= 0 ? view.sel : (view.searching ? 0 : -1);
        if (i >= 0) view.activate(view.shown[i]);
    }

    function goBack() {
        if (menu.visible) { menu.close(); return; }
        if (view.folder) { view.closeFolder(); return; }
        if (view.searching) { search.text = ""; return; }
        view.sys.closeLaunchpad();
    }

    function flip(d) {
        pages.currentIndex = Math.max(0, Math.min(view.pageCount - 1, pages.currentIndex + d));
    }

    // ------------------------------------------------------ перетаскивание
    property bool dragging: false
    property var dragEntry: null       // что тащим
    property string dragFrom: ""       // fid папки, из которой тащим, или ""
    property point dragPos: Qt.point(0, 0)
    // куда положим: слияние с плиткой или вставка перед плиткой
    property string mergeKey: ""
    property bool mergeArmed: false
    property int insertSlot: -1        // глобальный индекс в сетке, -1 — нет
    property int folderInsert: -1      // индекс внутри открытой папки

    readonly property bool canEdit: !searching

    function beginDrag(entry, fromFid, p) {
        view.dragEntry = entry;
        view.dragFrom = fromFid || "";
        view.dragPos = p;
        view.dragging = true;
        view.sel = -1;
        menu.close();
    }

    function overFolderPanel(p) {
        if (!view.folder) return false;
        var q = folderPanel.mapFromItem(view, p.x, p.y);
        return q.x >= 0 && q.y >= 0 && q.x <= folderPanel.width && q.y <= folderPanel.height;
    }

    function dragMove(p) {
        view.dragPos = p;
        // Из папки наружу: папка прячется, дальше тащим уже по сетке.
        if (view.folder && view.dragFrom !== "" && !view.folderHidden && !view.overFolderPanel(p))
            view.folderHidden = true;

        if (view.folder && !view.folderHidden) {
            view.folderInsert = folderGrid.slotAt(folderGrid.mapFromItem(view, p.x, p.y));
            view.setMerge("");
            return;
        }
        view.folderInsert = -1;

        // у края — листаем страницу
        if (p.x < view.gridX - 8) edgeFlip.arm(-1);
        else if (p.x > view.gridX + view.cols * view.cellW + 8) edgeFlip.arm(1);
        else edgeFlip.disarm();

        var cx = (p.x - view.gridX) / view.cellW;
        var cy = (p.y - view.gridY) / view.cellH;
        if (cx < 0 || cy < 0 || cx >= view.cols || cy >= view.rows) {
            view.setMerge("");
            view.insertSlot = -1;
            return;
        }
        var col = Math.floor(cx), row = Math.floor(cy);
        var idx = pages.currentIndex * view.perPage + row * view.cols + col;
        var target = view.shown[idx];
        // центр иконки — зона слияния, края клетки — вставка
        var fx = cx - col - 0.5, fy = (cy - row) - view.iconCenterFrac;
        var near = Math.hypot(fx * view.cellW, fy * view.cellH) < view.iconSize * 0.38;
        var canMerge = target && view.dragEntry.kind === "app"
                       && target.key !== view.dragEntry.key
                       && !(target.kind === "folder" && target.fid === view.dragFrom);
        if (near && canMerge) {
            view.setMerge(target.key);
            view.insertSlot = -1;
        } else {
            view.setMerge("");
            view.insertSlot = Math.min(view.entries.length, idx + (fx > 0 ? 1 : 0));
        }
    }

    // доля высоты клетки, где центр иконки
    readonly property real iconCenterFrac: (cellH * 0.1 + iconSize / 2) / cellH

    function setMerge(k) {
        if (view.mergeKey === k) return;
        view.mergeKey = k;
        view.mergeArmed = false;
        if (k.length) mergeDwell.restart(); else mergeDwell.stop();
    }
    Timer { id: mergeDwell; interval: 320; onTriggered: view.mergeArmed = true }

    Timer {
        id: edgeFlip
        property int dir: 0
        interval: 650
        repeat: true
        function arm(d) { if (dir !== d) { dir = d; restart(); } }
        function disarm() { dir = 0; stop(); }
        onTriggered: view.flip(dir)
    }

    property bool folderHidden: false

    function endDrag(p) {
        if (!view.dragging) return;
        view.dragMove(p);
        var e = view.dragEntry, from = view.dragFrom;
        if (view.folder && !view.folderHidden) {
            if (view.folderInsert >= 0) {
                var apps = view.folder.apps;
                var before = apps[view.folderInsert];
                view.reorderInFolder(from, e.id, before ? String(before.id) : "");
            }
        } else if (view.mergeArmed && view.mergeKey.length) {
            view.mergeInto(e.id, from, view.mergeKey);
        } else if (view.insertSlot >= 0) {
            var b = view.entries[view.insertSlot];
            var bk = b ? b.key : null;
            if (from !== "") view.moveOut(e.id, from, bk);
            else view.moveEntry(e.key, bk);
        } else if (from !== "") {
            // бросили мимо сетки — приложение всё равно выходит из папки
            view.moveOut(e.id, from, "");
        }
        view.cancelDrag();
    }

    function popupMenu(e, fid, p) { menu.popupFor(e, fid, p); }

    function cancelDrag() {
        var wasHidden = view.folderHidden;
        view.dragging = false;
        view.dragEntry = null;
        view.setMerge("");
        view.insertSlot = -1;
        view.folderInsert = -1;
        edgeFlip.disarm();
        view.folderHidden = false;
        if (wasHidden) view.closeFolder();
    }

    // ------------------------------------------------- открытие и закрытие
    // Снимок экрана для размытия держим одним постоянным захватом и только
    // просим новый кадр: пересоздание захвата на каждом открытии стоило
    // около трети секунды. Сетку показываем через пару кадров — композитор
    // к этому времени уже снял экран, пока слой был прозрачным, и сама
    // сетка в размытие не попадает.
    property bool revealed: false

    onOpenChanged: if (open) view.opened(); else { view.revealed = false; revealTimer.stop(); }
    // слой создаётся уже открытым — onOpenChanged при этом не приходит
    Component.onCompleted: { pHidden.running = true; if (open) view.opened(); }

    function opened() {
        view.revealed = false;
        view.query = "";
        search.text = "";
        view.sel = -1;
        view.folderId = "";
        view.cancelDrag();
        menu.close();
        if (shot.hasContent) shot.captureFrame();
        revealTimer.restart();
        search.forceActiveFocus();
    }
    Timer { id: revealTimer; interval: 40; onTriggered: view.revealed = true }

    // ------------------------------------------------------- иконки
    // Поиск иконки в теме с проверкой (iconPath(..., true)) синхронный и
    // медленный — до десятков миллисекунд на штуку, особенно на тех, которых
    // в теме нет. На сотне с лишним плиток открытие вставало на секунды.
    // Поэтому ищем заранее, по паре за раз, пока сетка закрыта, и кладём в
    // кэш; плитка без найденной иконки до тех пор показывает букву.
    property var iconCache: ({})        // id -> путь, "" — иконки нет
    property var iconQueue: []

    // Очередь — в порядке сетки, чтобы первая страница нашлась первой.
    // Через callLater: при первой сборке список плиток ещё не посчитан.
    onAppMapChanged: Qt.callLater(view.queueIcons)
    function queueIcons() {
        var q = [], seen = {};
        var push = function (id) {
            id = String(id);
            if (seen[id] || view.iconCache[id] !== undefined) return;
            seen[id] = true;
            q.push(id);
        };
        var ents = view.entries || [];
        for (var i = 0; i < ents.length; i++) {
            var e = ents[i];
            if (e.kind === "folder") e.apps.forEach(a => push(a.id));
            else push(e.id);
        }
        for (var id in view.appMap) push(id);
        view.iconQueue = q;
        if (q.length) iconWork.start();
    }
    Timer {
        id: iconWork
        interval: 50
        repeat: true
        onTriggered: {
            var q = view.iconQueue;
            if (!q.length) { stop(); return; }
            var c = Object.assign({}, view.iconCache);
            for (var n = 0; n < 3 && q.length; n++) {
                var id = q.shift();
                var a = view.appMap[id];
                c[id] = (a && a.icon) ? String(Quickshell.iconPath(a.icon, true) || "") : "";
            }
            view.iconCache = c;
        }
    }

    readonly property real shown01: (open && revealed) ? 1 : 0
    property real fade: shown01
    Behavior on fade {
        NumberAnimation { duration: view.sys.noMotion ? 0 : 220; easing.type: Easing.OutCubic }
    }

    // ------------------------------------------------------------------ фон
    ScreencopyView {
        id: shot
        anchors.fill: parent
        captureSource: view.outputScreen
        live: false
        paintCursor: false
        // сам снимок не рисуем: под размытием он проступал резким, пока
        // слой проявляется
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.hasContent
        opacity: view.fade
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        blurMultiplier: 1.2
        saturation: 0.15
    }
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: view.fade * (shot.hasContent ? 0.32 : 0.62)
    }

    // клик по пустому месту закрывает — сначала папку, потом весь слой
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            if (menu.visible) menu.close();
            else if (view.folder) view.closeFolder();
            else view.sys.closeLaunchpad();
        }
        onWheel: (w) => wheelPager.feed(w)
    }

    QtObject {
        id: wheelPager
        property real acc: 0
        property double last: 0
        function feed(w) {
            if (view.folder) return;
            var d = Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y) ? -w.angleDelta.x : -w.angleDelta.y;
            var now = Date.now();
            if (now - last < 380) { acc = 0; return; }   // не листать пачкой от инерции тачпада
            acc += d;
            if (Math.abs(acc) >= 90) {
                view.flip(acc > 0 ? 1 : -1);
                acc = 0;
                last = now;
            }
        }
    }

    // ----------------------------------------------------------- содержимое
    Item {
        id: content
        anchors.fill: parent
        // под открытой папкой сетка почти гаснет, как на macOS
        property real dim: (view.folder && !view.folderHidden) ? 0.06 : 1
        Behavior on dim { NumberAnimation { duration: view.sys.animFast } }
        opacity: view.fade * dim
        scale: 1.06 - 0.06 * view.fade
        visible: opacity > 0.01

        // поиск
        Rectangle {
            id: searchBox
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.max(36, parent.height * 0.06)
            width: 280
            height: 36
            radius: 11
            color: Qt.rgba(1, 1, 1, 0.12)
            border.color: Qt.rgba(1, 1, 1, search.activeFocus ? 0.26 : 0.14)
            border.width: 1

            Text {
                id: lens
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: Qt.rgba(1, 1, 1, 0.6)
                font { family: view.sys.fontFam; pixelSize: 13 }
            }
            TextInput {
                id: search
                anchors.left: lens.right
                anchors.leftMargin: 9
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                focus: true
                color: "#ffffff"
                selectionColor: view.sys.colOn
                clip: true
                font { family: view.sys.fontFam; pixelSize: 13 }
                onTextChanged: view.query = text

                Text {
                    anchors.fill: parent
                    visible: !search.text.length
                    text: view.sys.tr("Поиск")
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font: search.font
                    verticalAlignment: Text.AlignVCenter
                }

                Keys.onPressed: (ev) => {
                    if (view.renaming) return;
                    switch (ev.key) {
                    case Qt.Key_Left:     view.moveSel(-1, 0); break;
                    case Qt.Key_Right:    view.moveSel(1, 0); break;
                    case Qt.Key_Up:       view.moveSel(0, -1); break;
                    case Qt.Key_Down:     view.moveSel(0, 1); break;
                    case Qt.Key_Tab:      view.moveSel(1, 0); break;
                    case Qt.Key_PageDown: view.flip(1); break;
                    case Qt.Key_PageUp:   view.flip(-1); break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:    view.enter(); break;
                    case Qt.Key_Escape:   view.goBack(); break;
                    default: return;
                    }
                    ev.accepted = true;
                }
            }
        }

        // страницы
        ListView {
            id: pages
            anchors.top: searchBox.bottom
            anchors.topMargin: 28
            anchors.bottom: dots.top
            anchors.bottomMargin: 18
            anchors.left: parent.left
            anchors.right: parent.right
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: view.sys.noMotion ? 0 : 320
            boundsBehavior: Flickable.StopAtBounds
            // все страницы держим живыми: иначе плитка, которую тащат,
            // исчезала вместе со своей страницей при перелистывании
            cacheBuffer: width * Math.max(1, view.pageCount)
            interactive: !view.dragging && !view.folder
            model: view.pageCount
            clip: false

            // колесо и тачпад листают по странице, а не прокручивают ленту
            WheelHandler {
                onWheel: (ev) => wheelPager.feed(ev)
            }

            delegate: Item {
                id: page
                required property int index
                width: pages.width
                height: pages.height
                // Страницы живут все (см. cacheBuffer), но рисуем только
                // текущую и соседние: иначе каждое открытие отрисовывало
                // все сотни плиток разом.
                visible: Math.abs(page.index - pages.currentIndex) <= 1
                readonly property var items: { view.shown; return view.pageSlice(page.index); }

                Repeater {
                    model: page.items
                    delegate: Tile {
                        v: view
                        required property var modelData
                        required property int index
                        entry: modelData
                        globalIndex: page.index * view.perPage + index
                        x: (pages.width - view.cols * view.cellW) / 2 + (index % view.cols) * view.cellW
                        y: (pages.height - view.rows * view.cellH) / 2 + Math.floor(index / view.cols) * view.cellH
                        selected: view.sel === globalIndex && !view.folder
                    }
                }
            }
        }

        // метка вставки при перетаскивании
        Rectangle {
            readonly property int slot: view.insertSlot - pages.currentIndex * view.perPage
            visible: view.dragging && !view.folder && view.insertSlot >= 0 && slot >= 0 && slot <= view.perPage
            readonly property int col: slot % view.cols === 0 && slot > 0 && slot === view.perPage
                                       ? view.cols : slot % view.cols
            readonly property int row: Math.min(view.rows - 1, Math.floor(Math.max(0, slot - (col === view.cols ? 1 : 0)) / view.cols))
            x: view.gridX + col * view.cellW - width / 2
            y: view.gridY + row * view.cellH + view.cellH * 0.1
            width: 3
            height: view.iconSize
            radius: 2
            color: view.sys.colOn
        }

        // точки страниц
        Row {
            id: dots
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(28, parent.height * 0.05)
            spacing: 10
            visible: view.pageCount > 1
            Repeater {
                model: view.pageCount
                delegate: Rectangle {
                    required property int index
                    width: 8; height: 8; radius: 4
                    color: Qt.rgba(1, 1, 1, index === pages.currentIndex ? 0.95 : 0.35)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pages.currentIndex = parent.index
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: view.searching && view.results.length === 0
            text: view.sys.tr("Ничего не найдено")
            color: Qt.rgba(1, 1, 1, 0.6)
            font { family: view.sys.fontFam; pixelSize: 15 }
        }
    }

    // --------------------------------------------------------- открытая папка
    Item {
        id: folderLayer
        anchors.fill: parent
        visible: !!view.folder
        opacity: (view.folder && !view.folderHidden) ? view.fade : 0
        Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

        // под папкой сетку приглушаем
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.30
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: view.closeFolder()
            }
        }

        Rectangle {
            id: folderPanel
            readonly property int n: view.folder ? view.folder.apps.length : 0
            anchors.centerIn: parent
            width: folderGrid.fcols * view.cellW + 56
            height: Math.min(parent.height * 0.72, folderName.height + 40 + folderGrid.frows * view.cellH + 28)
            radius: 30
            color: Qt.rgba(1, 1, 1, 0.10)
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
            scale: view.folder ? 1 : 0.85
            Behavior on scale { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }

            // клики внутри панели не должны закрывать папку
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton }

            TextInput {
                id: folderName
                anchors.top: parent.top
                anchors.topMargin: 22
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 60
                horizontalAlignment: TextInput.AlignHCenter
                color: "#ffffff"
                selectionColor: view.sys.colOn
                font { family: view.sys.fontDisplay; pixelSize: 22; bold: true }
                readOnly: !view.renaming
                text: view.folder ? view.folder.name : ""
                onActiveFocusChanged: if (!activeFocus && view.renaming) commitName()

                function commitName() {
                    if (view.folder) view.renameFolder(view.folder.fid, text);
                    view.renaming = false;
                }

                Connections {
                    target: view
                    function onRenamingChanged() {
                        if (view.renaming) { folderName.forceActiveFocus(); folderName.selectAll(); }
                    }
                }
                Keys.onReturnPressed: { commitName(); search.forceActiveFocus(); }
                Keys.onEnterPressed:  { commitName(); search.forceActiveFocus(); }
                Keys.onEscapePressed: {
                    text = view.folder ? view.folder.name : "";
                    view.renaming = false;
                    search.forceActiveFocus();
                }

                // по имени папки щёлкают, чтобы переименовать
                MouseArea {
                    anchors.fill: parent
                    enabled: !view.renaming
                    cursorShape: Qt.IBeamCursor
                    onClicked: view.renaming = true
                }
            }

            Flickable {
                anchors.top: folderName.bottom
                anchors.topMargin: 18
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                width: folderGrid.width
                contentHeight: folderGrid.height
                clip: true
                interactive: !view.dragging && contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                Item {
                    id: folderGrid
                    readonly property var apps: view.folder ? view.folder.apps : []
                    readonly property int fcols: Math.max(3, Math.min(5, apps.length))
                    readonly property int frows: Math.max(1, Math.ceil(apps.length / fcols))
                    width: fcols * view.cellW
                    height: frows * view.cellH

                    function slotAt(q) {
                        if (q.x < 0 || q.y < 0 || q.x > width || q.y > height + view.cellH) return apps.length;
                        var c = Math.floor(q.x / view.cellW), r = Math.floor(q.y / view.cellH);
                        var fx = q.x / view.cellW - c;
                        var s = r * fcols + c + (fx > 0.5 ? 1 : 0);
                        return Math.max(0, Math.min(apps.length, s));
                    }

                    Repeater {
                        model: folderGrid.apps
                        delegate: Tile {
                        v: view
                            required property var modelData
                            required property int index
                            entry: ({ key: "app:" + modelData.id, kind: "app", id: String(modelData.id),
                                      app: modelData, name: modelData.name })
                            inFolder: view.folder ? view.folder.fid : ""
                            x: (index % folderGrid.fcols) * view.cellW
                            y: Math.floor(index / folderGrid.fcols) * view.cellH
                            selected: view.folderSel === index
                        }
                    }

                    Rectangle {
                        visible: view.dragging && view.folderInsert >= 0 && !view.folderHidden
                        readonly property int s: view.folderInsert
                        readonly property int c: (s === folderGrid.apps.length && s % folderGrid.fcols === 0 && s > 0)
                                                 ? folderGrid.fcols : s % folderGrid.fcols
                        readonly property int r: Math.floor((s - (c === folderGrid.fcols ? 1 : 0)) / folderGrid.fcols)
                        x: c * view.cellW - 1
                        y: r * view.cellH + view.cellH * 0.1
                        width: 3
                        height: view.iconSize
                        radius: 2
                        color: view.sys.colOn
                    }
                }
            }
        }
    }

    // ---------------------------------------------------- плитка (иконка)
    component Tile: Item {
        id: tile
        property var v: null
        property var entry
        property int globalIndex: -1
        property string inFolder: ""       // fid, если плитка внутри папки
        property bool selected: false

        readonly property bool isFolder: entry && entry.kind === "folder"
        readonly property bool isDragged: tile.v.dragging && tile.v.dragEntry
                                          && tile.v.dragEntry.key === (entry ? entry.key : "")
        readonly property bool isMergeTarget: tile.v.mergeKey.length && entry && tile.v.mergeKey === entry.key

        width: tile.v.cellW
        height: tile.v.cellH
        opacity: isDragged ? 0.25 : 1

        Rectangle {
            id: plate
            anchors.horizontalCenter: parent.horizontalCenter
            y: tile.v.cellH * 0.1 - 8
            width: tile.v.iconSize + 16
            height: tile.v.iconSize + 16
            radius: tile.v.iconSize * 0.3
            color: Qt.rgba(1, 1, 1, tile.selected ? 0.20 : (tileMa.containsMouse && !tile.v.dragging ? 0.08 : 0))
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Item {
            id: iconBox
            anchors.horizontalCenter: parent.horizontalCenter
            y: tile.v.cellH * 0.1
            width: tile.v.iconSize
            height: tile.v.iconSize
            scale: tile.isMergeTarget ? (tile.v.mergeArmed ? 1.18 : 1.08)
                 : (tileMa.pressed && !tile.v.dragging ? 0.92 : 1)
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            // приложение
            AppIcon {
                v: tile.v
                anchors.fill: parent
                visible: !tile.isFolder
                app: tile.isFolder ? null : (tile.entry ? tile.entry.app : null)
            }

            // папка: подложка и до девяти иконок внутри, как на macOS
            Rectangle {
                anchors.fill: parent
                visible: tile.isFolder
                radius: width * 0.24
                color: Qt.rgba(1, 1, 1, tile.isMergeTarget && tile.v.mergeArmed ? 0.34 : 0.22)
                border.color: Qt.rgba(1, 1, 1, 0.20)
                border.width: 1

                Grid {
                    anchors.centerIn: parent
                    columns: 3
                    spacing: parent.width * 0.06
                    Repeater {
                        model: tile.isFolder ? tile.entry.apps.slice(0, 9) : []
                        delegate: AppIcon {
                v: tile.v
                            required property var modelData
                            width: iconBox.width * 0.24
                            height: width
                            app: modelData
                        }
                    }
                }
            }
            // приложение под курсором — подсвечиваем, что станет папкой
            Rectangle {
                anchors.fill: parent
                anchors.margins: -6
                visible: tile.isMergeTarget && !tile.isFolder
                radius: width * 0.26
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, tile.v.mergeArmed ? 0.7 : 0.35)
                border.width: 2
            }
        }

        Text {
            anchors.top: iconBox.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: tile.v.cellW - 12
            horizontalAlignment: Text.AlignHCenter
            text: tile.entry ? (tile.entry.name || "") : ""
            color: "#ffffff"
            elide: Text.ElideRight
            maximumLineCount: 1
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.35)
            font { family: tile.v.sys.fontFam; pixelSize: 12; bold: tile.selected }
        }

        MouseArea {
            id: tileMa
            anchors.horizontalCenter: parent.horizontalCenter
            y: tile.v.cellH * 0.1 - 8
            width: tile.v.iconSize + 16
            height: Math.min(tile.v.cellH - y, tile.v.iconSize + 40)
            hoverEnabled: true
            cursorShape: tile.v.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            // начатое перетаскивание у нас не отбирает ни ListView, ни Flickable
            preventStealing: tile.v.canEdit
            property point pressAt
            property bool dragOn: false

            onPressed: (m) => {
                pressAt = Qt.point(m.x, m.y);
                if (m.button === Qt.RightButton)
                    tile.v.popupMenu(tile.entry, tile.inFolder, mapToItem(view, m.x, m.y));
            }
            onPositionChanged: (m) => {
                if (!(m.buttons & Qt.LeftButton)) return;
                var p = mapToItem(view, m.x, m.y);
                if (!dragOn && tile.v.canEdit
                    && Math.hypot(m.x - pressAt.x, m.y - pressAt.y) > 10) {
                    dragOn = true;
                    tile.v.beginDrag(tile.entry, tile.inFolder, p);
                }
                if (dragOn) tile.v.dragMove(p);
            }
            onReleased: (m) => {
                if (dragOn) {
                    dragOn = false;
                    tile.v.endDrag(mapToItem(view, m.x, m.y));
                } else if (m.button === Qt.LeftButton && containsMouse) {
                    tile.v.activate(tile.entry);
                }
            }
            onCanceled: if (dragOn) { dragOn = false; tile.v.cancelDrag(); }
        }
    }

    // иконка приложения из темы, с буквой на случай, если её нет
    component AppIcon: Item {
        id: ai
        property var v: null
        property var app

        Image {
            id: img
            anchors.fill: parent
            readonly property var cached: ai.v && ai.app ? ai.v.iconCache[String(ai.app.id)] : undefined
            source: cached ? cached : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize.width: 128
            sourceSize.height: 128
            visible: status === Image.Ready
            smooth: true
            mipmap: true
        }
        Rectangle {
            anchors.fill: parent
            visible: !img.visible
            radius: width * 0.24
            color: Qt.rgba(1, 1, 1, 0.16)
            Text {
                anchors.centerIn: parent
                text: String(ai.app ? (ai.app.name || "?") : "?").charAt(0).toUpperCase()
                color: "#ffffff"
                font { family: (ai.v ? ai.v.sys.fontFam : "sans"); pixelSize: Math.max(8, ai.width * 0.42); bold: true }
            }
        }
    }

    // --------------------------------------------- то, что тащим под курсором
    Item {
        visible: view.dragging
        x: view.dragPos.x - width / 2
        y: view.dragPos.y - height / 2
        width: view.iconSize
        height: view.iconSize
        z: 1000
        scale: 1.08

        AppIcon {
            v: view
            anchors.fill: parent
            visible: view.dragEntry && view.dragEntry.kind === "app"
            app: view.dragEntry && view.dragEntry.kind === "app" ? view.dragEntry.app : null
        }
        Rectangle {
            anchors.fill: parent
            visible: view.dragEntry && view.dragEntry.kind === "folder"
            radius: width * 0.24
            color: Qt.rgba(1, 1, 1, 0.28)
        }
    }

    // ------------------------------------------------- меню по правой кнопке
    Rectangle {
        id: menu
        property var entry: null
        property string fromFid: ""
        property var items: []

        visible: false
        z: 900
        width: 230
        height: menuCol.implicitHeight + 12
        radius: 12
        color: Qt.rgba(view.sys.colBg.r, view.sys.colBg.g, view.sys.colBg.b, 0.94)
        border.color: Qt.rgba(1, 1, 1, 0.14)
        border.width: 1

        function close() { visible = false; }

        function popupFor(e, fid, p) {
            if (!e) return;
            entry = e;
            var fromFid = fid || "";
            menu.fromFid = fromFid;
            var it = [];
            var T = view.sys.tr;
            if (e.kind === "folder") {
                it.push({ label: T("Открыть"), act: () => view.openFolder(e.fid, false) });
                it.push({ label: T("Переименовать"), act: () => view.openFolder(e.fid, true) });
                it.push({ label: T("Расформировать папку"), act: () => view.dissolveFolder(e.fid) });
            } else {
                it.push({ label: T("Открыть"), act: () => view.launchApp(e.app) });
                if (view.canEdit) {
                    if (fromFid !== "")
                        it.push({ label: T("Убрать из папки"), act: () => view.moveOut(e.id, fromFid, "") });
                    it.push({ label: T("Новая папка с этим приложением"),
                              act: () => view.newFolderWith(e.id, fromFid) });
                    var fl = view.entries.filter(x => x.kind === "folder" && x.fid !== fromFid);
                    for (var i = 0; i < fl.length; i++) {
                        (function (f) {
                            it.push({ label: T("В папку") + " «" + f.name + "»",
                                      act: () => view.mergeInto(e.id, fromFid, f.key) });
                        })(fl[i]);
                    }
                }
            }
            items = it;
            x = Math.min(p.x, view.width - width - 8);
            y = Math.min(p.y, view.height - (it.length * 32 + 12) - 8);
            visible = true;
        }

        Column {
            id: menuCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            Repeater {
                model: menu.items
                delegate: Rectangle {
                    required property var modelData
                    width: menuCol.width
                    height: 32
                    radius: 8
                    color: mItemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        elide: Text.ElideRight
                        text: modelData.label
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: 12 }
                    }
                    MouseArea {
                        id: mItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { menu.close(); modelData.act(); }
                    }
                }
            }
        }
    }
}
