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

    // Раскладка содержимого: "list" | "grid". Живёт в настройках, а не в самом
    // виде: проводник открывают и закрывают десятками раз за сеанс, и каждый
    // раз возвращаться к списку, когда работаешь с картинками, — маета.
    readonly property string mode: view.sys.cfg.filesMode === "grid" ? "grid" : "list"
    function setMode(m) {
        if (view.mode === m) return;
        view.sys.cfg.filesMode = m;
        view.sys.saveCfg();
    }
    // Сколько плиток помещается в ряд. Нужно не только сетке: по этому же
    // числу стрелки вверх и вниз ходят на строку, а не на соседний файл.
    readonly property int gridCell: 118
    readonly property int gridCols: Math.max(1, Math.floor(view.width > 0
                                                           ? view.width / view.gridCell : 1))

    // выбранный файл, для которого показываем «чем открыть»
    property string openWithFile: ""

    // буфер обмена проводника
    property var    clipPaths: []
    property string clipPath: clipPaths.length ? clipPaths[0] : ""
    property string clipMode: ""        // "copy" | "cut"

    // мультивыделение файлов
    property var    selectedPaths: []
    readonly property int selectedCount: selectedPaths.length
    property int    anchorIndex: -1

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
        // Каталог, с которого попросили открыться (карусель живых обоев,
        // например). Одноразовый: дальше проводник ходит сам.
        if (!view.dir.length && view.sys.filesStartDir.length) {
            view.dir = view.sys.filesStartDir;
            view.sys.filesStartDir = "";
        }
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

    // Очередь коротких операций. pAction здесь один на всех, и вторая
    // операция, начатая пока идёт первая, затирала её команду и молча
    // пропадала. Копирование и перенос сюда не попадают — они уходят в
    // пилюлю, к своей очереди: см. runLong().
    property var opQueue: []

    Process {
        id: pAction
        onRunningChanged: {
            if (running) return;
            // следующая из очереди — до перечитывания списка: перечитывать
            // между операциями значит дважды проиграть анимацию появления
            if (view.opQueue.length > 0) {
                var q = view.opQueue.slice();
                var next = q.shift();
                view.opQueue = q;
                view.startOp(next.args, next.note);
                return;
            }
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
        pList.command = ["sh", "-c", view.scripts + " list \"$1\" \"$2\"", "_", view.dir,
                         view.sys.cfg.filesHidden ? "hidden" : ""];
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
        // Запускаем НЕ отсюда: следующей строкой панель закрывается, а вместе
        // с ней уничтожается вид и всё, что в нём объявлено, — включая
        // Process. Он умирал раньше, чем успевал запустить программу, и
        // проводник просто закрывался, ничего не открыв.
        view.sys.openFileWith(view.openWithFile, desktopFile || "");
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

    function startOp(args, note) {
        pAction.command = args;
        pAction.running = true;
        if (note !== undefined) view.say(note);
    }
    function run(args, note) {
        if (pAction.running) {
            var q = view.opQueue.slice();
            q.push({ args: args, note: note });
            view.opQueue = q;
            if (note !== undefined) view.say(note);
            return;
        }
        view.startOp(args, note);
    }

    // Копирование и перенос уходят в пилюлю: они длятся минутами, а панель
    // закрывают сразу после того, как перетащили файлы. Здесь их процесс
    // умер бы вместе с Loader'ом, на середине.
    function runLong(args, note, label) {
        view.sys.runFileOp(args, label);
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
    // ---------------------------------------------------- мультивыделение
    function isSelected(path) {
        return view.selectedPaths.indexOf(path) !== -1;
    }
    function toggleSelection(path, idx) {
        var copy = view.selectedPaths.slice();
        var i = copy.indexOf(path);
        if (i !== -1) copy.splice(i, 1);
        else copy.push(path);
        view.selectedPaths = copy;
        if (idx !== undefined) view.anchorIndex = idx;
    }
    function selectSingle(path, idx) {
        view.selectedPaths = [path];
        if (idx !== undefined) view.anchorIndex = idx;
    }
    function selectRange(targetIdx) {
        if (view.anchorIndex < 0) view.anchorIndex = view.current;
        var start = Math.min(view.anchorIndex, targetIdx);
        var end = Math.max(view.anchorIndex, targetIdx);
        var res = [];
        for (var i = start; i <= end; i++) {
            if (i >= 0 && i < entries.count) {
                res.push(view.fullPath(entries.get(i).eName));
            }
        }
        view.selectedPaths = res;
    }
    function selectAll() {
        var res = [];
        for (var i = 0; i < entries.count; i++) {
            res.push(view.fullPath(entries.get(i).eName));
        }
        view.selectedPaths = res;
    }
    function clearSelection() {
        view.selectedPaths = [];
        view.anchorIndex = -1;
    }
    function updateSelectionByRect(rx, ry, rw, rh) {
        var rectX2 = rx + rw;
        var rectY2 = ry + rh;
        var matched = [];

        if (view.mode === "list") {
            var rowH = 42;
            var scrollY = list.contentY;
            for (var i = 0; i < entries.count; i++) {
                var itemY = i * rowH - scrollY;
                var itemY2 = itemY + rowH;
                if (itemY2 >= ry && itemY <= rectY2) {
                    matched.push(view.fullPath(entries.get(i).eName));
                }
            }
        } else {
            var cols = view.gridCols;
            var cellW = grid.cellWidth;
            var cellH = grid.cellHeight;
            var scrollY = grid.contentY;
            for (var j = 0; j < entries.count; j++) {
                var colIdx = j % cols;
                var rowIdx = Math.floor(j / cols);
                var itemX = colIdx * cellW;
                var itemX2 = itemX + cellW;
                var itemY = rowIdx * cellH - scrollY;
                var itemY2 = itemY + cellH;

                if (itemX2 >= rx && itemX <= rectX2 && itemY2 >= ry && itemY <= rectY2) {
                    matched.push(view.fullPath(entries.get(j).eName));
                }
            }
        }
        view.selectedPaths = matched;
    }

    // ----------------------------------------------------------- архивы
    function isArchive(path) {
        if (!path) return false;
        var l = String(path).toLowerCase();
        return l.endsWith(".zip") || l.endsWith(".tar.gz") || l.endsWith(".tgz")
            || l.endsWith(".tar.xz") || l.endsWith(".txz") || l.endsWith(".tar.bz2")
            || l.endsWith(".tbz2") || l.endsWith(".tar.zst") || l.endsWith(".tar")
            || l.endsWith(".7z") || l.endsWith(".rar") || l.endsWith(".gz")
            || l.endsWith(".xz") || l.endsWith(".zst") || l.endsWith(".bz2")
            || l.endsWith(".iso");
    }
    function archiveFolderName(path) {
        var name = view.baseName(path);
        name = name.replace(/\.(tar\.(gz|xz|bz2|zst)|tgz|txz|tbz2|zip|7z|rar|iso|gz|xz|zst|bz2)$/i, "");
        return name || "extracted";
    }
    function hasArchiveSelected() {
        for (var i = 0; i < view.selectedPaths.length; i++) {
            if (view.isArchive(view.selectedPaths[i])) return true;
        }
        return false;
    }
    function doExtractHere(path) {
        closeMenu();
        runLong(["sh", "-c", view.scripts + " extract \"$1\" \"$2\"", "_", path, view.dir],
                view.sys.tr("Распаковано: ") + view.baseName(path),
                view.baseName(path));
    }
    function doExtractToFolder(path) {
        closeMenu();
        var folder = view.dir + "/" + view.archiveFolderName(path);
        runLong(["sh", "-c", view.scripts + " extract \"$1\" \"$2\"", "_", path, folder],
                view.sys.tr("Распаковано в ") + view.archiveFolderName(path) + "/",
                view.baseName(path));
    }
    function doExtractAllSelected(toSubfolders) {
        closeMenu();
        var paths = view.selectedPaths.filter(view.isArchive);
        if (!paths.length && view.isArchive(view.menuPath)) paths = [view.menuPath];
        if (!paths.length) return;
        for (var i = 0; i < paths.length; i++) {
            var p = paths[i];
            var dst = toSubfolders ? (view.dir + "/" + view.archiveFolderName(p)) : view.dir;
            view.runLong(["sh", "-c", view.scripts + " extract \"$1\" \"$2\"", "_", p, dst],
                         view.sys.tr("Распаковано: ") + view.baseName(p),
                         view.baseName(p));
        }
    }

    function doCopy(path) {
        var targets = (view.selectedCount > 1 && (path === "" || view.isSelected(path)))
                    ? view.selectedPaths.slice()
                    : (path ? [path] : []);
        if (!targets.length) return;
        view.clipPaths = targets;
        view.clipMode = "copy";
        closeMenu();
        if (targets.length === 1) {
            view.say(view.sys.tr("Скопировано: ") + view.baseName(targets[0]));
        } else {
            view.say(view.sys.tr("Скопировано файлов: ") + targets.length);
        }
    }
    function doCut(path) {
        var targets = (view.selectedCount > 1 && (path === "" || view.isSelected(path)))
                    ? view.selectedPaths.slice()
                    : (path ? [path] : []);
        if (!targets.length) return;
        view.clipPaths = targets;
        view.clipMode = "cut";
        closeMenu();
        if (targets.length === 1) {
            view.say(view.sys.tr("Вырезано: ") + view.baseName(targets[0]));
        } else {
            view.say(view.sys.tr("Вырезано файлов: ") + targets.length);
        }
    }
    function doPaste() {
        if (!view.clipPaths.length) return;
        var op = view.clipMode === "cut" ? "move" : "copy";
        closeMenu();
        var label = view.clipPaths.length === 1 ? view.baseName(view.clipPaths[0])
                                               : (view.clipPaths.length + " " + view.sys.tr("файлов"));
        var note = (view.clipMode === "cut" ? view.sys.tr("Перемещено: ")
                                            : view.sys.tr("Вставлено: ")) + label;
        var cmd = ["sh", "-c", view.scripts + " " + op + " \"$1\" \"keepboth\" \"${@:2}\"", "_", view.dir];
        cmd = cmd.concat(view.clipPaths);
        runLong(cmd, note, label);
        if (view.clipMode === "cut") { view.clipPaths = []; view.clipMode = ""; }
    }
    function doCopyPath(path) {
        var targets = (view.selectedCount > 1 && (path === "" || view.isSelected(path)))
                    ? view.selectedPaths.slice()
                    : (path ? [path] : []);
        if (!targets.length) return;
        closeMenu();
        var text = targets.join("\n");
        run(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", text],
            view.sys.tr("Путь скопирован"));
    }
    function doTrash(path) {
        var targets = (view.selectedCount > 1 && (path === "" || view.isSelected(path)))
                    ? view.selectedPaths.slice()
                    : (path ? [path] : []);
        if (!targets.length) return;
        closeMenu();
        var cmd = ["sh", "-c", view.scripts + " trash \"$@\"", "_"].concat(targets);
        var label = targets.length === 1 ? view.baseName(targets[0])
                                         : (targets.length + " " + view.sys.tr("файлов"));
        run(cmd, view.sys.tr("В корзину: ") + label);
        view.clearSelection();
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
        if (view.selectedCount > 0) { view.clearSelection(); return; }
        if (view.openWithFile.length) { view.openWithFile = ""; return; }
        if (view.filter.length) { view.filter = ""; applyFilter(); return; }
        view.leave();
    }
    // В сетке вверх и вниз ходят на строку, а не на соседний файл: иначе
    // стрелка вниз ползла бы вдоль ряда, а глаз ждёт, что она опустится под
    // курсор. В списке строка и есть один файл, поэтому шаг там прежний.
    function step(delta) {
        var n = entries.count;
        if (n === 0) return;
        view.current = Math.max(0, Math.min(n - 1, view.current + delta));
    }
    // Пока открыт список «чем открыть», стрелки ходят по нему: он и есть то,
    // с чем сейчас работают. Ходить в это время по спрятанному списку файлов
    // бессмысленно — его не видно.
    Keys.onUpPressed:    view.openWithFile.length ? appList.step(-1)
                       : view.step(view.mode === "grid" ? -view.gridCols : -1)
    Keys.onDownPressed:  view.openWithFile.length ? appList.step(1)
                       : view.step(view.mode === "grid" ?  view.gridCols :  1)
    Keys.onLeftPressed:  if (view.mode === "grid") view.step(-1)
    Keys.onRightPressed: if (view.mode === "grid") view.step(1)
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
        if (event.key === Qt.Key_Delete) {
            if (view.selectedCount > 0) {
                view.doTrash("");
            } else {
                view.trashCurrent();
            }
            event.accepted = true;
            return;
        }
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_A) { view.selectAll(); event.accepted = true; return; }
            var p = view.currentPath();
            if (event.key === Qt.Key_C) { view.doCopy(p); event.accepted = true; return; }
            if (event.key === Qt.Key_X) { view.doCut(p); event.accepted = true; return; }
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
                color: parent.parent.danger ? view.sys.colCrit : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 14 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.label
                color: parent.parent.danger ? view.sys.colCrit : view.sys.colFg
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
        // В отдельном окне колонка обязана занять его целиком: список внутри
        // тянется на всю оставшуюся высоту. Без этого окно любого размера
        // показывало список одной и той же высоты, а под ним оставалась
        // чёрная полоса в треть экрана — файлы приходилось прокручивать в
        // окне, где на них хватало места с запасом.
        height: view.windowMode ? view.height : col.implicitHeight
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

            // ------------------------------------------- список или сетка
            // Две кнопки, а не выпадающий список: режимов ровно два, и между
            // ними переключаются часто. Выбор запоминается в настройках, иначе
            // проводник каждый раз открывался бы не тем, чем его закрыли.
            Rectangle {
                Layout.preferredWidth: 76
                Layout.preferredHeight: 38
                radius: 19
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: view.sys.colLine
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        model: [
                            { id: "list", g: 0xF0279 },   // md-format_list_bulleted
                            { id: "grid", g: 0xF0A0E }    // md-view_grid_outline
                        ]

                        Rectangle {
                            required property var modelData
                            readonly property bool on: view.mode === modelData.id

                            width: 34; height: 30
                            radius: 15
                            color: on ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                                view.sys.colOn.b, 0.25)
                                 : (modeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08)
                                                         : "transparent")
                            Behavior on color { ColorAnimation { duration: 130 } }

                            Glyph {
                                anchors.centerIn: parent
                                glyph: String.fromCodePoint(parent.modelData.g)
                                color: parent.on ? view.sys.colOn : view.sys.colMuted
                                fontFam: view.sys.fontFam
                                size: 15
                            }

                            MouseArea {
                                id: modeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.setMode(parent.modelData.id)
                            }
                        }
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

                    // Скрытые файлы. Выбор запоминается в настройках, а не
                    // живёт до закрытия окна: человек решает это один раз и
                    // не любит возвращаться к решению каждое утро.
                    Rectangle {
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: hidTxt.implicitWidth + 26
                        radius: 9
                        color: view.sys.cfg.filesHidden
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                         view.sys.colOn.b, 0.18)
                             : (hidMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: String.fromCodePoint(
                                          view.sys.cfg.filesHidden ? 0xF06D0 : 0xF06D1)
                                color: view.sys.cfg.filesHidden ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                            }
                            Text {
                                id: hidTxt
                                text: view.sys.tr("Скрытые")
                                color: view.sys.cfg.filesHidden ? view.sys.colFg : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                            }
                        }
                        MouseArea {
                            id: hidMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                view.sys.cfg.filesHidden = !view.sys.cfg.filesHidden;
                                view.sys.saveCfg();
                                view.reload();
                            }
                        }
                    }

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
                    visible: view.mode === "list"
                    Layout.fillWidth: true
                    // В пилюле высоту держим постоянной: список не должен
                    // «дышать» при переходе между папками с разным числом
                    // файлов. В отдельном окне наоборот — он занимает всё,
                    // что окно даёт, иначе часть окна пропадает впустую.
                    Layout.fillHeight: view.windowMode
                    Layout.preferredHeight: view.windowMode ? 0 : view.sys.filesListH
                    Layout.minimumHeight: view.windowMode ? 120 : 0
                    clip: true
                    model: entries
                    currentIndex: view.current
                    highlightMoveDuration: 130
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    // Рамка выделения внутри ListView
                    Rectangle {
                        id: listRubberBand
                        z: 90
                        visible: false
                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                        border.color: view.sys.colOn
                        border.width: 1
                        radius: 4
                    }

                    // Мышью список не таскается. ListView — это Flickable, а он
                    // по умолчанию понимает зажатую кнопку как прокрутку: то
                    // есть ровно тем же движением, которым файл берут, чтобы
                    // перетащить. Список уезжал из-под курсора на первых же
                    // пикселях, и перетаскивание превращалось в лотерею.
                    //
                    // Это поведение с сенсорного экрана, где другого способа
                    // прокрутить нет. Здесь есть колесо, и оно однозначно.
                    interactive: false

                    // interactive: false выключает у Flickable и колесо тоже,
                    // поэтому крутим сами. У мыши шаг приходит в angleDelta
                    // (одна «ступенька» — 120), у тачпада в pixelDelta и
                    // мелкими порциями; берём то, что пришло.
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function (ev) {
                            var step = ev.pixelDelta.y !== 0 ? ev.pixelDelta.y
                                     : ev.angleDelta.y;
                            if (step === 0) return;
                            var max = Math.max(0, list.contentHeight - list.height);
                            list.contentY = Math.max(0, Math.min(max, list.contentY - step));
                        }
                    }

                    // Подложка под делегатами: правый клик по пустому месту
                    // даёт меню самой папки. Живёт внутри ListView, иначе
                    // anchors ругались бы на управление со стороны Layout.
                    MouseArea {
                        id: listBgMa
                        anchors.fill: parent
                        z: -1
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true

                        property real startX: 0
                        property real startY: 0
                        property bool selecting: false

                        onPressed: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                startX = mouse.x;
                                startY = mouse.y;
                                selecting = true;
                                if (!(mouse.modifiers & Qt.ControlModifier)) {
                                    view.clearSelection();
                                }
                            }
                        }

                        onPositionChanged: mouse => {
                            if (!selecting || mouse.buttons !== Qt.LeftButton) return;
                            var rx = Math.min(startX, mouse.x);
                            var ry = Math.min(startY, mouse.y);
                            var rw = Math.abs(mouse.x - startX);
                            var rh = Math.abs(mouse.y - startY);

                            if (rw > 5 || rh > 5) {
                                listRubberBand.x = rx;
                                listRubberBand.y = ry;
                                listRubberBand.width = rw;
                                listRubberBand.height = rh;
                                listRubberBand.visible = true;

                                view.updateSelectionByRect(rx, ry, rw, rh);
                            }
                        }

                        onReleased: mouse => {
                            if (selecting) {
                                selecting = false;
                                listRubberBand.visible = false;
                            }
                        }

                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                var p = mapToItem(view, mouse.x, mouse.y);
                                view.openMenu("", true, p.x, p.y);
                            } else if (mouse.button === Qt.LeftButton) {
                                if (listRubberBand.width <= 5 && listRubberBand.height <= 5) {
                                    view.clearSelection();
                                }
                            }
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
                        readonly property bool isSelected:
                            view.isSelected(view.fullPath(row.model.eName))

                        color: row.dropTarget
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                         view.sys.colOn.b, 0.28)
                             : row.isSelected
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                         view.sys.colOn.b, 0.20)
                             : index === view.current ? Qt.rgba(1, 1, 1, 0.09)
                             : (rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }
                        border.color: row.dropTarget ? view.sys.colOn
                                    : row.isSelected ? view.sys.colOn
                                    : "transparent"
                        border.width: (row.dropTarget || row.isSelected) ? 1 : 0

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
                                    bold: row.index === view.current || row.isSelected
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
                                var p = view.fullPath(row.model.eName);
                                if (!view.isSelected(p)) view.selectSingle(p, row.index);
                                // панель сворачивается, файл остаётся на курсоре
                                view.sys.startFileDrag(p, view.windowMode);
                            }

                            onClicked: mouse => {
                                if (rowMa.dragging) return;
                                var p = view.fullPath(row.model.eName);
                                view.current = row.index;
                                view.forceActiveFocus();
                                if (mouse.button === Qt.RightButton) {
                                    if (!view.isSelected(p)) {
                                        view.selectSingle(p, row.index);
                                    }
                                    var pos = mapToItem(view, mouse.x, mouse.y);
                                    view.openMenu(p, row.model.eType === "d", pos.x, pos.y);
                                    return;
                                }
                                if (mouse.modifiers & Qt.ControlModifier) {
                                    view.toggleSelection(p, row.index);
                                } else if (mouse.modifiers & Qt.ShiftModifier) {
                                    view.selectRange(row.index);
                                } else {
                                    view.selectSingle(p, row.index);
                                }
                            }
                            onDoubleClicked: view.activate(row.index)
                        }
                    }
                }

                // ------------------------------------------------- сетка
                // Тот же список, разложенный плитками: значок крупно, имя под
                // ним в две строки. Пригождается там, где по имени файл не
                // узнать, — снимки, обои, загрузки.
                //
                // Модель, выделение, перетаскивание и меню — те же, что у
                // списка: это одна и та же папка, показанная иначе, и вести
                // себя она обязана одинаково.
                GridView {
                    id: grid
                    visible: view.mode === "grid"
                    Layout.fillWidth: true
                    Layout.fillHeight: view.windowMode
                    Layout.preferredHeight: view.windowMode ? 0 : view.sys.filesListH
                    Layout.minimumHeight: view.windowMode ? 120 : 0
                    clip: true
                    model: entries
                    currentIndex: view.current
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                    cellWidth: Math.floor(width / view.gridCols)
                    cellHeight: 104

                    // Мышью не таскается — по той же причине, что и список:
                    // зажатая кнопка здесь берёт файл, а не крутит содержимое.
                    interactive: false
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function (ev) {
                            var step = ev.pixelDelta.y !== 0 ? ev.pixelDelta.y
                                     : ev.angleDelta.y;
                            if (step === 0) return;
                            var max = Math.max(0, grid.contentHeight - grid.height);
                            grid.contentY = Math.max(0, Math.min(max, grid.contentY - step));
                        }
                    }

                    // Рамка выделения внутри GridView
                    Rectangle {
                        id: gridRubberBand
                        z: 90
                        visible: false
                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                        border.color: view.sys.colOn
                        border.width: 1
                        radius: 4
                    }

                    MouseArea {
                        id: gridBgMa
                        anchors.fill: parent
                        z: -1
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true

                        property real startX: 0
                        property real startY: 0
                        property bool selecting: false

                        onPressed: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                startX = mouse.x;
                                startY = mouse.y;
                                selecting = true;
                                if (!(mouse.modifiers & Qt.ControlModifier)) {
                                    view.clearSelection();
                                }
                            }
                        }

                        onPositionChanged: mouse => {
                            if (!selecting || mouse.buttons !== Qt.LeftButton) return;
                            var rx = Math.min(startX, mouse.x);
                            var ry = Math.min(startY, mouse.y);
                            var rw = Math.abs(mouse.x - startX);
                            var rh = Math.abs(mouse.y - startY);

                            if (rw > 5 || rh > 5) {
                                gridRubberBand.x = rx;
                                gridRubberBand.y = ry;
                                gridRubberBand.width = rw;
                                gridRubberBand.height = rh;
                                gridRubberBand.visible = true;

                                view.updateSelectionByRect(rx, ry, rw, rh);
                            }
                        }

                        onReleased: mouse => {
                            if (selecting) {
                                selecting = false;
                                gridRubberBand.visible = false;
                            }
                        }

                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                var p = mapToItem(view, mouse.x, mouse.y);
                                view.openMenu(view.dir, true, p.x, p.y);
                            } else if (mouse.button === Qt.LeftButton) {
                                if (gridRubberBand.width <= 5 && gridRubberBand.height <= 5) {
                                    view.clearSelection();
                                }
                            }
                        }
                    }

                    delegate: Rectangle {
                        id: tile
                        required property int index
                        required property var model

                        width: grid.cellWidth - 6
                        height: grid.cellHeight - 6
                        radius: 14
                        readonly property bool dropTarget:
                            tile.model.eType === "d" && tileDrop.containsDrag
                        readonly property bool isSelected:
                            view.isSelected(view.fullPath(tile.model.eName))

                        color: tile.dropTarget
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                         view.sys.colOn.b, 0.28)
                             : tile.isSelected
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                         view.sys.colOn.b, 0.20)
                             : index === view.current ? Qt.rgba(1, 1, 1, 0.09)
                             : (tileMa.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }
                        border.color: tile.dropTarget ? view.sys.colOn
                                    : tile.isSelected ? view.sys.colOn
                                    : "transparent"
                        border.width: (tile.dropTarget || tile.isSelected) ? 1 : 0

                        DropArea {
                            id: tileDrop
                            anchors.fill: parent
                            keys: ["text/uri-list"]
                            enabled: tile.model.eType === "d"
                            onDropped: drop => {
                                var p = view.mapFromItem(tile, drop.x, drop.y);
                                view.takeDrop(drop, view.fullPath(tile.model.eName), p.x, p.y);
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.topMargin: 12
                            anchors.bottomMargin: 8
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 6

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: view.iconFor(tile.model)
                                color: tile.model.eType === "d" ? view.sys.colOn
                                                                : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 34 }
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: tile.model.eName
                                color: view.sys.colFg
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: view.sys.fontSize - 4
                                    bold: tile.index === view.current || tile.isSelected
                                }
                            }
                        }

                        MouseArea {
                            id: tileMa
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
                                if (Math.abs(mouse.x - pressX) < 12
                                    && Math.abs(mouse.y - pressY) < 12) return;
                                view.current = tile.index;
                                dragging = true;
                                var p = view.fullPath(tile.model.eName);
                                if (!view.isSelected(p)) view.selectSingle(p, tile.index);
                                view.sys.startFileDrag(p, view.windowMode);
                            }

                            onClicked: mouse => {
                                if (tileMa.dragging) return;
                                var p = view.fullPath(tile.model.eName);
                                view.current = tile.index;
                                view.forceActiveFocus();
                                if (mouse.button === Qt.RightButton) {
                                    if (!view.isSelected(p)) {
                                        view.selectSingle(p, tile.index);
                                    }
                                    var pos = mapToItem(view, mouse.x, mouse.y);
                                    view.openMenu(p, tile.model.eType === "d", pos.x, pos.y);
                                    return;
                                }
                                if (mouse.modifiers & Qt.ControlModifier) {
                                    view.toggleSelection(p, tile.index);
                                } else if (mouse.modifiers & Qt.ShiftModifier) {
                                    view.selectRange(tile.index);
                                } else {
                                    view.selectSingle(p, tile.index);
                                }
                            }
                            onDoubleClicked: view.activate(tile.index)
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
            // Не во всю ширину: проводник занимает 78% экрана, и список из
            // пяти программ, растянутый на всю эту ширину, читался как
            // случайно раскрытая таблица. Список выбора должен быть узким и по
            // центру — глаз идёт по именам сверху вниз, а не слева направо.
            Layout.fillWidth: true
            Layout.maximumWidth: 520
            Layout.alignment: Qt.AlignHCenter
            spacing: 3
            visible: view.openWithFile.length > 0

            // Какая программа сейчас выбрана. Раньше Enter всегда запускал
            // ПЕРВУЮ: выбранной строки не существовало, а currentFile()
            // возвращал apps.get(0). Стрелками выбрать было нечего.
            property int index: 0
            onVisibleChanged: if (visible) appList.index = 0

            function currentFile() {
                if (apps.count === 0) return "";
                var i = Math.max(0, Math.min(apps.count - 1, appList.index));
                return apps.get(i).aFile;
            }
            function step(d) {
                if (apps.count === 0) return;
                appList.index = Math.max(0, Math.min(apps.count - 1, appList.index + d));
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
                    // Выделена выбранная строка, а не первая: раньше подсветка
                    // стояла на программе по умолчанию и не двигалась, из-за
                    // чего было не видно, что именно запустит Enter.
                    color: appRow.index === appList.index ? Qt.rgba(1, 1, 1, 0.11)
                         : (appMa.containsMouse ? view.sys.colHover : "transparent")
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
                                bold: appRow.index === appList.index
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
                        onEntered: appList.index = appRow.index
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
    // Что выбрали в первом меню, и что уже лежит в каталоге назначения.
    property bool dropMove: false
    property var  dropConflicts: []
    property bool dropAsk: false

    function dirOf(p) {
        var s = String(p).replace(/\/+$/, "");
        var i = s.lastIndexOf("/");
        return i <= 0 ? "/" : s.substring(0, i);
    }
    function dropTargetDir() {
        return view.dropDir.length ? view.dropDir : view.dir;
    }

    // То из перетаскиваемого, что действительно куда-то поедет.
    //
    // Файл, отпущенный там же, где он и лежал, никуда не переносится: копия
    // рядом с оригиналом — это не то, что человек имел в виду, отпустив кнопку
    // в паре сантиметров от места, где нажал. И папку внутрь себя самой класть
    // тоже незачем.
    function movablePaths() {
        var dest = view.dropTargetDir();
        var all = view.pathsOf(view.dropUrls), out = [];
        for (var i = 0; i < all.length; i++) {
            var p = String(all[i]).replace(/\/+$/, "");
            if (p === dest) continue;               // папка сама в себя
            if (view.dirOf(p) === dest) continue;   // уже здесь
            out.push(all[i]);
        }
        return out;
    }

    function dropCancel() {
        view.dropMenu = false;
        view.dropAsk = false;
        view.dropUrls = [];
        view.dropDir = "";
        view.dropConflicts = [];
    }

    // Первый вопрос: переместить или скопировать. Второй — что делать с
    // совпавшими именами — задаём только если совпадения есть, и только
    // после того, как выбран сам способ.
    Process {
        id: pConflicts
        stdout: StdioCollector {
            onStreamFinished: {
                var names = String(text).trim().split("\n").filter(function (x) {
                    return x.length > 0;
                });
                if (names.length === 0) { view.dropRun("keepboth"); return; }
                view.dropConflicts = names;
                view.dropAsk = true;
            }
        }
    }

    function dropPick(move) {
        var paths = view.movablePaths();
        if (paths.length === 0) { view.dropCancel(); return; }
        view.dropMove = move;
        view.dropMenu = false;
        pConflicts.running = false;
        pConflicts.command = ["sh", "-c", view.scripts + ' conflicts "$@"',
                              "_", view.dropTargetDir()].concat(paths);
        pConflicts.running = true;
    }

    function dropRun(mode) {
        var paths = view.movablePaths();
        if (paths.length === 0) { view.dropCancel(); return; }
        // Все файлы одним вызовом: скрипт сам обходит список и считает по
        // нему общий прогресс. Имена уходят отдельными аргументами, поэтому
        // пробелы и кавычки внутри них ничего не ломают.
        var op = view.dropMove ? "move" : "copy";
        var dest = view.dropTargetDir();
        var args = ["sh", "-c", view.scripts + " " + op + ' "$@"',
                    "_", dest, mode].concat(paths);
        view.runLong(args, undefined,
                     paths.length === 1 ? view.baseName(paths[0])
                                        : view.sys.tr("Файлов: ") + paths.length);
        view.dropCancel();
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

        // Отпустили там же, откуда взяли, — переносить нечего, и спрашивать не
        // о чем: любой ответ ничего бы не изменил. Меню в этом случае было
        // чистой помехой — оно появлялось на каждый промах мимо цели и его
        // приходилось закрывать.
        if (view.movablePaths().length === 0) {
            view.dropCancel();
            return;
        }

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
        onClicked: view.dropCancel()
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
                        onClicked: view.dropPick(dropItem.modelData.mv)
                    }
                }
            }
        }
    }

    // ------------------------------- совпавшие имена: что с ними делать
    // Второй вопрос задаётся только когда есть о чём спрашивать, и уже после
    // того, как выбран способ переноса. Раньше совпадения разбирались молча:
    // рядом появлялся «файл-2», и человек узнавал об этом, когда искал глазами
    // тот, что клал.
    MouseArea {
        z: 94
        anchors.fill: parent
        visible: view.dropAsk
        onClicked: view.dropCancel()
    }
    Rectangle {
        z: 95
        visible: view.dropAsk
        x: view.dropX
        y: view.dropY
        width: 236
        height: askCol.implicitHeight + 12
        radius: 12
        color: Qt.rgba(0.06, 0.06, 0.07, 0.99)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            id: askCol
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.topMargin: 6
                Layout.bottomMargin: 2
                text: view.dropConflicts.length === 1
                      ? view.sys.tr("Уже есть: ") + view.dropConflicts[0]
                      : view.sys.tr("Совпало имён: ") + view.dropConflicts.length
                color: view.sys.colMuted
                elide: Text.ElideMiddle
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
            }

            Repeater {
                model: [
                    { t: view.sys.tr("Заменить"),     g: 0xF0450, m: "overwrite" },
                    { t: view.sys.tr("Оставить оба"), g: 0xF018F, m: "keepboth" },
                    { t: view.sys.tr("Пропустить"),   g: 0xF0156, m: "skip" }
                ]
                Rectangle {
                    id: askItem
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 9
                    color: askItemMa.containsMouse ? view.sys.colHover : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 9
                        Text {
                            text: String.fromCodePoint(askItem.modelData.g)
                            color: askItem.modelData.m === "overwrite"
                                   ? view.sys.colCrit : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 14 }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: askItem.modelData.t
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }
                    }
                    MouseArea {
                        id: askItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.dropRun(askItem.modelData.m)
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
                visible: view.menuPath.length > 0 && view.selectedCount <= 1
                glyph: String.fromCodePoint(0xF0770)
                label: view.menuIsDir ? view.sys.tr("Открыть папку") : view.sys.tr("Открыть")
                onChosen: view.doOpen(view.menuPath)
            }
            MenuItem {
                visible: view.menuPath.length > 0 && !view.menuIsDir && view.selectedCount <= 1
                glyph: String.fromCodePoint(0xF03CB)
                label: view.sys.tr("Открыть с помощью…")
                onChosen: view.doOpenWith(view.menuPath)
            }

            // ---- меню для архивов
            MenuItem {
                visible: view.menuPath.length > 0 && !view.menuIsDir && view.isArchive(view.menuPath) && view.selectedCount <= 1
                glyph: String.fromCodePoint(0xF05C0)
                label: view.sys.tr("Распаковать сюда")
                onChosen: view.doExtractHere(view.menuPath)
            }
            MenuItem {
                visible: view.menuPath.length > 0 && !view.menuIsDir && view.isArchive(view.menuPath) && view.selectedCount <= 1
                glyph: String.fromCodePoint(0xF024B)
                label: view.sys.tr("Распаковать в ") + view.archiveFolderName(view.menuPath) + "/"
                onChosen: view.doExtractToFolder(view.menuPath)
            }
            MenuItem {
                visible: view.selectedCount > 1 && view.hasArchiveSelected()
                glyph: String.fromCodePoint(0xF05C0)
                label: view.sys.tr("Распаковать архивы в папки")
                onChosen: view.doExtractAllSelected(true)
            }

            Rectangle {
                visible: view.menuPath.length > 0 || view.selectedCount > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 3
                Layout.bottomMargin: 3
                color: view.sys.colLine
            }

            MenuItem {
                visible: view.menuPath.length > 0 || view.selectedCount > 0
                glyph: String.fromCodePoint(0xF018F)
                label: view.selectedCount > 1 ? (view.sys.tr("Копировать (") + view.selectedCount + ")")
                                             : view.sys.tr("Копировать")
                onChosen: view.doCopy(view.menuPath)
            }
            MenuItem {
                visible: view.menuPath.length > 0 || view.selectedCount > 0
                glyph: String.fromCodePoint(0xF0190)
                label: view.selectedCount > 1 ? (view.sys.tr("Вырезать (") + view.selectedCount + ")")
                                             : view.sys.tr("Вырезать")
                onChosen: view.doCut(view.menuPath)
            }
            MenuItem {
                visible: view.menuKind !== "trash"
                glyph: String.fromCodePoint(0xF0192)
                label: view.clipPaths.length > 1 ? (view.sys.tr("Вставить (") + view.clipPaths.length + ")")
                                                : view.sys.tr("Вставить")
                enabledItem: view.clipPaths.length > 0
                onChosen: view.doPaste()
            }
            MenuItem {
                visible: view.menuPath.length > 0 && view.selectedCount <= 1
                glyph: String.fromCodePoint(0xF03EB)
                label: view.sys.tr("Переименовать")
                onChosen: view.startRename(view.menuPath)
            }
            MenuItem {
                visible: view.menuPath.length > 0 || view.selectedCount > 0
                glyph: String.fromCodePoint(0xF0219)
                label: view.sys.tr("Копировать путь")
                onChosen: view.doCopyPath(view.menuPath)
            }
            MenuItem {
                visible: view.menuPath.length > 0 && view.menuKind !== "trash" && view.selectedCount <= 1
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
                visible: view.menuPath.length > 0 || view.selectedCount > 0
                glyph: String.fromCodePoint(0xF0A79)
                label: view.selectedCount > 1 ? (view.sys.tr("В корзину (") + view.selectedCount + ")")
                                             : view.sys.tr("В корзину")
                danger: true
                onChosen: view.doTrash(view.menuPath)
            }
        }
    }

    // ------------------------------------------------ плашка мультивыделения
    Rectangle {
        id: multiActionBar
        z: 88
        visible: view.selectedCount > 1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(view.width - 24, multiRow.implicitWidth + 32)
        height: 42
        radius: 21
        color: Qt.rgba(0.06, 0.06, 0.08, 0.96)
        border.color: view.sys.colLine
        border.width: 1

        RowLayout {
            id: multiRow
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: 8

            Text {
                text: view.selectedCount + " " + view.sys.tr("выбрано")
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: view.sys.colLine
            }

            // Копировать
            Rectangle {
                width: 30; height: 30; radius: 15
                color: btnCopyMa.containsMouse ? view.sys.colHover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF018F)
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }
                MouseArea {
                    id: btnCopyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.doCopy(view.selectedPaths[0])
                }
            }

            // Вырезать
            Rectangle {
                width: 30; height: 30; radius: 15
                color: btnCutMa.containsMouse ? view.sys.colHover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF0190)
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }
                MouseArea {
                    id: btnCutMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.doCut(view.selectedPaths[0])
                }
            }

            // Распаковать
            Rectangle {
                visible: view.hasArchiveSelected()
                width: 30; height: 30; radius: 15
                color: btnExtMa.containsMouse ? view.sys.colHover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF05C0)
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }
                MouseArea {
                    id: btnExtMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.doExtractAllSelected(true)
                }
            }

            // В корзину
            Rectangle {
                width: 30; height: 30; radius: 15
                color: btnTrashMa.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.18) : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF0A79)
                    color: view.sys.colCrit
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }
                MouseArea {
                    id: btnTrashMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.doTrash("")
                }
            }

            // Снять выделение
            Rectangle {
                width: 26; height: 26; radius: 13
                color: btnCloseMa.containsMouse ? view.sys.colHover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 12 }
                }
                MouseArea {
                    id: btnCloseMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.clearSelection()
                }
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
