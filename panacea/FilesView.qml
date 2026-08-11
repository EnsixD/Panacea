import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Проводник в пилюле: слева закладки, справа список файлов.
// Клавиатура — основной способ управления: стрелки, Enter, Backspace,
// печать фильтрует список, Esc закрывает.
Item {
    id: view
    property var sys
    // true — проводник открыт отдельным окном Hyprland: закрывать надо окно,
    // а пилюля живёт своей жизнью и трогать её нельзя
    property bool windowMode: false
    property int  windowId: 0

    function leave() {
        if (view.windowMode) view.sys.closeFilesWindow(view.windowId);
        else                 view.sys.collapse();
    }

    implicitHeight: col.implicitHeight

    // ------------------------------------------------------------ состояние
    property string dir: ""
    property int current: 0
    property string filter: ""
    // Сортировка: "name" | "time" | "size" | "type". Порядок и «папки сверху»
    // отдельными переключателями — так же, как в любом привычном проводнике.
    property string sortBy: "name"
    property bool   sortDesc: false
    property bool   foldersFirst: true
    property string status: ""

    // выбранный файл, для которого показываем «чем открыть»
    property string openWithFile: ""

    // буфер обмена проводника
    property string clipPath: ""
    property string clipMode: ""        // "copy" | "cut"

    // контекстное меню
    property bool   menuOpen: false
    property string menuPath: ""        // "" — меню пустого места
    property bool   menuIsDir: false
    property string menuKind: "folder"   // "file" | "folder" | "trash"
    property real   menuX: 0
    property real   menuY: 0

    // диалог ввода имени
    property string dialogMode: ""      // "rename" | "mkdir"

    // Переход между папками: список уезжает и гаснет, новый приезжает
    // с той стороны, куда мы двинулись. Направление помним, чтобы «вверх»
    // и «внутрь» ощущались по-разному.
    property real listOpacity: 1
    property real listShift: 0
    Behavior on listShift { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    property int  navDir: 1             // 1 — внутрь, -1 — наверх

    ListModel { id: entries }      // отфильтрованный список
    ListModel { id: rawEntries }   // всё, что вернул files.sh
    ListModel { id: places }
    // Смонтированные носители. Съёмные держим отдельной моделью: их раздел
    // должен появляться только когда что-то воткнули.
    ListModel { id: disks }
    ListModel { id: removables }
    ListModel { id: apps }

    readonly property string scripts: view.sys.scriptDir + "/files.sh"

    focus: true
    Component.onCompleted: {
        if (!view.dir.length) view.dir = view.sys.filesDir;
        forceActiveFocus();
        loadPlaces();
        reload();
    }

    // ---------------------------------------------------------------- чтение
    Process {
        id: pList
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 5) return;
                rawEntries.append({
                    eType: p[0], eName: p[1],
                    eSize: parseInt(p[2]) || 0,
                    eTime: parseInt(p[3]) || 0,
                    eMime: p[4]
                });
            }
        }
        onRunningChanged: if (!running) view.applyFilter()
    }

    Process {
        id: pPlaces
        command: ["sh", "-c", view.scripts + " places"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 3) return;
                places.append({ pKey: p[0], pPath: p[1], pLabel: p[2] });
            }
        }
    }

    Process {
        id: pApps
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 3) return;
                apps.append({ aFile: p[0], aName: p[1], aIcon: p[2] });
            }
        }
    }

    Process {
        id: pAction
        onRunningChanged: {
            if (running) return;
            view.reload();
            view.countTrash();
            // Соседние окна проводника про наши правки не знают: после
            // переноса файл исчезает здесь, но у них в списке ещё висит.
            // Флаг — чтобы не перечитать список ещё раз у самих себя: две
            // перезагрузки подряд дёргают анимацию появления.
            view.selfChange = true;
            view.sys.filesChanged();
            view.selfChange = false;
        }
    }
    property bool selfChange: false
    // ...и наоборот: правку в соседнем окне подхватываем сами
    Connections {
        target: view.sys
        ignoreUnknownSignals: true
        function onFilesChanged() {
            if (view.selfChange || pAction.running) return;
            view.reload();
        }
    }

    // сколько файлов в корзине — показываем счётчиком у закладки
    property int trashCount: 0
    readonly property string trashDir:
        (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share"))
        + "/Trash/files"
    readonly property bool inTrash: view.dir === view.trashDir

    Process {
        id: pTrashCount
        command: ["sh", "-c", view.scripts + " trashcount"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: view.trashCount = parseInt(text.trim()) || 0
        }
    }

    Process {
        id: pDisks
        command: ["sh", "-c", view.scripts + " disks"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var d = [], r = [];
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("|");
                    if (p.length < 6) continue;
                    var row = {
                        dPath: p[1], dLabel: p[2],
                        dSize: parseFloat(p[3]) || 0,
                        dUsed: parseFloat(p[4]) || 0,
                        dDev: p[5]
                    };
                    if (p[0] === "removable") r.push(row); else d.push(row);
                }
                // Раньше модель очищалась и набивалась заново каждые 4 секунды:
                // делегаты пересоздавались, и полоса заполнения каждый раз
                // заново уезжала от нуля. Теперь правим строки на месте, а
                // список трогаем, только если носитель появился или пропал.
                view.syncDisks(disks, d);
                view.syncDisks(removables, r);
            }
        }
    }
    function syncDisks(model, rows) {
        if (model.count !== rows.length) {
            model.clear();
            for (var i = 0; i < rows.length; i++) model.append(rows[i]);
            return;
        }
        for (var j = 0; j < rows.length; j++) {
            var cur = model.get(j);
            if (cur.dPath !== rows[j].dPath) { model.set(j, rows[j]); continue; }
            // меняем только цифры — делегат остаётся тем же
            if (cur.dUsed !== rows[j].dUsed) model.setProperty(j, "dUsed", rows[j].dUsed);
            if (cur.dSize !== rows[j].dSize) model.setProperty(j, "dSize", rows[j].dSize);
        }
    }
    function reloadDisks() { pDisks.running = false; pDisks.running = true; }
    // Воткнули флешку или подключили телефон — раздел появится сам.
    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: view.reloadDisks()
    }

    function human(b) {
        if (!b || b <= 0) return "";
        var u = ["B", "KB", "MB", "GB", "TB"];
        var i = 0;
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
        return (b >= 100 || i < 2 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }
    function countTrash() { pTrashCount.running = false; pTrashCount.running = true; }

    function emptyTrash() {
        closeMenu();
        run(["sh", "-c", view.scripts + " emptytrash"], view.sys.tr("Корзина очищена"));
    }

    function loadPlaces() {
        places.clear();
        pPlaces.running = false;
        pPlaces.running = true;
    }

    function reload() {
        rawEntries.clear();
        entries.clear();
        view.listOpacity = 0;
        view.listShift = 22 * view.navDir;
        pList.command = ["sh", "-c", view.scripts + " list \"$1\"", "_", view.dir];
        pList.running = false;
        pList.running = true;
        view.sys.filesDir = view.dir;
    }

    function applyFilter() {
        entries.clear();
        // содержимое готово — вернуть на место
        view.listOpacity = 1;
        view.listShift = 0;
        var f = view.filter.toLowerCase();
        var rows = [];
        for (var i = 0; i < rawEntries.count; i++) {
            var e = rawEntries.get(i);
            if (f.length && e.eName.toLowerCase().indexOf(f) < 0) continue;
            rows.push({ eType: e.eType, eName: e.eName, eSize: e.eSize,
                        eTime: e.eTime, eMime: e.eMime });
        }
        rows.sort(view.compare);
        for (var j = 0; j < rows.length; j++) entries.append(rows[j]);
        view.current = 0;
    }

    // Сравнение двух строк списка. Каталоги держим отдельной группой, если
    // включено «папки сверху»: иначе при сортировке по размеру они, все
    // нулевые, сваливались в одну кучу посреди файлов.
    function compare(a, b) {
        if (view.foldersFirst && a.eType !== b.eType)
            return a.eType === "d" ? -1 : 1;

        var r = 0;
        if (view.sortBy === "time") r = a.eTime - b.eTime;
        else if (view.sortBy === "size") r = a.eSize - b.eSize;
        else if (view.sortBy === "type") {
            var ea = view.extOf(a), eb = view.extOf(b);
            r = ea < eb ? -1 : ea > eb ? 1 : 0;
        }
        if (r === 0) {
            var na = a.eName.toLowerCase(), nb = b.eName.toLowerCase();
            r = na < nb ? -1 : na > nb ? 1 : 0;
            // имя всегда по возрастанию, если сортируем не по нему
            if (view.sortBy !== "name") return r;
        }
        return view.sortDesc ? -r : r;
    }
    function extOf(e) {
        if (e.eType === "d") return "";
        var i = e.eName.lastIndexOf(".");
        return i > 0 ? e.eName.substring(i + 1).toLowerCase() : "";
    }
    function setSort(k) {
        if (view.sortBy === k) view.sortDesc = !view.sortDesc;
        else { view.sortBy = k; view.sortDesc = (k === "time" || k === "size"); }
        view.applyFilter();
    }

    // «12 авг, 14:32», а для прошлых лет — с годом
    function timeText(e) {
        if (!e.eTime) return "";
        var d = new Date(e.eTime * 1000);
        var now = new Date();
        var fmt = d.getFullYear() === now.getFullYear() ? "d MMM, hh:mm" : "d MMM yyyy";
        return Qt.formatDateTime(d, fmt);
    }

    function go(path) {
        view.navDir = path.length < view.dir.length ? -1 : 1;
        view.filter = "";
        view.dir = path;
        view.openWithFile = "";
        view.reload();
    }
    function up() {
        if (view.dir === "/") return;
        var p = view.dir.replace(/\/+$/, "");
        var i = p.lastIndexOf("/");
        go(i <= 0 ? "/" : p.slice(0, i));
    }

    // что умеет показать наш плеер — открываем сразу, без вопроса «чем»
    function isMedia(e) {
        var m = String(e.eMime);
        return m.indexOf("image/") === 0 || m.indexOf("video/") === 0;
    }

    function activate(i) {
        if (i < 0 || i >= entries.count) return;
        var e = entries.get(i);
        var full = (view.dir === "/" ? "" : view.dir) + "/" + e.eName;
        if (e.eType === "d") { go(full); return; }
        // режим выбора обоев: картинку не открываем в плеере, а отдаём
        // странице обоев для сохранения
        if (view.sys.wallpaperPickMode) {
            var m = String(e.eMime);
            if (m.indexOf("image/") === 0) { view.sys.finishWallpaperPick(full); return; }
        }
        if (view.isMedia(e)) { view.sys.openMedia(full); return; }
        // остальное — сначала спрашиваем, чем открывать
        view.openWithFile = full;
        apps.clear();
        pApps.command = ["sh", "-c", view.scripts + " apps \"$1\"", "_", full];
        pApps.running = false;
        pApps.running = true;
    }

    function openWith(desktopFile) {
        if (!view.openWithFile.length) return;
        pAction.command = desktopFile.length
            ? ["sh", "-c", view.scripts + " open \"$1\" \"$2\"", "_",
               view.openWithFile, desktopFile]
            : ["sh", "-c", view.scripts + " open \"$1\"", "_", view.openWithFile];
        pAction.running = true;
        view.openWithFile = "";
        view.leave();
    }

    function trashCurrent() {
        if (view.current < 0 || view.current >= entries.count) return;
        var e = entries.get(view.current);
        var full = (view.dir === "/" ? "" : view.dir) + "/" + e.eName;
        view.status = view.sys.tr("В корзину: ") + e.eName;
        statusClear.restart();
        pAction.command = ["sh", "-c", view.scripts + " trash \"$1\"", "_", full];
        pAction.running = true;
    }
    Timer { id: statusClear; interval: 2600; onTriggered: view.status = "" }

    function say(msg) { view.status = msg; statusClear.restart(); }

    function fullPath(name) {
        return (view.dir === "/" ? "" : view.dir) + "/" + name;
    }
    function currentPath() {
        if (view.current < 0 || view.current >= entries.count) return "";
        return view.fullPath(entries.get(view.current).eName);
    }
    function baseName(p) { return String(p).split("/").pop(); }

    // Подписи закладок переводим здесь: скрипт про язык интерфейса не знает.
    function placeLabel(key, fallback) {
        switch (key) {
            case "home":      return view.sys.tr("Домашняя");
            case "downloads": return view.sys.tr("Загрузки");
            case "documents": return view.sys.tr("Документы");
            case "pictures":  return view.sys.tr("Изображения");
            case "videos":    return view.sys.tr("Видео");
            case "music":     return view.sys.tr("Музыка");
            case "desktop":   return view.sys.tr("Рабочий стол");
            case "trash":     return view.sys.tr("Корзина");
            case "root":      return view.sys.tr("Система");
        }
        return fallback;
    }

    function run(args, note) {
        pAction.command = args;
        pAction.running = true;
        if (note !== undefined) view.say(note);
    }

    // --------------------------------------------------------- меню действий
    function openMenu(path, isDir, x, y, kind) {
        view.menuPath = path;
        view.menuIsDir = isDir;
        view.menuKind = kind !== undefined ? kind : (path.length ? "file" : "folder");
        // держим меню внутри панели, иначе его срежет капсула
        view.menuX = Math.max(0, Math.min(x, view.width - 210));
        view.menuY = Math.max(0, Math.min(y, Math.max(0, view.height - 250)));
        view.menuOpen = true;
    }
    function closeMenu() { view.menuOpen = false; }

    function doOpen(path) {
        if (!path.length) return;
        closeMenu();
        for (var i = 0; i < entries.count; i++) {
            if (view.fullPath(entries.get(i).eName) === path) { view.activate(i); return; }
        }
    }
    // явный выбор программы — минуя автозапуск медиа в своём плеере
    function doOpenWith(path) {
        if (!path.length) return;
        closeMenu();
        view.openWithFile = path;
        apps.clear();
        pApps.command = ["sh", "-c", view.scripts + " apps \"$1\"", "_", path];
        pApps.running = false;
        pApps.running = true;
    }
    function doCopy(path) {
        view.clipPath = path; view.clipMode = "copy";
        closeMenu();
        view.say(view.sys.tr("Скопировано: ") + view.baseName(path));
    }
    function doCut(path) {
        view.clipPath = path; view.clipMode = "cut";
        closeMenu();
        view.say(view.sys.tr("Вырезано: ") + view.baseName(path));
    }
    function doPaste() {
        if (!view.clipPath.length) return;
        var cmd = view.clipMode === "cut" ? " move " : " copy ";
        closeMenu();
        run(["sh", "-c", view.scripts + cmd + "\"$1\" \"$2\"", "_", view.clipPath, view.dir],
            (view.clipMode === "cut" ? view.sys.tr("Перемещено: ")
                                     : view.sys.tr("Вставлено: ")) + view.baseName(view.clipPath));
        if (view.clipMode === "cut") { view.clipPath = ""; view.clipMode = ""; }
    }
    function doCopyPath(path) {
        closeMenu();
        run(["sh", "-c", view.scripts + " copypath \"$1\"", "_", path],
            view.sys.tr("Путь скопирован"));
    }
    function doTrash(path) {
        closeMenu();
        run(["sh", "-c", view.scripts + " trash \"$1\"", "_", path],
            view.sys.tr("В корзину: ") + view.baseName(path));
    }

    // ---------------------------------------------------------- свойства
    property bool  propsOpen: false
    property var   propsData: ({})
    property string propsPath: ""
    function showProps(path) {
        closeMenu();
        view.propsPath = path;
        view.propsData = ({});
        pProps.command = ["sh", "-c", view.sys.scriptDir + "/props.sh \"$1\"", "_", path];
        pProps.running = true;
        view.propsOpen = true;
    }
    Process {
        id: pProps
        stdout: StdioCollector {
            onStreamFinished: {
                var o = {};
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var t = lines[i].split("\t");
                    if (t.length >= 2) o[t[0]] = t.slice(1).join("\t");
                }
                view.propsData = o;
            }
        }
    }
    function fmtDuration(sec) {
        var s = Math.floor(parseFloat(sec) || 0);
        var h = Math.floor(s / 3600); s -= h * 3600;
        var m = Math.floor(s / 60); s -= m * 60;
        var p2 = function (n) { return n < 10 ? "0" + n : "" + n; };
        return (h > 0 ? h + ":" + p2(m) : m) + ":" + p2(s);
    }
    function startRename(path) {
        closeMenu();
        view.menuPath = path;
        view.dialogMode = "rename";
        dialogField.text = view.baseName(path);
        dialogField.selectAll();
        dialogFocus.restart();
    }
    function startMkdir() {
        closeMenu();
        view.dialogMode = "mkdir";
        dialogField.text = view.sys.tr("Новая папка");
        dialogField.selectAll();
        dialogFocus.restart();
    }
    function confirmDialog() {
        var name = dialogField.text.trim();
        var mode = view.dialogMode;
        view.dialogMode = "";
        view.forceActiveFocus();
        if (!name.length) return;
        if (mode === "rename")
            run(["sh", "-c", view.scripts + " rename \"$1\" \"$2\"", "_", view.menuPath, name],
                view.sys.tr("Переименовано"));
        else if (mode === "mkdir")
            run(["sh", "-c", view.scripts + " mkdir \"$1\" \"$2\"", "_", view.dir, name],
                view.sys.tr("Папка создана"));
    }
    function cancelDialog() {
        view.dialogMode = "";
        view.forceActiveFocus();
    }
    Timer { id: dialogFocus; interval: 40; onTriggered: dialogField.forceActiveFocus() }

    // -------------------------------------------------------------- клавиши
    Keys.onEscapePressed: {
        if (view.dialogMode.length) { view.cancelDialog(); return; }
        if (view.menuOpen) { view.closeMenu(); return; }
        if (view.openWithFile.length) { view.openWithFile = ""; return; }
        if (view.filter.length) { view.filter = ""; applyFilter(); return; }
        view.leave();
    }
    Keys.onUpPressed:    if (view.current > 0) view.current--;
    Keys.onDownPressed:  if (view.current < entries.count - 1) view.current++;
    Keys.onReturnPressed: view.openWithFile.length ? view.openWith(appList.currentFile())
                                                   : view.activate(view.current)
    Keys.onEnterPressed:  view.openWithFile.length ? view.openWith(appList.currentFile())
                                                   : view.activate(view.current)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Backspace) {
            if (view.filter.length) {
                view.filter = view.filter.slice(0, -1);
                applyFilter();
            } else {
                view.up();
            }
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Delete) { view.trashCurrent(); event.accepted = true; return; }
        if (event.modifiers & Qt.ControlModifier) {
            var p = view.currentPath();
            if (event.key === Qt.Key_C && p.length) { view.doCopy(p); event.accepted = true; return; }
            if (event.key === Qt.Key_X && p.length) { view.doCut(p); event.accepted = true; return; }
            if (event.key === Qt.Key_V) { view.doPaste(); event.accepted = true; return; }
            if (event.key === Qt.Key_N) { view.startMkdir(); event.accepted = true; return; }
            return;
        }
        if (event.key === Qt.Key_F2) {
            var r = view.currentPath();
            if (r.length) view.startRename(r);
            event.accepted = true;
            return;
        }
        if (event.text.length === 1 && event.text >= " ") {
            view.filter += event.text;
            applyFilter();
            event.accepted = true;
        }
    }

    // ------------------------------------------------------------- иконки
    function iconFor(e) {
        if (e.eType === "d") return String.fromCodePoint(0xF024B);   // folder
        var m = String(e.eMime);
        if (m.indexOf("image/") === 0) return String.fromCodePoint(0xF021F);
        if (m.indexOf("video/") === 0) return String.fromCodePoint(0xF022B);
        if (m.indexOf("audio/") === 0) return String.fromCodePoint(0xF0388);
        if (m === "application/pdf") return String.fromCodePoint(0xF0226);
        if (m.indexOf("text/") === 0) return String.fromCodePoint(0xF0219);
        if (m.indexOf("zip") >= 0 || m.indexOf("tar") >= 0 || m.indexOf("compress") >= 0)
            return String.fromCodePoint(0xF05C0);
        return String.fromCodePoint(0xF0224);                        // generic file
    }

    function sizeText(e) {
        if (e.eType === "d") return "";
        var s = e.eSize;
        if (s < 1024) return s + " B";
        if (s < 1024 * 1024) return (s / 1024).toFixed(0) + " KB";
        if (s < 1024 * 1024 * 1024) return (s / 1048576).toFixed(1) + " MB";
        return (s / 1073741824).toFixed(2) + " GB";
    }

    // ------------------------------------------------------ контекстное меню
    component MenuItem: Rectangle {
        property string glyph: ""
        property string label: ""
        property bool danger: false
        property bool enabledItem: true
        signal chosen()

        width: parent ? parent.width : 0
        height: 34
        radius: 9
        color: itemMa.containsMouse && enabledItem
               ? (danger ? Qt.rgba(0.94, 0.27, 0.27, 0.18) : view.sys.colHover)
               : "transparent"
        opacity: enabledItem ? 1 : 0.35
        Behavior on color { ColorAnimation { duration: 110 } }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 11
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.glyph
                color: parent.parent.danger ? "#ef4444" : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 14 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.label
                color: parent.parent.danger ? "#ef4444" : view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
            }
        }

        MouseArea {
            id: itemMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.enabledItem
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.chosen()
        }
    }

    // ---------------------------------------------------------------- вид
    // Раздел «Диски» / «Съёмные»: подпись, занятое место и полоска заполнения.
    // Пустой раздел не рисуется вовсе — флешки нет, и заголовка быть не должно.
    component DiskSection: ColumnLayout {
        property string title: ""
        property var items: null
        property bool removable: false

        Layout.fillWidth: true
        Layout.topMargin: 8
        spacing: 3
        visible: items && items.count > 0

        Text {
            Layout.leftMargin: 10
            Layout.bottomMargin: 2
            text: parent.title
            color: Qt.rgba(1, 1, 1, 0.32)
            font {
                family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5
                bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
            }
        }

        Repeater {
            model: parent.items

            Rectangle {
                id: disk
                required property var model
                readonly property bool active: view.dir === disk.model.dPath
                readonly property real frac: disk.model.dSize > 0
                                             ? disk.model.dUsed / disk.model.dSize : 0

                Layout.fillWidth: true
                Layout.preferredHeight: disk.model.dSize > 0 ? 58 : 34
                radius: 12
                color: diskMa.containsMouse ? view.sys.colHover
                     : (disk.active ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                Behavior on color { ColorAnimation { duration: 130 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 5
                    anchors.bottomMargin: 5
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9
                        Text {
                            text: String.fromCodePoint(
                                      disk.model.dDev === "mtp" ? 0xF011C
                                    : disk.parent.parent.removable ? 0xF129B
                                                                   : 0xF02CA)
                            color: disk.active ? view.sys.colOn : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 15 }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: disk.model.dLabel
                            color: disk.active ? view.sys.colFg : view.sys.colMuted
                            elide: Text.ElideRight
                            font {
                                family: view.sys.fontFam
                                pixelSize: view.sys.fontSize - 2
                                bold: disk.active
                            }
                        }
                        Text {
                            visible: disk.model.dSize > 0
                            text: Math.round(disk.frac * 100) + "%"
                            color: disk.frac > 0.9 ? view.sys.colCrit
                                                   : Qt.rgba(1, 1, 1, 0.42)
                            font {
                                family: view.sys.fontFam
                                pixelSize: view.sys.fontSize - 6
                                bold: true
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: disk.model.dSize > 0
                        text: view.human(disk.model.dUsed) + " / " + view.human(disk.model.dSize)
                        color: Qt.rgba(1, 1, 1, 0.28)
                        elide: Text.ElideRight
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 7 }
                    }

                    // полоска заполнения; у телефонов размера нет — и полосы тоже
                    Rectangle {
                        visible: disk.model.dSize > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 3
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.10)
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, disk.frac))
                            height: parent.height
                            radius: 2
                            color: disk.frac > 0.9 ? view.sys.colCrit : view.sys.colOn
                            Behavior on width { NumberAnimation { duration: 240 } }
                        }
                    }
                }

                MouseArea {
                    id: diskMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.go(disk.model.dPath)
                }
            }
        }
    }

    // Колонка закладок и список лежат на одном фоне, без черты граница не
    // читалась. В раскладке она обрывалась вместе со строкой, поэтому рисуем
    // её слоем: от шапки и до самого низа окна.
    Rectangle {
        z: 1
        width: 1
        x: 190 + 7
        // Не anchors: headSep лежит внутри col, а не рядом, и привязка к
        // не-родителю и не-соседу молча не срабатывает — черта просто
        // не имела высоты. Считаем координату через положение в раскладке.
        y: col.y + headSep.y + headSep.height
        height: Math.max(0, view.height - y)
        color: Qt.rgba(1, 1, 1, 0.14)
        visible: !view.openWithFile.length && height > 0
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        // ------------------------------------------------------- шапка
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 40; Layout.preferredHeight: 40
                radius: 13
                color: upMa.containsMouse ? view.sys.colHover : Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 140 } }

                Glyph {
                    anchors.fill: parent
                    glyph: String.fromCodePoint(0xF0143)   // chevron-up
                    color: view.sys.colFg
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize - 2
                }
                MouseArea {
                    id: upMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.up()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: view.dir === Quickshell.env("HOME")
                          ? view.sys.tr("Домашняя") : view.dir.split("/").pop() || "/"
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 5; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: view.status.length ? view.status : view.dir
                    color: view.status.length ? view.sys.colOn : view.sys.colMuted
                    elide: Text.ElideMiddle
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }

            // строка фильтра
            Rectangle {
                Layout.preferredWidth: 260
                Layout.preferredHeight: 38
                radius: 19
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: view.filter.length ? view.sys.colOn : view.sys.colLine
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 11
                    spacing: 7
                    Text {
                        text: String.fromCodePoint(0xF0349)   // magnify
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 13 }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: view.filter.length ? view.filter : view.sys.tr("Просто печатайте")
                        color: view.filter.length ? view.sys.colFg : Qt.rgba(1, 1, 1, 0.30)
                        elide: Text.ElideRight
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                    }
                }
            }
        }

        Rectangle {
            id: headSep
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: view.sys.colLine
        }

        // ---------------------------------------------- закладки + список
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            visible: !view.openWithFile.length

            // закладки: узкая колонка фиксированной ширины, остальное — списку
            ColumnLayout {
                Layout.preferredWidth: 190
                Layout.maximumWidth: 190
                Layout.minimumWidth: 190
                Layout.alignment: Qt.AlignTop
                spacing: 3

                Repeater {
                    model: places
                    Rectangle {
                        id: place
                        required property var model
                        readonly property bool active: view.dir === place.model.pPath

                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 12
                        color: placeMa.containsMouse ? view.sys.colHover
                             : (place.active ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                        Behavior on color { ColorAnimation { duration: 130 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            spacing: 9
                            Text {
                                text: String.fromCodePoint(
                                          place.model.pKey === "home" ? 0xF02DC
                                        : place.model.pKey === "downloads" ? 0xF0179
                                        : place.model.pKey === "pictures" ? 0xF021F
                                        : place.model.pKey === "videos" ? 0xF022B
                                        : place.model.pKey === "music" ? 0xF0388
                                        : place.model.pKey === "documents" ? 0xF0219
                                        : place.model.pKey === "trash" ? 0xF0A79
                                        : place.model.pKey === "root" ? 0xF02CA
                                                                      : 0xF024B)
                                color: place.active ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 16 }
                            }
                            Text {
                                visible: place.model.pKey === "trash" && view.trashCount > 0
                                text: String(view.trashCount)
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: view.placeLabel(place.model.pKey, place.model.pLabel)
                                color: place.active ? view.sys.colFg : view.sys.colMuted
                                elide: Text.ElideRight
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: view.sys.fontSize - 1
                                    bold: place.active
                                }
                            }
                        }
                        MouseArea {
                            id: placeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                // у корзины своё короткое меню: только очистка
                                if (mouse.button === Qt.RightButton) {
                                    if (place.model.pKey !== "trash") return;
                                    var p = mapToItem(view, mouse.x, mouse.y);
                                    view.openMenu("", true, p.x, p.y, "trash");
                                    return;
                                }
                                view.go(place.model.pPath);
                            }
                        }
                    }
                }

                // ------------------------------------------- носители
                DiskSection {
                    title: view.sys.tr("Диски")
                    items: disks
                }
                DiskSection {
                    title: view.sys.tr("Съёмные")
                    items: removables
                    removable: true
                }
            }

            // место под вертикальную черту: сама она нарисована отдельно,
            // чтобы идти до самого низа окна, а не до конца строки
            Item { Layout.preferredWidth: 1 }

            // список файлов — занимает всё оставшееся место
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 380
                spacing: 1

                // ---------------------------------------------- сортировка
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    spacing: 6

                    component SortBtn: Rectangle {
                        property string key: ""
                        property string label: ""
                        readonly property bool on: view.sortBy === key

                        Layout.preferredHeight: 26
                        Layout.preferredWidth: sortTxt.implicitWidth + (on ? 30 : 18)
                        radius: 9
                        color: on ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                            view.sys.colOn.b, 0.20)
                             : (sortMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on Layout.preferredWidth { NumberAnimation { duration: 140 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                id: sortTxt
                                text: parent.parent.label
                                color: parent.parent.on ? view.sys.colFg : view.sys.colMuted
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: view.sys.fontSize - 4
                                    bold: parent.parent.on
                                }
                            }
                            // стрелка показывает направление и переключает его
                            Text {
                                visible: parent.parent.on
                                text: view.sortDesc ? "󰄼" : "󰄿"
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                            }
                        }
                        MouseArea {
                            id: sortMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.setSort(parent.key)
                        }
                    }

                    Text {
                        text: view.sys.tr("Сортировка")
                        color: Qt.rgba(1, 1, 1, 0.30)
                        font {
                            family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5
                            bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                        }
                    }
                    SortBtn { key: "name"; label: view.sys.tr("Имя") }
                    SortBtn { key: "time"; label: view.sys.tr("Дата") }
                    SortBtn { key: "size"; label: view.sys.tr("Размер") }
                    SortBtn { key: "type"; label: view.sys.tr("Тип") }

                    Item { Layout.fillWidth: true }

                    // папки сверху — отдельным переключателем, а не частью
                    // порядка: он нужен при любой сортировке
                    Rectangle {
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: ffTxt.implicitWidth + 26
                        radius: 9
                        color: view.foldersFirst
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                         view.sys.colOn.b, 0.18)
                             : (ffMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: String.fromCodePoint(0xF024B)
                                color: view.foldersFirst ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                            }
                            Text {
                                id: ffTxt
                                text: view.sys.tr("Папки сверху")
                                color: view.foldersFirst ? view.sys.colFg : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                            }
                        }
                        MouseArea {
                            id: ffMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                view.foldersFirst = !view.foldersFirst;
                                view.applyFilter();
                            }
                        }
                    }
                }

                // Сдвиг делаем трансформом, а не x: координатами элементов
                // внутри Layout распоряжается сам Layout, и присвоение x
                // разъезжалось с раскладкой — колонки налезали друг на друга.
                opacity: view.listOpacity
                transform: Translate { x: view.listShift }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    // высоту держим постоянной: список не должен «дышать»
                    // при переходе между папками с разным числом файлов
                    Layout.preferredHeight: view.sys.filesListH
                    clip: true
                    model: entries
                    currentIndex: view.current
                    highlightMoveDuration: 130
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    // Подложка под делегатами: правый клик по пустому месту
                    // даёт меню самой папки. Живёт внутри ListView, иначе
                    // anchors ругались бы на управление со стороны Layout.
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        acceptedButtons: Qt.RightButton
                        onClicked: mouse => {
                            var p = mapToItem(view, mouse.x, mouse.y);
                            view.openMenu("", true, p.x, p.y);
                        }
                    }

                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property var model

                        width: ListView.view.width
                        height: 42
                        radius: 12
                        readonly property bool dropTarget:
                            row.model.eType === "d" && rowDrop.containsDrag

                        color: row.dropTarget
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                         view.sys.colOn.b, 0.28)
                             : index === view.current ? Qt.rgba(1, 1, 1, 0.09)
                             : (rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }
                        border.color: view.sys.colOn
                        border.width: row.dropTarget ? 1 : 0

                        // Папку можно выбрать курсором: бросили на строку —
                        // кладём внутрь неё, а не в открытый каталог.
                        DropArea {
                            id: rowDrop
                            anchors.fill: parent
                            keys: ["text/uri-list"]
                            enabled: row.model.eType === "d"
                            onDropped: drop => {
                                var p = view.mapFromItem(row, drop.x, drop.y);
                                view.takeDrop(drop, view.fullPath(row.model.eName), p.x, p.y);
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            spacing: 10

                            Text {
                                text: view.iconFor(row.model)
                                color: row.model.eType === "d" ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 19 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.model.eName
                                color: view.sys.colFg
                                elide: Text.ElideMiddle
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: view.sys.fontSize
                                    bold: row.index === view.current
                                }
                            }
                            // дата изменения — у всех, включая папки
                            Text {
                                text: view.timeText(row.model)
                                color: Qt.rgba(1, 1, 1, 0.26)
                                horizontalAlignment: Text.AlignRight
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                            }
                            Text {
                                Layout.preferredWidth: 62
                                text: view.sizeText(row.model)
                                color: Qt.rgba(1, 1, 1, 0.32)
                                horizontalAlignment: Text.AlignRight
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                            }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            property bool dragging: false
                            property real pressX: 0
                            property real pressY: 0

                            onPressed: mouse => { pressX = mouse.x; pressY = mouse.y; }
                            onReleased: dragging = false
                            onPositionChanged: mouse => {
                                if (dragging || !pressed || mouse.buttons !== Qt.LeftButton) return;
                                // порог, чтобы обычный клик не превращался в перетаскивание
                                if (Math.abs(mouse.x - pressX) < 12
                                    && Math.abs(mouse.y - pressY) < 12) return;
                                view.current = row.index;
                                dragging = true;
                                // панель сворачивается, файл остаётся на курсоре
                                view.sys.startFileDrag(view.fullPath(row.model.eName), view.windowMode);
                            }

                            onClicked: mouse => {
                                if (rowMa.dragging) return;
                                view.current = row.index;
                                view.forceActiveFocus();
                                if (mouse.button === Qt.RightButton) {
                                    var p = mapToItem(view, mouse.x, mouse.y);
                                    view.openMenu(view.fullPath(row.model.eName),
                                                  row.model.eType === "d", p.x, p.y);
                                }
                            }
                            onDoubleClicked: view.activate(row.index)
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: entries.count === 0
                    text: view.filter.length ? view.sys.tr("Ничего не найдено")
                                             : view.sys.tr("Пусто")
                    color: view.sys.colMuted
                    horizontalAlignment: Text.AlignHCenter
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }
        }

        // -------------------------------------------------- чем открыть
        ColumnLayout {
            id: appList
            Layout.fillWidth: true
            spacing: 3
            visible: view.openWithFile.length > 0

            function currentFile() {
                return apps.count > 0 ? apps.get(0).aFile : "";
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                Text {
                    text: String.fromCodePoint(0xF0770)
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: view.sys.tr("Чем открыть")
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1; bold: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: view.openWithFile.split("/").pop()
                        color: view.sys.colMuted
                        elide: Text.ElideMiddle
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 28; Layout.preferredHeight: 28
                    radius: 14
                    color: backMa.containsMouse ? view.sys.colHover : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: 16 }
                    }
                    MouseArea {
                        id: backMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.openWithFile = ""
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(apps.count * 44, 520)
                clip: true
                model: apps

                delegate: Rectangle {
                    id: appRow
                    required property int index
                    required property var model

                    width: ListView.view.width
                    height: 44
                    radius: 12
                    color: appMa.containsMouse ? view.sys.colHover
                         : (appRow.index === 0 ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 11
                        anchors.rightMargin: 11
                        spacing: 10

                        Image {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            source: appRow.model.aIcon.length
                                    ? Quickshell.iconPath(appRow.model.aIcon, true) : ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: status === Image.Ready
                        }
                        Text {
                            Layout.fillWidth: true
                            text: appRow.model.aName
                            color: view.sys.colFg
                            elide: Text.ElideRight
                            font {
                                family: view.sys.fontFam
                                pixelSize: view.sys.fontSize
                                bold: appRow.index === 0
                            }
                        }
                        Text {
                            visible: appRow.index === 0
                            text: view.sys.tr("по умолчанию")
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 6 }
                        }
                    }

                    MouseArea {
                        id: appMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.openWith(appRow.model.aFile)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: apps.count === 0
                text: view.sys.tr("Подходящих программ не нашлось")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }

        // Строки-подсказки внизу больше нет: длинный список наезжал на неё,
        // и получалась каша из имён файлов и справки.
    }

    // ------------------------------------------------------ приём файлов
    // Перетаскивание идёт через системный drag (Drag.Automatic), поэтому
    // работает и между двумя окнами проводника, а не только внутри одного.
    property var dropUrls: []
    property real dropX: 0
    property real dropY: 0
    property bool dropMenu: false
    // Куда именно кладём: пусто — в открытую папку, иначе в ту, над которой
    // отпустили. Так можно бросить прямо на строку каталога.
    property string dropDir: ""
    property string dropHover: ""

    function pathsOf(urls) {
        var out = [];
        for (var i = 0; i < urls.length; i++) {
            var u = String(urls[i]);
            if (u.indexOf("file://") === 0) u = u.substring(7);
            out.push(decodeURIComponent(u));
        }
        return out;
    }
    function dropRun(move) {
        var paths = view.pathsOf(view.dropUrls);
        if (paths.length === 0) { view.dropMenu = false; return; }
        // Все файлы одним процессом: pAction здесь один на всех, и цикл с
        // повторным running = true просто затирал бы предыдущий запуск.
        // Имена уходят отдельными аргументами, поэтому пробелы и кавычки
        // внутри них ничего не ломают.
        var op = move ? " move " : " copy ";
        var dest = view.dropDir.length ? view.dropDir : view.dir;
        var args = ["sh", "-c",
                    'd="$1"; shift; for f in "$@"; do ' + view.scripts + op
                    + '"$f" "$d"; done', "_", dest];
        pAction.command = args.concat(paths);
        pAction.running = true;
        view.dropMenu = false;
        view.dropUrls = [];
        view.dropDir = "";
        // перечитывать список тут не надо: pAction сделает это сам, когда
        // закончит. Две перезагрузки подряд запускали анимацию списка дважды,
        // и появление файла дёргалось.
    }

    // Общий приём: если отпустили не над папкой — кладём в открытый каталог.
    // Лежит под строками списка, поэтому их собственные области получают
    // событие первыми.
    function takeDrop(drop, targetDir, px, py) {
        if (!drop.hasUrls || drop.urls.length === 0) return;
        drop.accept(Qt.CopyAction);
        view.dropUrls = drop.urls;
        view.dropDir = targetDir;
        view.dropX = Math.max(6, Math.min(px, view.width - 192));
        view.dropY = Math.max(6, Math.min(py, view.height - 84));
        view.dropMenu = true;
    }

    DropArea {
        id: dropZone
        // Ниже всего: событие перетаскивания достаётся самой ВЕРХНЕЙ области
        // под курсором и дальше не идёт. Пока эта висела сверху, строки папок
        // до неё не доживали, и бросить файл в папку было нельзя.
        z: -1
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: drop => {
            var p = view.mapFromItem(dropZone, drop.x, drop.y);
            view.takeDrop(drop, "", p.x, p.y);
        }
    }

    // тонкая рамка, пока над окном что-то тащат: заливка во весь экран
    // мешала целиться в конкретную папку
    Rectangle {
        z: 6
        anchors.fill: parent
        visible: dropZone.containsDrag
        color: "transparent"
        border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.55)
        border.width: 2
        radius: 14
    }

    // что делать с перенесённым — спрашиваем, а не угадываем по модификатору
    MouseArea {
        z: 92
        anchors.fill: parent
        visible: view.dropMenu
        onClicked: { view.dropMenu = false; view.dropUrls = []; }
    }
    Rectangle {
        z: 93
        visible: view.dropMenu
        x: view.dropX
        y: view.dropY
        width: 186
        height: dropCol.implicitHeight + 12
        radius: 12
        color: Qt.rgba(0.06, 0.06, 0.07, 0.99)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            id: dropCol
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Repeater {
                model: [
                    { t: view.sys.tr("Скопировать сюда"), g: 0xF018F, mv: false },
                    { t: view.sys.tr("Переместить сюда"), g: 0xF0552, mv: true }
                ]
                Rectangle {
                    id: dropItem
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 9
                    color: dropItemMa.containsMouse ? view.sys.colHover : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 9
                        Text {
                            text: String.fromCodePoint(dropItem.modelData.g)
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 14 }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: dropItem.modelData.t
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }
                    }
                    MouseArea {
                        id: dropItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.dropRun(dropItem.modelData.mv)
                    }
                }
            }
        }
    }

    // ------------------------------------------------ слой контекстного меню
    MouseArea {
        anchors.fill: parent
        z: 90
        visible: view.menuOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: view.closeMenu()
    }

    Rectangle {
        id: menu
        z: 91
        visible: view.menuOpen
        x: view.menuX
        y: view.menuY
        width: 220
        height: menuCol.implicitHeight + 12
        radius: 14
        color: Qt.rgba(0.04, 0.04, 0.05, 0.98)
        border.color: view.sys.colLine
        border.width: 1

        opacity: view.menuOpen ? 1 : 0
        scale: view.menuOpen ? 1 : 0.94
        transformOrigin: Item.TopLeft
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

        ColumnLayout {
            id: menuCol
            anchors.fill: parent
            anchors.margins: 6
            spacing: 1

            // ---- меню для файла или папки
            MenuItem {
                visible: view.menuPath.length > 0
                glyph: String.fromCodePoint(0xF0770)
                label: view.menuIsDir ? view.sys.tr("Открыть папку") : view.sys.tr("Открыть")
                onChosen: view.doOpen(view.menuPath)
            }
            MenuItem {
                visible: view.menuPath.length > 0 && !view.menuIsDir
                glyph: String.fromCodePoint(0xF03CB)
                label: view.sys.tr("Открыть с помощью…")
                onChosen: view.doOpenWith(view.menuPath)
            }

            Rectangle {
                visible: view.menuPath.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 3
                Layout.bottomMargin: 3
                color: view.sys.colLine
            }

            MenuItem {
                visible: view.menuPath.length > 0
                glyph: String.fromCodePoint(0xF018F)
                label: view.sys.tr("Копировать")
                onChosen: view.doCopy(view.menuPath)
            }
            MenuItem {
                visible: view.menuPath.length > 0
                glyph: String.fromCodePoint(0xF0190)
                label: view.sys.tr("Вырезать")
                onChosen: view.doCut(view.menuPath)
            }
            MenuItem {
                visible: view.menuKind !== "trash"
                glyph: String.fromCodePoint(0xF0192)
                label: view.sys.tr("Вставить")
                enabledItem: view.clipPath.length > 0
                onChosen: view.doPaste()
            }
            MenuItem {
                visible: view.menuPath.length > 0
                glyph: String.fromCodePoint(0xF03EB)
                label: view.sys.tr("Переименовать")
                onChosen: view.startRename(view.menuPath)
            }
            MenuItem {
                visible: view.menuPath.length > 0
                glyph: String.fromCodePoint(0xF0219)
                label: view.sys.tr("Копировать путь")
                onChosen: view.doCopyPath(view.menuPath)
            }
            MenuItem {
                visible: view.menuPath.length > 0 && view.menuKind !== "trash"
                glyph: String.fromCodePoint(0xF02FD)   // информация
                label: view.sys.tr("Свойства")
                onChosen: view.showProps(view.menuPath)
            }

            Rectangle {
                visible: view.menuKind !== "trash"
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 3
                Layout.bottomMargin: 3
                color: view.sys.colLine
            }

            // ---- меню самой папки
            MenuItem {
                visible: view.menuKind !== "trash"
                glyph: String.fromCodePoint(0xF0257)
                label: view.sys.tr("Создать папку")
                onChosen: view.startMkdir()
            }
            MenuItem {
                visible: view.menuKind !== "trash"
                glyph: String.fromCodePoint(0xF0450)
                label: view.sys.tr("Обновить")
                onChosen: { view.closeMenu(); view.reload(); }
            }
            // ---- меню закладки «Корзина»
            MenuItem {
                visible: view.menuKind === "trash"
                glyph: String.fromCodePoint(0xF0A79)
                label: view.sys.tr("Очистить корзину")
                danger: true
                enabledItem: view.trashCount > 0
                onChosen: view.emptyTrash()
            }
            MenuItem {
                visible: view.menuPath.length > 0
                glyph: String.fromCodePoint(0xF0A79)
                label: view.sys.tr("В корзину")
                danger: true
                onChosen: view.doTrash(view.menuPath)
            }
        }
    }

    // ---------------------------------------------- диалог ввода имени
    MouseArea {
        anchors.fill: parent
        z: 95
        visible: view.dialogMode.length > 0
        onClicked: view.cancelDialog()
    }

    Rectangle {
        z: 96
        visible: view.dialogMode.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(20, view.height / 2 - height)
        width: 420
        height: 64
        radius: 32
        color: Qt.rgba(0.04, 0.04, 0.05, 0.98)
        border.color: view.sys.colOn
        border.width: 1

        scale: view.dialogMode.length > 0 ? 1 : 0.94
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 14
            spacing: 12

            Text {
                text: String.fromCodePoint(view.dialogMode === "mkdir" ? 0xF0257 : 0xF03EB)
                color: view.sys.colOn
                font { family: view.sys.fontFam; pixelSize: 18 }
            }
            TextField {
                id: dialogField
                Layout.fillWidth: true
                color: view.sys.colFg
                placeholderTextColor: view.sys.colMuted
                placeholderText: view.sys.tr("Имя")
                background: null
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize }
                onAccepted: view.confirmDialog()
                Keys.onEscapePressed: view.cancelDialog()
            }
            Rectangle {
                Layout.preferredWidth: 40; Layout.preferredHeight: 40
                radius: 20
                color: dialogField.text.trim().length ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.10)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF012C)
                    color: "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.confirmDialog()
                }
            }
        }
    }

    // ------------------------------------------------------ панель «Свойства»
    MouseArea {
        anchors.fill: parent
        z: 97
        visible: view.propsOpen
        onClicked: view.propsOpen = false
    }
    Rectangle {
        id: propsPanel
        z: 98
        visible: view.propsOpen
        anchors.centerIn: parent
        width: 440
        implicitHeight: propsCol.implicitHeight + 36
        radius: 20
        color: Qt.rgba(0.04, 0.04, 0.05, 0.98)
        border.color: view.sys.colLine
        border.width: 1
        scale: view.propsOpen ? 1 : 0.94
        opacity: view.propsOpen ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        readonly property bool isDir: String(view.propsData.kind || "") === "inode/directory"

        component PropRow: RowLayout {
            property string k: ""
            property string v: ""
            visible: v.length > 0
            Layout.fillWidth: true
            spacing: 12
            Text {
                Layout.preferredWidth: 130
                text: k
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
            }
            Text {
                Layout.fillWidth: true
                text: v
                color: view.sys.colFg
                wrapMode: Text.WrapAnywhere
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
            }
        }

        ColumnLayout {
            id: propsCol
            anchors.fill: parent
            anchors.margins: 18
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 11
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40
                    radius: 11
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Glyph {
                        anchors.fill: parent
                        glyph: String.fromCodePoint(propsPanel.isDir ? 0xF024B : 0xF0224)
                        color: view.sys.colOn
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: String(view.propsData.name || "")
                    color: view.sys.colFg
                    elide: Text.ElideMiddle
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize; bold: true }
                }
                Text {
                    text: "×"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 6 }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.propsOpen = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 1
                Layout.topMargin: 4; Layout.bottomMargin: 4
                color: view.sys.colLine
            }

            PropRow { k: view.sys.tr("Тип");        v: String(view.propsData.kind || "") }
            PropRow { k: view.sys.tr("Внутри");     v: propsPanel.isDir ? (String(view.propsData.items || "") + " " + view.sys.tr("элементов")) : "" }
            PropRow { k: view.sys.tr("Размер");     v: String(view.propsData.size_human || "")
                                                       + (view.propsData.size_bytes ? "  (" + view.propsData.size_bytes + " " + view.sys.tr("байт") + ")" : "") }
            PropRow { k: view.sys.tr("Разрешение"); v: String(view.propsData.resolution || "") }
            PropRow { k: view.sys.tr("Длительность"); v: view.propsData.duration ? view.fmtDuration(view.propsData.duration) : "" }
            PropRow { k: view.sys.tr("Изменён");    v: String(view.propsData.modified || "") }
            PropRow { k: view.sys.tr("Создан");     v: String(view.propsData.created || "") }
            PropRow { k: view.sys.tr("Права");      v: String(view.propsData.perms || "") }
            PropRow { k: view.sys.tr("Владелец");   v: String(view.propsData.owner || "") }
            PropRow { k: view.sys.tr("Путь");       v: String(view.propsData.path || "") }
        }
    }
}
