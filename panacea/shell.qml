import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Hyprland

// Одна пилюля на всё.
//
// Свёрнутая: день недели, время, заряд.
// Играет музыка/видео -> пилюля превращается в медиа-капсулу
//   (обложка + название + живой эквалайзер).
// Наведение -> плавно раскрывается: без музыки — Wi-Fi и Bluetooth,
//   с музыкой — плеер. Курсор ушёл -> сворачивается обратно.
// Super+A -> лаунчер приложений в той же пилюле.
ShellRoot {

PanelWindow {
    id: root

    // ------------------------------------------------- сохраняемые настройки
    // Живут в ~/.config/panacea/settings.json и правятся по Super+I.
    // Файл читается на старте и перечитывается при внешнем изменении.
    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/panacea/settings.json"
        watchChanges: true
        onFileChanged: reload()
        adapter: JsonAdapter {
            property string fontFam: "JetBrainsMono Nerd Font"
            property int    fontSize: 15
            property int    iconSize: 17
            property string colFg:    "#ffffff"
            property real   mutedAlpha: 0.45
            property string colOn:    "#3b82f6"
            property int    pillH:  38
            property int    panelW: 540
            property int    cornerR: 14
            property int    animMs: 230
            property string lang: "en"        // "en" | "ru", по умолчанию английский
            property bool   clock12: false    // 12-часовой формат с AM/PM
            // сочетания; пересобираются в lua/binds_data.lua
            property string bind_pillLauncher: "SUPER + A"
            property string bind_pillControls: "SUPER + Z"
            property string bind_pillPlayer: "SUPER + M"
            property string bind_pillSettings: "SUPER + I"
            property string bind_pillWifi: "SUPER + SHIFT + W"
            property string bind_pillBt: "SUPER + SHIFT + B"
            property string bind_pillClip: "SUPER + V"
            property string bind_pillPower: "CTRL + ALT + delete"
            property string bind_terminal: "SUPER + T"
            property string bind_terminalAlt: "SUPER + Return"
            property string bind_closeWindow: "SUPER + Q"
            property string bind_browser: "SUPER + F"
            property string bind_fullscreen: "SUPER + SHIFT + F"
            property string bind_exitHypr: "SUPER + SHIFT + M"
            property string bind_themeSwitch: "SUPER + SHIFT + T"
            property string bind_floatCenter: "SUPER + SHIFT + Space"
            property string bind_fileManager: "SUPER + E"
            property string bind_fileManagerTui: "SUPER + SHIFT + E"
            property string bind_toggleSplit: "SUPER + J"
            property string bind_notes: "SUPER + O"
            property string bind_screenshot: "SUPER + SHIFT + S"
            property string bind_screenOff: "SUPER + SHIFT + F12"
            property string bind_packWorkspaces: "SUPER + SHIFT + A"
            property string bind_emptyWorkspace: "SUPER + Space"
            property string bind_specialWorkspace: "SUPER + S"
        }
    }
    // Заводские сочетания. Держим одним списком, чтобы «Сбросить»
    // возвращал ровно те значения, что заданы по умолчанию.
    readonly property var defaultBinds: ({
        pillLauncher: "SUPER + A",
        pillControls: "SUPER + Z",
        pillPlayer:   "SUPER + M",
        pillSettings: "SUPER + I",
        pillWifi:     "SUPER + SHIFT + W",
        pillBt:       "SUPER + SHIFT + B",
        pillClip:     "SUPER + V",
        pillPower:    "CTRL + ALT + delete",
        terminal:       "SUPER + T",
        terminalAlt:    "SUPER + Return",
        closeWindow:    "SUPER + Q",
        browser:        "SUPER + F",
        fullscreen:     "SUPER + SHIFT + F",
        exitHypr:       "SUPER + SHIFT + M",
        themeSwitch:    "SUPER + SHIFT + T",
        floatCenter:    "SUPER + SHIFT + Space",
        fileManager:    "SUPER + E",
        fileManagerTui: "SUPER + SHIFT + E",
        toggleSplit:    "SUPER + J",
        notes:          "SUPER + O",
        screenshot:     "SUPER + SHIFT + S",
        screenOff:      "SUPER + SHIFT + F12",
        packWorkspaces: "SUPER + SHIFT + A",
        emptyWorkspace: "SUPER + Space",
        specialWorkspace: "SUPER + S"
    })

    readonly property var cfg: cfgFile.adapter
    function saveCfgNow() { cfgFile.writeAdapter(); }

    // семейства моноширинных шрифтов для выпадающего списка настроек
    property var fontList: ["JetBrainsMono Nerd Font"]
    Process {
        id: pFonts
        command: ["sh", "-c",
            "fc-list :spacing=100 family | tr ',' '\\n' | sed 's/^ *//' | sort -u | grep -v '^$'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var a = text.trim().split("\n").filter(x => x.length);
                if (a.length) root.fontList = a;
            }
        }
    }

    function saveCfg() { cfgFile.writeAdapter(); }

    // Перевод. Ключ — русский текст, поэтому исходники остаются читаемыми,
    // а словарь нужен только для английского.
    readonly property var dictEn: ({
        "одна пилюля на всё": "one pill for everything",
        "Настройки пилюли": "Pill settings",
        "Сбросить": "Reset",
        "Язык": "Language",
        "Шрифт": "Font",
        "Семейство": "Family",
        "Размер текста": "Text size",
        "Размер иконок": "Icon size",
        "Цвета": "Colours",
        "Текст": "Text",
        "Акцент": "Accent",
        "Блёклость": "Dimming",
        "Размеры": "Sizes",
        "Высота пилюли": "Pill height",
        "Ширина панели": "Panel width",
        "Радиус углов": "Corner radius",
        "Скорость": "Speed",
        "Горячие клавиши": "Shortcuts",
        "Лаунчер приложений": "App launcher",
        "Wi-Fi, Bluetooth, питание": "Quick settings",
        "Плеер": "Player",
        "Эти настройки": "These settings",
        "Список сетей": "Network list",
        "Устройства Bluetooth": "Bluetooth",
        "Буфер обмена": "Clipboard",
        "Меню питания": "Power menu",
        "Пилюля": "Pill",
        "Клавиши": "Shortcuts",
        "Применить": "Apply",
        "Предпросмотр": "Preview",
        "Есть несохранённые изменения": "Unsaved changes",
        "Изменения применены": "All changes applied",
        "Приложения": "Applications",
        "Окна": "Windows",
        "Рабочие столы": "Workspaces",
        "Система": "System",
        "Несменяемые": "Fixed",
        "Терминал": "Terminal",
        "Терминал (запасная)": "Terminal (alt)",
        "Браузер": "Browser",
        "Файловый менеджер": "File manager",
        "Файлы в терминале": "Files (TUI)",
        "Заметки": "Notes",
        "Скриншот области": "Screenshot",
        "Смена темы": "Switch theme",
        "Закрыть окно": "Close window",
        "Во весь экран": "Fullscreen",
        "Плавающее по центру": "Float \u0026 centre",
        "Сменить направление сплита": "Toggle split",
        "На пустой стол": "Empty workspace",
        "Спецстол": "Scratchpad",
        "Собрать столы подряд": "Pack workspaces",
        "Погасить экран": "Turn screen off",
        "Выйти из Hyprland": "Exit Hyprland",
        "Перейти на рабочий стол": "Switch workspace",
        "Перенести окно на стол": "Move to workspace",
        "Фокус по направлению": "Focus by direction",
        "Двигать окно": "Move window",
        "Менять размер окна": "Resize window",
        "Мультимедиа-клавиши": "Media keys",
        "Громкость, яркость, плеер": "Volume, brightness",
        "Крышка ноутбука": "Laptop lid",
        "Блокировка экрана": "Lock screen",
        "Русский": "Russian",
        "Формат часов": "Clock format",
        "24 часа": "24-hour",
        "12 часов": "12-hour",
        "Быстрые настройки": "Quick settings",
        "Показать все страницы": "Show every page",
        "Остановить показ": "Stop the tour",
        "Пролистает все страницы по очереди": "Cycles through every page in turn",
        "Пауза показа": "Step delay",
        "с": "s",
        "Нажмите сочетание…": "Press a shortcut…",
        "Нажмите на сочетание, чтобы изменить. × убирает клавишу.":
            "Click a shortcut to change it. \u00d7 removes it.",
        "Сочетания правятся в ~/.config/hypr/lua/keybindings.lua":
            "Shortcuts live in ~/.config/hypr/lua/keybindings.lua",
        "Поиск в буфере": "Search clipboard",
        "Изображение": "Image",
        "Ничего не найдено": "Nothing found",
        "Буфер пуст": "Clipboard is empty",
        "Завершение работы": "Power",
        "Ещё раз, чтобы подтвердить: ": "Press again to confirm: ",
        "Сон": "Sleep",
        "Блокировка": "Lock",
        "Выйти": "Log out",
        "Перезагрузка": "Restart",
        "Выключить": "Shut down",
        "Выключен": "Off",
        "Включён": "On",
        "Не подключено": "Not connected",
        "Нет подключений": "No devices",
        "Экономия": "Power saver",
        "Баланс": "Balanced",
        "Максимум": "Performance",
        "Поиск приложений": "Search apps",
        "Сети": "Networks",
        "Устройства": "Devices",
        "Назад": "Back",
        "Обновить": "Refresh",
        "Пароль": "Password",
        "Подключить": "Connect",
        "Забыть": "Forget",
        "Подключение…": "Connecting…",
        "Поиск…": "Scanning…",
        "Не удалось подключиться": "Could not connect",
        "Подключено": "Connected",
        "Доступно": "Available",
        "Защищённая": "Secured",
        "Открытая": "Open",
        "Пароль от «": "Password for \u00ab",
        "Поиск приложений…": "Search apps…",
        "Поиск сетей…": "Scanning networks…",
        "Поиск устройств…": "Scanning devices…",
        "Сети Wi-Fi": "Wi-Fi networks",
        "Сети не найдены": "No networks found",
        "Сопряжено": "Paired",
        "Устройства не найдены": "No devices found",
        "мс": "ms",
        "Сохранено": "Saved"
    })

    readonly property bool isEn: cfg.lang === "en"
    function tr(k) { return isEn && dictEn[k] !== undefined ? dictEn[k] : k; }

    readonly property string scriptDir:
        Quickshell.env("HOME") + "/.config/panacea/scripts"

    // capture.sh off зовёт этот IPC, чтобы панель сняла режим захвата
    signal cancelCaptureRequested()

    // ------------------------------------------------------------- обход
    // Показ всех страниц по очереди с паузой — чтобы рассмотреть каждую.
    property bool tourRunning: false
    property int  tourIndex: 0
    readonly property var tourPages: ["main", "wifi", "bt", "player", "clip", "power", "launcher"]
    property int tourStepMs: 2200

    function startTour() {
        if (tourRunning) { stopTour(); return; }
        tourRunning = true;
        tourIndex = -1;
        // Короткий разгон только до появления первой страницы.
        // Показывается каждая страница ровно tourStepMs — время отсчитывается
        // от момента её показа, поэтому паузы одинаковые.
        tourTimer.interval = 250;
        tourTimer.restart();
    }
    function stopTour() {
        tourRunning = false;
        tourTimer.stop();
        togglePage("settings");
    }

    Timer {
        id: tourTimer
        repeat: false
        onTriggered: {
            if (!root.tourRunning) return;
            root.tourIndex++;
            if (root.tourIndex >= root.tourPages.length) {
                // круг закончен — возвращаемся в настройки
                root.tourRunning = false;
                pageResetTimer.stop();
                root.page = "settings";
                root.expanded = true;
                root.holdOpen = true;
                return;
            }
            pageResetTimer.stop();
            root.page = root.tourPages[root.tourIndex];
            root.expanded = true;
            root.holdOpen = true;
            if (root.page === "wifi") { root.refreshWifiList(); root.scanWifi(); }
            if (root.page === "bt")   root.scanBt();
            tourTimer.interval = root.tourStepMs;
            tourTimer.restart();
        }
    }

    // Пересобрать binds_data.lua и перечитать конфиг Hyprland
    Process { id: pGenBinds }
    function applyBinds() {
        saveCfg();
        pGenBinds.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/panacea/scripts/genbinds.sh"];
        pGenBinds.running = true;
    }

    // ---------------------------------------------------------------- палитра
    readonly property color colBg:     "#000000"
    readonly property color colFg:     cfg.colFg
    readonly property color colMuted:  Qt.rgba(colFg.r, colFg.g, colFg.b, cfg.mutedAlpha)
    readonly property color colLine:   Qt.rgba(1, 1, 1, 0.10)
    readonly property color colHover:  Qt.rgba(1, 1, 1, 0.10)
    readonly property color colOn:     cfg.colOn
    readonly property color colOk:     "#22c55e"
    readonly property color colCrit:   "#ef4444"
    readonly property string fontFam:  cfg.fontFam
    readonly property int fontSize:    cfg.fontSize
    readonly property int iconSize:    cfg.iconSize

    // ---------------------------------------------------------------- метрики
    readonly property int pillH: cfg.pillH      // высота свёрнутой пилюли
    readonly property int panelW: cfg.panelW    // ширина раскрытой панели
    readonly property int gap: 5                // зазор между пилюлей и окнами
    readonly property int cornerR: cfg.cornerR  // радиус примыкания к кромке

    // Единая кривая: панель «перетекает», а не прыгает.
    readonly property int animMs: cfg.animMs
    readonly property int animFast: Math.round(cfg.animMs * 0.52)
    // изменение содержимого (список приложений, новая сеть) — коротко и резко
    readonly property int animQuick: Math.round(cfg.animMs * 0.48)

    // true только пока идёт раскрытие/схлопывание или смена страницы.
    // Нужно, чтобы рост списка не ехал по длинной кривой раскрытия.
    property bool morphing: false
    onExpandedChanged: { morphing = true; morphTimer.restart() }
    onPageChanged:     { morphing = true; morphTimer.restart() }
    Timer { id: morphTimer; interval: root.animMs; onTriggered: root.morphing = false }

    // ------------------------------------------------------------ состояние UI
    property bool expanded: false
    // "main" | "wifi" | "bt" | "launcher" | "player"
    // main    — плитки Wi-Fi / Bluetooth / режимы питания
    // player  — мультимедиа (наведение при играющей музыке, либо Super+M)
    property string page: "main"
    // пока вводят пароль или открыт лаунчер, панель не закрывается по уходу мыши
    property bool holdOpen: false

    readonly property bool launcherOpen: expanded && page === "launcher"

    function collapse() {
        expanded = false;
        holdOpen = false;
        // Страницу НЕ сбрасываем сразу: панель ещё едет вниз, и подмена
        // содержимого на «главную» успевала мелькнуть. Сбросим, когда
        // капсула действительно схлопнется.
        pageResetTimer.restart();
    }
    Timer {
        id: pageResetTimer
        interval: root.animMs + 40
        onTriggered: if (!root.expanded) root.page = "main"
    }

    // Открыть страницу закреплённо; повторный вызов той же страницы закрывает.
    function togglePage(name) {
        if (expanded && page === name) { collapse(); return; }
        pageResetTimer.stop();
        page = name;
        expanded = true;
        holdOpen = true;
    }
    function openLauncher() {
        pageResetTimer.stop();
        page = "launcher";
        expanded = true;
        holdOpen = true;
    }
    function closeLauncher() { collapse(); }
    function toggleLauncher() {
        if (launcherOpen) closeLauncher(); else openLauncher();
    }

    readonly property bool playerOpen: expanded && page === "player"
    // Настройки — единственная страница, которая отрывается от верхней кромки
    // и встаёт по центру экрана: содержимого много, у верха оно было тесным.
    readonly property bool settingsMode: expanded && page === "settings"

    // Вкладка «Клавиши» раскладывается в две колонки, поэтому окно шире:
    // вертикальный список не влезал и уезжал за нижнюю кромку экрана.
    property bool wideSettings: false
    readonly property int settingsW: {
        var want = wideSettings ? 1120 : 720;
        var lim = (screen ? screen.width : 1920) - 80;
        return Math.min(want, lim);
    }

    // Super+M: плеер в закреплённом положении — не закрывается по уходу мыши
    function togglePlayer() { togglePage("player"); }

    // ------------------------------------------------------------------ медиа
    readonly property var player: {
        var list = Mpris.players ? Mpris.players.values : [];
        var playing = null, any = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p) continue;
            if (!any) any = p;
            if (p.isPlaying && !playing) playing = p;
        }
        return playing || any;
    }
    readonly property bool mediaActive:
        player !== null && player !== undefined
        && String(player.trackTitle).trim().length > 0

    // ---------------------------------------------------------------- батарея
    // Батарея через UPower: свойства приходят по сигналам D-Bus, поэтому
    // иконка меняется сразу при подключении и отключении зарядки.
    // Раньше здесь был опрос /sys раз в 20 секунд — отсюда задержка.
    readonly property var battDev: UPower.displayDevice

    readonly property int batteryPct:
        battDev && battDev.ready ? Math.round(battDev.percentage * 100) : 100

    readonly property bool batteryCharging:
        battDev && battDev.ready && battDev.state === UPowerDeviceState.Charging

    readonly property bool acOnline: !UPower.onBattery

    // Заряжается — молния. От сети без зарядки — вилка.
    // Иначе обычная батарея с заполнением по проценту (шаг 10).
    readonly property var battIcons: [
        0xF008E, 0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E,
        0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079]

    readonly property string batteryIcon: {
        // Заряжается — молния. От сети без зарядки — обычная батарея,
        // отличается только цветом (зелёный), без иконки розетки.
        if (batteryCharging) return String.fromCodePoint(0xF0241);
        var step = Math.max(0, Math.min(10, Math.round(batteryPct / 10)));
        return String.fromCodePoint(battIcons[step]);
    }

    // ------------------------------------------------------- профиль питания
    readonly property string powerScript:
        Quickshell.env("HOME") + "/.config/panacea/scripts/power.sh"

    // "power-saver" | "balanced" | "performance"
    property string powerProfile: "balanced"

    Process {
        id: pPowerGet
        command: ["sh", "-c", root.powerScript + " get"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var s = line.trim();
                if (s.length) root.powerProfile = s;
            }
        }
    }
    Process {
        id: pPowerSet
        onRunningChanged: if (!running) pPowerGet.running = true
    }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: pPowerGet.running = true }

    function setPowerProfile(name) {
        // отражаем сразу, потом подтверждаем реальным значением от демона
        root.powerProfile = name;
        pPowerSet.command = ["sh", "-c", root.powerScript + " set \"$1\"", "_", name];
        pPowerSet.running = true;
    }

    // ------------------------------------------------------- рабочий стол
    readonly property int wsId:
        Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    // -------------------------------------------------- раскладка клавиатуры
    property string kbLayout: "US"
    Process {
        id: pKbLayout
        command: ["sh", "-c",
            "hyprctl devices -j | jq -r '.keyboards[]|select(.main==true)|.active_keymap' | head -1"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var s = line.trim();
                if (!s.length) return;
                root.kbLayout = /rus/i.test(s) ? "RU" : "US";
            }
        }
    }
    // Hyprland шлёт activelayout при каждом переключении Alt+Shift
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name === "activelayout") pKbLayout.running = true;
        }
    }

    // ------------------------------------------------------------------ часы
    property string timeText: ""
    property string dayText: ""
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            // 12-часовой формат — с AM/PM, 24-часовой — без
            root.timeText = root.cfg.clock12
                ? Qt.formatDateTime(d, "h:mm AP")
                : Qt.formatDateTime(d, "HH:mm");
            root.dayText = root.isEn
                ? ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][d.getDay()]
                : ["Вс","Пн","Вт","Ср","Чт","Пт","Сб"][d.getDay()];
        }
    }

    // ------------------------------------------------------------------ Wi-Fi
    readonly property string wifiScript: Quickshell.env("HOME") + "/.config/panacea/scripts/wifi.sh"

    property bool wifiOn: true
    property string wifiSsid: ""
    property int wifiQuality: 0
    property bool wifiBusy: false
    property string wifiError: ""

    ListModel { id: wifiModel }
    // отдаём модель наружу: ControlsView лежит в другом файле
    readonly property var wifiNetworks: wifiModel

    Process {
        id: pWifiStatus
        command: ["sh", "-c", root.wifiScript + " status"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 3) return;
                root.wifiOn = (p[0] === "on");
                root.wifiSsid = p[1] || "";
                root.wifiQuality = parseInt(p[2]) || 0;
            }
        }
    }
    Timer { interval: 4000; running: true; repeat: true; onTriggered: pWifiStatus.running = true }

    Process {
        id: pWifiList
        command: ["sh", "-c", root.wifiScript + " list"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 5) return;
                wifiModel.append({
                    connected: p[0] === "yes",
                    ssid: p[1],
                    security: p[2],
                    quality: parseInt(p[3]) || 0,
                    known: p[4] === "yes"
                });
            }
        }
        onRunningChanged: if (!running) root.wifiBusy = false
    }

    Process { id: pWifiScan; command: ["sh", "-c", root.wifiScript + " scan"] }
    Process {
        id: pWifiToggle
        command: ["sh", "-c", root.wifiScript + " toggle"]
        onRunningChanged: if (!running) pWifiStatus.running = true
    }
    Process {
        id: pWifiConnect
        onRunningChanged: {
            if (running) return;
            root.wifiBusy = false;
            if (exitCode !== 0) root.wifiError = "Не удалось подключиться";
            else { root.wifiError = ""; root.page = "main"; }
            pWifiStatus.running = true;
            root.refreshWifiList();
        }
    }

    function toggleWifi() { pWifiToggle.running = true; }
    function refreshWifiList() {
        wifiModel.clear();
        root.wifiBusy = true;
        pWifiList.running = true;
    }
    function scanWifi() {
        root.wifiBusy = true;
        pWifiScan.running = true;
        wifiRescanTimer.restart();
    }
    Timer { id: wifiRescanTimer; interval: 2600; onTriggered: root.refreshWifiList() }

    function connectWifi(ssid, password) {
        root.wifiBusy = true;
        root.wifiError = "";
        pWifiConnect.command = password && password.length
            ? ["sh", "-c", root.wifiScript + " connect \"$1\" \"$2\"", "_", ssid, password]
            : ["sh", "-c", root.wifiScript + " connect \"$1\"", "_", ssid];
        pWifiConnect.running = true;
    }

    // -------------------------------------------------------------- Bluetooth
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    readonly property var btDevices: btAdapter ? btAdapter.devices : null
    readonly property string btConnectedName: {
        if (!btDevices) return "";
        var list = btDevices.values;
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].connected) return list[i].name || "Устройство";
        return "";
    }

    function toggleBt() { if (btAdapter) btAdapter.enabled = !btAdapter.enabled; }
    function scanBt() {
        if (!btAdapter || !btAdapter.enabled) return;
        btAdapter.discovering = true;
        btScanStop.restart();
    }
    Timer { id: btScanStop; interval: 12000; onTriggered: if (root.btAdapter) root.btAdapter.discovering = false }

    // -------------------------------------------------------------------- IPC
    IpcHandler {
        target: "pill"
        function launcher(): void { root.toggleLauncher(); }
        // Всегда плитки Wi-Fi/Bluetooth, даже когда играет музыка
        function controls(): void { root.togglePage("main"); }
        function player(): void   { root.togglePage("player"); }
        function wifi(): void {
            if (root.expanded && root.page === "wifi") { root.collapse(); return; }
            root.togglePage("wifi");
            root.refreshWifiList(); root.scanWifi();
        }
        function bluetooth(): void {
            if (root.expanded && root.page === "bt") { root.collapse(); return; }
            root.togglePage("bt");
            root.scanBt();
        }
        function settings(): void { root.togglePage("settings"); }
        function clipboard(): void { root.togglePage("clip"); }
        function powermenu(): void { root.togglePage("power"); }
        function cancelCapture(): void { root.cancelCaptureRequested(); }
        function tour(): void { root.startTour(); }
        function close(): void { root.collapse(); }
    }

    // ----------------------------------------------------------------- окно
    anchors { top: true; left: true; right: true }
    implicitHeight: root.settingsMode
                    ? (root.screen ? root.screen.height : 1080)
                    : 560
    color: "transparent"
    // зазор между пилюлей и окнами
    exclusiveZone: pillH + gap
    WlrLayershell.layer: WlrLayer.Overlay
    // клики ловим только там, где нарисована пилюля
    // Пока открыта закреплённая страница, ввод принимает всё окно:
    // иначе клики по панели (особенно по центрированным настройкам)
    // проваливались мимо, и ползунки не реагировали.
    Region { id: capsuleRegion; item: capsule }
    mask: root.holdOpen ? null : capsuleRegion
    // Лаунчер забирает клавиатуру сразу (Exclusive), чтобы можно было
    // печатать без клика. OnDemand отдаёт фокус только после клика мышью.
    WlrLayershell.keyboardFocus: root.holdOpen ? WlrKeyboardFocus.Exclusive
                                              : WlrKeyboardFocus.None

    // Клик мимо закреплённой панели — закрыть.
    // Раньше это была одна MouseArea на всё окно под капсулой: если хоть один
    // элемент панели не принимал нажатие, оно проваливалось вниз и панель
    // закрывалась. Теперь области лежат строго ВОКРУГ капсулы, поэтому клик
    // по самой панели до них физически не доходит.
    Repeater {
        model: 4
        MouseArea {
            required property int index
            enabled: root.holdOpen
            visible: enabled
            // 0 — сверху, 1 — снизу, 2 — слева, 3 — справа от капсулы
            x: index === 3 ? capsule.x + capsule.width : 0
            y: index === 1 ? capsule.y + capsule.height
             : index >= 2 ? capsule.y : 0
            width:  index < 2 ? root.width
                  : index === 2 ? capsule.x
                                : Math.max(0, root.width - capsule.x - capsule.width)
            height: index === 0 ? capsule.y
                  : index === 1 ? Math.max(0, root.height - capsule.y - capsule.height)
                                : capsule.height
            onClicked: root.collapse()
        }
    }

    // ------------------------------------------------------------- сама пилюля
    Rectangle {
        id: capsule

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        // у верха — 0, в режиме настроек — по центру экрана
        anchors.topMargin: root.settingsMode
                           ? Math.max(24, (root.height - targetH) / 2)
                           : 0
        Behavior on anchors.topMargin {
            NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
        }

        width: root.settingsMode ? root.settingsW
             : root.expanded     ? root.panelW
             : (root.mediaActive ? mediaCapsule.implicitWidth + 32
                                 : idleCapsule.implicitWidth + 32)
        // целевая высота — к ней анимируется height и по ней же сразу
        // рассчитывается центрирование, чтобы движение было одноэтапным
        readonly property real targetH: root.expanded
                ? (contentLoader.item ? contentLoader.item.implicitHeight + 30 : 220)
                : root.pillH
        height: targetH

        color: root.colBg
        // прижата к верхней кромке: сверху углов нет, снизу — полное скругление
        topLeftRadius:  root.settingsMode ? 26 : 0
        topRightRadius: root.settingsMode ? 26 : 0
        bottomLeftRadius: root.expanded ? 26 : root.pillH / 2
        bottomRightRadius: root.expanded ? 26 : root.pillH / 2
        Behavior on topLeftRadius  { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }
        Behavior on topRightRadius { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }

        // Niente bordo, in nessuno stato: e' l'unica differenza di stile che
        // c'era fra pillola e pannello. Un bordo largo 1 viene disegnato
        // *dentro* al rettangolo, quindi anche quando era trasparente lasciava
        // passare 1px di sfondo sul lato superiore: da qui l'impressione che
        // la pillola non fosse attaccata al bordo dello schermo e che il fondo
        // cambiasse all'apertura.
        border.width: 0

        Behavior on width  { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }
        Behavior on height {
            NumberAnimation {
                duration: root.morphing ? root.animMs : root.animQuick
                easing.type: root.morphing ? Easing.InOutCubic : Easing.OutCubic
            }
        }
        Behavior on bottomLeftRadius  { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }
        Behavior on bottomRightRadius { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }

        clip: true

        // --- курсор отслеживаем поверх всего содержимого
        HoverHandler {
            id: capsuleHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                if (hovered) { collapseTimer.stop(); expandTimer.restart(); }
                else { expandTimer.stop(); collapseTimer.restart(); }
            }
        }
        Timer {
            id: expandTimer; interval: 0
            onTriggered: {
                if (!capsuleHover.hovered || root.launcherOpen) return;
                // страницу трогаем только если панель ещё закрыта: иначе
                // наведение сбрасывало бы уже открытый список сетей
                if (!root.expanded) {
                    pageResetTimer.stop();
                    root.page = root.mediaActive ? "player" : "main";
                }
                root.expanded = true;
            }
        }
        Timer {
            id: collapseTimer; interval: 180
            onTriggered: {
                if (capsuleHover.hovered || root.holdOpen) return;
                root.collapse();
            }
        }

        // ---------------------------------------------------- свёрнутое: покой
        RowLayout {
            id: idleCapsule
            anchors.centerIn: parent
            height: root.pillH
            spacing: 14
            visible: !root.expanded && !root.mediaActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                text: root.dayText
                color: root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            }
            Text {
                text: root.timeText
                color: root.colFg
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }

            // номер текущего рабочего стола: перелистывается при смене
            FlipText {
                value: String(root.wsId)
                textColor: root.colFg
                fontFam: root.fontFam
                pixelSize: root.fontSize - 1
                Layout.alignment: Qt.AlignVCenter
            }

            // текущая раскладка: перелистывается при Alt+Shift
            FlipText {
                value: root.kbLayout
                textColor: root.kbLayout === "RU" ? "#7FB3FF" : root.colMuted
                fontFam: root.fontFam
                pixelSize: root.fontSize - 2
                Layout.alignment: Qt.AlignVCenter
            }

            RowLayout {
                spacing: 5
                Text {
                    text: root.batteryIcon
                    color: root.batteryCharging || root.acOnline ? root.colOk
                         : root.batteryPct <= 15 ? root.colCrit
                         : root.colFg
                    font { family: root.fontFam; pixelSize: root.iconSize }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: root.batteryPct + "%"
                    color: root.colMuted
                    font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                }
            }
        }

        // ------------------------------------------------- свёрнутое: медиа
        RowLayout {
            id: mediaCapsule
            anchors.centerIn: parent
            height: root.pillH
            spacing: 11
            visible: !root.expanded && root.mediaActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 7
                color: Qt.rgba(1, 1, 1, 0.08)
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 56
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !root.player || !root.player.trackArtUrl
                    text: "󰝚"
                    color: root.colMuted
                    font { family: root.fontFam; pixelSize: 13 }
                }
            }

            Text {
                Layout.maximumWidth: 240
                text: root.player ? root.player.trackTitle : ""
                color: root.colFg
                elide: Text.ElideRight
                font { family: root.fontFam; pixelSize: 15; bold: true }
            }

            WaveBars {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 17
                barColor: root.colFg
                active: root.player ? root.player.isPlaying : false
            }
        }

        // --------------------------------------------------- раскрытая панель
        Loader {
            id: contentLoader
            anchors.top: parent.top
            anchors.topMargin: 15
            anchors.horizontalCenter: parent.horizontalCenter
            // Ширина берётся у ЦЕЛЕВОЙ панели, а не у анимируемой капсулы:
            // иначе содержимое переливалось по ширине на каждом кадре
            // сворачивания и выглядело как размазанная краска.
            width: (root.settingsMode ? root.settingsW : root.panelW) - 30
            active: root.expanded || capsule.height > root.pillH + 4
            opacity: root.expanded ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: root.expanded ? root.animFast : 70 }
            }

            sourceComponent: root.page === "launcher" ? launcherComp
                           : root.page === "player"   ? playerComp
                           : root.page === "settings" ? settingsComp
                           : root.page === "clip"     ? clipComp
                           : root.page === "power"    ? powerComp
                                                      : controlsComp
        }

        Component { id: controlsComp; ControlsView { sys: root } }
        Component { id: playerComp;   PlayerView   { sys: root } }
        Component { id: launcherComp; LauncherView { sys: root } }
        Component { id: settingsComp; SettingsView { sys: root } }
        Component { id: clipComp;     ClipboardView { sys: root } }
        Component { id: powerComp;    PowerView { sys: root } }
    }

    // ------------------------------------ плавное примыкание к кромке экрана
    // Два вогнутых уголка по бокам: переход от кромки к пилюле без ступеньки.
    NotchCorner {
        side: "left"
        fill: root.colBg
        r: root.cornerR
        anchors.top: parent.top
        anchors.right: capsule.left
        // Gli angoli restano anche da espansa: sono ancorati ai lati della
        // capsula, quindi scorrono insieme a lei mentre si allarga.
        opacity: root.settingsMode ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: root.animFast } }
    }
    NotchCorner {
        side: "right"
        fill: root.colBg
        r: root.cornerR
        anchors.top: parent.top
        anchors.left: capsule.right
        opacity: root.settingsMode ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: root.animFast } }
    }
}

}
