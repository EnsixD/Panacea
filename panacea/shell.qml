import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Services.Polkit
import Quickshell.Services.Pam
import Quickshell.Bluetooth
import Quickshell.Hyprland
import "Themes.js" as Themes

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
            // где живёт остров: top | bottom | left | right
            property string pillPos: "top"
            // Автоскрытие: остров уезжает за кромку и не занимает место под
            // себя, окна получают весь экран. Возвращается наведением на
            // узкую полоску у самого края.
            property bool   pillAutoHide: false
            // Режим оверлея: остров парит поверх окон без резервирования полосы
            property bool   pillOverlay: true
            // Закрывать оверлей Panacea по Super+Q (иначе убивать фоновое окно)
            property bool   closePanaceaFirst: true

            // Настройки мониторов из вкладки Display, JSON вида
            // {"eDP-1":{w,h,rr,scale,transform,vrr,pos}}. Hyprland их не
            // запоминает: hyprctl правит живое состояние, и после перезагрузки
            // конфига или перезахода экран возвращается к своему конфигу.
            property string monOverrides: ""
            // На каком экране живёт остров. "auto" — на том, где сейчас
            // фокус: остров переезжает за человеком. Иначе имя выхода
            // ("eDP-1", "DP-2") — остров прибит к нему намертво.
            property string pillScreen: "auto"

            // ---------------------------------------------- Bar & Island
            // Режим выреза: остров примыкает вплотную к кромке экрана и
            // растекается по ней вогнутыми уголками. Выключенный — остров
            // становится прямоугольной капсулой с отступом от кромки.
            property bool   notchMode: true
            // радиус вогнутого уголка примыкания
            property int    notchFlare: 12
            // ширина свёрнутого острова и высота развёрнутой панели
            property int    collapsedW: 260
            property int    expandedH: 620
            // отступ капсулы от кромки, когда режим выреза выключен
            property int    islandGap: 12
            // скругление капсулы вне режима выреза (0 — по половине высоты)
            property int    islandRadius: 0

            // ---------------------------------------------- Clock & Date
            property bool   clockSeconds: false
            property bool   clockWeekday: true
            // "auto" — регион и часовой пояс берутся у системы
            property string clockTz: "auto"
            property string clockDateFmt: "d MMMM"

            // ---------------------------------------------- Appearance
            // Тема палитры, независимая от обоев. "default" — то, что стоит
            // сейчас; остальные перечислены в root.themes.
            property string themeId: "default"
            // текстовый шрифт и шрифт заголовков
            property string fontBody: "JetBrainsMono Nerd Font"
            property string fontDisplay: "JetBrainsMono Nerd Font"
            // шаг отступов и малый радиус — из них считается вся геометрия
            property int    spacingUnit: 8
            property int    smallRadius: 10

            // ---------------------------------------------- Motion
            // Полный отказ от анимаций: все длительности считаются нулевыми.
            property bool   reduceMotion: false
            property int    animMove: 230      // размер и положение, мс
            property int    animFade: 200      // прозрачность и цвет, мс
            property int    animHover: 150     // отклик на наведение, мс
            property int    animBounce: 79     // перелёт осциллятора, %

            // ---------------------------------------------- Notifications
            property bool   notifDnd: false
            property int    notifTimeout: 5000       // обычные, мс
            property int    notifCritTimeout: 0      // 0 — висят до ответа
            property bool   notifPreview: true       // текст в свёрнутом виде

            // ---------------------------------------------- Lock Screen
            property int    lockBlur: 32
            property string lockHint: ""

            // ---------------------------------------------- Control Center
            // Порядок плиток быстрых настроек, заданный человеком.
            // Пустая строка — заводская раскладка из root.ccDefault.
            property string ccLayout: ""
            // разрешено ли переносить остров мышью прямо на экране
            property bool   pillDrag: false
            property int    panelW: 540
            property string lang: "en"        // "en" | "ru", по умолчанию английский
            property bool   clock12: false    // 12-часовой формат с AM/PM
            // запись экрана
            property int    recFps: 60
            property string recDir: "~/Videos"
            property bool   recSysAudio: false   // звук системы
            property bool   recMic: false        // микрофон
            property string recMicDevice: ""     // "" = микрофон по умолчанию
            // менеджер паролей: предлагать сохранять пароли из буфера обмена
            property bool   vaultCapture: true
            // проводник отдельным окном Hyprland, а не страницей пилюли
            property bool   filesWindow: false
            // Показывать файлы с точки. По умолчанию да: в домашнем каталоге
            // почти всё, за чем в него заходят, начинается именно с неё —
            // .config, .local, .ssh.
            property bool   filesHidden: true
            // Как проводник раскладывает содержимое: "list" — строки с
            // мелкими значками, размером и датой; "grid" — плитки покрупнее,
            // когда важнее узнать файл в лицо, чем прочитать про него цифры.
            // Переключатель стоит рядом с поиском, выбор запоминается.
            property string filesMode: "list"

            // Цифровая интенсивность, шкала как в панели NVIDIA: 50 — как
            // есть, 100 — максимум. На Wayland ручка из nvidia-settings не
            // работает вовсе, поэтому цвет правит шейдер компоновщика.
            property int    vibrance: 50

            // ------------------------------------------------------- мышь
            // Скорость указателя в понимании libinput: -1 — самая медленная,
            // 0 — как есть, 1 — самая быстрая. Это не «умножение на два», а
            // сдвиг кривой, поэтому шаг мелкий.
            property real   mouseSens: 0
            // Прямой ввод: libinput перестаёт разгонять указатель за резкое
            // движение, и одно и то же расстояние по столу всегда даёт одно
            // и то же расстояние по экрану. То, ради чего в играх выключают
            // «повышенную точность установки указателя».
            property bool   mouseRaw: false

            // Включённые функции. При установке дотфайлов целиком доступно всё
            // (по умолчанию true); установщик острова выключает то, что человек
            // не отметил, и тогда соответствующей кнопки/страницы в пилюле нет,
            // а служба (демон уведомлений, агент polkit) не регистрируется —
            // чтобы не спорить с уже установленными в системе.
            property bool   featLauncher: true
            property bool   featPlayer: true
            property bool   featWifi: true
            property bool   featBluetooth: true
            property bool   featClipboard: true
            property bool   featNotifications: true
            property bool   featCalendar: true
            property bool   featThemes: true
            property bool   featRecord: true
            property bool   featFiles: true
            property bool   featMedia: true
            property bool   featVault: true
            property bool   featLock: true
            property bool   featAudio: true
            property bool   featPowerProfiles: true
            property bool   featOsd: true
            property bool   featPowermenu: true
            property bool   featPolkit: true

            // ---------------------------------------------- Weather & Widgets
            // Ключ и город пусты по умолчанию: без них виджет погоды просто
            // не показывается. Ключ чужой, бесплатный и выдаётся на почту —
            // подставить сюда что-то своё нельзя.
            property string weatherKey: ""
            property string weatherCity: ""
            property string weatherUnits: "metric"   // metric | imperial
            // Погода в свёрнутом острове. Включена: место она занимает
            // небольшое, а смотрят на остров чаще, чем на рабочий стол,
            // который закрыт окнами.
            property bool   weatherOnIsland: true
            // Настольные виджеты. Выключены по умолчанию: они рисуются
            // поверх обоев и меняют вид рабочего стола, а такое включают
            // сами, а не обнаруживают после обновления.
            property bool   featWidgets: false

            // Прозрачность терминала. Живёт здесь, а правится в foot.ini:
            // сам foot настройки оболочки не читает.
            property real   termAlpha: 0.90

            // сочетания; пересобираются в lua/binds_data.lua
            property string bind_pillLauncher: "SUPER + A"
            property string bind_pillControls: "SUPER + Z"
            property string bind_pillSettings: "SUPER + I"
            property string bind_pillShortcuts: "SUPER + slash"
            property string bind_overview: "SUPER + Tab"
            property string bind_pillWifi: "SUPER + SHIFT + W"
            property string bind_pillBt: "SUPER + SHIFT + B"
            property string bind_pillClip: "SUPER + V"
            property string bind_pillPower: "CTRL + ALT + delete"
            property string bind_pillNotif: "SUPER + SHIFT + N"
            property string bind_pillRecord: "SUPER + P"
            property string bind_terminal: "SUPER + T"
            property string bind_terminalAlt: "SUPER + Return"
            property string bind_closeWindow: "SUPER + Q"
            property string bind_browser: "SUPER + F"
            property string bind_fullscreen: "SUPER + SHIFT + F"
            property string bind_exitHypr: "SUPER + SHIFT + M"
            property string bind_themeSwitch: "SUPER + SHIFT + T"
            property string bind_floatToggle: "SUPER + W"
            property string bind_pillVault: "SUPER + SHIFT + P"
            // Голос в текст (voxtype): зажми правый Alt — говоришь, отпустил —
            // вставилось. Обрабатывается парой press/release в keybindings.lua.
            property string bind_voxDictate: "Alt_R"
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
        pillSettings: "SUPER + I",
        pillShortcuts: "SUPER + slash",
        overview:     "SUPER + Tab",
        pillWifi:     "SUPER + SHIFT + W",
        pillBt:       "SUPER + SHIFT + B",
        pillClip:     "SUPER + V",
        pillPower:    "CTRL + ALT + delete",
        pillNotif:    "SUPER + SHIFT + N",
        pillRecord:   "SUPER + P",
        terminal:       "SUPER + T",
        terminalAlt:    "SUPER + Return",
        closeWindow:    "SUPER + Q",
        browser:        "SUPER + F",
        fullscreen:     "SUPER + SHIFT + F",
        exitHypr:       "SUPER + SHIFT + M",
        themeSwitch:    "SUPER + SHIFT + T",
        floatToggle:    "SUPER + W",
        pillVault:      "SUPER + SHIFT + P",
        voxDictate:     "Alt_R",
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

    // Заводские значения всего, что правится в окне настроек. Сочетания
    // клавиш сюда не входят: у них свой список и своя кнопка сброса.
    readonly property var defaultCfg: ({
        fontFam: "JetBrainsMono Nerd Font", fontBody: "JetBrainsMono Nerd Font",
        fontDisplay: "JetBrainsMono Nerd Font", fontSize: 15, iconSize: 17,
        colFg: "#ffffff", colOn: "#3b82f6", mutedAlpha: 0.45, themeId: "default",
        spacingUnit: 8, smallRadius: 10,
        pillH: 38, pillPos: "top", pillScreen: "auto", pillAutoHide: false, pillOverlay: true,
        closePanaceaFirst: true,
        pillDrag: false, panelW: 540,
        monOverrides: "",
        notchMode: true, notchFlare: 12, collapsedW: 260, expandedH: 620,
        islandGap: 12, islandRadius: 0,
        reduceMotion: false, animMove: 230, animFade: 200, animHover: 150, animBounce: 0,
        clock12: false, clockSeconds: false, clockWeekday: true,
        clockTz: "auto", clockDateFmt: "d MMMM",
        notifDnd: false, notifTimeout: 5000, notifCritTimeout: 0, notifPreview: true,
        lockBlur: 32, lockHint: "",
        ccLayout: "", filesWindow: false, filesHidden: true, filesMode: "list",
        vaultCapture: true,
        vibrance: 50, mouseSens: 0, mouseRaw: false,
        recFps: 60, recDir: "~/Videos", recSysAudio: false, recMic: false, recMicDevice: "",
        weatherKey: "", weatherCity: "", weatherUnits: "metric",
        weatherOnIsland: true, featWidgets: false, termAlpha: 0.90,
        uiSounds: true
    })

    // ------------------------------------------------------------------ звуки
    Process { id: pSound }
    function playSound(name) {
        if (root.cfg.uiSounds === false) return;
        var p = Quickshell.env("HOME") + "/.config/panacea/sounds/" + name + ".wav";
        pSound.command = ["sh", "-c", "command -v pw-play >/dev/null 2>&1 && pw-play \"$1\" >/dev/null 2>&1 || (command -v paplay >/dev/null 2>&1 && paplay \"$1\" >/dev/null 2>&1)", "_", p];
        pSound.running = false;
        pSound.running = true;
    }

    function resetCfg() {
        for (var k in root.defaultCfg) cfg[k] = root.defaultCfg[k];
        root.saveCfg();
    }

    // ------------------------------------------------------- экраны
    // Одна точка, через которую вкладка Display разговаривает с Hyprland,
    // и она же — память об этом разговоре.
    //
    // hyprctl keyword отвергается новым (не-legacy) парсером конфига и при
    // этом выходит с нулевым кодом, поэтому раньше настройки монитора молча
    // никуда не уезжали. Идём через hyprctl eval и hl.monitor{}, а keyword
    // оставляем запасным путём для старых конфигов.
    Process { id: pMon; property string args: ""; command: ["sh", "-c", pMon.args] }

    function monCmd(n, o) {
        var mode = o.w + "x" + o.h + "@" + Number(o.rr).toFixed(2);
        var lua = "hl.monitor({ output=\"" + n + "\", mode=\"" + mode
                + "\", position=\"" + o.pos + "\", scale=" + Number(o.scale).toFixed(6)
                + ", transform=" + o.transform + ", vrr=" + (o.vrr ? 1 : 0) + " })";
        var legacy = n + "," + mode + "," + o.pos + "," + Number(o.scale).toFixed(6)
                   + ",transform," + o.transform + ",vrr," + (o.vrr ? 1 : 0);
        return "out=$(hyprctl eval '" + lua + "' 2>&1); case \"$out\" in ok*) ;; *) "
             + "hyprctl keyword monitor '" + legacy + "' ;; esac";
    }

    function monMap() {
        try { return JSON.parse(root.cfg.monOverrides || "{}") || ({}); }
        catch (e) { return ({}); }
    }

    function monApply(n, o) {
        pMon.args = root.monCmd(n, o);
        pMon.running = false;
        pMon.running = true;
        var all = root.monMap();
        all[n] = o;
        root.cfg.monOverrides = JSON.stringify(all);
        root.saveCfg();
        // Компоновщику режим нужен ещё до нашего запуска: Qt привязывает
        // таймер анимаций к частоте обновления, когда создаёт первое окно, а
        // мы к тому моменту только стартуем. Пересобираем его конфиг, чтобы в
        // следующий раз монитор поднялся сразу на своей частоте.
        genMonTimer.restart();
    }

    Process { id: pGenMon }
    Timer {
        id: genMonTimer
        interval: 400
        onTriggered: {
            pGenMon.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/panacea/scripts/genmonitors.sh"];
            pGenMon.running = false;
            pGenMon.running = true;
        }
    }

    // Накатить запомненное заново: на старте оболочки и после каждой
    // перезагрузки конфига компоновщика — она сбрасывает живые настройки.
    function monReplay() {
        var all = root.monMap(), parts = [];
        for (var n in all) parts.push(root.monCmd(n, all[n]));
        if (!parts.length) return;
        pMon.args = parts.join("; ");
        pMon.running = false;
        pMon.running = true;
    }

    // ------------------------------------------- цифровая интенсивность
    // Считает и применяет отдельный скрипт: там же лежит сам шейдер и знание
    // о том, как разговаривать с компоновщиком. Здесь только запоминаем.
    Process { id: pVibrance }

    // Ползунок шлёт значение на каждое движение мыши, а каждый вызов — это
    // пересборка шейдера и перечитывание его компоновщиком. Без сдерживания
    // они идут внахлёст, и Hyprland ловит файл на середине записи. Число в
    // окне меняется сразу, к компоновщику уходит только то, на чём ручка
    // остановилась.
    Timer {
        id: vibranceFlush
        interval: 160
        onTriggered: {
            pVibrance.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/panacea/scripts/vibrance.sh set "
                + root.cfg.vibrance];
            pVibrance.running = false;
            pVibrance.running = true;
            root.saveCfg();
        }
    }

    function applyVibrance(pct) {
        root.cfg.vibrance = Math.max(0, Math.min(100, Math.round(pct)));
        vibranceFlush.restart();
    }

    // ----------------------------------------------------------- мышь
    // Через hyprctl eval по той же причине, что и настройки мониторов:
    // keyword не-legacy парсер молча отвергает, выходя с нулевым кодом.
    Process { id: pInput; property string args: ""; command: ["sh", "-c", pInput.args] }
    function applyInput() {
        var lua = "hl.config({ input = { sensitivity = "
                + Number(root.cfg.mouseSens).toFixed(3)
                + ", accel_profile = \"" + (root.cfg.mouseRaw ? "flat" : "adaptive") + "\""
                + " } })";
        var legacy = "hyprctl keyword input:sensitivity "
                   + Number(root.cfg.mouseSens).toFixed(3)
                   + "; hyprctl keyword input:accel_profile "
                   + (root.cfg.mouseRaw ? "flat" : "adaptive");
        pInput.args = "out=$(hyprctl eval '" + lua + "' 2>&1); "
                    + "case \"$out\" in ok*) ;; *) " + legacy + " ;; esac";
        pInput.running = false;
        pInput.running = true;
        root.saveCfg();
    }

    // Настройки ввода и цвета живут в компоновщике, а он их не помнит: любой
    // hyprctl reload — и всё вернулось к тому, что записано в конфиге. Своё
    // накатываем заново вместе с настройками мониторов, одним таймером —
    // см. monReplayTimer, он же срабатывает и на старте оболочки.

    // ------------------------------------------------- проводная сеть
    // Кабель воткнут — значок сети должен быть проводной, а не Wi-Fi: связь
    // идёт по нему, и рисовать антенну поверх работающего кабеля неверно.
    //
    // Смотрим в sysfs, а не спрашиваем NetworkManager: в системе может стоять
    // iwd с systemd-networkd, и тогда NM просто нет. Ядро же знает про
    // несущую на интерфейсе всегда, кто бы сетью ни управлял.
    //
    //   type == 1  — Ethernet (ARPHRD_ETHER);
    //   carrier    — есть ли линк прямо сейчас, то есть воткнут ли кабель;
    //   wireless/  — каталог есть только у беспроводных, их пропускаем.
    //
    // Мосты, докер, туннели и виртуальные пары отсеиваем по имени: у них
    // тоже type 1 и своя несущая, но интернетом они не являются.
    property string wiredName: ""
    readonly property bool wiredOn: root.wiredName.length > 0

    Process {
        id: pWired
        command: ["sh", "-c",
            "for d in /sys/class/net/*; do " +
            "n=${d##*/}; " +
            "[ -d \"$d/wireless\" ] && continue; " +
            "case $n in lo|docker*|veth*|br-*|virbr*|tun*|tap*|wg*|zt*|tailscale*) continue ;; esac; " +
            "[ \"$(cat $d/type 2>/dev/null)\" = 1 ] || continue; " +
            "[ \"$(cat $d/carrier 2>/dev/null)\" = 1 ] && { echo $n; exit 0; }; " +
            "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                root.wiredName = lines.length ? lines[lines.length - 1].trim() : "";
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { pWired.running = false; pWired.running = true; }
    }

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
    // а словарь нужен только для английского; сами строки — в Translations.qml.
    readonly property Translations i18n: Translations {}

    readonly property bool isEn: cfg.lang === "en"
    function tr(k) { return isEn && i18n.en[k] !== undefined ? i18n.en[k] : k; }

    // -------------------------------------------------- язык экрана входа
    // Greeter работает от пользователя sddm и наши настройки прочитать не
    // может: ~/ закрыт. Дублируем выбранный язык в общий каталог тем же
    // QML-фрагментом, что и акцент темы, — иначе экран входа продолжал бы
    // говорить по-русски после переключения системы на английский.
    // Каталог заводит установщик; если его нет, молча ничего не делаем.
    Process {
        id: pGreeterLocale
        command: ["sh", "-c",
            "d=/var/lib/panacea; [ -w \"$d\" ] || exit 0; " +
            "printf 'import QtQuick 2.15\\nQtObject { property string lang: \"%s\" }\\n' " +
            "\"$1\" > \"$d/locale.qml\" && chmod 644 \"$d/locale.qml\"",
            "_", root.cfg.lang]
    }
    // Палитра для экрана входа — тем же способом и в тот же каталог.
    //
    // Раньше её писал hypr/scripts/palette.sh из $accent_color, а это
    // палитра терминалов и редакторов, к теме оболочки отношения не имеющая.
    // Совпадение было случайным: на чёрно-белой теме экран входа встречал
    // терракотовым кружком аватара и таким же кружком загрузки.
    //
    // Пишем не один акцент, а всю четвёрку: у Nothing своя не только
    // выделяющая краска, но и текст с фоном.
    Process {
        id: pGreeterTheme
        command: ["sh", "-c",
            "d=/var/lib/panacea; [ -w \"$d\" ] || exit 0; " +
            "printf 'import QtQuick 2.15\\nQtObject {\\n" +
            "  property color value: \"%s\"\\n" +
            "  property color fg: \"%s\"\\n" +
            "  property color muted: \"%s\"\\n" +
            "  property color bg: \"%s\"\\n}\\n' " +
            "\"$1\" \"$2\" \"$3\" \"$4\" > \"$d/accent.qml\" " +
            "&& chmod 644 \"$d/accent.qml\"",
            "_",
            String(root.colOn), String(root.colFg),
            String(root.colMuted), String(root.colBg)]
    }
    // Прозрачность терминала — правилом компоновщика, а не alpha в foot.ini.
    //
    // Сам foot читает свой конфиг только при запуске: ползунок не менял бы
    // ничего в уже открытых окнах, а именно там его и двигают, глядя на
    // терминал. Правило Hyprland применяется сразу и ко всем окнам разом.
    //
    // Пишем и применяем: файл нужен, чтобы значение пережило перезагрузку —
    // windowrules.lua подхватывает его при старте, — а eval, чтобы увидеть
    // результат сейчас, не дожидаясь следующего входа в систему.
    Process {
        id: pTermAlpha
        command: ["sh", "-c",
            "d=\"$HOME/.config/hypr/lua\"; mkdir -p \"$d\" || exit 0; " +
            "printf 'return { opacity = %s }\\n' \"$1\" > \"$d/term_data.lua\"; " +
            "hyprctl eval \"hl.window_rule({ name = 'panacea-term-opacity', " +
            "match = { class = '^(footclient|foot)$' }, opacity = $1 })\" >/dev/null 2>&1",
            "_", root.cfg.termAlpha.toFixed(2)]
    }
    // Сдерживаем, как и запись яркости по шине: ползунок шлёт значение на
    // каждое движение мыши, а каждое — это запуск hyprctl. Наперегонки они
    // спорят за один и тот же вызов, и компоновщик показывает баннер с
    // ошибкой. Пишем, когда рука остановилась.
    Timer {
        id: termAlphaFlush
        interval: 180
        onTriggered: {
            pTermAlpha.running = false;
            pTermAlpha.running = true;
        }
    }
    function applyTermAlpha() { termAlphaFlush.restart(); }

    // Перезапуск сервера терминала.
    //
    // Нужен там, где правило компоновщика бессильно: своя alpha у foot,
    // цвета, шрифт — всё это сервер читает один раз при старте и раздаёт
    // клиентам. Просто убить его нельзя: автозапуск отрабатывает один раз за
    // сеанс и заново не поднимет, а без сервера терминал перестанет
    // открываться вовсе. Поэтому убиваем и тут же поднимаем сами.
    //
    // Открытые окна при этом закроются — они и есть клиенты умершего
    // сервера. Об этом сказано на кнопке.
    Process {
        id: pTermRestart
        command: ["sh", "-c",
            "pkill -x foot >/dev/null 2>&1; sleep 0.4; " +
            "setsid -f foot --server >/dev/null 2>&1"]
    }
    // Запуск команды, переживающей закрытие панели.
    //
    // Process, объявленный внутри страницы, умирает вместе с ней: меню
    // питания закрывает панель сразу после запуска, и страница уничтожается
    // в тот же миг. Быстрым командам вроде systemctl хватало мгновения
    // отделиться, а блокировке — нет: её скрипт сперва готовит фон из обоев,
    // и Process убивали раньше, чем дело доходило до самого экрана. Со
    // стороны это выглядело как неработающая кнопка.
    //
    // Здесь процесс живёт в корне оболочки, который не уничтожается никогда,
    // так что торопиться ему некуда.
    Process { id: pDetached }
    function runDetached(cmd) {
        // Через компоновщик, а не своим Process.
        //
        // Даже отвязанный setsid потомок не переживал закрытия панели:
        // блокировка успевала дойти до запуска экрана — это видно по следу в
        // lock.log, — и тут же умирала, не оставив ни строчки в stderr и ни
        // своего файла журнала. Так выглядит убитый процесс, а не упавший.
        //
        // Hyprland запускает программы своим потомком — тем же способом,
        // каким их открывают горячие клавиши, — и оболочка ему в этом не
        // родитель. Дальше процесс живёт сам по себе.
        //
        // Одинарные кавычки внутри команды экранируем: путь их не содержит,
        // но команда приходит извне, и молча испорченная строка хуже явной.
        if (Hyprland.usingLua) {
            var safe = String(cmd).replace(/'/g, "\\'");
            Hyprland.dispatch("hl.dsp.exec_cmd('" + safe + "')");
        } else {
            Hyprland.dispatch("exec " + String(cmd));
        }
    }

    function restartTerminalServer() {
        pTermRestart.running = false;
        pTermRestart.running = true;
    }

    // Фон терминала под тему.
    //
    // На Nothing он совпадает с карточками виджетов — тем же тёмно-серым,
    // чтобы терминал читался частью набора, а не чужим окном. На остальных
    // темах файл пустой, и цвет остаётся тот, что задаёт общая палитра: она
    // правится руками и о темах оболочки не знает.
    //
    // Пишем в свой файл, а не в тот, что генерирует palette.sh: у одного
    // файла не бывает двух хозяев без спора. foot.ini подключает оба, наш
    // вторым — побеждает подключённый позже.
    readonly property string termBg: "171717"
    Process {
        id: pTermTheme
        command: ["sh", "-c",
            "f=\"$HOME/.config/foot/panacea-theme\"; mkdir -p \"$(dirname \"$f\")\" || exit 0; " +
            "if [ -n \"$1\" ]; then " +
            "printf '[colors-dark]\\nbackground=%s\\n' \"$1\" > \"$f\"; " +
            "else : > \"$f\"; fi",
            "_", root.themeNothing ? root.termBg : ""]
    }
    function syncTermTheme() {
        pTermTheme.running = false;
        pTermTheme.running = true;
    }

    function syncGreeterTheme() {
        pGreeterTheme.running = false;
        pGreeterTheme.running = true;
    }
    onThemeChanged: {
        root.syncGreeterTheme();
        root.syncTermTheme();
    }

    // ------------------------------------------------------------ язык
    // Язык оболочки меняется мгновенно — это её собственный словарь. Язык
    // остального (приложений, меню, системных сообщений) живёт в LANG и
    // требует root, поэтому идёт через pkexec: агент polkit у оболочки свой,
    // окно с паролем нарисует она сама.
    //
    // Часы при этом остаются 24-часовыми при любом языке: за формат отвечает
    // отдельная переменная, и скрипт её не трогает.
    property string sysLang: "en"
    property bool   sysLangPending: false

    Process {
        id: pLocaleGet
        running: true
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/locale.sh get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim().split("\n").pop().trim();
                if (s === "ru" || s === "en") root.sysLang = s;
            }
        }
    }

    Process {
        id: pLocaleSet
        onExited: {
            root.sysLangPending = false;
            pLocaleGet.running = false;
            pLocaleGet.running = true;
        }
    }

    function setLang(code) {
        // Оболочка переключается сразу, не дожидаясь пароля: её словарь
        // системного языка не касается, и ждать здесь нечего.
        root.cfg.lang = code;
        root.saveCfg();

        root.sysLangPending = true;
        pLocaleSet.command = ["sh", "-c",
            "pkexec " + Quickshell.env("HOME") + "/.config/panacea/scripts/locale.sh set " + code];
        pLocaleSet.running = false;
        pLocaleSet.running = true;
    }

    function syncGreeterLocale() {
        pGreeterLocale.running = false;
        pGreeterLocale.running = true;
    }
    // Один обработчик на сигнал: QML второго не допускает, поэтому всё, что
    // должно случиться на смене языка, собрано здесь.
    //
    // Погоду переспрашиваем потому, что описание словами приходит от сервиса
    // уже переведённым — язык передаётся в запросе. Свои подписи оболочка
    // переключает сразу, а это одно осталось бы на прежнем языке до
    // следующего опроса, то есть до четверти часа.
    onIsEnChanged: {
        root.syncGreeterLocale();
        if (root.cfg.featWidgets || root.cfg.weatherOnIsland) root.refreshWeather();
    }

    // Видимость вогнутых уголков острова.
    //
    // Гаснут они сразу, а появляются с задержкой на время движения капсулы.
    // Уголки — отдельные элементы, привязанные к её краям, и при возврате из
    // настроек они проявлялись мгновенно, ещё когда капсула ехала на место:
    // со стороны выглядело, будто две наклейки слетаются к острову с разных
    // сторон. Пока он едет, их просто нет, и приезжает он целым.
    readonly property bool cornersWanted:
        !(root.settingsMode || root.wallsOpen || root.pillHidden)
    property bool cornersOn: false
    Timer {
        id: cornerReveal
        interval: root.animMs + 40
        onTriggered: root.cornersOn = true
    }
    onCornersWantedChanged: {
        if (root.cornersWanted) {
            cornerReveal.restart();
        } else {
            cornerReveal.stop();
            root.cornersOn = false;
        }
    }

    // ------------------------------------ перезагрузка в другую систему
    // Процесс живёт ЗДЕСЬ, в корне, а не в лаунчере, откуда его вызывают.
    //
    // Лаунчер закрывается сразу после выбора, и через animMs + 40 мс страница
    // сбрасывается на главную — вид уничтожается, а вместе с ним и всё, что в
    // нём объявлено. Process, заведённый внутри лаунчера, умирал за четверть
    // секунды, тогда как pkexec к этому моменту только успевал нарисовать окно
    // с паролем. Снаружи это выглядело ровно как «нажал и ничего не
    // произошло»: ни ошибки, ни окна, ни перезагрузки.
    //
    // setsid здесь не годится, хотя и пережил бы закрытие панели: он уводит
    // процесс в новый сеанс, а polkit по сеансу и решает, чьё это право. Корень
    // оболочки живёт столько же, сколько сама оболочка, и этого достаточно.
    Process {
        id: pBootOs
        stderr: StdioCollector {
            onStreamFinished: {
                var t = String(text).trim();
                if (t.length === 0) return;
                // Тихо падать этой команде нельзя: человек ждёт перезагрузки и
                // по отсутствию окна не отличит отказ polkit от того, что
                // нажатие вовсе не дошло.
                console.warn("bootos:", t);
                pBootOsSay.command = ["notify-send", "-u", "critical",
                                      root.tr("Не удалось перезагрузиться"), t];
                pBootOsSay.running = false;
                pBootOsSay.running = true;
            }
        }
    }
    Process { id: pBootOsSay }

    // ------------------------------------ открыть файл выбранной программой
    // Живёт здесь по той же причине, что и перезагрузка в другую систему:
    // проводник закрывается сразу после выбора, и Process, объявленный внутри
    // него, умирал вместе с видом — раньше, чем успевал запустить программу.
    // Снаружи это выглядело как «выбрал программу, проводник закрылся, ничего
    // не открылось».
    Process { id: pOpenWith }
    function openFileWith(path, desktopFile) {
        if (!path) return;
        var s = root.scriptDir + "/files.sh";
        pOpenWith.command = desktopFile && desktopFile.length
            ? ["sh", "-c", s + ' open "$1" "$2"', "_", String(path), String(desktopFile)]
            : ["sh", "-c", s + ' open "$1"', "_", String(path)];
        pOpenWith.running = false;
        pOpenWith.running = true;
    }

    function bootIntoSystem(id) {
        if (!id) return;
        pBootOs.command = ["pkexec", root.scriptDir + "/bootos.sh", "boot", String(id)];
        pBootOs.running = false;
        pBootOs.running = true;
    }

    // Номер версии оболочки: его правит автор при выпуске, а хеш коммита
    // рядом говорит, из какого состояния репозитория собрана сборка.
    readonly property string version: "1.0.11"

    // ------------------------------------------------------------ обновление
    // Установленную версию помечает установщик (~/.config/panacea/.version),
    // а update.sh сверяет её с концом ветки на GitHub. Хеш коммита меняется от
    // любой правки — и от новых файлов, и от изменений в старых, и от удалений,
    // поэтому одного сравнения хватает, чтобы поймать всё сразу.
    property string updStatus: ""      // "" | current | behind | unknown | offline
    property string updSubject: ""     // заголовок последнего коммита
    property string updLatest: ""      // хеш на GitHub
    property string updCurrent: ""     // хеш, с которого ставили
    property bool   updBusy: false
    property string updStep: ""
    property string updError: ""      // код ошибки от update.sh, не текст
    // о какой версии уже сообщали: одно уведомление на выпуск, а не на проверку
    property string updNotified: ""

    readonly property bool updateAvailable: updStatus === "behind"

    // update.sh печатает код, а не фразу: иначе текст ошибки приходил бы на
    // языке скрипта и не слушался выбранного языка интерфейса.
    readonly property string updErrorText: {
        switch (root.updError) {
        case "":         return "";
        case "nogit":    return root.tr("Не установлен git");
        case "offline":  return root.tr("Нет связи с GitHub");
        case "download": return root.tr("Не удалось скачать обновление");
        case "install":  return root.tr("Установщик завершился с ошибкой");
        default:         return root.tr("Обновление не удалось");
        }
    }

    // Идёт ли сейчас проверка. Отдельно от updBusy: обновление длится минуты и
    // показывается в острове, а проверка — секунду-другую и живёт только в
    // окне настроек. Без этого флага нажатие на «Проверить» не отвечало ничем:
    // ответ приходил, когда человек уже решил, что кнопка сломана, — и если
    // версия оказывалась прежней, не менялось вообще ничего.
    property bool updChecking: false

    function checkUpdate() {
        if (root.updBusy || root.updChecking) return;
        root.updChecking = true;
        root.updError = "";
        pUpdCheck.running = false;
        pUpdCheck.running = true;
    }

    function applyUpdate() {
        if (root.updBusy) return;
        root.updBusy = true;
        root.updError = "";
        root.updStep = "download";
        root.updCreepAt = 0;
        // Обновление идёт минуты и переживает закрытие настроек: показываем
        // его в острове, иначе о нём знало бы только открытое окно.
        root.beginBusy(root.tr("Обновление…"), "󰚰", root.updStepPercent);
        pUpdApply.running = true;
    }

    // Проценты у обновления считаются по этапам, которые печатает update.sh:
    // байтов и файлов оно не считает, а этапы известны наперёд.
    //
    // Веса, а не равные доли. Этапы длятся по-разному: скачивание идёт
    // секунды, а сохранение настроек и отметка версии — доли секунды. При
    // равных долях полоса замирала на первой седьмой, а потом за миг
    // проскакивала остальные шесть — то есть скакала вместо того, чтобы
    // заполняться. Числа взяты из замеров: клон около трёх секунд,
    // установщик около одной, остальное — мгновения.
    readonly property var updSteps: [
        { id: "download",   w: 30 },
        { id: "selfupdate", w: 2  },
        { id: "backup",     w: 3  },
        { id: "install",    w: 12 },
        { id: "greeter",    w: 2  },
        { id: "restore",    w: 3  },
        { id: "restart",    w: 2  },
        { id: "done",       w: 0  }
    ]
    readonly property real updWeightTotal: {
        var t = 0;
        for (var i = 0; i < root.updSteps.length; i++) t += root.updSteps[i].w;
        return t > 0 ? t : 1;
    }
    function updStepIndex(id) {
        for (var i = 0; i < root.updSteps.length; i++)
            if (root.updSteps[i].id === id) return i;
        return -1;
    }
    // Доля начатого этапа — то, что накоплено до него. Внутри самого этапа
    // полосу двигает updCreep: сколько именно прошло, скрипт не знает.
    readonly property int updStepPercent: {
        var i = root.updStepIndex(root.updStep);
        if (i < 0) return 0;
        var acc = 0;
        for (var k = 0; k < i; k++) acc += root.updSteps[k].w;
        return Math.round(acc * 100 / root.updWeightTotal);
    }
    // Сколько отдать текущему этапу целиком: до этой границы его и подползаем.
    readonly property int updStepCeil: {
        var i = root.updStepIndex(root.updStep);
        if (i < 0) return 0;
        var acc = 0;
        for (var k = 0; k <= i; k++) acc += root.updSteps[k].w;
        return Math.round(acc * 100 / root.updWeightTotal);
    }

    // Полоса ползёт и внутри этапа, не дожидаясь следующего.
    //
    // Самый долгий шаг — скачивание, и его длительность зависит от связи:
    // ни git, ни установщик о ходе работы не сообщают. Стоящая полоса на
    // медленной сети читается как зависшее обновление. Поэтому она движется
    // сама, замедляясь у границы этапа и никогда её не переступая: дойти до
    // конца раньше настоящего конца было бы обманом.
    // Своя дробная доля, а не busyProgress: тот целый, и приращение меньше
    // единицы в нём терялось бы — полоса застревала бы у самой границы, куда
    // подползает всё медленнее.
    property real updCreepAt: 0

    Timer {
        id: updCreep
        interval: 220
        repeat: true
        running: root.updBusy && root.updStep !== "done"
        onTriggered: {
            var to = root.updStepCeil;
            if (root.updCreepAt >= to) return;
            // шаг тем меньше, чем ближе граница
            var left = to - root.updCreepAt;
            root.updCreepAt = Math.min(to, root.updCreepAt + Math.max(0.25, left * 0.06));
            root.busyProgress = Math.round(root.updCreepAt);
        }
    }
    onUpdStepChanged: {
        if (!root.updBusy) return;
        // Назад полоса не ходит: этап мог начаться раньше, чем подполз
        // предыдущий, и откат читался бы как сбой.
        if (root.updStepPercent > root.updCreepAt)
            root.updCreepAt = root.updStepPercent;
        if (root.updStep === "done") root.updCreepAt = 100;
        root.busyProgress = Math.round(root.updCreepAt);
    }

    function updParse(text, done) {
        var lines = String(text).trim().split("\n");
        for (var i = 0; i < lines.length; i++) {
            var kv = lines[i].split("=");
            if (kv.length < 2) continue;
            var k = kv[0].trim(), v = lines[i].slice(kv[0].length + 1).trim();
            if (k === "status")       root.updStatus = v;
            else if (k === "subject") root.updSubject = v;
            else if (k === "latest")  root.updLatest = v;
            else if (k === "current") root.updCurrent = v;
            else if (k === "step")    root.updStep = v;
            else if (k === "error")   root.updError = v;
            else if (k === "missing")  root.missingDeps = v;
            else if (k === "obsolete") root.obsoleteDeps = v;
            else if (k === "version") root.updCurrent = v;
        }
        if (!done) return;
        // Уведомление показываем один раз на версию: проверка идёт по таймеру,
        // и каждые шесть часов напоминать об одном и том же — навязчиво.
        if (root.updStatus === "behind" && root.updLatest !== root.updNotified) {
            root.updNotified = root.updLatest;
            pUpdNotify.running = true;
        }
    }

    Process {
        id: pUpdCheck
        command: [root.scriptDir + "/update.sh", "check"]
        stdout: StdioCollector { onStreamFinished: root.updParse(text, true) }
        // Снимаем флаг по выходу процесса, а не по концу вывода: скрипт может
        // упасть, ничего не напечатав, и тогда крутилка осталась бы навсегда.
        onExited: root.updChecking = false
    }

    Process {
        id: pUpdApply
        command: [root.scriptDir + "/update.sh", "apply"]
        // Построчно, а не StdioCollector.
        //
        // StdioCollector копит весь вывод и отдаёт его одним куском, когда
        // поток закроется, то есть когда обновление уже кончилось. Строки
        // step= приезжали все разом и в самом конце — полоса честно стояла на
        // нуле всё обновление, а потом оболочка просто перезапускалась. Ход
        // работы, показанный после её окончания, — это не ход работы.
        //
        // SplitParser отдаёт каждую строку сразу, как скрипт её напечатал.
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.updParse(data, false)
        }
        onExited: code => {
            root.updBusy = false;
            root.endBusy();
            if (code !== 0 && root.updError.length === 0)
                root.updError = "failed";
            if (code === 0) { root.updStatus = "current"; root.updStep = "done"; }
        }
    }

    // Обычное уведомление рабочего стола: его увидят, даже когда окно настроек
    // закрыто, а поймает его собственная служба уведомлений оболочки.
    // -p заставляет notify-send напечатать номер уведомления. Он нужен,
    // чтобы потом узнать своё же уведомление в общей ленте: сравнивать текст
    // нельзя — он переводится, и на другом языке проверка молча перестала бы
    // совпадать.
    property int updNotifId: -1
    Process {
        id: pUpdNotify
        command: ["notify-send", "-p", "-a", "Panacea", "-i",
                  Quickshell.env("HOME") + "/.config/panacea/assets/logo-128.png",
                  root.tr("Доступно обновление Panacea"), root.updSubject]
        stdout: StdioCollector {
            onStreamFinished: root.updNotifId = parseInt(String(text).trim()) || -1
        }
    }

    // ----------------------------------------------------- «что нового»
    // update.sh кладёт список изменений в .whatsnew. Оболочка после
    // перезапуска показывает его один раз и файл стирает.
    property var whatsNew: []
    readonly property bool whatsNewOpen: whatsNew.length > 0

    FileView {
        id: whatsNewFile
        path: Quickshell.env("HOME") + "/.config/panacea/.whatsnew"
        watchChanges: true
        // Файла почти всегда нет, и это не ошибка: он появляется только
        // после обновления. Без этого лог засорялся при каждом запуске.
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var t = String(whatsNewFile.text()).trim();
            root.whatsNew = t.length ? t.split("\n").filter(x => x.trim().length) : [];
        }
        onLoadFailed: root.whatsNew = []
    }

    // Слежение цепляется к существующему файлу, а .whatsnew появляется уже
    // после запуска оболочки, если обновлялись без перезапуска. Поэтому
    // первые полминуты перечитываем сами.
    Timer {
        interval: 3000
        running: root.whatsNew.length === 0
        repeat: true
        triggeredOnStart: true
        property int tries: 0
        onTriggered: {
            whatsNewFile.reload();
            if (++tries > 10) running = false;
        }
    }

    // Пакеты, которых не хватает после обновления. Ставим не мы: обновление
    // идёт с --no-deps, а хватать пакеты через sudo из-под кнопки в настройках
    // — не то, чего от него ждут. Поэтому просто называем их на том же экране.
    property string missingDeps: ""

    // Простое копирование в буфер. Пароли идут своим путём — им нужен
    // --sensitive-data и очистка по таймеру, см. vaultCopy().
    Process { id: pCopyText }
    function copyText(t) {
        pCopyText.running = false;
        pCopyText.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", String(t)];
        pCopyText.running = true;
    }

    FileView {
        id: missingDepsFile
        path: Quickshell.env("HOME") + "/.config/panacea/.missingdeps"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.missingDeps = String(missingDepsFile.text()).trim()
        onLoadFailed: root.missingDeps = ""
    }

    // Обратная сторона: что оболочка ставила раньше и больше не использует.
    // Удалять сами не будем — это пакеты в системе человека, а не наши.
    property string obsoleteDeps: ""
    FileView {
        id: obsoleteDepsFile
        path: Quickshell.env("HOME") + "/.config/panacea/.obsoletedeps"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.obsoleteDeps = String(obsoleteDepsFile.text()).trim()
        onLoadFailed: root.obsoleteDeps = ""
    }

    function dismissWhatsNew() {
        root.whatsNew = [];
        root.missingDeps = "";
        root.obsoleteDeps = "";
        pWhatsNewClear.running = true;
    }
    Process {
        id: pWhatsNewClear
        command: ["sh", "-c",
                  "rm -f \"$1/.whatsnew\" \"$1/.missingdeps\" \"$1/.obsoletedeps\"", "_",
                  Quickshell.env("HOME") + "/.config/panacea"]
    }

    // Первая проверка не на старте: при входе в систему сеть ещё поднимается,
    // и запрос почти наверняка не прошёл бы.
    Timer { interval: 45000; running: true; onTriggered: root.checkUpdate() }
    Timer { interval: 6 * 3600 * 1000; running: true; repeat: true; onTriggered: root.checkUpdate() }

    readonly property string scriptDir:
        Quickshell.env("HOME") + "/.config/panacea/scripts"

    // capture.sh off зовёт этот IPC, чтобы панель сняла режим захвата
    signal cancelCaptureRequested()

    // Какая вкладка настроек откроется: 0 — пилюля, 2 — экран, 3 — клавиши.
    property int settingsTab: 0
    // Открыть настройки на разделе по имени, а не по номеру: номера зависят
    // от порядка в списке разделов, и новый раздел посередине молча уводил бы
    // не туда. Пустая строка — раздел не задан.
    property string settingsSection: ""
    function openSettingsAt(sectionId) {
        root.settingsSection = sectionId;
        if (root.page !== "settings" || !root.expanded) root.togglePage("settings");
    }

    // Пересобрать binds_data.lua и перечитать конфиг Hyprland
    Process { id: pGenBinds }
    // Скрипт читает settings.json, а запись файла асинхронная: если запускать
    // его сразу после saveCfg(), он успевал прочитать ещё старое сочетание —
    // и «Применить» не меняло ничего. Ждём сигнала о завершении записи.
    property bool bindsPending: false
    function applyBinds() {
        root.bindsPending = true;
        saveCfg();
        bindsFallback.restart();
    }
    function runGenBinds() {
        if (!root.bindsPending) return;
        root.bindsPending = false;
        bindsFallback.stop();
        pGenBinds.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/panacea/scripts/genbinds.sh"];
        pGenBinds.running = true;
    }
    // страховка, если сигнала о записи почему-то не будет
    Timer { id: bindsFallback; interval: 700; onTriggered: root.runGenBinds() }

    // Сочетания живут в settings.json, но Hyprland читает только производный
    // от него binds_data.lua. Файл лежит внутри ~/.config/hypr, который
    // установщик заменяет целиком, — и пропадал вместе с ним. Настройки при
    // этом оставались на месте, поэтому со стороны это выглядело так, будто
    // сочетания «не сохраняются»: окно Super+/ показывает своё, а нажатия
    // работают заводские. Собираем файл заново, если его нет.
    Process {
        id: pBindsHeal
        running: true
        command: ["sh", "-c",
            "[ -f \"$HOME/.config/hypr/lua/binds_data.lua\" ] "
            + "|| \"$HOME/.config/panacea/scripts/genbinds.sh\""]
    }
    Connections {
        target: cfgFile
        function onSaved() { root.runGenBinds(); }
    }

    // ---------------------------------------------------------------- палитра
    // Темы не зависят от обоев: цвет всей оболочки задаёт выбранная тема, а
    // не картинка на столе. Тема «default» — то, что было раньше: фон чёрный,
    // а текст и акцент берутся из настроек, поэтому вручную выбранные цвета
    // никуда не деваются.
    readonly property var themes: Themes.list
    function themeOf(id) { return Themes.of(id); }
    readonly property var theme: themeOf(cfg.themeId)
    readonly property bool themeCustom: cfg.themeId === "default"
    // Единственный флаг на весь облик Nothing. Проверять cfg.themeId по строке
    // в двух десятках мест значило бы искать их все при переименовании темы.
    readonly property bool themeNothing: cfg.themeId === "nothing"

    // Размер точки в числах Nothing. Считается от размера шрифта, а не задан
    // числом: человек двигает ползунок кегля в настройках, и точечные часы
    // должны расти вместе с остальными подписями, иначе остров расползается.
    //
    // Три ступени — высота цифры в пикселях, тем же числом, каким меряют
    // обычный текст. Считаются от кегля со сдвигом, а не долей от него:
    // рядом с цифрой всегда стоит подпись, и разница между ними должна
    // оставаться одинаковой, а не растягиваться вместе с ползунком.
    readonly property real dotHBig:   root.fontSize + 10   // часы в панели
    readonly property real dotHClock: root.fontSize - 1    // часы в острове
    readonly property real dotHSmall: root.fontSize - 3    // числа при значках
    readonly property real dotHTiny:  root.fontSize - 5    // сводка нагрузки

    // Цвет надписи поверх заливки акцентом. На светлом акценте белым по
    // белому не видно ничего — а на теме Nothing акцент именно белый.
    // Яркость по Rec. 709: зелёный глаз видит куда лучше синего, и среднее
    // арифметическое трёх каналов ошибается как раз на жёлтом и голубом.
    function fgOn(c) {
        return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) > 0.6
               ? root.colBg : "#ffffff";
    }

    readonly property color colBg:     theme.bg
    // у «default» цвета текста и акцента остаются за настройками
    readonly property color colFg:     themeCustom ? cfg.colFg : theme.fg
    readonly property color colMuted:  Qt.rgba(colFg.r, colFg.g, colFg.b, cfg.mutedAlpha)
    readonly property color colLine:   Qt.rgba(colFg.r, colFg.g, colFg.b, 0.10)
    readonly property color colHover:  Qt.rgba(colFg.r, colFg.g, colFg.b, 0.10)
    readonly property color colOn:     themeCustom ? cfg.colOn : theme.on
    readonly property color colOk:     theme.ok
    readonly property color colCrit:   theme.crit

    // Цвета состояний, которых в палитре темы нет. На теме Nothing цветного
    // выделения не бывает вовсе: смысл там несёт яркость, а не оттенок, и
    // одинокое зелёное или синее пятно среди чёрно-белого выглядит чужим.
    // Красный — единственное исключение, он значит «внимание», а не
    // украшение, и живёт в палитре как colCrit.
    //
    // tint() для тех цветов, под которые заводить строку в палитре не за
    // чем: они встречаются в одном-двух местах и означают ровно себя.
    function tint(c) { return root.themeNothing ? root.colFg : c; }
    // янтарный «на паузе» и «осторожно» — он встречается часто
    readonly property color colWarn: root.tint("#fbbf24")
    readonly property string fontFam:  cfg.fontFam
    // текстовый шрифт и шрифт заголовков; пустое значение — общий fontFam
    readonly property string fontBody:    cfg.fontBody || cfg.fontFam
    readonly property string fontDisplay: cfg.fontDisplay || cfg.fontFam
    readonly property int fontSize:    cfg.fontSize
    readonly property int iconSize:    cfg.iconSize
    // шаг отступов и малый радиус: из них считается геометрия карточек
    readonly property int unit:        cfg.spacingUnit
    readonly property int radiusS:     cfg.smallRadius

    // ---------------------------------------------------------------- метрики
    readonly property int pillH: cfg.pillH      // высота свёрнутой пилюли

    // Где висит остров. Раскрытие всегда идёт к центру экрана: сверху —
    // вниз, снизу — вверх, слева — вправо, справа — влево. Это выходит само
    // собой, потому что капсула прижата к своей кромке и растёт от неё.
    readonly property string pillPos: {
        var p = String(cfg.pillPos || "top");
        return (p === "bottom" || p === "left" || p === "right") ? p : "top";
    }
    readonly property bool pillAtTop:    pillPos === "top"
    readonly property bool pillAtBottom: pillPos === "bottom"
    readonly property bool pillAtLeft:   pillPos === "left"
    readonly property bool pillAtRight:  pillPos === "right"
    // у боковых положений капсула стоит по центру высоты, а не у кромки экрана
    readonly property bool pillSide: pillAtLeft || pillAtRight

    // ------------------------------------------------- перенос острова мышью
    // Тумблер в настройках; тянут за полосу над часами в раскрытых быстрых
    // настройках. У кромки остров цепляется к её центру, в пустоте —
    // возвращается на место: цепляться там не за что.
    property bool  pillDragging: false
    property real  dragDX: 0            // смещение от родного места, px
    property real  dragDY: 0
    // кромка, к которой прицепится остров, если отпустить сейчас
    property string dragEdge: ""

    // Кромку выбираем по тому, к какой ближе центр капсулы, и только если он
    // уже в её полосе — четверть экрана. Иначе отпускать некуда.
    function edgeAt(cx, cy) {
        var w = root.width, h = root.height;
        var dTop = cy, dBottom = h - cy, dLeft = cx, dRight = w - cx;
        var m = Math.min(dTop, dBottom, dLeft, dRight);
        if (m > Math.min(w, h) * 0.25) return "";
        if (m === dTop)    return "top";
        if (m === dBottom) return "bottom";
        if (m === dLeft)   return "left";
        return "right";
    }

    function dropPill() {
        var edge = root.dragEdge;
        root.pillDragging = false;
        root.dragEdge = "";
        // смещение снимаем с анимацией: остров едет либо к новой кромке,
        // либо обратно на своё место
        root.dragDX = 0;
        root.dragDY = 0;
        if (edge.length && edge !== root.pillPos) {
            cfg.pillPos = edge;
            root.saveCfg();
        }
        // Сворачиваемся и не раскрываемся, пока курсор не уйдёт и не вернётся.
        // У новой кромки раскладка страницы другая, и раскрытая панель
        // переезжала вместе с островом, разъезжаясь на ходу. Так остров сначала
        // спокойно встаёт на место, а панель открывается уже наведением.
        root.hoverExpandArmed = false;
        capsuleHover.markArmPoint();
        root.collapse();
    }

    // Где именно сейчас стоит капсула. Нужно карусели обоев: она начинает
    // разворот ровно из острова, поэтому ей нужны его координаты.
    property real pillRectX: 0
    property real pillRectY: 0
    property real pillRectW: 0
    property real pillRectH: 0
    readonly property int panelW: cfg.panelW    // ширина раскрытой панели
    readonly property int gap: 5                // зазор между пилюлей и окнами
    // радиус примыкания к кромке; вне режима выреза примыкать нечему
    readonly property int cornerR: cfg.notchMode ? cfg.notchFlare : 0

    // Единая кривая: панель «перетекает», а не прыгает.
    // Длительности задаёт вкладка Motion. «Reduce motion» обнуляет их все
    // разом: движение исчезает, а не ускоряется.
    readonly property bool noMotion: cfg.reduceMotion
    readonly property int animMs:   noMotion ? 0 : cfg.animMove
    readonly property int animFade: noMotion ? 0 : cfg.animFade
    readonly property int animHover: noMotion ? 0 : cfg.animHover
    // перелёт осциллятора в долях: 79 % → 0.79 сверх цели
    readonly property real animBounce: noMotion ? 0 : cfg.animBounce / 100
    // перелёт для кривых OutBack: 100 % ползунка — это заметный, но ещё не
    // резиновый отскок, поэтому доля умножается, а не берётся как есть
    readonly property real easeOvershoot: animBounce * 1.7
    readonly property int animFast: Math.round(animMs * 0.52)
    // изменение содержимого (список приложений, новая сеть) — коротко и резко
    readonly property int animQuick: Math.round(animMs * 0.48)

    // true только пока идёт раскрытие/схлопывание или смена страницы.
    // Нужно, чтобы рост списка не ехал по длинной кривой раскрытия.
    property bool morphing: false
    onExpandedChanged: {
        morphing = true;
        morphTimer.restart();
        // панель закрылась — показываем карточки, накопившиеся за это время
        if (!expanded) toastPump.restart();
    }
    onPageChanged:     { morphing = true; morphTimer.restart() }
    // Держим дольше самой анимации: высота страницы приходит с задержкой
    // в кадр-другой, и без запаса второй шаг ехал бы по «быстрой» кривой.
    Timer { id: morphTimer; interval: root.animMs + 140; onTriggered: root.morphing = false }

    // ------------------------------------------------------------ состояние UI
    property bool expanded: false
    // "main" | "wifi" | "bt" | "battery" | "launcher"
    // main    — плитки Wi-Fi / Bluetooth / звук, трек и запись
    // battery — режимы питания и состояние заряда
    // Отдельной страницы плеера нет: играющий трек с кнопками и полосами
    // живёт карточкой на главной, там же, где всё остальное.
    property string page: "main"
    // что показывает медиаплеер (страница "media")
    property string mediaPath: ""
    // высота полотна плеера: большую часть экрана, но не впритык
    readonly property int mediaStageH: Math.round((screen ? screen.height : 1080) * 0.58)
    // Плеер живёт в Loader и снаружи по id не виден, поэтому режим кропа
    // держим здесь: кнопка и горячая клавиша дёргают один и тот же флаг.
    property bool mediaCrop: false
    function mediaCropToggle() { root.mediaCrop = !root.mediaCrop; }

    // ---------------------------------------------------- добавление обоев
    // «+» на странице обоев открывает проводник в режиме выбора: следующая
    // выбранная картинка не откроется в плеере, а уедет на страницу обоев,
    // где её просят назвать и сохранить.
    property bool   wallpaperPickMode: false
    property string wallpaperPick: ""       // путь выбранной, ждёт имени
    function startWallpaperPick() {
        wallsOpen = false;
        wallpaperPickMode = true;
        togglePage("files");
    }
    function finishWallpaperPick(path) {
        wallpaperPickMode = false;
        collapse();
        wallpaperPick = path;
        openWalls();
    }
    function cancelWallpaperPick() { wallpaperPick = ""; }

    function openMedia(path) {
        if (!cfg.featMedia) return;
        root.mediaCrop = false;
        root.mediaPath = path;
        pageResetTimer.stop();
        root.page = "media";
        root.expanded = true;
        root.holdOpen = true;
    }

    // ------------------------------------------------ полноэкранные окна
    // Пилюля живёт в слое Overlay и по умолчанию рисуется поверх всего.
    // Пока активное окно развёрнуто на весь экран, прячем её целиком:
    // сочетания клавиш при этом работают — по ним панель раскрывается
    // и окно снова показывается.
    property bool fullscreenActive: false

    Process {
        id: pFullscreen
        command: ["sh", "-c",
            "hyprctl activewindow -j 2>/dev/null | grep -o '\"fullscreen\": *[0-9]*' | grep -o '[0-9]*$'"]
        stdout: StdioCollector {
            onStreamFinished: root.fullscreenActive = parseInt(text.trim()) > 0
        }
    }
    Timer { id: fsProbe; interval: 120; onTriggered: pFullscreen.running = true }
    // События Hyprland приходят не на все переходы (например, при смене
    // окна внутри полноэкранного слоя), поэтому подстраховываемся опросом.
    // Опрос — только страховка: основное приходит событиями Hyprland, и
    // fsProbe перепроверяет состояние сразу после каждого. Ежесекундный
    // запуск hyprctl с двумя grep'ами стоил трёх процессов в секунду
    // круглые сутки, а ловил лишь редкие пропущенные переходы.
    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: pFullscreen.running = true
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = String(event.name);
            if (n === "fullscreen" || n === "activewindow" || n === "activewindowv2"
                || n === "closewindow" || n === "openwindow" || n === "workspace"
                || n === "focusedmon")
                fsProbe.restart();
            // перезагрузка конфига Hyprland стирает всё, что мы наприменяли
            if (n === "configreloaded") monReplayTimer.restart();
        }
    }
    // Перезагрузка конфига стирает не только настройки мониторов: скорость
    // указателя, разгон и шейдер насыщенности живут там же и уезжают вместе
    // с ними. Накатываем всё своё одним заходом, иначе после любого
    // hyprctl reload мышь и цвет молча возвращались к заводским.
    Timer {
        id: monReplayTimer
        interval: 400
        onTriggered: {
            root.monReplay();
            root.applyInput();
            pVibrance.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/panacea/scripts/vibrance.sh set "
                + root.cfg.vibrance];
            pVibrance.running = false;
            pVibrance.running = true;
        }
    }

    // Один обработчик на сигнал: QML второго не допускает, поэтому всё, что
    // должно случиться при запуске, собрано здесь.
    Component.onCompleted: {
        fsProbe.restart();
        syncGreeterLocale();
        monReplayTimer.restart();
        syncGreeterTheme();
        syncTermTheme();
        root.cornersOn = root.cornersWanted;
        // Первое заполнение списка столов: дальше его ведёт onWsRawChanged, а
        // тот срабатывает только на изменение — стартовое значение он бы
        // пропустил, и до первого переключения точек не было бы вовсе.
        root.wsList = root.wsRaw;
    }

    // ------------------------------------------------- перетаскивание файлов
    // Источник живёт прямо в окне, а не внутри страницы: панель во время
    // перетаскивания сворачивается, её содержимое уничтожается, и элемент
    // изнутри утащил бы за собой начатый drag.
    Item {
        id: fileDrag
        width: 1
        height: 1
        visible: false

        property string uri: ""

        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.CopyAction
        Drag.mimeData: ({ "text/uri-list": fileDrag.uri,
                          "text/plain": fileDrag.uri.replace("file://", "") })
    }
    Timer {
        id: fileDragStart
        interval: 90        // даём панели уехать вниз, потом начинаем drag
        onTriggered: fileDrag.Drag.active = true
    }

    // ------------------------------------------------------ обзор столов
    // Для превью нужны две вещи: геометрия окна (её знает Hyprland) и
    // wayland-хэндл (по нему ScreencopyView берёт живой кадр). Оба лежат
    // на HyprlandToplevel, поэтому собираем их в один список.
    property bool overviewOpen: false
    function openOverview() {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        root.overviewOpen = true;
    }
    function closeOverview() { root.overviewOpen = false; }

    // Переход на стол. С Lua-конфигом Hyprland разбирает строку запроса как
    // Lua-код, и привычное "workspace 2" валится синтаксической ошибкой —
    // нужен настоящий диспетчер. На обычном конфиге работает старая форма.
    function gotoWorkspace(id) {
        if (Hyprland.usingLua) Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
        else                   Hyprland.dispatch("workspace " + id);
    }
    function toggleOverview() {
        if (root.overviewOpen) closeOverview(); else openOverview();
    }

    // ------------------------------------------------------------- клавиши
    // Список сочетаний уехал из настроек в своё окно: их правят редко и
    // подолгу, список длинный, а держать его пятой вкладкой значило каждый раз
    // растягивать окно настроек под самый большой раздел.
    property bool keysWindowOpen: false
    function toggleKeysWindow() { root.keysWindowOpen = !root.keysWindowOpen; }

    // ------------------------------------------------------------------ обои
    // Карусель обоев — отдельный полноэкранный слой, как обзор столов:
    // картинку надо видеть большой, а в пилюле для этого нет места.
    property bool wallsOpen: false
    function openWalls() {
        if (!cfg.featThemes) return;
        collapse();
        root.wallsOpen = true;
        // список обновится в фоне; на экране пока прежний, а не пустота
        root.refreshWalls();
    }
    function closeWalls() { root.wallsOpen = false; }

    // Список обоев держим здесь и читаем заранее: карусель должна открываться
    // уже с картинками. Пока список жил внутри неё, первые полсекунды на
    // экране висело «обоев не найдено».
    property var wallList: []
    property bool wallListReady: false
    Process {
        id: pWallList
        command: ["sh", "-c", root.scriptDir + "/themes.sh list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split("|");
                    if (p.length < 5) continue;
                    rows.push({
                        wName:   p[0],
                        wThumb:  p[1],
                        wActive: p[2] === "yes",
                        wOwn:    p[3] === "yes",
                        wPath:   p[4]
                    });
                }
                root.wallList = rows;
                root.wallListReady = true;
            }
        }
    }
    // Миниатюра текущих обоев: макет рабочего стола в настройках показывает
    // именно её, а не условный градиент — иначе по макету не поймёшь, как
    // остров будет читаться на своём фоне.
    readonly property string currentWallThumb: {
        for (var i = 0; i < wallList.length; i++) {
            if (wallList[i].wActive) return wallList[i].wThumb;
        }
        return "";
    }

    function refreshWalls() {
        pWallList.running = false;
        pWallList.running = true;
        root.refreshLiveWalls();
    }

    // ------------------------------------------------------- живые обои
    // Видео вместо картинки на фоне. Список и постеры готовит
    // hypr/scripts/live_wallpaper.sh, играет mpvpaper.
    property var liveList: []
    property bool liveListReady: false
    property string liveDir: ""

    Process {
        id: pLiveDir
        command: ["bash", Quickshell.env("HOME")
                          + "/.config/hypr/scripts/live_wallpaper.sh", "dir"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.liveDir = text.trim() }
    }
    Process {
        id: pLiveList
        command: ["bash", Quickshell.env("HOME")
                          + "/.config/hypr/scripts/live_wallpaper.sh", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split("|");
                    if (p.length < 4) continue;
                    rows.push({
                        wName:   p[0],
                        wThumb:  p[1],          // постер; пусто, пока не готов
                        wActive: p[2] === "yes",
                        wOwn:    true,          // живые обои всегда свои
                        wPath:   p[3]
                    });
                }
                root.liveList = rows;
                root.liveListReady = true;
            }
        }
    }
    function refreshLiveWalls() {
        pLiveList.running = false;
        pLiveList.running = true;
    }
    // папка живых обоев в проводнике: складывать видео надо именно туда
    function openLiveFolder() {
        if (root.liveDir.length === 0) return;
        root.closeWalls();
        root.openFilesAt(root.liveDir);
    }
    Timer {
        // не на самом старте: при входе в систему и без нас есть чем заняться
        interval: 4000
        running: true
        onTriggered: root.refreshWalls()
    }
    function toggleWalls() {
        if (root.wallsOpen) closeWalls(); else openWalls();
    }

    readonly property var overviewToplevels: {
        var out = [];
        if (!root.overviewOpen) return out;
        var all = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (var i = 0; i < all.length; i++) {
            var t = all[i];
            if (!t) continue;
            var o = t.lastIpcObject;
            if (!o || !o.at || !o.size) continue;
            if (o.hidden || o.workspace === undefined) continue;
            out.push({
                wayland: t.wayland,
                geo: {
                    x: o.at[0], y: o.at[1], w: o.size[0], h: o.size[1],
                    ws: o.workspace.id, cls: String(o.initialClass || o.class || "")
                }
            });
        }
        return out;
    }

    // Кто-то из окон проводника изменил файлы — остальным пора перечитать
    // свой список: они смотрят на ту же файловую систему.
    signal filesChanged()

    // fromWindow — тащат из отдельного окна проводника: пилюлю трогать не надо
    // и ждать её уезда тоже, перетаскивание начинается сразу.
    function startFileDrag(path, fromWindow) {
        fileDrag.uri = "file://" + path;
        if (fromWindow) { fileDrag.Drag.active = true; return; }
        root.collapse();
        fileDragStart.restart();
    }

    // Высота списка в проводнике фиксирована: иначе панель прыгала на каждой
    // смене папки, подстраиваясь под число файлов.
    readonly property int filesListH: Math.round((screen ? screen.height : 1080) * 0.64)

    // последняя папка проводника — чтобы он открывался там, где закрыли
    property string filesDir: Quickshell.env("HOME")
    // Иконка трея, чьё контекстное меню сейчас открыто (страница "traymenu").
    property var trayMenuItem: null
    // пока вводят пароль или открыт лаунчер, панель не закрывается по уходу мыши
    property bool holdOpen: false
    // клавиатуру окно получает уже после загрузки страницы — возвращаем
    // фокус содержимому, иначе стрелки и Enter уходят в пустоту
    onHoldOpenChanged: if (holdOpen) refocusTimer.restart()
    Timer {
        id: refocusTimer
        interval: 60
        onTriggered: if (contentLoader.item) contentLoader.item.forceActiveFocus()
    }

    readonly property bool launcherOpen: expanded && page === "launcher"

    function collapse() {
        expanded = false;
        holdOpen = false;
        weatherDetailsOpen = false;
        pageResetTimer.restart();
    }
    Timer {
        id: pageResetTimer
        interval: root.animMs + 40
        onTriggered: if (!root.expanded) { root.page = "main"; root.trayMenuItem = null; }
    }

    // Открыть страницу закреплённо; повторный вызов той же страницы закрывает.
    // Какая функция отвечает за страницу. Пустая строка — страница всегда есть
    // (главная, календарь-из-часов и т.п. проверяются отдельно).
    function pageEnabled(name) {
        switch (name) {
            case "launcher":  return cfg.featLauncher;
            case "wifi":      return cfg.featWifi;
            case "bt":        return cfg.featBluetooth;
            case "clip":      return cfg.featClipboard;
            case "notif":     return cfg.featNotifications;
            case "cal":       return cfg.featCalendar;
            case "record":    return cfg.featRecord;
            case "files":     return cfg.featFiles;
            case "media":     return cfg.featMedia;
            case "vault":     return cfg.featVault;
            case "vaultsave": return cfg.featVault;
            case "audio":     return cfg.featAudio;
            case "power":     return cfg.featPowermenu;
            default:          return true;   // main, settings, auth
        }
    }

    // ------------------------------------------------- проводник отдельно
    // С включённой настройкой проводник перестаёт быть страницей пилюли и
    // становится обычным окном: Hyprland сам его тайлит, оно остаётся на
    // своём рабочем столе и переносится между ними как любое другое. Пилюля
    // при этом не раскрывается и остаётся в обычном виде.
    // Окон может быть сколько угодно: Super+E в оконном режиме каждый раз
    // открывает ещё одно, как любой нормальный проводник. Закрывается каждое
    // само по себе — по крестику или Esc внутри него.
    property int filesWindowSeq: 0
    ListModel { id: filesWindows }

    function openFilesWindow(startDir) {
        root.filesWindowSeq++;
        filesWindows.append({ wid: root.filesWindowSeq,
                              startDir: String(startDir || "") });
    }

    // Открыть проводник сразу в нужной папке — например в каталоге живых
    // обоев из карусели. В оконном режиме это новое окно, иначе страница
    // пилюли, которая читает каталог при загрузке.
    property string filesStartDir: ""
    function openFilesAt(path) {
        var p = String(path || "");
        if (p.length === 0) return;
        if (cfg.filesWindow) { root.openFilesWindow(p); return; }
        root.filesStartDir = p;
        if (root.page === "files" && root.expanded) root.collapse();
        root.togglePage("files");
    }
    function closeFilesWindow(wid) {
        for (var i = 0; i < filesWindows.count; i++) {
            if (filesWindows.get(i).wid !== wid) continue;
            filesWindows.remove(i);
            return;
        }
    }

    // Открыть подстраницу и закрепить панель. Раньше страница батареи,
    // сетей или устройств открывалась простым присваиванием page, панель
    // оставалась незакреплённой и захлопывалась, стоило увести курсор —
    // до списка было не дотянуться. Возврат — Esc или кнопка «назад».
    function openSub(name) {
        pageResetTimer.stop();
        page = name;
        expanded = true;
        holdOpen = true;
    }

    function togglePage(name) {
        if (!pageEnabled(name)) return;   // выключено установщиком — молчим
        // проводник в оконном режиме пилюлю не трогает вовсе
        if (name === "files" && cfg.filesWindow) { openFilesWindow(); return; }
        if (expanded && page === name) { collapse(); return; }
        pageResetTimer.stop();
        page = name;
        expanded = true;
        holdOpen = true;
    }
    function openLauncher() {
        if (!cfg.featLauncher) return;
        pageResetTimer.stop();
        page = "launcher";
        expanded = true;
        holdOpen = true;
    }
    function closeLauncher() { collapse(); }
    function toggleLauncher() {
        if (launcherOpen) closeLauncher(); else openLauncher();
    }

    // Агенты открываются из лаунчера, как приложение, — своей строкой в общем
    // списке. Отдельной кнопки в быстрых настройках нет намеренно: туда ходят
    // за переключателями, а это справка, к которой обращаются, когда о ней
    // вспомнили. Искать её там же, где всё остальное, — короче, чем помнить
    // ещё одно сочетание клавиш.
    // Растёт на каждое открытие: вид агентов на это подписан и перечитывает
    // цифры. Само создание вида на это не годится — пока страница не сброшена
    // на главную, повторное открытие переиспользует уже созданный.
    property int agentsEpoch: 0
    function openAgents() {
        root.agentsEpoch++;
        togglePage("agents");
    }

    // ----------------------------------------------------- стоп-кадр экрана
    // Путь к снимку всего экрана, который scripts/shot.sh показывает поверх
    // всего, пока идёт выделение области. Пусто — слоя нет.
    property string freezeShot: ""

    // Логические границы всей раскладки экранов (минимальный прямоугольник,
    // накрывающий все мониторы). По ним слой стоп-кадра растягивает снимок,
    // снятый в физическом разрешении, — чтобы на экране с масштабом он лёг
    // один в один, а не куском в углу.
    readonly property rect freezeBounds: {
        var xs = Quickshell.screens;
        if (!xs || xs.length === 0) return Qt.rect(0, 0, 0, 0);
        var minx = Infinity, miny = Infinity, maxx = -Infinity, maxy = -Infinity;
        for (var i = 0; i < xs.length; i++) {
            var s = xs[i];
            minx = Math.min(minx, s.x);
            miny = Math.min(miny, s.y);
            maxx = Math.max(maxx, s.x + s.width);
            maxy = Math.max(maxy, s.y + s.height);
        }
        return Qt.rect(minx, miny, maxx - minx, maxy - miny);
    }

    // Скриншот кладётся в буфер обмена, и по экрану этого не видно: рамка
    // выделения пропала — и всё. Уведомление здесь, а не в скрипте, потому
    // что текст переводится вместе с остальной оболочкой.
    Process { id: pShotSay }
    function shotCopied(path: string): void {
        // Значком берём сам снимок: уведомление показывает, что именно сняли,
        // и промах по рамке видно, не открывая файл.
        var name = String(path).split("/").pop();
        pShotSay.command = ["notify-send", "-a", "Panacea", "-i", String(path),
                            "-h", "int:transient:1",
                            root.tr("Скриншот"),
                            root.tr("В буфере обмена") + " · " + name];
        pShotSay.running = false;
        pShotSay.running = true;
        root.playSound("screenshot");
    }

    // Настройки — единственная страница, которая отрывается от верхней кромки
    // и встаёт по центру экрана: содержимого много, у верха оно было тесным.
    // Страницы, которые отрываются от верхней кромки и встают по центру:
    // содержимого много, у верха оно тесное.
    // Темы отсюда убраны: список стал узким и живёт прямо под пилюлей,
    // как сети и устройства. Отдельное окно посреди экрана для выбора обоев
    // было слишком тяжёлым жестом.
    readonly property bool settingsMode:
        expanded && (page === "settings"
                     || page === "files" || page === "media")

    // Вкладка «Клавиши» раскладывается в две колонки, поэтому окно шире:
    // вертикальный список не влезал и уезжал за нижнюю кромку экрана.
    property bool wideSettings: false
    readonly property int settingsW: {
        var want = page === "files" ? Math.round((screen ? screen.width : 1920) * 0.78)
                 : page === "media" ? Math.round((screen ? screen.width : 1920) * 0.72)
                 : (wideSettings ? 1300 : 1040);
        var lim = (screen ? screen.width : 1920) - 80;
        return Math.min(want, lim);
    }

    // ------------------------------------------------------------ смена темы
    // hyprpaper меняет обои мгновенно и без перехода. Поэтому снимок старых
    // обоев остаётся висеть поверх экрана и плавно тает — снизу к этому
    // моменту уже новые, и получается честный кроссфейд без смены бэкенда.
    property string themeFadeWall: ""
    property bool   themeFading: false

    FileView {
        id: curWallFile
        path: Quickshell.env("HOME") + "/.config/hypr/wallpaper.conf"
        blockLoading: true
    }

    function startThemeFade() {
        var m = /^\$wallpaper\s*=\s*(.+)$/m.exec(curWallFile.text() || "");
        if (!m) return;
        root.themeFadeWall = "file://" + String(m[1]).trim();
        root.themeFading = true;
    }
    function endThemeFade() { root.themeFading = false; }

    // ------------------------------------------------------------------ медиа
    // «Липкий» текущий плеер: пока выбранный плеер ещё существует, держимся
    // за него, даже когда на паузе он перестаёт быть «играющим». Иначе на
    // паузе выбор перескакивал на другой MPRIS-источник (например, вкладку
    // браузера без обложки) — и обложка/название мигали.
    // Прежний выбор держим в обычном объекте, а не в свойстве: привязка
    // player читает его и тут же сама в него пишет. Со свойством это был
    // цикл привязки — Qt ругался в лог и пересчитывал выбор на каждом кадре
    // проигрывания. Поле внутри объекта зависимости не создаёт.
    readonly property var stickyBox: ({ p: null })
    readonly property var player: {
        var list = Mpris.players ? Mpris.players.values : [];
        var playing = null, any = null, stickyAlive = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p) continue;
            if (!any) any = p;
            if (p === root.stickyBox.p) stickyAlive = p;
            if (p.isPlaying && !playing) playing = p;
        }
        // играющий побеждает; иначе прежний, если он ещё жив; иначе любой
        return playing || stickyAlive || any;
    }
    onPlayerChanged: { if (player) root.stickyBox.p = player; refreshMediaArt(); }
    readonly property bool mediaActive:
        cfg.featPlayer
        && player !== null && player !== undefined
        && String(player.trackTitle).trim().length > 0

    // Обложка мигала: на паузе/возобновлении MPRIS на миг отдаёт пустой
    // trackArtUrl, и картинка в капсуле пропадала. Запоминаем последнюю
    // непустую обложку текущего трека и показываем её, пока трек не сменился.
    property string mediaArt: ""
    property string mediaArtTrack: ""
    function refreshMediaArt() {
        if (!player) { return; }
        var title = String(player.trackTitle || "");
        var art = String(player.trackArtUrl || "");
        // Пустое название на миг проскакивает при паузе — такие «полукадры»
        // игнорируем, чтобы не сбросить обложку в ноту.
        if (title.length === 0) return;
        if (title !== root.mediaArtTrack) {
            root.mediaArtTrack = title;
            root.mediaArt = art;           // новый трек — берём что есть
        } else if (art.length > 0) {
            root.mediaArt = art;           // тот же трек — обновляем лишь непустым
        }
    }
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackArtUrlChanged() { root.refreshMediaArt(); }
        function onTrackTitleChanged()  { root.refreshMediaArt(); }
        function onPostTrackChanged()   { root.refreshMediaArt(); }
        // На паузе/возобновлении плеер иногда переотдаёт метаданные — заодно
        // перечитываем обложку, чтобы она не пропадала после resume.
        function onIsPlayingChanged()   { root.refreshMediaArt(); }
    }

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

    // Только уровень, без подмены на молнию: в Quick settings молния стоит
    // отдельным значком рядом, а сама батарея должна показывать заряд.
    readonly property string batteryLevelIcon:
        String.fromCodePoint(battIcons[Math.max(0, Math.min(10, Math.round(batteryPct / 10)))])

    // Есть ли вообще батарея — на десктопе блок заряда прятать целиком.
    //
    // По списку устройств, а не по сводному displayDevice: на настольной
    // машине оно тоже «готово», просто отдаёт ноль, и остров честно рисовал
    // «0%» там, где батареи нет вовсе.
    //
    // Ищем именно системную батарею (isLaptopBattery). Тип Battery носят и
    // мышь с клавиатурой — их заряд не имеет отношения к питанию машины, и
    // показывать его в острове как заряд компьютера было бы неверно.
    readonly property bool batteryPresent: {
        var list = UPower.devices ? UPower.devices.values : [];
        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            if (d && d.ready && d.isLaptopBattery) return true;
        }
        return false;
    }

    // ------------------------------------------------------------- машина
    // Ноутбук или ПК — вопрос железа, а не настройки, поэтому спрашивать не о
    // чем: батарея, тачпад и способ управления яркостью просто есть или их
    // нет. Разбирается brightness.sh, тут только результат.
    //
    // Батарею берём у UPower (он и так подключён и сам следит за появлением
    // устройств), остальное — разовым опросом на старте: тачпад и монитор в
    // работающей системе не появляются.
    property string brightBackend: "none"   // backlight | ddc | none
    property bool   hasTouchpad: false
    property bool   ddcutilPresent: false
    readonly property bool isLaptop: root.batteryPresent
    // На ПК прячем то, что относится только к ноутбуку: заряд, профили
    // питания и настройки тачпада. Пустые разделы честнее убрать, чем
    // показывать вечные нули.
    readonly property bool showBattery: root.batteryPresent
    readonly property bool showPowerProfiles: root.batteryPresent && root.cfg.featPowerProfiles

    Process {
        id: pMachine
        running: true
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/brightness.sh detect"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.slice(text.lastIndexOf("backend="));
                t.trim().split("\n").forEach(function (line) {
                    var p = line.split("=");
                    if (p.length !== 2) return;
                    if (p[0] === "backend")  root.brightBackend  = p[1].trim();
                    if (p[0] === "touchpad") root.hasTouchpad    = p[1].trim() === "1";
                    if (p[0] === "ddcutil")  root.ddcutilPresent = p[1].trim() === "1";
                });
                // Список экранов нужен самой панели, а не только вкладке
                // Display: дорожка яркости стоит в быстрых настройках и
                // должна быть там с первого раскрытия, а не после того, как
                // человек однажды заглянул в настройки экрана.
                root.brightRefresh(false);
            }
        }
    }

    // ---------------------------------------------------------- погода
    // Числа держим строками ровно так, как их отдал сервис: округлять и
    // подписывать — дело виджета, а здесь важно отличать «ноль градусов» от
    // «ещё не спрашивали». Пустая строка и значит «нет данных».
    property string weatherTemp: ""
    property string weatherFeels: ""
    property string weatherHumidity: ""
    property string weatherPressure: ""
    property string weatherWind: ""
    property string weatherClouds: ""
    property string weatherCond: ""      // Clouds, Rain, Clear …
    property string weatherDesc: ""      // словами, на языке оболочки
    property string weatherIcon: ""      // код вида 04d — по нему берётся значок
    property string weatherPlace: ""     // как город назвал сам сервис
    property string weatherErr: ""       // пусто — всё в порядке
    property bool   weatherBusy: false

    readonly property bool weatherReady:
        root.weatherErr.length === 0 && root.weatherTemp.length > 0
    // Градус в обеих системах пишется одинаково; различаются они шкалой, а
    // не знаком, поэтому буква нужна только там, где её спрашивают явно.
    readonly property string weatherUnitLetter:
        root.cfg.weatherUnits === "imperial" ? "F" : "C"
    // Единица скорости ветра — она же подпись под числом в кружке, поэтому
    // переводится здесь, а не остаётся латиницей на русском интерфейсе.
    readonly property string weatherWindUnit:
        root.cfg.weatherUnits === "imperial" ? (root.isEn ? "mph" : "миль/ч")
                                             : (root.isEn ? "m/s" : "м/с")

    // Значок погоды знаком шрифта — для тем, где точечных значков нет.
    // Разбор кода тот же, что в DotIcon: первые две цифры — сама погода.
    readonly property string weatherGlyph: {
        var k = String(root.weatherIcon).slice(0, 2);
        return String.fromCodePoint(
              k === "01" ? 0xF0599                        // солнце
            : k === "02" ? 0xF0595                        // солнце за облаком
            : (k === "03" || k === "04") ? 0xF0590         // облако
            : (k === "09" || k === "10") ? 0xF0597         // дождь
            : k === "11" ? 0xF0593                        // гроза
            : k === "13" ? 0xF0598                        // снег
            : k === "50" ? 0xF0591                        // туман
                         : 0xF0590);
    }

    Process {
        id: pWeather
        stdout: StdioCollector {
            onStreamFinished: {
                root.weatherBusy = false;
                // Сборщик копит вывод всех запусков подряд: берём последнюю
                // порцию, а не начало текста.
                var txt = String(text);
                var cut = txt.lastIndexOf("temp=");
                var errCut = txt.lastIndexOf("err=");
                if (errCut > cut) cut = errCut;
                if (cut > 0) txt = txt.slice(cut);

                var got = {};
                txt.trim().split("\n").forEach(function (line) {
                    var i = line.indexOf("=");
                    if (i > 0) got[line.slice(0, i)] = line.slice(i + 1).trim();
                });

                root.weatherErr = got["err"] || "";
                if (root.weatherErr.length) return;

                root.weatherTemp     = got["temp"]     || "";
                root.weatherFeels    = got["feels"]    || "";
                root.weatherHumidity = got["humidity"] || "";
                root.weatherPressure = got["pressure"] || "";
                root.weatherWind     = got["wind"]     || "";
                root.weatherClouds   = got["clouds"]   || "";
                root.weatherCond     = got["cond"]     || "";
                root.weatherDesc     = got["desc"]     || "";
                root.weatherIcon     = got["icon"]     || "";
                root.weatherPlace    = got["city"]     || "";
            }
        }
    }

    function refreshWeather() {
        if (!root.cfg.weatherCity.length) {
            root.weatherErr = "no-city";
            return;
        }
        root.weatherBusy = true;
        pWeather.command = ["sh", "-c",
            root.scriptDir + "/weather.sh \"$1\" \"$2\" \"$3\" \"$4\"", "_",
            String(root.cfg.weatherKey), String(root.cfg.weatherCity),
            String(root.cfg.weatherUnits), root.isEn ? "en" : "ru"];
        pWeather.running = false;
        pWeather.running = true;
    }

    // Раз в четверть часа. Чаще незачем: погода столько и не меняется, а у
    // бесплатного ключа есть предел обращений в минуту, который делят между
    // собой все программы, куда его вписали.
    Timer {
        interval: 900000
        running: (root.cfg.featWidgets || root.cfg.weatherOnIsland)
                 && (root.cfg.weatherCity.length > 0 || root.cfg.weatherKey.length > 0)
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshWeather()
    }

    // ------------------------------------------------ детальный прогноз
    property bool weatherDetailsOpen: false
    property var  weatherForecastData: null

    Process {
        id: pWeatherForecast
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    if (parsed && !parsed.err) {
                        root.weatherForecastData = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    function openWeatherDetails() {
        root.weatherDetailsOpen = true;
        root.refreshWeatherForecast();
    }

    function refreshWeatherForecast() {
        if (!root.cfg.weatherCity.length) return;
        pWeatherForecast.command = ["sh", "-c",
            root.scriptDir + "/weather_forecast.sh \"$1\" \"$2\" \"$3\" \"$4\"", "_",
            String(root.cfg.weatherKey), String(root.cfg.weatherCity),
            String(root.cfg.weatherUnits), root.isEn ? "en" : "ru"];
        pWeatherForecast.running = false;
        pWeatherForecast.running = true;
    }

    // --------------------------------------------------------- нагрузка
    // Сводка для быстрых настроек на теме Nothing. Минус означает «измерить
    // не вышло»: строка тогда прячется, а не показывает ноль. Ноль здесь врёт
    // слишком убедительно — «видеокарта простаивает» и «датчика нет» на глаз
    // неразличимы.
    property int loadCpu:  -1
    property int loadMem:  -1
    property int loadGpu:  -1
    property int loadTempCpu: -1
    property int loadTempGpu: -1

    // Опрашиваем только пока панель раскрыта и только на той теме, где эта
    // сводка есть. Постоянный процесс раз в две секунды ради чисел, которых
    // никто не видит, — плата ни за что: скрипт будит nvidia-smi, а тот
    // просыпается заметно дольше, чем читается файл.
    readonly property bool loadWanted: root.expanded

    Process {
        id: pLoad
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/sysload.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Сборщик копит вывод всех запусков подряд, поэтому берём
                // последнюю законченную строку, а не начало текста.
                var recs = String(text).trim().split("\n").filter(r => r.indexOf("|") >= 0);
                if (!recs.length) return;
                var a = recs[recs.length - 1].split("|");
                function num(s) {
                    s = String(s || "").trim();
                    return s.length ? (+s) : -1;
                }
                root.loadCpu = num(a[0]);
                root.loadMem = num(a[1]);
                root.loadGpu = num(a[2]);
                root.loadTempCpu = num(a[3]);
                root.loadTempGpu = num(a[4]);
            }
        }
    }

    Timer {
        interval: 2000
        running: root.loadWanted
        repeat: true
        triggeredOnStart: true
        // Перезапуск через сброс: присваивание running = true, пока процесс
        // ещё не отметился завершённым, ничего не делает, и показания
        // замирали бы на первом снимке.
        onTriggered: { pLoad.running = false; pLoad.running = true; }
    }

    // ------------------------------------------------------------- яркость
    // [{ id, name, pct }] — экраны, у которых яркость вообще управляется.
    // Пустой список на ПК означает «монитор не отвечает по DDC/CI», и вкладка
    // Display говорит об этом словами вместо мёртвого ползунка.
    property var brightList: []
    property bool brightBusy: false

    Process {
        id: pBrightList
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/brightness.sh list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                text.trim().split("\n").forEach(function (line) {
                    var p = line.split("\t");
                    if (p.length < 3) return;
                    var pct = parseInt(p[2]);
                    if (isNaN(pct)) return;
                    out.push({ id: p[0], name: p[1], pct: pct });
                });
                root.brightList = out;
                root.brightBusy = false;
            }
        }
    }

    function brightRefresh(rescan) {
        if (root.brightBackend === "none") return;
        root.brightBusy = true;
        pBrightList.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/panacea/scripts/brightness.sh "
            + (rescan ? "rescan" : "list")];
        pBrightList.running = false;
        pBrightList.running = true;
    }

    // Запись по DDC идёт по I2C и занимает десятки миллисекунд, а ползунок
    // шлёт значения на каждое движение мыши. Без сдерживания шина забивается
    // очередью, монитор отстаёт от ручки и догоняет её через секунду после
    // отпускания. Копим последнее значение и отправляем не чаще, чем шина
    // успевает переварить.
    Process { id: pBrightSet }
    property string brightPendingId: ""
    property int    brightPendingPct: -1

    Timer {
        id: brightFlush
        // Ждём паузы в движении, а не шлём каждые N мс. Одна запись по DDC
        // занимает десятки миллисекунд, монитор на неё моргает подсветкой, и
        // очередь из промежуточных значений превращала протяжку ползунка в
        // мигание с отставанием. Уходит только то, на чём ручка остановилась.
        interval: 180
        repeat: false
        onTriggered: {
            if (root.brightPendingPct < 0) return;
            pBrightSet.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/panacea/scripts/brightness.sh set "
                + root.brightPendingId + " " + root.brightPendingPct];
            pBrightSet.running = false;
            pBrightSet.running = true;
            root.brightPendingPct = -1;
        }
    }

    function brightSet(id, pct) {
        pct = Math.max(1, Math.min(100, Math.round(pct)));
        // Показываем сразу, не дожидаясь монитора: ползунок под рукой обязан
        // ходить без задержки, даже когда шина отвечает медленно.
        var l = root.brightList.slice();
        for (var i = 0; i < l.length; i++)
            if (l[i].id === id) l[i] = { id: id, name: l[i].name, pct: pct };
        root.brightList = l;

        root.brightPendingId = id;
        root.brightPendingPct = pct;
        brightFlush.restart();
    }

    // Подробности для страницы «Батарея»: ёмкость, износ и текущий расход.
    // Прогнозов «сколько осталось» здесь намеренно нет — UPower пересчитывает
    // их рывками, и цифра прыгала на глазах.
    readonly property real batteryHealth:
        battDev && battDev.ready ? Math.round(battDev.healthPercentage) : 0
    readonly property real batteryCapacity:
        battDev && battDev.ready ? battDev.energyCapacity : 0
    // Вт: положительная — заряд, отрицательная — разряд
    readonly property real batteryRate:
        battDev && battDev.ready ? battDev.changeRate : 0

    readonly property string batteryIcon: {
        // Заряжается — молния. От сети без зарядки — обычная батарея,
        // отличается только цветом (зелёный), без иконки розетки.
        if (batteryCharging) return String.fromCodePoint(0xF0241);
        var step = Math.max(0, Math.min(10, Math.round(batteryPct / 10)));
        return String.fromCodePoint(battIcons[step]);
    }

    // ---------------------------------------------------------------- polkit
    // Запрос пароля при установке пакетов и прочих привилегированных
    // действиях рисуется в пилюле, а не отдельным окном агента.
    property var authFlow: null
    readonly property bool authActive: authFlow !== null && !authFlow.isCompleted

    // Агент polkit — тоже в Loader: выключен установщиком, значит остров не
    // регистрируется агентом и место остаётся за уже установленным
    // (hyprpolkitagent и т.п.); polkit допускает только одного на сессию.
    Loader {
        active: root.cfg.featPolkit
        sourceComponent: PolkitAgent {
            onAuthenticationRequestStarted: {
                root.authFlow = flow;
                pageResetTimer.stop();
                root.page = "auth";
                root.expanded = true;
                root.holdOpen = true;
            }
        }
    }

    Connections {
        target: root.authFlow
        ignoreUnknownSignals: true
        function onIsCompletedChanged() {
            if (root.authFlow && root.authFlow.isCompleted) {
                root.authFlow = null;
                root.collapse();
            }
        }
    }

    // ---------------------------------------------------------------- не спать
    // Пока тумблер включён, systemd-inhibit держит блокировку: система не
    // уснёт и не погасит экран. Quickshell сам убивает процесс при выключении.
    property bool keepAwake: false
    Process {
        running: root.keepAwake
        command: ["systemd-inhibit", "--what=idle:sleep:handle-lid-switch",
                  "--who=Panacea", "--why=Keep awake", "sleep", "infinity"]
    }

    // ------------------------------------------------------- звук: устройства и приложения
    // Список выходов и переключение между ними.
    readonly property var audioSinks: {
        var out = [];
        var all = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && n.isSink && !n.isStream) out.push(n);
        }
        return out;
    }
    // Список активных аудиопотоков приложений (раздельный микшер)
    readonly property var audioStreams: {
        var out = [];
        var all = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && n.isStream && n.audio) {
                var props = n.properties || {};
                var name = String(props["application.name"] || props["media.name"] || n.name || "").toLowerCase();
                if (name.indexOf("cava") < 0 && name.indexOf("quickshell") < 0) {
                    out.push(n);
                }
            }
        }
        return out;
    }
    readonly property string sinkName: {
        var n = Pipewire.defaultAudioSink;
        if (!n) return "";
        return String(n.nickname || n.description || n.name || "");
    }
    function setSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    // Прогрев кеша миниатюр обоев при старте, чтобы страница тем
    // открывалась мгновенно уже с первого раза.
    Process {
        running: true
        command: ["sh", "-c", Quickshell.env("HOME")
                  + "/.config/panacea/scripts/thumbs.sh all"]
    }

    // ------------------------------------------------------------ системный трей
    readonly property var trayItems: SystemTray.items

    // ---------------------------------------------------------- уведомления
    // Пилюля сама работает демоном уведомлений: в системе его не было вовсе,
    // и всё, что присылали программы, молча пропадало.
    // «Не беспокоить» — состояние, а не настройка: его переключает кнопка в
    // быстрых настройках, но живёт оно в файле, чтобы переживать перезапуск и
    // совпадать с тем, что показывает окно настроек.
    property bool dnd: cfg.notifDnd
    function toggleDnd() { cfg.notifDnd = !cfg.notifDnd; root.saveCfg(); }
    property var  notifCurrent: null         // то, что показывается сейчас
    ListModel { id: notifModel }             // история
    readonly property var notifications: notifModel
    // Демон уведомлений живёт в Loader: если функция выключена установщиком,
    // сервер не создаётся и остров не регистрируется как daemon — тогда
    // работает уже установленный mako/dunst без спора за шину.
    readonly property bool hasNotifications: cfg.featNotifications
    property var notifServer: notifLoader.item
    Loader {
        id: notifLoader
        active: root.cfg.featNotifications
        sourceComponent: notifServerComp
    }
    // живые уведомления, которые ещё не закрыты программой или пользователем
    readonly property var activeNotifications:
        notifServer ? notifServer.trackedNotifications : null

    // Живые объекты уведомлений по id. Нужны, чтобы нажатие открывало сам
    // повод: у мессенджеров есть действие «default», и именно оно
    // разворачивает нужный чат — угадать его снаружи невозможно.
    property var notifObjs: ({})

    Process { id: pFocusApp }
    // Переводим фокус на приложение: Hyprland сам перелистнёт на его стол,
    // а если окна нет — скрипт запустит приложение.
    function focusApp(hint) {
        var h = String(hint || "").trim();
        if (h.length === 0) return;
        pFocusApp.running = false;
        pFocusApp.command = ["sh", "-c",
            root.scriptDir + "/focusapp.sh \"$1\"", "_", h];
        pFocusApp.running = true;
    }

    // Раскрытие по наведению после клика по уведомлению только мешает: курсор
    // остаётся над пилюлей, и она тут же разворачивается в «Быстрые
    // настройки» — а там сверху часы с подписью «Календарь» и своей областью
    // нажатия, поэтому следующий же щелчок уводил в календарь.
    //
    // Поэтому взводим наведение заново только когда курсор уйдёт с пилюли:
    // по времени было ненадёжно, курсор ведь остаётся на месте.
    property bool hoverExpandArmed: true

    // Нажали на уведомление: сначала просим приложение показать повод
    // (действие «default»), потом уходим к его окну и убираем карточку.
    //
    // Принимает либо сам объект уведомления (карточка знает его напрямую),
    // либо id из истории. По id раньше промахивались: ключи в notifObjs
    // приводились к числу неодинаково, и действие «default» не вызывалось —
    // приложение не открывалось вовсе.
    function activateNotification(what) {
        var n = null;
        var id = -1;
        if (what !== null && typeof what === "object") {
            n = what;
            id = Number(what.id);
        } else {
            id = Number(what);
            n = root.notifObjs[String(id)] || null;
        }
        var hint = "";
        if (n) {
            hint = String(n.desktopEntry || "") || String(n.appName || "");
            var acts = n.actions || [];
            var used = false;
            for (var i = 0; i < acts.length; i++) {
                if (String(acts[i].identifier) === "default") {
                    acts[i].invoke(); used = true; break;
                }
            }
            // одно действие без имени — тоже почти всегда «открыть»
            if (!used && acts.length === 1) acts[0].invoke();
        }
        // Своё уведомление об обновлении ведёт не в приложение, а в настройки:
        // кнопка «Обновить» живёт там, и искать её после нажатия странно.
        if (id >= 0 && id === root.updNotifId) {
            root.updNotifId = -1;
            root.dismissToast();
            root.dropNotification(id);
            root.openSettingsAt("system");
            return;
        }

        root.focusApp(hint);
        root.dismissToast();
        if (id >= 0) root.dropNotification(id);
        // не раскрываемся под курсором после клика — до тех пор, пока курсор
        // не уйдёт с пилюли
        root.hoverExpandArmed = false;
        capsuleHover.markArmPoint();
        root.collapse();
    }

    readonly property bool toastActive: notifCurrent !== null && !expanded
    readonly property string notifSummary: notifCurrent ? String(notifCurrent.summary || "") : ""
    readonly property string notifBody:    notifCurrent ? String(notifCurrent.body || "") : ""
    readonly property string notifApp:     notifCurrent ? String(notifCurrent.appName || "") : ""
    readonly property string notifImage:   notifCurrent ? root.notifIconFor(notifCurrent) : ""

    // notify-send -i отдаёт ИМЯ значка из темы оформления, а не путь к файлу.
    // Image такое имя открыть не может и рисует на его месте «битую картинку»
    // в клеточку. Имена разворачиваем через тему; не нашлось — отдаём пусто,
    // и карточка нарисует свой значок колокольчика.
    function notifIconFor(n) {
        var img = String(n.image || "");
        if (img.length === 0) img = String(n.appIcon || "");
        if (img.length === 0) return "";
        // Значок из темы оформления Quickshell отдаёт как image://icon/ИМЯ,
        // и если темы в системе нет, провайдер молча возвращает клетчатую
        // заглушку со статусом Ready — поймать её по статусу нельзя. Поэтому
        // разворачиваем имя сами: iconPath со вторым true отдаёт пустую
        // строку, когда значка нет, и карточка рисует свой колокольчик.
        if (img.indexOf("image://icon/") === 0)
            return Quickshell.iconPath(img.substring(13).split("?")[0], true);
        // путь, file://, data: — отдаём как есть
        if (img.indexOf("/") >= 0 || img.indexOf(":") >= 0) return img;
        return Quickshell.iconPath(img, true);
    }
    readonly property bool   notifUrgent:
        notifCurrent ? notifCurrent.urgency === NotificationUrgency.Critical : false

    Component {
    id: notifServerComp
    NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;

            var app = String(n.appName || "");
            var sum = String(n.summary || "");
            var isTransient = (app === "Panacea"
                               || sum === root.tr("Скриншот")
                               || sum === "Скриншот"
                               || sum === "Screenshot"
                               || sum.indexOf("Скриншот") >= 0
                               || sum.indexOf("Screenshot") >= 0);
            if (n.hints && (n.hints["transient"] === true || n.hints["transient"] === 1 || n.hints["transient"] === "1")) {
                isTransient = true;
            }

            if (!isTransient) {
                notifModel.insert(0, {
                    nId: Number(n.id),
                    nSummary: String(n.summary || ""),
                    nBody: String(n.body || ""),
                    nApp: String(n.appName || ""),
                    nImage: root.notifIconFor(n),
                    nUrgent: n.urgency === NotificationUrgency.Critical,
                    nTime: Qt.formatDateTime(new Date(), "HH:mm")
                });
                while (notifModel.count > 50) notifModel.remove(notifModel.count - 1);
            }

            // Программа сама закрывает уведомление, когда оно потеряло смысл:
            // Telegram делает это, как только сообщение прочитано в самом
            // мессенджере. Раньше такая карточка всё равно висела в истории —
            // теперь она уходит вместе с поводом.
            var nid = Number(n.id);
            var objs = root.notifObjs;
            objs[String(nid)] = n;
            root.notifObjs = objs;
            n.closed.connect(function (reason) {
                var o = root.notifObjs;
                delete o[String(nid)];
                root.notifObjs = o;
                if (reason !== NotificationCloseReason.CloseRequested) return;
                root.dropNotification(nid);
            });

            // Критичные показываем даже в режиме «не беспокоить»
            if (root.dnd && n.urgency !== NotificationUrgency.Critical) return;

            root.enqueueToast(n);
        }
    }
    }

    // Очередь карточек. Раньше уведомление, пришедшее пока панель раскрыта
    // или пока показывается предыдущая карточка, просто уходило в историю —
    // и человек о нём не узнавал. Теперь оно дожидается своей очереди.
    property var toastQueue: []

    function enqueueToast(n) {
        var q = root.toastQueue.slice();
        q.push({ notif: n, at: Date.now() });
        root.toastQueue = q;
        root.pumpToasts();
    }

    function pumpToasts() {
        // занято текущей карточкой или панель раскрыта — подождём
        if (root.notifCurrent !== null || root.expanded) return;
        if (root.toastQueue.length === 0) return;

        var q = root.toastQueue.slice();
        var item = q.shift();
        root.toastQueue = q;

        // протухшие (больше минуты в очереди) не показываем: они уже в истории
        if (Date.now() - item.at > 60000) { root.pumpToasts(); return; }

        var n = item.notif;
        root.notifCurrent = n;
        // Своё время приложения уважаем, но верхнюю и нижнюю границу задаёт
        // человек: важные с нулевым сроком висят до ответа.
        var crit = n.urgency === NotificationUrgency.Critical;
        var want = crit ? root.cfg.notifCritTimeout : root.cfg.notifTimeout;
        var ms = n.expireTimeout > 0 ? (n.expireTimeout < 100 ? n.expireTimeout * 1000 : n.expireTimeout) : want;
        if (!crit && want > 0 && ms > want) ms = want;
        if (crit && want === 0) ms = 0;
        toastTimer.interval = ms > 0 ? Math.max(1000, ms) : 24 * 60 * 60 * 1000;
        toastTimer.restart();
    }

    Timer { id: toastPump; interval: 260; onTriggered: root.pumpToasts() }

    Timer {
        id: toastTimer
        // если курсор на карточке — не убираем, ждём решения пользователя
        onTriggered: {
            if (capsuleHover.hovered) { toastTimer.interval = 1200; restart(); return; }
            root.dismissToast();
        }
    }
    // Крестик в истории: убираем строку и заодно говорим программе, что
    // уведомление закрыто, — иначе оно так и висит у неё «непрочитанным».
    function forgetNotification(index) {
        var e = notifModel.get(index);
        var nid = e ? Number(e.nId) : -1;
        notifModel.remove(index);
        if (nid < 0 || !notifServer) return;
        var live = notifServer.trackedNotifications.values;
        for (var i = 0; i < live.length; i++) {
            if (live[i] && Number(live[i].id) === nid) { live[i].dismiss(); break; }
        }
        if (root.notifCurrent && Number(root.notifCurrent.id) === nid) root.dismissToast();
    }

    // Убрать уведомление из истории (и с экрана, если оно сейчас показывается)
    function dropNotification(nid) {
        for (var i = 0; i < notifModel.count; i++) {
            if (Number(notifModel.get(i).nId) === nid) { notifModel.remove(i); break; }
        }
        // и из очереди карточек, до которой оно могло не дойти
        var q = root.toastQueue.filter(function (it) {
            return !it.notif || Number(it.notif.id) !== nid;
        });
        if (q.length !== root.toastQueue.length) root.toastQueue = q;

        if (root.notifCurrent && Number(root.notifCurrent.id) === nid) root.dismissToast();
    }

    function dismissToast() {
        toastTimer.stop();
        root.notifCurrent = null;
        toastPump.restart();
    }
    function clearNotifications() {
        notifModel.clear();
        // активные тоже закрываем — иначе «Очистить» убирает лишь половину
        if (!notifServer) return;
        var live = notifServer.trackedNotifications.values;
        for (var i = live.length - 1; i >= 0; i--) {
            if (live[i]) live[i].dismiss();
        }
    }

    // ------------------------------------------------------- менеджер паролей
    // Записи лежат в ~/.local/share/panacea/vault.enc, зашифрованные на пароле
    // пользователя. Пилюля держит расшифрованный список и сам пароль в памяти,
    // пока хранилище открыто, и забывает всё через 15 минут без обращений.
    property bool   vaultUnlocked: false
    property string vaultKey: ""            // пароль-ключ, только в памяти
    property var    vaultEntries: []        // [{id,label,login,pw,at}]
    property string vaultError: ""
    property bool   vaultBusy: false
    readonly property int vaultIdleMs: 15 * 60 * 1000

    // окно ввода пароля от хранилища держит его открытым, пока им пользуются
    Timer {
        id: vaultIdle
        interval: root.vaultIdleMs
        onTriggered: root.lockVault()
    }
    function touchVault() { if (root.vaultUnlocked) vaultIdle.restart(); }

    // Закрывается сразу, но ключ и записи держим до конца недописанного
    // сохранения: иначе правка, сделанная за секунду до блокировки, пропадала.
    property bool vaultLockPending: false
    function finishLockVault() {
        root.vaultLockPending = false;
        root.vaultKey = "";
        root.vaultEntries = [];
    }
    function lockVault() {
        vaultIdle.stop();
        root.vaultUnlocked = false;
        root.vaultError = "";
        if (root.vaultDirty || pVaultSave.running) {
            root.vaultLockPending = true;
            vaultSaveTimer.restart();
            return;
        }
        finishLockVault();
    }

    PamContext {
        id: vaultPam
        // тот же профиль, что у экрана блокировки: проверяет пароль
        // пользователя — тот, который спрашивает sudo
        config: "swaylock"
        onPamMessage: {
            if (responseRequired) respond(root.vaultKey);
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.vaultLoad();
            } else {
                root.vaultKey = "";
                root.vaultBusy = false;
                root.vaultError = root.tr("Неверный пароль");
            }
        }
    }

    // Открыть хранилище: сначала PAM подтверждает пароль, затем на нём же
    // расшифровывается файл.
    function unlockVault(password) {
        if (root.vaultBusy) return;
        root.vaultError = "";
        root.vaultKey = String(password || "");
        if (root.vaultKey.length === 0) return;
        root.vaultBusy = true;
        if (!vaultPam.start()) {
            root.vaultBusy = false;
            root.vaultKey = "";
            root.vaultError = root.tr("Не удалось проверить пароль");
        }
    }

    Process {
        id: pVaultLoad
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                if (t.length === 0) return;
                try { root.vaultEntries = JSON.parse(t); } catch (e) { root.vaultEntries = []; }
            }
        }
        onExited: code => {
            root.vaultBusy = false;
            if (code === 0) {
                root.vaultUnlocked = true;
                vaultIdle.restart();
                root.vaultError = "";
            } else {
                root.vaultKey = "";
                root.vaultError = code === 2 ? root.tr("Хранилище не открылось")
                                             : root.tr("Ошибка хранилища");
            }
        }
    }
    function vaultLoad() {
        pVaultLoad.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/panacea/scripts/vault.sh load"];
        pVaultLoad.running = true;
        pVaultLoad.write(root.vaultKey + "\n");
        pVaultLoad.stdinEnabled = false;
    }

    Process {
        id: pVaultSave
        stdinEnabled: true
        onExited: code => {
            if (code !== 0) root.vaultError = root.tr("Не удалось сохранить");
            // за время записи список мог измениться ещё раз — пишем снова
            if (root.vaultDirty) vaultSaveTimer.restart();
            else if (root.vaultLockPending) root.finishLockVault();
        }
    }

    // Запись идёт через один процесс, поэтому подряд идущие правки нельзя
    // отправлять «в лоб». Раньше «Добавить все» вызывал vaultSave() на каждую
    // запись: первый вызов запускал openssl, остальные видели running === true,
    // ничего не запускали, а их write() уходил в уже закрытый stdin. На диск
    // попадала одна первая запись — отсюда «пароли не сохраняются».
    // Теперь правки копятся и уходят одним файлом.
    property bool vaultDirty: false
    Timer {
        id: vaultSaveTimer
        interval: 120
        onTriggered: root.vaultFlush()
    }
    function vaultSave() {
        if (!root.vaultUnlocked) return;
        touchVault();
        root.vaultDirty = true;
        vaultSaveTimer.restart();
    }
    function vaultFlush() {
        // Не по vaultUnlocked: закрытие хранилища ждёт именно этой записи,
        // а к тому моменту флаг уже снят.
        if (root.vaultKey.length === 0) return;
        // предыдущая запись ещё идёт — подождём и попробуем снова
        if (pVaultSave.running) { vaultSaveTimer.restart(); return; }
        root.vaultDirty = false;
        pVaultSave.stdinEnabled = true;
        pVaultSave.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/panacea/scripts/vault.sh save"];
        pVaultSave.running = true;
        pVaultSave.write(root.vaultKey + "\n" + JSON.stringify(root.vaultEntries));
        pVaultSave.stdinEnabled = false;
    }

    function vaultAdd(label, login, pw) {
        if (!root.vaultUnlocked) return;
        var a = root.vaultEntries.slice();
        a.unshift({
            id: String(Date.now()) + "-" + Math.floor(Math.random() * 1e6),
            label: String(label || root.tr("Без названия")),
            login: String(login || ""),
            pw: String(pw || ""),
            at: Qt.formatDateTime(new Date(), "dd.MM.yyyy HH:mm")
        });
        root.vaultEntries = a;
        vaultSave();
    }
    function vaultUpdate(id, label, login, pw) {
        var a = root.vaultEntries.slice();
        for (var i = 0; i < a.length; i++) {
            if (a[i].id !== id) continue;
            a[i] = { id: id, label: String(label), login: String(login),
                     pw: String(pw), at: a[i].at };
            break;
        }
        root.vaultEntries = a;
        vaultSave();
    }
    function vaultRemove(id) {
        root.vaultEntries = root.vaultEntries.filter(function (e) { return e.id !== id; });
        vaultSave();
    }
    function vaultHas(pw) {
        for (var i = 0; i < root.vaultEntries.length; i++)
            if (root.vaultEntries[i].pw === pw) return true;
        return false;
    }

    // --- импорт из браузеров
    // browser_pw.py читает профили установленных браузеров и печатает
    // найденное JSON-ом. Ничего сам не сохраняет: список показывается в
    // хранилище, а переносит записи уже человек — кнопкой.
    property var    browserFound: []      // [{url, login, pw, browser}]
    property bool   browserScanning: false
    property bool   browserScanned: false // был ли хоть один поиск в этом сеансе
    property string browserError: ""

    function browserScan() {
        if (!root.vaultUnlocked || root.browserScanning) return;
        root.browserError = "";
        root.browserFound = [];
        root.browserScanning = true;
        pBrowserScan.running = true;
    }

    Process {
        id: pBrowserScan
        command: ["python3", root.scriptDir + "/browser_pw.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                var a = [];
                try { a = JSON.parse(text); } catch (e) { a = []; }
                // Уже сохранённые не показываем: список должен состоять из
                // того, что действительно можно добавить.
                root.browserFound = a.filter(function (e) {
                    return String(e.pw || "").length > 0 && !root.vaultHas(String(e.pw));
                });
                root.browserScanning = false;
                root.browserScanned = true;
                root.touchVault();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length) root.browserError = text.trim()
        }
        onExited: (code, status) => {
            root.browserScanning = false;
            root.browserScanned = true;
            if (code !== 0 && root.browserError.length === 0)
                root.browserError = root.tr("Не удалось прочитать браузеры");
        }
    }

    // Перенос одной найденной записи в хранилище.
    function browserImport(item) {
        if (!root.vaultUnlocked || !item) return;
        root.vaultAdd(String(item.url || item.browser || root.tr("Из браузера")),
                      String(item.login || ""), String(item.pw || ""));
        root.browserFound = root.browserFound.filter(function (e) {
            return !(e.pw === item.pw && e.login === item.login && e.url === item.url);
        });
    }

    function browserImportAll() {
        if (!root.vaultUnlocked) return;
        var list = root.browserFound.slice();
        for (var i = 0; i < list.length; i++) {
            var e = list[i];
            if (root.vaultHas(String(e.pw))) continue;
            root.vaultAdd(String(e.url || e.browser || root.tr("Из браузера")),
                          String(e.login || ""), String(e.pw || ""));
        }
        root.browserFound = [];
    }

    // --- предложение сохранить пароль
    // Подсмотреть, что человек печатает в чужом окне, нельзя (и не нужно —
    // это был бы кейлоггер). Зато пароль почти всегда проходит через буфер
    // обмена: из менеджера, из письма, из генератора. Пилюля замечает такую
    // строку и спрашивает, сохранить ли её.
    property var vaultPrompt: null           // {pw, label}

    function looksLikePassword(s) {
        if (!root.cfg.featVault || !root.cfg.vaultCapture) return false;
        if (!s || s.length < 8 || s.length > 128) return false;
        if (/\s/.test(s)) return false;
        if (/^(https?|ftp|file|magnet):/i.test(s)) return false;
        if (s.indexOf("/") === 0 || s.indexOf("~/") === 0) return false;
        if (/^[0-9]+$/.test(s)) return false;          // номера, коды, счета
        if (/^[a-z]+$/.test(s)) return false;          // просто слово
        if (/@[^@]+\.[a-z]{2,}$/i.test(s)) return false; // почта
        var classes = 0;
        if (/[a-z]/.test(s)) classes++;
        if (/[A-Z]/.test(s)) classes++;
        if (/[0-9]/.test(s)) classes++;
        if (/[^A-Za-z0-9]/.test(s)) classes++;
        return classes >= 3;
    }

    Process {
        id: pClipWatch
        running: root.cfg.featVault
        // печатаем только первую строку: многострочный текст паролем не бывает
        command: ["sh", "-c",
            "wl-paste --type text --watch sh -c "
            + "'printf \"%s\\n\" \"$(wl-paste -n -t text 2>/dev/null | head -1)\"'"]
        stdout: SplitParser {
            onRead: line => {
                var s = String(line);
                if (!root.looksLikePassword(s)) return;
                if (root.vaultUnlocked && root.vaultHas(s)) return;
                if (root.vaultPrompt && root.vaultPrompt.pw === s) return;
                root.vaultPrompt = { pw: s, label: "" };
                pVaultWhere.running = true;
                root.togglePage("vaultsave");
            }
        }
    }
    // чьё окно сейчас активно — подставим как название записи
    Process {
        id: pVaultWhere
        command: ["sh", "-c",
            "hyprctl activewindow -j 2>/dev/null | jq -r '.initialClass // .class // \"\"'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var c = text.trim();
                if (c.length === 0 || !root.vaultPrompt) return;
                root.vaultPrompt = { pw: root.vaultPrompt.pw,
                                     label: c.charAt(0).toUpperCase() + c.slice(1) };
            }
        }
    }
    // Копируем пароль в буфер. wl-copy запускаем с --sensitive-data, чтобы
    // строка не осела в истории cliphist, и очищаем буфер через минуту.
    Process { id: pVaultCopy }
    function vaultCopy(pw) {
        touchVault();
        pVaultCopy.command = ["sh", "-c",
            "printf '%s' \"$1\" | wl-copy --sensitive-data 2>/dev/null "
            + "|| printf '%s' \"$1\" | wl-copy", "_", String(pw)];
        pVaultCopy.running = true;
        vaultClipClear.restart();
    }
    Process { id: pVaultClip; command: ["sh", "-c", "wl-copy --clear"] }
    Timer { id: vaultClipClear; interval: 60000; onTriggered: pVaultClip.running = true }

    function dismissVaultPrompt() {
        root.vaultPrompt = null;
        if (root.page === "vaultsave") root.collapse();
    }

    // ------------------------------------------------------------------ OSD
    // При изменении громкости или яркости пилюля на пару секунд превращается
    // в полоску уровня и возвращается обратно.
    property string osdKind: ""          // "vol" | "mic" | "bright"
    property real   osdValue: 0          // 0..1
    property bool   osdMuted: false
    readonly property bool osdActive: osdKind.length > 0 && !expanded

    Timer {
        id: osdTimer
        interval: 1700
        onTriggered: root.osdKind = ""
    }
    function showOsd(kind, value, muted) {
        if (!cfg.featOsd) return;
        osdKind = kind;
        osdValue = Math.max(0, Math.min(1, value));
        osdMuted = muted === true;
        osdTimer.restart();
    }

    readonly property string osdIcon: {
        if (osdKind === "bright") return String.fromCodePoint(0xF00DE);       // солнце
        if (osdKind === "mic")
            return String.fromCodePoint(osdMuted ? 0xF036D : 0xF036C);        // микрофон
        if (osdMuted || osdValue <= 0.001) return String.fromCodePoint(0xF075F);
        if (osdValue < 0.34) return String.fromCodePoint(0xF057F);
        if (osdValue < 0.67) return String.fromCodePoint(0xF0580);
        return String.fromCodePoint(0xF057E);
    }

    // --- громкость и микрофон берём из Pipewire: реагируем на любое изменение,
    //     не только на нажатие мультимедийной клавиши
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    readonly property var sinkAudio:
        Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property var srcAudio:
        Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null

    property bool osdReady: false        // не показывать OSD при старте оболочки
    Timer { interval: 1500; running: true; onTriggered: root.osdReady = true }

    // Смена устройства вывода (подключились Bluetooth-наушники, воткнули
    // джек) перепривязывает sinkAudio, и onVolumeChanged срабатывает начальной
    // громкостью нового устройства — на миг всплывал OSD с полосой громкости,
    // хотя никто её не трогал. Гасим OSD на короткое окно вокруг переключения.
    property bool sinkSwitching: false
    onSinkAudioChanged: { root.sinkSwitching = true; sinkSettleTimer.restart(); }
    Timer { id: sinkSettleTimer; interval: 700; onTriggered: root.sinkSwitching = false }

    Connections {
        target: root.sinkAudio
        enabled: root.sinkAudio !== null
        function onVolumeChanged() {
            if (root.osdReady && !root.sinkSwitching)
                root.showOsd("vol", root.sinkAudio.volume, root.sinkAudio.muted);
        }
        function onMutedChanged() {
            if (root.osdReady && !root.sinkSwitching)
                root.showOsd("vol", root.sinkAudio.volume, root.sinkAudio.muted);
        }
    }
    Connections {
        target: root.srcAudio
        enabled: root.srcAudio !== null
        function onMutedChanged() {
            if (root.osdReady) root.showOsd("mic", root.srcAudio.volume, root.srcAudio.muted);
        }
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
    // Режим питания меняется человеком и почти всегда через саму панель,
    // поэтому в закрытом виде его достаточно сверять раз в полминуты.
    Timer {
        interval: root.expanded ? 10000 : 30000
        running: true; repeat: true
        onTriggered: pPowerGet.running = true
    }

    // Человеческое имя текущего режима питания — для подписи плитки батареи
    readonly property string profileLabel:
        powerProfile === "power-saver" ? tr("Экономия")
      : powerProfile === "performance" ? tr("Максимум")
                                       : tr("Баланс")

    function setPowerProfile(name) {
        // отражаем сразу, потом подтверждаем реальным значением от демона
        root.powerProfile = name;
        pPowerSet.command = ["sh", "-c", root.powerScript + " set \"$1\"", "_", name];
        pPowerSet.running = true;
    }

    // ------------------------------------------------------- рабочий стол
    readonly property int wsId:
        Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    // Столы по порядку номеров — для точек в свёрнутом острове. Спецстолы
    // (отрицательные) пропускаем: на них не переходят подряд с остальными,
    // и точка под них сбивала бы счёт.
    readonly property var wsRaw: {
        var out = [];
        var all = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (var i = 0; i < all.length; i++)
            if (all[i] && all[i].id > 0) out.push(all[i].id);
        out.sort(function (a, b) { return a - b; });
        return out;
    }

    // Список столов держим отдельно и меняем, только когда он вправду стал
    // другим.
    //
    // Вычисление выше пересчитывается на каждое событие Hyprland — а их при
    // одном переключении приходит несколько, — и каждый раз отдаёт новый
    // массив. Repeater судит по самому объекту, а не по его содержимому, и
    // на новый массив уничтожает и создаёт заново все точки разом. Отсюда и
    // мигание при переходе на пустой стол: точка текущего успевала родиться
    // полосой и тут же исчезнуть вместе со всем рядом.
    property var wsList: []
    onWsRawChanged: {
        var a = root.wsRaw, b = root.wsList;
        if (a.length === b.length) {
            var same = true;
            for (var i = 0; i < a.length; i++)
                if (a[i] !== b[i]) { same = false; break; }
            if (same) return;
        }
        root.wsList = a;
    }

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
    property string dateLong: ""
    // Секунды отдельной строкой. В timeText они появляются только если их
    // попросили во вкладке Clock & Date, а раскрытому острову на теме Nothing
    // они нужны всегда: там это мелкое число сбоку от крупных часов, а не
    // часть их. Смешивать эти два случая в одной строке нельзя.
    property string secText: ""
    // Число месяца и выходной ли он — для карточки даты на рабочем столе.
    // Держим отдельно от dateLong: тот собирается по выбранному формату и
    // числа из него уже не выковырять.
    property string dayNum: ""
    property bool   weekend: false
    // Месяц своим списком, а не через Qt.formatDateTime: тот берёт язык из
    // системной локали, а подписи оболочки идут за её собственной настройкой
    // языка — иначе на английском интерфейсе месяц оставался бы русским.
    property string monthText: ""
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            // 12-часовой формат — с AM/PM, 24-часовой — без; секунды
            // добавляются в оба, если их попросили во вкладке Clock & Date
            var sec = root.cfg.clockSeconds ? ":ss" : "";
            root.timeText = root.cfg.clock12
                ? Qt.formatDateTime(d, "h:mm" + sec + " AP")
                : Qt.formatDateTime(d, "HH:mm" + sec);
            root.secText = Qt.formatDateTime(d, "ss");
            // формат даты и день недели перед ней — тоже из настроек
            root.dateLong = (root.cfg.clockWeekday ? Qt.formatDateTime(d, "dddd") + ", " : "")
                + Qt.formatDateTime(d, root.cfg.clockDateFmt || "d MMMM");
            root.dayText = root.isEn
                ? ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][d.getDay()]
                : ["Вс","Пн","Вт","Ср","Чт","Пт","Сб"][d.getDay()];
            root.dayNum = String(d.getDate());
            root.weekend = d.getDay() === 0 || d.getDay() === 6;
            root.monthText = (root.isEn
                ? ["January","February","March","April","May","June","July",
                   "August","September","October","November","December"]
                : ["Январь","Февраль","Март","Апрель","Май","Июнь","Июль",
                   "Август","Сентябрь","Октябрь","Ноябрь","Декабрь"])[d.getMonth()];
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
    // Присваивание running = true работающему процессу не делает ничего:
    // опрос молча пропускается, и состояние застывает до следующего раза.
    // Перезапускаем явно.
    function refreshWifiStatus() {
        pWifiStatus.running = false;
        pWifiStatus.running = true;
    }
    // Свёрнутый остров показывает только значок сети: там хватает редкого
    // опроса. Частый нужен, когда открыт список сетей.
    Timer {
        interval: root.expanded ? 4000 : 15000
        running: true; repeat: true
        onTriggered: root.refreshWifiStatus()
    }

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
            root.refreshWifiStatus();
            // iwctl возвращается раньше, чем соединение поднялось: сразу после
            // него `iw dev link` ещё пуст, и панель показывала подключённую
            // сеть без имени. Спрашиваем ещё раз, когда связь устоялась.
            wifiSettleTimer.begin();
            root.refreshWifiList();
        }
    }

    // Связь поднимается не мгновенно и не за одинаковое время: у одной точки
    // это доли секунды, у другой — несколько. Поэтому после подключения не
    // один отложенный опрос, а несколько подряд, и прекращаются они, как
    // только имя сети появилось. Иначе панель показывала подключённую сеть
    // без имени до ближайшего общего опроса — или до ручного сканирования.
    Timer {
        id: wifiSettleTimer
        interval: 1200
        repeat: true
        property int tries: 0
        onTriggered: {
            root.refreshWifiStatus();
            if (root.wifiSsid.length || ++wifiSettleTimer.tries > 6) {
                wifiSettleTimer.tries = 0;
                wifiSettleTimer.stop();
            }
        }
        function begin() { wifiSettleTimer.tries = 0; wifiSettleTimer.restart(); }
    }

    // Отключиться от сети и забыть её. Забывание — не то же самое, что
    // отключение: пока сеть сохранена, iwd подключится к ней сам при первой
    // возможности, и «отключился» держится ровно до следующего появления
    // этой точки в эфире.
    Process { id: pWifiDisconnect }
    function disconnectWifi() {
        pWifiDisconnect.running = false;
        pWifiDisconnect.command = ["sh", "-c", root.wifiScript + " disconnect"];
        pWifiDisconnect.running = true;
        wifiSettleTimer.begin();
    }
    Process { id: pWifiForget }
    function forgetWifi(ssid) {
        if (!ssid || !ssid.length) return;
        pWifiForget.running = false;
        pWifiForget.command = ["sh", "-c", root.wifiScript + " forget \"$1\"", "_", String(ssid)];
        pWifiForget.running = true;
        wifiSettleTimer.begin();
        wifiRescanTimer.restart();
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

    // --------------------------------------------------------- запись экрана
    // Всё состояние держит scripts/record.sh: пилюлю можно перезапустить
    // прямо во время записи, и она подхватит её обратно.
    property bool   recActive: false
    property bool   recPaused: false
    property int    recStarted: 0        // unix-время старта
    property int    recPausedTotal: 0    // сколько секунд простояли на паузе
    property string recFile: ""
    property string recError: ""
    property int    recNow: 0            // «сейчас» для таймера, тикает раз в секунду

    readonly property int recSeconds:
        recActive ? Math.max(0, recNow - recStarted - recPausedTotal) : 0
    readonly property string recTimeText: {
        var s = recSeconds;
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), x = s % 60;
        var mm = (m < 10 ? "0" : "") + m, ss = (x < 10 ? "0" : "") + x;
        return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss;
    }

    readonly property string recScript: root.scriptDir + "/record.sh"

    // ------------------------------------------------- длительная работа
    // Всё, что идёт дольше пары секунд, показывает свёрнутый остров: копирование
    // папки в несколько гигабайт, обновление оболочки, прогрев миниатюр. Раньше
    // они шли молча, и отличить работу от зависания было нельзя.
    //
    // Проценты знает не всякая работа, поэтому busyProgress < 0 означает
    // «идёт, сколько осталось — неизвестно»: там, где считать нечего, полоска
    // просто ходит из стороны в сторону.
    property string busyLabel: ""
    property int    busyProgress: -1
    // значок слева от подписи: у копирования свой, у обновления свой
    property string busyGlyph: ""

    function beginBusy(label, glyph, progress) {
        root.busyLabel = label;
        root.busyGlyph = glyph;
        root.busyProgress = progress === undefined ? -1 : progress;
    }
    function endBusy() {
        root.busyLabel = "";
        root.busyGlyph = "";
        root.busyProgress = -1;
    }

    // ------------------------------------------ длительная файловая операция
    // Процесс живёт здесь, а не в проводнике, нарочно: панель закрывают сразу
    // после того, как перетащили файлы, и вместе с ней умирал бы и Loader, и
    // копирование на середине. Теперь оно доживает до конца само, а остров
    // показывает, сколько осталось.
    property var fileOpQueue: []

    // Вторая операция, начатая пока идёт первая, раньше затирала бы команду
    // работающего процесса и молча пропадала.
    function runFileOp(args, label) {
        if (pFileOp.running) {
            var q = root.fileOpQueue.slice();
            q.push({ args: args, label: label });
            root.fileOpQueue = q;
            return;
        }
        root.beginBusy(label, "󰆏", 0);
        pFileOp.command = args;
        pFileOp.running = true;
    }

    Process {
        id: pFileOp
        stdout: SplitParser {
            onRead: line => {
                var m = /^PROGRESS (\d+)$/.exec(String(line).trim());
                if (m) root.busyProgress = parseInt(m[1], 10);
            }
        }
        onRunningChanged: {
            if (running) return;
            // все открытые проводники перечитывают списки: файл появился
            // (или исчез) не у того окна, что затеяло операцию
            root.filesChanged();
            if (root.fileOpQueue.length > 0) {
                var q = root.fileOpQueue.slice();
                var next = q.shift();
                root.fileOpQueue = q;
                root.beginBusy(next.label, "󰆏", 0);
                pFileOp.command = next.args;
                pFileOp.running = true;
                return;
            }
            root.endBusy();
        }
    }

    Process {
        id: pRecStatus
        command: ["sh", "-c", root.recScript + " status"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p[0] === "idle") {
                    root.recActive = false;
                    root.recPaused = false;
                    return;
                }
                root.recActive = true;
                root.recPaused = (p[0] === "paused");
                root.recStarted = parseInt(p[2]) || 0;
                root.recPausedTotal = parseInt(p[3]) || 0;
                root.recFile = p[4] || "";
            }
        }
    }
    // Пока запись не идёт, секундная стрелка никому не нужна: таймер сам
    // переходит на редкий шаг и перестаёт будить процессор каждую секунду.
    Timer {
        interval: root.recActive ? 1000 : 15000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            root.recNow = Math.floor(Date.now() / 1000);
            pRecStatus.running = true;
        }
    }

    Process {
        id: pRecCmd
        onRunningChanged: if (!running) pRecStatus.running = true
        stderr: SplitParser {
            onRead: line => {
                var t = line.trim();
                if (!t.length) return;
                root.recError = t === "already" ? root.tr("Запись уже идёт")
                              : t === "no-recorder" ? root.tr("wf-recorder не найден")
                              : t === "failed"  ? root.tr("Не удалось начать запись")
                                                : t;
                recErrorClear.restart();
            }
        }
    }
    Timer { id: recErrorClear; interval: 4000; onTriggered: root.recError = "" }

    // Выбор экрана для записи. Несколько мониторов (ноутбук + HDMI) — wf-recorder
    // без -o спрашивает, какой писать, и в фоне падал. Спрашиваем сами карточкой.
    property bool recPick: false
    property var  recPickMons: []
    readonly property bool recPickActive: recPick && !expanded

    function startRecord() {
        if (root.recActive) return;
        root.recError = "";
        var scr = Quickshell.screens;
        if (scr && scr.length > 1) {
            var list = [];
            for (var i = 0; i < scr.length; i++)
                list.push({ name: scr[i].name,
                            desc: String(scr[i].model || scr[i].name) });
            root.recPickMons = list;
            root.recPick = true;
            if (root.expanded) root.collapse();
            return;
        }
        root.startRecordOn(scr && scr.length ? scr[0].name : "");
    }
    function startRecordOn(output) {
        root.recPick = false;
        root.recError = "";
        pRecCmd.command = ["sh", "-c",
            root.recScript + " start \"$1\" \"$2\" \"$3\" \"$4\" \"$5\" \"$6\"", "_",
            String(root.cfg.recFps), String(root.cfg.recDir),
            root.cfg.recSysAudio ? "1" : "0",
            root.cfg.recMic ? "1" : "0",
            String(root.cfg.recMicDevice),
            String(output)];
        pRecCmd.running = true;
    }
    function cancelRecPick() { root.recPick = false; }
    // Не оставляем карточку выбора висеть вечно, если передумали.
    Timer { id: recPickTimer; interval: 8000; running: root.recPickActive
            onTriggered: root.cancelRecPick() }
    function stopRecord() {
        if (!root.recActive) return;
        pRecCmd.command = ["sh", "-c", root.recScript + " stop"];
        pRecCmd.running = true;
    }
    function pauseRecord() {
        if (!root.recActive) return;
        pRecCmd.command = ["sh", "-c", root.recScript + " pause"];
        pRecCmd.running = true;
    }
    function toggleRecord() { if (root.recActive) stopRecord(); else startRecord(); }

    // ---------------------------------------------------- голос в текст (voxtype)
    // Пока зажат правый Alt — остров показывает индикатор: «Слушаю…» во время
    // записи, «Расшифровываю…» пока voxtype печатает текст. Ведёт индикатор
    // scripts/voxtype.sh (его дёргает Hyprland на нажатие/отпускание клавиши)
    // через IPC voxListening/voxTranscribing/voxDone. Само распознавание и
    // вставку текста в активное поле делает voxtype.
    property string voxState: ""     // "" | "listening" | "transcribing"
    readonly property bool voxActive: voxState.length > 0 && !expanded

    // Страховка: если «Расшифровываю…» почему-то не закрылось (voxtype упал и
    // не прислал voxDone) — прячем сами через несколько секунд.
    Timer {
        id: voxGuard
        interval: 8000
        running: root.voxState === "transcribing"
        onTriggered: root.voxState = ""
    }

    // список микрофонов для выбора в пульте записи
    ListModel { id: micModel }
    readonly property var recMics: micModel
    Process {
        id: pRecMics
        command: ["sh", "-c", root.recScript + " mics"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 2) return;
                micModel.append({ mName: p[0], mDesc: p[1] });
            }
        }
    }
    function refreshMics() {
        micModel.clear();
        pRecMics.running = false;
        pRecMics.running = true;
    }

    Process { id: pMkRecDir }
    function openRecordDir() {
        var d = String(root.cfg.recDir);
        if (d.indexOf("~") === 0) d = Quickshell.env("HOME") + d.slice(1);
        // папки может ещё не быть: создаём, иначе проводник покажет пустоту
        pMkRecDir.command = ["sh", "-c", "mkdir -p \"$1\"", "_", d];
        pMkRecDir.running = true;
        root.filesDir = d;
        root.togglePage("files");
    }

    // -------------------------------------------------------------- Bluetooth
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    readonly property var btDevices: btAdapter ? btAdapter.devices : null
    readonly property var btConnectedDevice: {
        if (!btDevices) return null;
        var list = btDevices.values;
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].connected) return list[i];
        return null;
    }
    readonly property string btConnectedName: {
        if (btConnectedDevice) return btConnectedDevice.name || "Устройство";
        return "";
    }
    readonly property string btConnectedType: {
        if (!btConnectedDevice) return "earbuds";
        var icon = String(btConnectedDevice.icon || "").toLowerCase();
        var name = String(btConnectedDevice.name || "").toLowerCase();
        if (icon === "input-mouse" || name.indexOf("mouse") >= 0 || name.indexOf("мышь") >= 0) return "mouse";
        if (icon === "input-keyboard" || name.indexOf("keyboard") >= 0 || name.indexOf("клави") >= 0) return "keyboard";
        if (icon === "input-gaming" || name.indexOf("controller") >= 0 || name.indexOf("gamepad") >= 0 || name.indexOf("dualsense") >= 0 || name.indexOf("xbox") >= 0) return "gamepad";
        if (icon === "phone" || name.indexOf("phone") >= 0 || name.indexOf("iphone") >= 0 || name.indexOf("android") >= 0) return "phone";
        if (icon === "audio-speakers" || icon === "audio-speaker" || name.indexOf("speaker") >= 0 || name.indexOf("колонк") >= 0) return "speaker";
        return "earbuds";
    }
    // Заряд подключённого устройства (наушников). -1, если батарею не сообщают.
    readonly property int btConnectedBattery: {
        if (btConnectedDevice && btConnectedDevice.batteryAvailable)
            return Math.round(btConnectedDevice.battery * 100);
        return -1;
    }

    // ---- Тост «Bluetooth-устройство подключено / отключено» ----------------
    property string btToastName: ""
    property string btToastType: "earbuds"
    property bool   btToastDisconnected: false
    property bool   btToastShown: false
    readonly property bool btToastActive: btToastShown && !expanded
    property string btPrevConnected: ""

    onBtConnectedNameChanged: {
        var name = root.btConnectedName;
        if (name.length > 0 && name !== root.btPrevConnected) {
            root.btPrevConnected = name;
            root.showBtToast(name, root.btConnectedType, false);
        } else if (name.length === 0 && root.btPrevConnected.length > 0) {
            var prev = root.btPrevConnected;
            var prevType = root.btToastType;
            root.btPrevConnected = "";
            root.showBtToast(prev, prevType, true);
        }
    }

    function showBtToast(name, type, isDisconnect) {
        root.btToastName = name;
        root.btToastType = type || "earbuds";
        root.btToastDisconnected = isDisconnect || false;
        root.btToastShown = true;
        if (root.expanded) root.collapse();
        btToastTimer.restart();
        root.playSound(isDisconnect ? "disconnect" : "connect");
    }
    function dismissBtToast() {
        root.btToastShown = false;
        btToastTimer.stop();
    }
    Timer {
        id: btToastTimer
        interval: 2500
        onTriggered: root.dismissBtToast()
    }

    // ---- Тост «зарядка подключена» ---------------------------------------
    // При подключении блока питания к ноутбуку остров на пару секунд
    // сворачивается в такую же карточку: значок зарядки, «Заряжается» и заряд.
    // Фон карточки — плавная волна, расходящаяся из центра. Ловим переход
    // питания от сети из false в true; только на ноутбуке (на десктопе сеть
    // есть всегда). Уступает Bluetooth-тосту, если тот показывается.
    property bool acToastShown: false
    readonly property bool acToastActive:
        acToastShown && !expanded && root.isLaptop && !root.btToastActive
    property bool acPrev: root.acOnline

    onAcOnlineChanged: {
        if (root.acOnline && !root.acPrev && root.isLaptop) root.showAcToast();
        root.acPrev = root.acOnline;
    }
    function showAcToast() {
        root.acToastShown = true;
        if (root.expanded) root.collapse();
        acToastTimer.restart();
        root.playSound("charge");
    }
    function dismissAcToast() {
        root.acToastShown = false;
        acToastTimer.stop();
    }
    Timer {
        id: acToastTimer
        interval: 2300
        onTriggered: root.dismissAcToast()
    }

    // rfkill может держать адаптер программно заблокированным (после
    // предыдущей сессии, гибернации, ядра). Пока он заблокирован, BlueZ не даёт
    // включить питание, и плитка «щёлкала» вхолостую. Снимаем блокировку перед
    // включением. rfkill без root снимает только soft-block — этого достаточно.
    Process { id: pBtUnblock; command: ["rfkill", "unblock", "bluetooth"] }
    function toggleBt() {
        if (!btAdapter) return;
        if (!btAdapter.enabled) {
            pBtUnblock.running = true;
            btPowerOn.restart();           // дать rfkill вступить в силу
        } else {
            btAdapter.enabled = false;
        }
    }
    Timer {
        id: btPowerOn
        interval: 250
        onTriggered: if (root.btAdapter) root.btAdapter.enabled = true;
    }
    function scanBt() {
        if (!btAdapter || !btAdapter.enabled) return;
        // без pairable сопряжение нового устройства не начиналось, и наушники
        // зависали в цикле «подключилось — отвалилось»
        btAdapter.pairable = true;
        btAdapter.discovering = true;
        btScanStop.restart();
    }
    Timer { id: btScanStop; interval: 12000; onTriggered: if (root.btAdapter) root.btAdapter.discovering = false }

    // -------------------------------------------------------------------- IPC
    IpcHandler {
        target: "pill"
        // индикатор голосового ввода: зовёт voxtype.sh на разных этапах
        function voxListening(): void {
            root.voxState = "listening";
            root.playSound("voice_start");
        }
        function voxTranscribing(): void { root.voxState = "transcribing"; }
        function voxDone(): void {
            root.voxState = "";
            root.playSound("voice_done");
        }
        function voxUnavailable(): void {
            root.voxState = "";
            root.recError = root.tr("voxtype не установлен");
        }
        function launcher(): void { root.toggleLauncher(); }
        function overview(): void { root.toggleOverview(); }
        // Всегда плитки Wi-Fi/Bluetooth, даже когда играет музыка
        function controls(): void { root.togglePage("main"); }
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
        function settings(): void { root.settingsTab = 0; root.togglePage("settings"); }
        // открыть окно настроек сразу на нужном разделе: удобно вешать на
        // сочетание клавиш и незаменимо при проверке самих настроек
        function settingsAt(tab: string): void {
            root.settingsTab = parseInt(tab) || 0;
            if (root.page !== "settings" || !root.expanded) root.togglePage("settings");
        }
        function shortcuts(): void { root.toggleKeysWindow(); }
        function clipboard(): void { root.togglePage("clip"); }
        function powermenu(): void { root.togglePage("power"); }
        function weather(): void { root.openWeatherDetails(); }
        function smartClose(): string {
            if (!root.cfg.closePanaceaFirst) return "disabled";
            var anyOpen = root.expanded || root.overviewOpen || root.wallsOpen || root.keysWindowOpen || root.whatsNewOpen || root.weatherDetailsOpen;
            if (anyOpen) {
                if (root.weatherDetailsOpen) root.weatherDetailsOpen = false;
                else if (root.overviewOpen) root.closeOverview();
                else if (root.wallsOpen) root.closeWalls();
                else if (root.keysWindowOpen) root.closeKeysWindow();
                else if (root.whatsNewOpen) root.dismissWhatsNew();
                else if (root.expanded) root.collapse();
                return "closed_overlay";
            }
            return "none";
        }
        function cancelCapture(): void { root.cancelCaptureRequested(); }
        // Стоп-кадр под выделение области, см. scripts/shot.sh
        function freeze(path: string): void { root.freezeShot = "file://" + path; }
        function unfreeze(): void { root.freezeShot = ""; }
        function shotCopied(path: string): void { root.shotCopied(path); }
        function notifications(): void { root.togglePage("notif"); }
        function audio(): void { root.togglePage("audio"); }
        function calendar(): void { root.togglePage("cal"); }
        function theme(): void { root.toggleWalls(); }
        function record(): void { root.togglePage("record"); }
        function files(): void { root.togglePage("files"); }
        // Открыть проводник сразу в нужном каталоге. Нужно, чтобы система
        // могла назначить его обработчиком inode/directory: без пути «открыть
        // папку» приводило бы всегда в один и тот же каталог.
        function filesAt(path: string): void { root.openFilesAt(path); }
        function passwords(): void { root.togglePage("vault"); }
        function agents(): void { root.openAgents(); }
        function media(path: string): void { root.openMedia(path); }
        // переключить выделение области в плеере (то же, что кнопка «Кроп»)
        function mediaCrop(): void { root.mediaCropToggle(); }
        function recordToggle(): void { root.toggleRecord(); }
        function dnd(): void { root.toggleDnd(); }
        // Яркость приходит от smart_brightness.sh: службы для неё нет.
        //
        // Помимо накладки двигаем и сам ползунок в быстрых настройках. Он
        // читает список экранов, а тот наполняется только по запросу — от
        // клавиш ноутбука список не обновлялся, и ползунок оставался там,
        // где его бросили в прошлый раз, показывая неправду.
        function brightness(pct: string): void {
            var v = parseFloat(pct);
            root.showOsd("bright", v / 100.0, false);

            var l = root.brightList.slice();
            var hit = false;
            for (var i = 0; i < l.length; i++) {
                // Клавиши правят подсветку встроенного экрана — у него в
                // списке признак «bl:», — а внешние мониторы висят на DDC, и
                // до них эти клавиши не достают.
                if (String(l[i].id).indexOf("bl:") === 0 || l.length === 1) {
                    l[i] = { id: l[i].id, name: l[i].name, pct: Math.round(v) };
                    hit = true;
                }
            }
            if (hit) root.brightList = l;
            // Список ещё не собран — соберём: без него ползунка нет вовсе.
            else if (l.length === 0) root.brightRefresh(false);
        }
        // Режим энергосбережения гасит движение и в оболочке: анимации —
        // самое дорогое, что она делает без спроса. Настройка та же, что на
        // вкладке Motion, поэтому режим её честно возвращает при выходе.
        function motion(on: string): void {
            root.cfg.reduceMotion = (on !== "on");
            root.saveCfg();
        }
        function close(): void { root.collapse(); }
    }

    // ----------------------------------------------------------------- окно
    // Экран, на котором висит остров. Слой Wayland пересоздаётся при смене,
    // поэтому вычисляем аккуратно: имя из настроек — только если такой выход
    // сейчас подключён, иначе (и в режиме "auto") идём за фокусом. Если
    // Hyprland ещё не ответил, отдаём null — Quickshell возьмёт экран сам.
    screen: root.pickScreen

    readonly property var pickScreen: {
        var want = root.cfg.pillScreen;
        if (want && want !== "auto") {
            var all = Quickshell.screens;
            for (var i = 0; i < all.length; i++)
                if (all[i].name === want) return all[i];
        }
        var fm = Hyprland.focusedMonitor;
        return (fm && fm.screen) ? fm.screen : null;
    }

    // Прижимаемся тремя кромками: свободной остаётся та, в сторону которой
    // раскрывается панель. Иначе слой занял бы весь экран и exclusiveZone
    // (место под остров) считался бы не от той кромки.
    anchors.top:    !root.pillAtBottom
    anchors.bottom: !root.pillAtTop
    anchors.left:   !root.pillAtRight
    anchors.right:  !root.pillAtLeft
    // Высота окна ПОСТОЯННА и равна экрану.
    //
    // Раньше она переключалась 560 <-> 1080 при закреплении панели, и слой
    // Wayland пересоздавался прямо посреди анимации: содержимое успевало
    // схлопнуться и разложиться заново. Именно это выглядело как рывок при
    // открытии календаря по клику на часы.
    //
    // Постоянная высота ничего не ломает: пока панель не закреплена, ввод
    // ограничен маской по капсуле, и клики проходят сквозь окно как раньше.
    implicitHeight: root.screen ? root.screen.height : 1080
    // для боковых положений свободна вертикальная кромка, и размер по ширине
    // окно тоже должно задать само
    implicitWidth: root.screen ? root.screen.width : 1920
    color: "transparent"
    // зазор между пилюлей и окнами (0 в режиме оверлея или при скрытии)
    exclusiveZone: (root.cfg.pillOverlay || root.pillHidden || (root.fullscreenActive && !root.expanded))
                   ? 0 : pillH + gap
    WlrLayershell.layer: WlrLayer.Overlay
    // Пока поверх экрана развёрнутое окно, пилюли не видно совсем.
    // Показываем её обратно, если панель раскрыли клавишами или если
    // нужно показать уровень громкости/яркости.
    visible: !root.fullscreenActive || root.expanded || root.osdActive

    Process {
        id: pCloseWin
        command: ["sh", "-c", "out=$(hyprctl dispatch 'hl.dsp.window.close()' 2>&1); case \"$out\" in ok*) ;; *) hyprctl dispatch killactive ;; esac"]
    }
    function closeActiveWindow(): void {
        pCloseWin.running = false;
        pCloseWin.running = true;
    }

    // Закрытие раскрытой панели по Escape или Super+Q / Meta+W
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.collapse();
            event.accepted = true;
            return;
        }
        if ((event.key === Qt.Key_Q || event.key === Qt.Key_W) && (event.modifiers & Qt.MetaModifier)) {
            if (root.cfg.closePanaceaFirst) {
                root.collapse();
            } else {
                root.closeActiveWindow();
            }
            event.accepted = true;
            return;
        }
    }
    // клики ловим только там, где нарисована пилюля
    // Пока открыта закреплённая страница, ввод принимает всё окно:
    // иначе клики по панели (особенно по центрированным настройкам)
    // проваливались мимо, и ползунки не реагировали.
    // Спрятан ли остров прямо сейчас. Всё, ради чего его вообще показывают —
    // раскрытая панель, перетаскивание, громкость — держит его на экране.
    readonly property bool pillHidden: root.cfg.pillAutoHide
                                       && !root.expanded && !root.holdOpen
                                       && !root.osdActive && !root.pillDragging
                                       && !revealHover.hovered && !capsuleHover.hovered

    // Появление из-за кромки — не повод раскрываться. Остров выезжает прямо
    // под неподвижный курсор, и раскрытие по наведению срабатывало само:
    // человек хотел увидеть часы, а получал панель. Взводим раскрытие
    // заново, только когда курсор после этого действительно двинется.
    onPillHiddenChanged: {
        if (root.pillHidden) return;
        root.hoverExpandArmed = false;
        capsuleHover.markArmPoint();
    }

    // Полоска у самой кромки: спрятанный остров курсором не поймать, и
    // вернуть его нечем — кроме узкой зоны, которая ловит наведение.
    Item {
        id: revealStrip
        visible: root.cfg.pillAutoHide
        anchors.top:    root.pillAtBottom ? undefined : parent.top
        anchors.bottom: root.pillAtBottom ? parent.bottom : undefined
        anchors.left:   root.pillAtRight  ? undefined : parent.left
        anchors.right:  root.pillAtRight  ? parent.right : undefined
        width:  root.pillSide ? 4 : parent.width
        height: root.pillSide ? parent.height : 4
        HoverHandler { id: revealHover }
    }

    Region {
        id: capsuleRegion
        item: capsule
        // спрятанный остров вне экрана, и без полоски его не позвать
        Region { item: revealStrip; intersection: Intersection.Combine }
    }
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

    // Снимок прежних обоев: лежит ниже пилюли и выше рабочего стола,
    // клики не ловит — маска окна всё равно пропускает их насквозь.
    Image {
        anchors.fill: parent
        z: -5
        // Пока кроссфейда нет, снимок не нужен и в памяти его быть не должно:
        // распакованные обои во весь экран — это десяток мегабайт, которые
        // висели круглые сутки ради семисот миллисекунд перехода.
        source: (root.themeFading || opacity > 0.01) ? root.themeFadeWall : ""
        fillMode: Image.PreserveAspectCrop
        // у обоев бывает 75 мегапикселей: без ограничения Qt отказывается их
        // декодировать (лимит 256 МБ на картинку) и кроссфейд не появлялся
        sourceSize.width: root.screen ? root.screen.width : 1920
        asynchronous: false
        cache: false
        visible: opacity > 0.01
        opacity: root.themeFading ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 700; easing.type: Easing.InOutCubic }
        }
    }

    // Подсветка кромки, к которой прицепится остров. Пока тянут по пустоте,
    // ничего не горит — значит отпускать некуда, вернётся на место.
    Repeater {
        model: ["top", "bottom", "left", "right"]
        Rectangle {
            required property string modelData
            readonly property bool side: modelData === "left" || modelData === "right"
            readonly property bool lit: root.pillDragging && root.dragEdge === modelData

            width:  side ? 4 : parent.width
            height: side ? parent.height : 4
            x: modelData === "right" ? parent.width - width : 0
            y: modelData === "bottom" ? parent.height - height : 0
            z: 80
            radius: 2
            color: root.colOn
            opacity: lit ? 0.9 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
    }

    // ------------------------------------------------------------- сама пилюля
    Rectangle {
        id: capsule

        // Прижата к своей кромке и растёт от неё — поэтому «раскрытие к
        // центру» получается само, без отдельной анимации направления.
        anchors.top:    root.pillAtTop    ? parent.top    : undefined
        anchors.bottom: root.pillAtBottom ? parent.bottom : undefined
        anchors.left:   root.pillAtLeft   ? parent.left   : undefined
        anchors.right:  root.pillAtRight  ? parent.right  : undefined
        anchors.horizontalCenter: root.pillSide ? undefined : parent.horizontalCenter
        anchors.verticalCenter:   root.pillSide ? parent.verticalCenter : undefined

        // у кромки — 0, в режиме настроек — по центру экрана
        // Вне режима выреза остров отходит от кромки на islandGap: он
        // перестаёт быть продолжением края экрана и становится отдельной
        // капсулой, висящей рядом с ним.
        readonly property real freeGap: root.cfg.notchMode ? 0 : root.cfg.islandGap
        // Спрятанный остров уходит за кромку целиком: отрицательный отступ
        // выносит его за границу окна, и на экране не остаётся ничего.
        readonly property real edgeMargin: root.settingsMode && !root.pillSide
                                           ? Math.max(24, (root.height - targetH) / 2)
                                           : root.pillHidden ? -(targetH + 4) : freeGap
        // у боковых положений от кромки отрывает уже горизонтальный отступ
        readonly property real sideMargin: root.settingsMode && root.pillSide
                                           ? Math.max(24, (root.width - width) / 2)
                                           : root.pillHidden ? -(width + 4) : freeGap
        anchors.topMargin:    root.pillAtTop    ? edgeMargin : 0
        anchors.bottomMargin: root.pillAtBottom ? edgeMargin : 0
        anchors.leftMargin:   root.pillAtLeft   ? sideMargin : 0
        anchors.rightMargin:  root.pillAtRight  ? sideMargin : 0
        Behavior on anchors.leftMargin {
            NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
        }
        Behavior on anchors.rightMargin {
            NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
        }
        Behavior on anchors.topMargin {
            NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
        }
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
        }

        // Свёрнутый остров измеряется вдоль своей кромки и поперёк неё: у
        // боковых положений он стоит вертикально, поэтому длина уходит в
        // высоту, а толщина — в ширину.
        // collapsedW задаёт нижнюю границу, а не саму ширину: содержимое
        // свёрнутого острова меняется (часы, трек, всплеск громкости), и
        // жёсткая ширина обрезала бы его.
        // Nothing носит остров заметно длиннее: там по краям стоят точки
        // столов и три показателя сразу, и на общей нижней границе всё это
        // жалось к часам вплотную.
        readonly property int collapsedMin: root.themeNothing
                ? Math.max(root.cfg.collapsedW, 420) : root.cfg.collapsedW

        // Округляем до чётного числа пикселей. Остров стоит по центру экрана,
        // то есть его x равен половине разности ширин: при нечётной или
        // дробной длине он попадает на полпикселя, и вогнутые уголки по бокам
        // — отдельные элементы со своими координатами — приезжают на ту же
        // половину. На стыке остаётся сглаженная серая щель, и правый уголок
        // начинает читаться как приклеенный отдельно.
        //
        // Раньше до этого не доходило: содержимое было уже нижней границы, и
        // длиной работало ровное число из настроек. Точечные цифры шире, и
        // дробная ширина содержимого стала попадать наружу.
        function evenUp(v) { return Math.round(v / 2) * 2; }

        readonly property real idleLen: root.voxActive
                    ? capsule.evenUp(Math.max(voxCapsule.implicitWidth + 40, 240))
                : root.recPickActive
                    ? capsule.evenUp(Math.max(recPickCapsule.implicitWidth + 28, 240))
                : root.btToastActive
                    ? capsule.evenUp(Math.max(btCapsule.implicitWidth + 48, 240))
                : root.acToastActive
                    ? capsule.evenUp(Math.max(acCapsule.implicitWidth + 48, 240))
                : root.toastActive ? 440
                : root.osdActive ? capsule.evenUp(osdCapsule.implicitWidth + 32)
                : root.pillSide  ? capsule.evenUp(Math.max(vertCapsule.implicitHeight + 30,
                                                           capsule.collapsedMin))
                : root.themeNothing
                                 ? capsule.evenUp(Math.max(nothingCapsule.implicitWidth + 28,
                                                           capsule.collapsedMin))
                                 : capsule.evenUp(Math.max(idleCapsule.implicitWidth + 32,
                                                           capsule.collapsedMin))
        readonly property real idleThick: (root.btToastActive || root.acToastActive
                    || root.recPickActive || root.voxActive)
                ? root.pillH
                : root.toastActive
                ? toastCapsule.implicitHeight + 24 : root.pillH

        width: root.settingsMode ? root.settingsW
             : root.expanded     ? root.panelW
             : root.pillSide     ? idleThick
                                 : idleLen
        // целевая высота — к ней анимируется height и по ней же сразу
        // рассчитывается центрирование, чтобы движение было одноэтапным
        // Высота содержимого держится отдельно: при смене страницы новый вид
        // на первом кадре ещё не разложен и его implicitHeight равен нулю.
        // Раньше капсула успевала схлопнуться до нуля и разложиться заново —
        // отсюда рывок при переходе, например, из плиток в календарь.
        property real contentH: 220

        // Раскладка новой страницы идёт в несколько проходов: сетка календаря
        // из 42 ячеек успевает отдать промежуточные высоты. Если применять
        // каждую, капсула дёргается. Собираем их в один шаг через таймер.
        Timer {
            id: contentSettle
            interval: 24
            onTriggered: capsule.applyContentH()
        }
        function refreshContentH() { contentSettle.restart(); }
        function applyContentH() {
            var it = contentLoader.item;
            if (!it || it.implicitHeight <= 40) return;
            var target = it.implicitHeight + 30;
            // Мелкие колебания раскладки цель не двигают. Высота идёт через
            // Behavior, а тот на каждое изменение цели начинает анимацию
            // заново — с текущей точки и на полную длительность. Пока страница
            // доразмечается, цель успевает поменяться несколько раз, и вместо
            // одного плавного роста капсула идёт ступеньками. Разница в
            // несколько пикселей глазу не видна, а перезапуск — виден.
            if (Math.abs(target - capsule.contentH) < 8) return;
            capsule.contentH = target;
        }
        Connections {
            target: contentLoader
            function onItemChanged() { capsule.refreshContentH(); }
        }
        Connections {
            target: contentLoader.item
            ignoreUnknownSignals: true
            function onImplicitHeightChanged() { capsule.refreshContentH(); }
        }

        // Раскрытая панель не выше expandedH: страницы бывают длинные, но
        // их высоту ограничивает уже своя прокрутка, а не остров.
        readonly property real targetH: root.expanded
                ? Math.min(contentH, root.settingsMode ? root.height - 48 : root.cfg.expandedH)
                : root.pillSide ? idleLen
                                : idleThick
        // Не выше экрана: у боковых кромок вертикальная раскладка страницы
        // отдавала такую высоту, что остров разворачивался во весь экран.
        height: Math.min(targetH, root.height - root.gap * 2)

        // Перенос: капсула сдвигается от своего места на dragDX/dragDY. Пока
        // тянут — без анимации, чтобы шла точно за курсором; на отпускании
        // смещение сбрасывается в ноль и она сама доезжает до кромки.
        transform: Translate {
            x: root.dragDX
            y: root.dragDY
            Behavior on x {
                enabled: !root.pillDragging
                NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: !root.pillDragging
                NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic }
            }
        }

        onXChanged:      root.pillRectX = capsule.x
        onYChanged:      root.pillRectY = capsule.y
        onWidthChanged:  root.pillRectW = capsule.width
        onHeightChanged: root.pillRectH = capsule.height
        Component.onCompleted: {
            root.pillRectX = capsule.x;      root.pillRectY = capsule.y;
            root.pillRectW = capsule.width;  root.pillRectH = capsule.height;
        }

        // Пока карусель обоев открыта, остров спрятан: она выросла из него,
        // и два острова на экране разом смотрелись бы как две панели.
        opacity: root.wallsOpen ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: root.animFast } }

        color: root.colBg
        // Углы у прижатой кромки срезаны, у смотрящей в экран — скруглены:
        // так остров выглядит выросшим из края, а не приклеенным к нему.
        // В режиме настроек капсула отрывается от кромки, и круглыми
        // становятся все четыре.
        // Оторванная от кромки капсула круглая со всех сторон: срезать ей
        // углы не от чего, кромка её больше не держит.
        readonly property real edgeR: (root.settingsMode || !root.cfg.notchMode)
                                      ? (root.cfg.islandRadius > 0 ? root.cfg.islandRadius : 26)
                                      : 0
        readonly property real freeR: root.expanded
                ? (root.cfg.islandRadius > 0 && !root.cfg.notchMode ? root.cfg.islandRadius : 26)
                : (root.cfg.islandRadius > 0 && !root.cfg.notchMode
                   ? root.cfg.islandRadius : root.pillH / 2)
        topLeftRadius:     root.pillAtTop || root.pillAtLeft  ? edgeR : freeR
        topRightRadius:    root.pillAtTop || root.pillAtRight ? edgeR : freeR
        bottomLeftRadius:  root.pillAtBottom || root.pillAtLeft  ? edgeR : freeR
        bottomRightRadius: root.pillAtBottom || root.pillAtRight ? edgeR : freeR
        Behavior on topLeftRadius  { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }
        Behavior on topRightRadius { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }

        // Niente bordo, in nessuno stato: e' l'unica differenza di stile che
        // c'era fra pillola e pannello. Un bordo largo 1 viene disegnato
        // *dentro* al rettangolo, quindi anche quando era trasparente lasciava
        // passare 1px di sfondo sul lato superiore: da qui l'impressione che
        // la pillola non fosse attaccata al bordo dello schermo e che il fondo
        // cambiasse all'apertura.
        border.width: 0

        // Bounce со вкладки Motion живёт здесь: остров меняет размер по
        // кривой с перелётом, и ползунок задаёт, насколько сильно он
        // проскакивает цель, прежде чем осесть. На нуле перелёта нет и
        // кривая обычная — движение просто останавливается.
        Behavior on width {
            NumberAnimation {
                duration: root.animMs
                easing.type: root.animBounce > 0 ? Easing.OutBack : Easing.InOutCubic
                easing.overshoot: root.easeOvershoot
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: root.morphing ? root.animMs : root.animQuick
                easing.type: root.animBounce > 0 ? Easing.OutBack
                           : root.morphing ? Easing.InOutCubic : Easing.OutCubic
                easing.overshoot: root.easeOvershoot
            }
        }
        Behavior on bottomLeftRadius  { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }
        Behavior on bottomRightRadius { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }

        clip: true

        // --- курсор отслеживаем поверх всего содержимого
        HoverHandler {
            id: capsuleHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            // Где стоял курсор, когда раскрытие по наведению запретили.
            // Запрет ставится после переноса острова и после клика по
            // уведомлению, а снимался он только уходом курсора с острова.
            // Если остров вставал ровно под неподвижным курсором (а после
            // переноса к кромке так и происходит), уходить было нечему:
            // запрет оставался навсегда, и панель больше не открывалась.
            // Поэтому его снимает ещё и осмысленный сдвиг мыши.
            property point armPos: Qt.point(-9999, -9999)
            // точку отсчёта ставят те места, что запрещают раскрытие
            function markArmPoint() {
                capsuleHover.armPos = capsuleHover.hovered
                        ? capsuleHover.point.scenePosition : Qt.point(-9999, -9999);
            }
            onPointChanged: {
                if (root.hoverExpandArmed || !capsuleHover.hovered) return;
                var p = capsuleHover.point.scenePosition;
                if (Math.abs(p.x - capsuleHover.armPos.x)
                    + Math.abs(p.y - capsuleHover.armPos.y) < 12) return;
                root.hoverExpandArmed = true;
                expandTimer.restart();
            }

            onHoveredChanged: {
                // курсор снова на острове — считать сдвиг заново от этой точки
                if (hovered && !root.hoverExpandArmed)
                    capsuleHover.armPos = capsuleHover.point.scenePosition;
                if (hovered) {
                    collapseTimer.stop();
                    expandTimer.restart();
                    rearmTimer.stop();
                } else {
                    expandTimer.stop();
                    collapseTimer.restart();
                    // Курсор ушёл — разрешаем раскрытие снова, но не сразу.
                    // При переезде к другой кромке остров на кадр выскакивает
                    // из-под курсора, и мгновенное возвращение разрешения
                    // означало, что у новой кромки он тут же раскрывался под
                    // тем же самым курсором.
                    rearmTimer.restart();
                }
            }
        }
        // Раскрыть плитки. Страницу трогаем только если панель ещё закрыта:
        // иначе наведение сбрасывало бы уже открытый список сетей.
        //
        // Открываются всегда плитки. Ни музыка, ни идущая запись своей
        // страницы не подсовывают: трек живёт карточкой прямо здесь, а до
        // пульта записи один клик по плитке — зато не приходится гадать,
        // что откроется.
        function openPanel() {
            if (!root.expanded) {
                pageResetTimer.stop();
                root.page = "main";
            }
            root.expanded = true;
        }

        Timer {
            id: expandTimer; interval: 0
            onTriggered: {
                if (!capsuleHover.hovered || root.launcherOpen) return;
                if (!root.hoverExpandArmed) return;
                // пока висит уведомление, наведение не раскрывает панель:
                // иначе до крестика не добраться
                if (root.toastActive || root.btToastActive || root.acToastActive || root.recPickActive || root.voxActive) return;
                // При автопрятании наведением остров только показывают. Он и
                // выезжает-то из-за кромки под этот самый курсор, так что
                // раскрытие следом означало бы: хотел посмотреть время —
                // получи панель во весь экран. Разворачивает клик.
                if (root.cfg.pillAutoHide) return;
                capsule.openPanel();
            }
        }
        // курсор должен побыть в стороне, а не просто мигнуть мимо
        Timer {
            id: rearmTimer
            interval: 450
            onTriggered: root.hoverExpandArmed = true
        }
        Timer {
            id: collapseTimer; interval: 180
            onTriggered: {
                if (capsuleHover.hovered || root.holdOpen) return;
                root.collapse();
            }
        }

        // Клик по свёрнутому острову разворачивает его. Единственный способ
        // открыть панель, когда включено автопрятание, и просто удобный —
        // когда нет: до этого пилюля на нажатия не отвечала вовсе.
        MouseArea {
            anchors.fill: parent
            z: 5
            enabled: !root.expanded && !root.toastActive && !root.pillDragging
                     && !root.osdActive && !root.btToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
            cursorShape: Qt.PointingHandCursor
            onClicked: capsule.openPanel()
        }

        // Клик по карточке открывает историю. Отдельным слоем под ней:
        // внутри RowLayout якоря ломают раскладку.
        // Нажатие открывает сам повод: чат, письмо, загрузку. Раньше карточка
        // уводила в список уведомлений — оттуда всё равно приходилось искать
        // приложение руками.
        //
        // z поверх всего содержимого капсулы: пока висит карточка, ни одна
        // область под ней не должна перехватывать щелчок.
        MouseArea {
            anchors.fill: parent
            z: 100
            enabled: root.toastActive
            visible: enabled
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.notifCurrent) root.activateNotification(root.notifCurrent)
        }

        // ------------------------------------------ свёрнутое: уведомление
        RowLayout {
            id: toastCapsule
            // Выше области нажатия карточки: сама она щелчки не перехватывает
            // (это просто текст и иконки), зато крестик внутри остаётся
            // доступным — иначе его накрыло бы прозрачной областью.
            z: 110
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 14
            anchors.topMargin: 12
            spacing: 12
            visible: root.toastActive && !root.btToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            // значок программы, если прислали
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignTop
                radius: 10
                color: root.notifUrgent ? Qt.rgba(1, 0.27, 0.27, 0.18)
                                        : Qt.rgba(1, 1, 1, 0.08)

                Image {
                    id: toastIcon
                    anchors.fill: parent
                    anchors.margins: 5
                    source: root.notifImage
                    // не Ready — значит не открылась: пусть лучше будет свой
                    // значок, чем клетчатый прямоугольник «битой картинки»
                    visible: source != "" && status === Image.Ready
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: !toastIcon.visible
                    text: String.fromCodePoint(root.notifUrgent ? 0xF0026 : 0xF009A)
                    color: root.notifUrgent ? root.colCrit : root.colFg
                    font { family: root.fontFam; pixelSize: root.iconSize - 1 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: root.notifSummary
                        color: root.colFg
                        elide: Text.ElideRight
                        font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                    }
                    Text {
                        text: root.notifApp
                        color: root.colMuted
                        font { family: root.fontFam; pixelSize: root.fontSize - 5 }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    // «Показывать текст в карточке» из настроек: выключено —
                    // видно только приложение и заголовок
                    visible: root.notifBody.length > 0 && root.cfg.notifPreview
                    text: root.notifBody
                    color: root.colMuted
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    // Спецификация разрешает в теле подмножество разметки
                    // (<b>, <i>, <u>, <a>), и мы заявляем её поддержку в
                    // bodyMarkupSupported. PlainText показывал теги как есть —
                    // Telegram присылал «<b>Паша брат</b>» прямо текстом.
                    textFormat: Text.StyledText
                    font { family: root.fontFam; pixelSize: root.fontSize - 3 }
                }
            }

            // закрыть тост
            Text {
                Layout.alignment: Qt.AlignTop
                text: "×"
                color: closeMa.containsMouse ? root.colFg : root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize + 2 }
                Behavior on color { ColorAnimation { duration: 150 } }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismissToast()
                }
            }
        }

        // ---------------------------------- свёрнутое: Bluetooth устройство
        // Слева иконка устройства (наушники, мышь, клавиатура, геймпад и т.д.),
        // по центру статус (Подключено / Отключено) и имя, справа кольцо с зарядом.
        RowLayout {
            id: btCapsule
            z: 110
            anchors.centerIn: parent
            spacing: 11
            visible: root.btToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 6

                Text {
                    anchors.centerIn: parent
                    text: root.btToastDisconnected ? String.fromCodePoint(0xF00B2)
                        : root.btToastType === "earbuds" ? String.fromCodePoint(0xF15C6)
                        : root.btToastType === "mouse" ? String.fromCodePoint(0xF098B)
                        : root.btToastType === "keyboard" ? String.fromCodePoint(0xF030C)
                        : root.btToastType === "gamepad" ? String.fromCodePoint(0xF02B4)
                        : root.btToastType === "phone" ? String.fromCodePoint(0xF011E)
                        : root.btToastType === "speaker" ? String.fromCodePoint(0xF04C3)
                        : String.fromCodePoint(0xF00AF)
                    color: root.btToastDisconnected ? root.colCrit : root.colFg
                    font { family: root.fontFam; pixelSize: 20 }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                transform: Translate { y: -2 }

                Text {
                    text: root.btToastDisconnected ? root.tr("Отключено") : root.tr("Подключено")
                    color: root.btToastDisconnected ? root.colCrit : root.colMuted
                    transform: Translate { y: 2 }
                    font { family: root.fontFam; pixelSize: root.fontSize - 4 }
                }
                Text {
                    Layout.maximumWidth: 220
                    text: root.btToastName
                    color: root.colFg
                    elide: Text.ElideRight
                    font { family: root.fontFam; pixelSize: root.fontSize + 1; bold: true }
                }
            }

            // Правая часть: кольцо заряда или иконка состояния
            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 48

                // Кольцо заряда при наличии батареи
                Canvas {
                    id: btRing
                    anchors.fill: parent
                    visible: !root.btToastDisconnected && root.btConnectedBattery >= 0

                    readonly property real level:
                        root.btConnectedBattery >= 0 ? root.btConnectedBattery / 100 : 0
                    property real fill: 0
                    readonly property real lineW: 3.5

                    onFillChanged: requestPaint()
                    onLevelChanged: {
                        if (!root.btToastActive) return;
                        btRingAnim.stop();
                        btRingAnim.from = btRing.fill;
                        btRingAnim.to = btRing.level;
                        btRingAnim.start();
                    }

                    NumberAnimation {
                        id: btRingAnim
                        target: btRing; property: "fill"
                        duration: 900; easing.type: Easing.OutCubic
                    }
                    function play() {
                        btRingAnim.stop();
                        btRing.fill = 0;
                        btRingAnim.from = 0;
                        btRingAnim.to = btRing.level;
                        btRingAnim.start();
                    }
                    Connections {
                        target: root
                        function onBtToastActiveChanged() {
                            if (root.btToastActive) btRing.play();
                        }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        if (width <= 0 || height <= 0) return;
                        var c = root.colFg;
                        if (root.btConnectedBattery >= 0 && root.btConnectedBattery <= 20) {
                            c = root.colCrit;
                        } else if (root.themeNothing) {
                            c = root.colOn;
                        } else if (root.btConnectedBattery > 20) {
                            c = "#34d399";
                        }
                        var r = (Math.min(width, height) - lineW) / 2;
                        var cx = width / 2, cy = height / 2;

                        ctx.lineWidth = lineW;
                        ctx.lineCap = "round";

                        // бледный контур
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.22);
                        ctx.stroke();

                        // дуга заряда
                        if (fill > 0) {
                            var start = -Math.PI / 2;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, start, start + 2 * Math.PI * fill);
                            ctx.strokeStyle = c;
                            ctx.stroke();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: String(root.btConnectedBattery)
                        color: root.btConnectedBattery <= 20 ? root.colCrit : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 6; bold: true }
                    }
                }

                // Иконка без батареи
                Rectangle {
                    anchors.fill: parent
                    visible: !root.btToastDisconnected && root.btConnectedBattery < 0
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.10)
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF00AF)
                        color: root.colFg
                        font { family: root.fontFam; pixelSize: 14 }
                    }
                }

                // Индикатор отключения
                Rectangle {
                    anchors.fill: parent
                    visible: root.btToastDisconnected
                    radius: 14
                    color: Qt.rgba(1, 0, 0, 0.12)
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF00B2)
                        color: root.colCrit
                        font { family: root.fontFam; pixelSize: 14 }
                    }
                }
            }
        }

        // ---- свёрнутое: зарядка подключена ------------------------------
        // Фон карточки — та же волна заряда, что на кнопке батареи в быстрых
        // настройках (ControlsView.ChargeWave): две бегущие синусоиды цветом
        // заряда, налитые до уровня батареи. Рисуется под содержимым (z ниже
        // капсул с z:110) и обрезается клипом пилюли; идёт, пока карточка на
        // экране.
        Canvas {
            id: acWave
            anchors.fill: parent
            z: 1
            visible: root.acToastActive
            property color tint: root.colOk
            property real level: root.batteryPct / 100
            property real phase: 0
            onPhaseChanged: requestPaint()
            onLevelChanged: requestPaint()
            onTintChanged: requestPaint()

            Timer {
                interval: 45
                running: root.acToastActive && acWave.visible
                repeat: true
                onTriggered: acWave.phase += 0.16
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                if (width <= 0 || height <= 0) return;

                // Клип по скруглению пилюли: у капсулы прямоугольный clip, и
                // без этого волна вылезала в скруглённые углы полупрозрачными
                // острыми уголками. Радиусы берём у самой капсулы.
                var mr = Math.min(width, height) / 2;
                var tl = Math.min(capsule.topLeftRadius, mr);
                var tr = Math.min(capsule.topRightRadius, mr);
                var br = Math.min(capsule.bottomRightRadius, mr);
                var bl = Math.min(capsule.bottomLeftRadius, mr);
                ctx.beginPath();
                ctx.moveTo(tl, 0);
                ctx.arcTo(width, 0, width, height, tr);
                ctx.arcTo(width, height, 0, height, br);
                ctx.arcTo(0, height, 0, 0, bl);
                ctx.arcTo(0, 0, width, 0, tl);
                ctx.closePath();
                ctx.clip();

                // Уровень держим в стороне от краёв: у самого верха волна
                // срезалась бы и выглядела ровной полосой.
                var base = height * (1 - Math.max(0.12, Math.min(0.92, level)));
                var amp = 3.2;

                for (var w = 0; w < 2; w++) {
                    var off = w === 0 ? 0 : Math.PI * 0.7;
                    var k = w === 0 ? 0.055 : 0.041;
                    ctx.beginPath();
                    ctx.moveTo(0, height);
                    for (var x = 0; x <= width; x += 3) {
                        var y = base + amp * Math.sin(k * x + phase + off)
                                     + amp * 0.5 * Math.sin(k * 1.9 * x - phase * 0.7);
                        if (x === 0) ctx.lineTo(0, y); else ctx.lineTo(x, y);
                    }
                    ctx.lineTo(width, height);
                    ctx.closePath();
                    ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, w === 0 ? 0.16 : 0.11);
                    ctx.fill();
                }
            }
        }

        // Значок зарядки, «Заряжается» и процент — одной строкой по центру
        // пилюли, без кольца.
        RowLayout {
            id: acCapsule
            z: 110
            anchors.centerIn: parent
            spacing: 8
            visible: root.acToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: String.fromCodePoint(0xF0241)
                color: root.colOk
                font { family: root.fontFam; pixelSize: root.iconSize + 3 }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.tr("Заряжается")
                color: root.colFg
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.batteryPct + "%"
                color: root.colOk
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }
        }

        // ---- свёрнутое: выбор экрана для записи -------------------------
        // Несколько мониторов — спрашиваем, какой писать: значок записи,
        // подпись и по чипу на каждый экран. Клик по чипу запускает запись
        // именно этого выхода; × отменяет. z выше остальных капсул — карточка
        // интерактивная, клики должны доходить до чипов.
        RowLayout {
            id: recPickCapsule
            z: 130
            anchors.centerIn: parent
            spacing: 9
            visible: root.recPickActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: String.fromCodePoint(0xF044A)
                color: root.colCrit
                font { family: root.fontFam; pixelSize: root.iconSize + 2 }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.tr("Записать экран")
                color: root.colFg
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }
            Repeater {
                model: root.recPickMons
                delegate: Rectangle {
                    required property var modelData
                    Layout.alignment: Qt.AlignVCenter
                    radius: 9
                    implicitWidth: chipTxt.implicitWidth + 20
                    implicitHeight: 26
                    color: chipMa.containsMouse ? root.colOn : Qt.rgba(1, 1, 1, 0.10)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: chipTxt
                        anchors.centerIn: parent
                        text: modelData.name
                        color: chipMa.containsMouse ? "#ffffff" : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 2; bold: true }
                    }
                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startRecordOn(modelData.name)
                    }
                }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: "×"
                color: pickCloseMa.containsMouse ? root.colFg : root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize + 2 }
                MouseArea {
                    id: pickCloseMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelRecPick()
                }
            }
        }

        // ---- свёрнутое: голосовой ввод (voxtype) ------------------------
        // Пока зажата кнопка/клавиша — «Слушаю…» с живым эквалайзером микрофона (cava);
        // после отпускания, пока voxtype печатает текст, — «Расшифровываю…».
        RowLayout {
            id: voxCapsule
            z: 120
            anchors.centerIn: parent
            spacing: 10
            visible: root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: String.fromCodePoint(0xF036C)   // микрофон
                color: root.voxState === "listening"
                    ? (root.themeNothing ? root.colCrit : "#60a5fa")
                    : (root.themeNothing ? root.colFg : root.colOn)
                font { family: root.fontFam; pixelSize: root.iconSize + 3 }

                SequentialAnimation on opacity {
                    running: root.voxState === "transcribing"
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.35; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.35; to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                }
                onVisibleChanged: if (!visible) opacity = 1
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.voxState === "transcribing" ? root.tr("Расшифровываю…")
                                                       : root.tr("Слушаю…")
                color: root.colFg
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }

            MicWaveBars {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 18
                visible: root.voxState === "listening"
                active: root.voxState === "listening" && root.voxActive
                barColor: root.themeNothing ? root.colCrit : "#60a5fa"
                barCount: 9
                gap: 2.5
            }
        }

        // ------------------------------------------- свёрнутое: уровень (OSD)
        RowLayout {
            id: osdCapsule
            anchors.centerIn: parent
            height: root.pillH
            spacing: 12
            visible: root.osdActive && !root.toastActive && !root.btToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                text: root.osdIcon
                color: root.osdMuted ? root.colMuted : root.colFg
                // Ширина зафиксирована: глифы громкости, микрофона и солнца
                // разной ширины, из-за чего пилюля дёргалась при смене уровня.
                Layout.preferredWidth: mOsdIcon.width + 4
                horizontalAlignment: Text.AlignHCenter
                font { family: root.fontFam; pixelSize: root.iconSize }
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            Rectangle {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 5
                Layout.alignment: Qt.AlignVCenter
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.16)

                Rectangle {
                    width: parent.width * (root.osdMuted ? 0 : root.osdValue)
                    height: parent.height
                    radius: 3
                    color: root.osdKind === "bright" ? root.colWarn : root.colOn
                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }

            Text {
                Layout.preferredWidth: mBatt.width
                horizontalAlignment: Text.AlignRight
                text: root.osdMuted ? "—" : Math.round(root.osdValue * 100) + "%"
                color: root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            }
        }

        // Эталоны ширины: числа в пилюле занимают место по самому широкому
        // варианту, поэтому капсула не растягивается и не сужается на ходу.
        TextMetrics {
            id: mClock
            font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            // Эталон под самый широкий вариант ИМЕННО текущего формата:
            // с секундами строка длиннее, а место под неё резервировалось
            // старое — часы налезали на соседей, и остров стоял впритык.
            text: (root.cfg.clock12 ? "12:00" : "00:00")
                  + (root.cfg.clockSeconds ? ":00" : "")
                  + (root.cfg.clock12 ? " PM" : "")
        }
        TextMetrics {
            id: mBatt
            font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            text: "100%"
        }
        TextMetrics {
            id: mBattIcon
            font { family: root.fontFam; pixelSize: root.iconSize }
            // глифы заряда моноширинные между собой, хватит одного образца
            text: String.fromCodePoint(0xF0079)
        }
        TextMetrics {
            id: mOsdIcon
            font { family: root.fontFam; pixelSize: root.iconSize }
            // самый широкий из используемых глифов уровня
            text: String.fromCodePoint(0xF057E)
        }
        TextMetrics {
            id: mWs
            font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            text: "10"
        }

        // ---------------------------------------------------- свёрнутое: покой
        RowLayout {
            id: idleCapsule
            anchors.centerIn: parent
            height: root.pillH
            spacing: 14
            // На теме Nothing свёрнутый остров устроен иначе — его собирает
            // nothingCapsule, а эта раскладка целиком уступает ему место.
            visible: !root.themeNothing && !root.expanded && !root.osdActive && !root.toastActive && !root.btToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
            // Прозрачностью, а не visible: у скрытой раскладки implicitWidth
            // равен нулю, и остров считал бы свою длину по пустоте.
            opacity: root.pillSide ? 0 : (visible ? 1 : 0)
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            // ------------------------------------------------ играет медиа
            // Плеер больше не отдельное состояние пилюли: обложка, название и
            // полосы просто встают слева от дня недели, а часы, стол и заряд
            // остаются на местах. Так пилюля не «подменяется» на музыку.
            RowLayout {
                id: mediaSeg
                spacing: 9
                visible: root.mediaActive
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.animFast } }

                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    radius: 6
                    color: Qt.rgba(1, 1, 1, 0.08)
                    // clip у Rectangle прямоугольный — углы обложки от него
                    // острые. Скругляем саму картинку маской по радиусу:
                    // скрытый Image-источник + маска, а рисует MultiEffect.
                    Image {
                        id: capsuleArt
                        anchors.fill: parent
                        source: root.mediaArt
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 56
                        visible: false
                        layer.enabled: true
                    }
                    Item {
                        id: capsuleArtMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle { anchors.fill: parent; radius: 6; color: "#ffffff" }
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: capsuleArt
                        maskEnabled: true
                        maskSource: capsuleArtMask
                        visible: capsuleArt.status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: capsuleArt.status !== Image.Ready
                        text: "󰝚"
                        color: root.colMuted
                        font { family: root.fontFam; pixelSize: 11 }
                    }
                }

                Text {
                    Layout.maximumWidth: 150
                    Layout.alignment: Qt.AlignVCenter
                    text: root.player ? root.player.trackTitle : ""
                    color: root.colFg
                    elide: Text.ElideRight
                    font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                }

                WaveBars {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                    barColor: root.colFg
                    active: root.player ? root.player.isPlaying : false
                }

                // разделитель — чтобы трек читался отдельно от часов
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 2
                    color: Qt.rgba(1, 1, 1, 0.14)
                }
            }

            // идёт долгая работа — значок, подпись и полоска слева от даты
            RowLayout {
                spacing: 7
                visible: root.busyLabel.length > 0

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.busyGlyph
                    color: root.colOn
                    font { family: root.fontFam; pixelSize: root.fontSize - 2 }
                }

                Text {
                    Layout.maximumWidth: 130
                    Layout.alignment: Qt.AlignVCenter
                    text: root.busyLabel
                    color: root.colFg
                    elide: Text.ElideMiddle
                    font { family: root.fontFam; pixelSize: root.fontSize - 2 }
                }

                // Полоска, а не проценты цифрами: остров и так узкий, а точное
                // число тут никому не нужно — важно, что дело движется.
                Rectangle {
                    id: busyTrack
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 4
                    Layout.alignment: Qt.AlignVCenter
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.16)
                    clip: true

                    readonly property bool unknown: root.busyProgress < 0

                    Rectangle {
                        id: busyFill
                        // Пока проценты неизвестны, короткий отрезок ходит
                        // туда-обратно: полоса в ноль читалась бы как «ничего
                        // не происходит», а полная — как «уже готово».
                        width: busyTrack.unknown ? parent.width * 0.4
                             : parent.width * Math.min(100, root.busyProgress) / 100
                        height: parent.height
                        radius: parent.radius
                        color: root.colOn
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                        SequentialAnimation on x {
                            running: busyTrack.unknown && busyTrack.visible
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: busyTrack.width - busyFill.width
                                              duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { from: busyTrack.width - busyFill.width; to: 0
                                              duration: 900; easing.type: Easing.InOutSine }
                        }
                        onXChanged: if (!busyTrack.unknown) x = 0
                    }
                }

                // разделитель — чтобы работа читалась отдельно от часов
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 2
                    color: Qt.rgba(1, 1, 1, 0.14)
                }
            }

            // идёт запись — мигающая точка и таймер слева от даты
            RowLayout {
                spacing: 6
                visible: root.recActive

                Rectangle {
                    Layout.preferredWidth: 9
                    Layout.preferredHeight: 9
                    Layout.alignment: Qt.AlignVCenter
                    radius: 5
                    color: root.recPaused ? root.colWarn : root.colCrit
                    // на паузе точка горит ровно, при записи — пульсирует
                    SequentialAnimation on opacity {
                        running: root.recActive && !root.recPaused
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 620; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
                    }
                    onVisibleChanged: if (!visible) opacity = 1
                }
                Text {
                    text: root.recTimeText
                    color: root.recPaused ? root.colWarn : root.colCrit
                    font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                }
            }

            // Погода перед датой: значок и градусы. Виджетов на обоях у этой
            // темы нет, и остров — единственное место, где погода вообще
            // видна, поэтому она здесь, а не только на Nothing.
            RowLayout {
                spacing: 5
                visible: root.weatherReady && root.cfg.weatherOnIsland

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.weatherGlyph
                    color: islWthMa1.containsMouse ? root.colOn : root.colFg
                    font { family: root.fontFam; pixelSize: root.iconSize - 1 }
                }
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.weatherTemp + "°"
                    color: islWthMa1.containsMouse ? root.colOn : root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                }

                MouseArea {
                    id: islWthMa1
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openWeatherDetails()
                }

                // разделитель — чтобы погода читалась отдельно от даты
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 3
                    color: Qt.rgba(1, 1, 1, 0.14)
                }
            }

            Text {
                text: root.dayText
                color: root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            }
            Text {
                text: root.timeText
                color: root.colFg
                Layout.preferredWidth: mClock.width
                horizontalAlignment: Text.AlignHCenter
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }

            // номер текущего рабочего стола: перелистывается при смене
            FlipText {
                value: String(root.wsId)
                textColor: root.colFg
                fontFam: root.fontFam
                pixelSize: root.fontSize - 1
                minWidth: mWs.width
                Layout.alignment: Qt.AlignVCenter
            }

            // текущая раскладка: перелистывается при Alt+Shift
            FlipText {
                value: root.kbLayout
                textColor: root.kbLayout === "RU" ? root.tint("#7FB3FF") : root.colMuted
                fontFam: root.fontFam
                pixelSize: root.fontSize - 2
                Layout.alignment: Qt.AlignVCenter
            }

            // Место резервируется под самый широкий вариант («100%»), иначе
            // пилюля дышала бы на каждом проценте. Но раньше эталонная
            // ширина висела на самом числе, и весь запас копился между
            // иконкой и цифрами — на «48%» там зияла дыра. Теперь ширину
            // держит контейнер, а пара внутри стоит по центру вплотную.
            Item {
                // без батареи блока нет совсем: на настольной машине это не
                // «ноль процентов», а «нечему показываться»
                visible: root.batteryPresent
                Layout.preferredWidth: root.batteryPresent
                                       ? mBattIcon.width + battPair.spacing + mBatt.width : 0
                Layout.preferredHeight: root.pillH
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: battPair
                    anchors.centerIn: parent
                    spacing: 4

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
        }

        // ------------------------------------------ свёрнутое: Nothing
        // Часы стоят ровно по центру острова, столы — слева, состояние
        // машины — справа. Это не RowLayout: в строке часы уезжали бы от
        // центра каждый раз, когда слева появляется точка нового стола или
        // справа пропадают проценты заряда. Здесь края разведены по якорям,
        // а под них резервируется одинаковое место — часы стоят намертво.
        Item {
            id: nothingCapsule
            // Растянут на всю длину острова, а не сжат по содержимому.
            // Прижатый к своей ширине, он вставал посреди пилюли, и при
            // длине больше содержимого точки столов оказывались не у левого
            // края, а где-то в середине, вместе с остальным.
            //
            // implicitWidth при этом остаётся: по нему считается, короче
            // какой длины остров сжимать уже нельзя.
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            height: root.pillH
            visible: root.themeNothing && !root.expanded && !root.btToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
                     && !root.osdActive && !root.toastActive
            opacity: root.pillSide ? 0 : (visible ? 1 : 0)
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            // просвет между часами и крайними группами
            readonly property real armGap: 22

            // Место под точки столов: пять слотов по шесть пикселей, просветы
            // между ними и надбавка на текущий стол — он растекается в полосу
            // и шире остальных.
            readonly property int wsSlots: 5
            readonly property real wsReserve:
                nothingCapsule.wsSlots * 6
                + (nothingCapsule.wsSlots - 1) * nLeft.spacing
                + (17 - 6)
            // Обе группы получают ширину по большей из них: без этого часы
            // считались бы центром пустого места, а не острова.
            readonly property real arm:
                Math.max(nLeft.implicitWidth, nRight.implicitWidth)
            implicitWidth: nClock.implicitWidth + 2 * (nothingCapsule.arm + nothingCapsule.armGap)

            // ------------------------------------------- слева: столы
            RowLayout {
                id: nLeft
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Запись важнее столов и потому стоит первой: пока идёт
                // съёмка, об этом надо знать раньше всего остального.
                Rectangle {
                    Layout.preferredWidth: 7
                    Layout.preferredHeight: 7
                    Layout.alignment: Qt.AlignVCenter
                    radius: 4
                    visible: root.recActive
                    color: root.recPaused ? root.colWarn : root.colCrit
                    SequentialAnimation on opacity {
                        running: root.recActive && !root.recPaused
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 620; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
                    }
                    onVisibleChanged: if (!visible) opacity = 1
                }

                // Точки столов. Текущий — короткая белая полоса: номер стола
                // на острове всё равно никто не читал как число, важно лишь
                // «который по счёту из скольких», а это точки показывают
                // прямо, без чтения.
                //
                // Под них резервируется место на пять столов, даже когда их
                // меньше. Hyprland заводит и убирает столы на ходу, а от
                // числа точек зависела длина всего острова: часы стоят по его
                // центру, правая группа прижата к его краю — и на каждом
                // открытии четвёртого стола весь остров переставлялся. Пока
                // столов не больше пяти, теперь не меняется ничего.
                Item {
                    Layout.preferredWidth: Math.max(wsRow.implicitWidth,
                                                    nothingCapsule.wsReserve)
                    Layout.preferredHeight: 6
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        id: wsRow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: nLeft.spacing

                Repeater {
                    model: root.wsList

                    Rectangle {
                        required property var modelData
                        readonly property bool here: modelData === root.wsId
                        // Ширину держим своим свойством: Behavior не вешается
                        // на присоединённые Layout.*, а растекание точки в
                        // полосу без анимации — просто подмена картинки.
                        property real len: here ? 17 : 6

                        // Анимация включается после того, как точка встала на
                        // место. Иначе появление нового стола проигрывается
                        // как выезжающая полоса — а это не изменение, это
                        // первый кадр, и показывать его движением не за чем.
                        property bool settled: false
                        Component.onCompleted: settled = true

                        Layout.preferredWidth: len
                        Layout.preferredHeight: 6
                        Layout.alignment: Qt.AlignVCenter
                        radius: 3
                        color: root.colFg
                        opacity: here ? 1 : (wsMa.containsMouse ? 0.6 : 0.3)

                        Behavior on len {
                            enabled: settled
                            NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity {
                            enabled: settled
                            NumberAnimation { duration: root.animFast }
                        }

                        MouseArea {
                            id: wsMa
                            anchors.fill: parent
                            // по точке в шесть пикселей не попасть мышью,
                            // поэтому цель шире самой точки
                            anchors.margins: -5
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.gotoWorkspace(modelData)
                        }
                    }
                }
                    }
                }

                // Погода сразу за точками. Значок и градусы, без города и
                // слов: город человек и так знает, а описание словами на
                // острове не помещается — оно есть в карточке на обоях.
                RowLayout {
                    Layout.leftMargin: 6
                    spacing: 5
                    visible: root.weatherReady && root.cfg.weatherOnIsland

                    DotIcon {
                        Layout.alignment: Qt.AlignVCenter
                        code: root.weatherIcon
                        size: root.dotHClock
                        color: islWthMa2.containsMouse ? root.colOn : root.colFg
                    }
                    // Градусы обычным шрифтом. Точки оставлены часам и
                    // столам — тому, что на этой теме и должно быть набрано
                    // ими. Знак градуса в точечной сетке выходит квадратным
                    // кружком из четырёх точек, а он должен быть гладким.
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.weatherTemp + "°"
                        color: islWthMa2.containsMouse ? root.colOn : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize }
                    }

                    MouseArea {
                        id: islWthMa2
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openWeatherDetails()
                    }
                }
            }

            // --------------------------------------------- центр: часы
            DotText {
                id: nClock
                anchors.centerIn: parent
                value: root.timeText
                size: root.dotHClock
                // Жирность у точечной цифры — это плотность точек, а не
                // толщина линии: рисовать нечем, кроме них. Просвет ужат до
                // десятой доли, точки почти смыкаются, и цифра читается
                // плотной и ярко-белой.
                //
                // Так она догоняет по насыщенности крупные часы в панели, не
                // вырастая следом за ними: там та же цифра вдвое выше, и
                // яркой она выглядит просто из-за размера.
                gapRatio: 0.1
                color: root.colFg
            }

            // ------------------------------- справа: сеть, звук, заряд
            RowLayout {
                id: nRight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // Кабель вытесняет антенну: связь идёт по нему, и значок
                // Wi-Fi поверх работающего кабеля только сбивал бы с толку.
                //
                // Кабель нарисован фигурой, а не взят из шрифта: дерево сети
                // в Nerd Font идёт с перекладиной шире самих квадратов, и на
                // этом размере она читается полосой поперёк значка.
                // Размер задаётся через Layout.*, а не width/height: в
                // раскладке своя ширина элемента ничего не решает, её ставит
                // сама раскладка — по preferred, а без него по implicit.
                // Отсюда значок и оставался прежним, сколько ему ни
                // прописывай width.
                LanGlyph {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: root.iconSize - 6
                    Layout.preferredHeight: root.iconSize - 6
                    visible: root.wiredOn
                    color: root.colFg
                }
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    visible: !root.wiredOn
                    text: root.wifiOn ? (root.wifiQuality > 66 ? "󰤨"
                                       : root.wifiQuality > 33 ? "󰤥" : "󰤟") : "󰤮"
                    color: root.wifiOn ? root.colFg : root.colMuted
                    font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                }

                // Раскладка сразу за сетью. Буквами, а не точками: точечная
                // сетка знает цифры, а «RU» на ней пришлось бы рисовать
                // отдельно ради двух знаков.
                //
                // Текущая — в полную яркость, вторая приглушена: цветом их
                // на этой теме не развести, а разница нужна беглая.
                //
                // FlipText, а не обычная надпись: раскладку переключают
                // вслепую, посреди набора, и подтверждение нужно заметить
                // краем глаза. Подмена буквы без движения незаметна — здесь
                // она перелистывается, как и в обычном острове.
                FlipText {
                    Layout.alignment: Qt.AlignVCenter
                    value: root.kbLayout
                    textColor: root.kbLayout === "RU" ? root.colFg : root.colMuted
                    fontFam: root.fontFam
                    pixelSize: root.fontSize - 4
                    bold: true
                }

                RowLayout {
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: !root.sinkAudio ? String.fromCodePoint(0xF075F)
                            : root.sinkAudio.muted ? String.fromCodePoint(0xF075F)
                            : root.sinkAudio.volume < 0.34 ? String.fromCodePoint(0xF057F)
                            : root.sinkAudio.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                                           : String.fromCodePoint(0xF057E)
                        color: (root.sinkAudio && root.sinkAudio.muted)
                               ? root.colMuted : root.colFg
                        font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                    }

                    DotText {
                        Layout.alignment: Qt.AlignVCenter
                        value: root.sinkAudio
                               ? String(Math.round(root.sinkAudio.volume * 100)) : "0"
                        size: root.dotHSmall
                        color: (root.sinkAudio && root.sinkAudio.muted)
                               ? root.colMuted : root.colFg
                    }
                }

                // Заряда на настольной машине не существует — там этой пары
                // нет совсем, а не «ноль процентов».
                RowLayout {
                    spacing: 6
                    visible: root.batteryPresent

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.batteryIcon
                        color: root.batteryPct <= 15 && !root.acOnline
                               ? root.colCrit : root.colFg
                        font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                    }

                    DotText {
                        Layout.alignment: Qt.AlignVCenter
                        value: String(root.batteryPct)
                        size: root.dotHSmall
                        color: root.batteryPct <= 15 && !root.acOnline
                               ? root.colCrit : root.colFg
                    }
                }
            }
        }

            // Текст столбиком: каждая буква на своей строке. Повёрнутый на
            // 90° текст пришлось бы читать с наклонённой головой, а так
            // вертикальный остров остаётся читаемым.
            component VertText: Column {
                id: vt
                property string value: ""
                property color textColor: root.colFg
                property real size: root.fontSize
                property bool bold: false
                property int maxChars: 16

                spacing: -2
                Repeater {
                    model: String(vt.value).slice(0, vt.maxChars).split("")
                    Text {
                        required property string modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData === " " ? "·" : modelData
                        color: vt.textColor
                        font {
                            family: root.fontFam
                            pixelSize: vt.size
                            bold: vt.bold
                        }
                    }
                }
            }

            // ------------------------------------- вертикальный остров
            // У боковых кромок содержимое стоит столбиком и НЕ повёрнуто:
            // повёрнутый текст читается только с наклонённой головой. Поэтому
            // здесь свой набор — короткие значения, которые влезают в толщину
            // острова: часы двумя строками, стол, раскладка, заряд.
            ColumnLayout {
                id: vertCapsule
                anchors.centerIn: parent
                width: root.pillH
                spacing: 7
                visible: !root.expanded && !root.btToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
                opacity: root.pillSide ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.animFast } }

                // Играет музыка: обложка и эквалайзер. Названию в толщину
                // острова не поместиться, а повёрнутый текст не читается —
                // поэтому оно показывается подписью при наведении.
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: mediaCol.implicitHeight
                    visible: root.mediaActive

                ColumnLayout {
                    id: mediaCol
                    anchors.fill: parent
                    spacing: 5

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 7
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Image {
                            id: vertArt
                            anchors.fill: parent
                            source: root.mediaArt
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 64
                            visible: false
                            layer.enabled: true
                        }
                        Item {
                            id: vertArtMask
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            Rectangle { anchors.fill: parent; radius: 7; color: "#ffffff" }
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: vertArt
                            maskEnabled: true
                            maskSource: vertArtMask
                            visible: vertArt.status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: vertArt.status !== Image.Ready
                            text: "󰝚"
                            color: root.colMuted
                            font { family: root.fontFam; pixelSize: 11 }
                        }
                    }

                    // название трека столбиком: коротко, но читаемо
                    VertText {
                        Layout.alignment: Qt.AlignHCenter
                        value: root.player ? String(root.player.trackTitle || "") : ""
                        textColor: root.colFg
                        size: root.fontSize - 3
                        bold: true
                        maxChars: 10
                    }

                    // Тот же эквалайзер, что и в горизонтальном виде, только
                    // повёрнутый: полосы абстрактные, читать их не нужно.
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 28
                        WaveBars {
                            anchors.centerIn: parent
                            width: 28
                            height: 14
                            rotation: -90
                            barColor: root.colFg
                            active: root.player ? root.player.isPlaying : false
                        }
                    }

                }

                    // Клик открывает плеер, наведение показывает название:
                    // подпись рисует корень, поэтому текст остаётся прямым.
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            var t = root.player ? String(root.player.trackTitle || "") : "";
                            if (t.length === 0) return;
                            var p = mapToItem(null, width / 2, height / 2);
                            root.showTip(t, p.x, p.y);
                        }
                        onExited: root.hideTip(root.player
                                               ? String(root.player.trackTitle || "") : "")
                        onClicked: root.togglePage("media")
                    }
                }

                // идёт запись экрана
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    visible: root.recActive
                    color: root.recPaused ? root.colWarn : root.colCrit
                }

                // Черта отделяет музыку от постоянной части — как в
                // горизонтальном виде она стоит между cava и днём недели.
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 1
                    visible: root.mediaActive
                    color: Qt.rgba(1, 1, 1, 0.18)
                }

                // день недели столбиком
                VertText {
                    Layout.alignment: Qt.AlignHCenter
                    value: root.dayText
                    textColor: root.colMuted
                    size: root.fontSize - 2
                    bold: true
                }

                // часы: часы и минуты отдельными строками
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.timeText.split(":")[0] || ""
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: (root.timeText.split(":")[1] || "").replace(/[^0-9]/g, "")
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: String(root.wsId)
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.kbLayout
                    color: root.kbLayout === "RU" ? root.tint("#7FB3FF") : root.colMuted
                    font { family: root.fontFam; pixelSize: root.fontSize - 4; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.batteryPresent
                    text: root.batteryIcon
                    color: root.batteryCharging || root.acOnline ? root.colOk
                         : root.batteryPct <= 15 ? root.colCrit : root.colMuted
                    font { family: root.fontFam; pixelSize: root.fontSize - 1 }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.batteryPresent
                    text: root.batteryPct
                    color: root.colMuted
                    font { family: root.fontFam; pixelSize: root.fontSize - 4 }
                }
            }

        // ------------------------------------------------------- ручка переноса
        // Полоса над содержимым: тянут за неё, а не за всю панель — иначе
        // любое движение по плиткам таскало бы остров. Видна только когда
        // перенос разрешён и открыты быстрые настройки.
        Item {
            id: dragHandle
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 16
            z: 60
            visible: root.cfg.pillDrag && root.expanded && root.page === "main"
                     && !root.settingsMode

            Rectangle {
                anchors.centerIn: parent
                width: 46
                height: 4
                radius: 2
                color: root.pillDragging ? root.colOn
                     : (handleMa.containsMouse ? Qt.rgba(1, 1, 1, 0.45)
                                               : Qt.rgba(1, 1, 1, 0.18))
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            MouseArea {
                id: handleMa
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: root.pillDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real pressX: 0
                property real pressY: 0

                onPressed: mouse => {
                    var p = mapToItem(null, mouse.x, mouse.y);
                    handleMa.pressX = p.x;
                    handleMa.pressY = p.y;
                    root.pillDragging = true;
                }
                onPositionChanged: mouse => {
                    if (!root.pillDragging) return;
                    var p = mapToItem(null, mouse.x, mouse.y);
                    root.dragDX = p.x - handleMa.pressX;
                    root.dragDY = p.y - handleMa.pressY;
                    root.dragEdge = root.edgeAt(capsule.x + root.dragDX + capsule.width / 2,
                                                capsule.y + root.dragDY + capsule.height / 2);
                }
                onReleased: root.dropPill()
                onCanceled: root.dropPill()
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
            // Пока показывается карточка выбора экрана (или тост), контент
            // раскрытой панели не рисуем: при старте записи из quick settings
            // панель сворачивается, а её содержимое иначе видно ещё пару кадров
            // позади карточки — экраны «проблёскивали».
            active: (root.expanded || capsule.height > root.pillH + 4)
                    && !root.recPickActive && !root.btToastActive
                    && !root.acToastActive && !root.voxActive
            visible: !root.recPickActive && !root.btToastActive && !root.acToastActive && !root.voxActive
            // без этого клавиатура не доходила до содержимого страницы:
            // сам Loader фокуса не имел, и forceActiveFocus() внутри вида
            // ни к чему не приводил
            focus: true
            onLoaded: if (item) item.forceActiveFocus()
            // Esc закрывает любую страницу: если сам вид его не обработал
            // (или обработал только на подстранице), событие всплывает сюда.
            // Сначала спрашиваем вид, есть ли ему куда вернуться: со списка
            // сетей или устройств Escape должен уводить к плиткам, а не
            // захлопывать панель целиком.
            Keys.onEscapePressed: {
                var it = contentLoader.item;
                if (it && typeof it.goBack === "function" && it.goBack()) return;
                root.collapse();
            }
            opacity: root.expanded ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: root.expanded ? root.animFast : 70 }
            }

            sourceComponent: root.page === "launcher" ? launcherComp
                           : root.page === "settings" ? settingsComp
                           : root.page === "clip"     ? clipComp
                           : root.page === "power"    ? powerComp
                           : root.page === "notif"    ? notifComp
                           : root.page === "audio"    ? audioComp
                           : root.page === "cal"      ? calComp
                           : root.page === "record"   ? recordComp
                           : root.page === "files"    ? filesComp
                           : root.page === "media"    ? mediaComp
                           : root.page === "auth"     ? authComp
                           : root.page === "vault"    ? vaultComp
                           : root.page === "vaultsave" ? vaultSaveComp
                           : root.page === "agents"   ? agentsComp
                                                      : controlsComp
        }

        Component { id: controlsComp; ControlsView { sys: root } }
        Component { id: launcherComp; LauncherView { sys: root } }
        Component { id: settingsComp; SettingsView { sys: root; tab: root.settingsTab } }
        Component { id: clipComp;     ClipboardView { sys: root } }
        Component { id: powerComp;    PowerView { sys: root } }
        Component { id: notifComp;    NotificationsView { sys: root } }
        Component { id: audioComp;    AudioView { sys: root } }
        Component { id: calComp;      CalendarView { sys: root } }
        Component { id: recordComp;   RecordView { sys: root } }
        Component { id: filesComp;    FilesView { sys: root } }
        Component { id: mediaComp;    MediaView { sys: root } }
        Component { id: authComp;     AuthView { sys: root } }
        Component { id: vaultComp;     VaultView { sys: root } }
        Component { id: vaultSaveComp; VaultSaveView { sys: root } }
        Component { id: agentsComp;    AgentsView { sys: root } }
    }

    // ------------------------------------------------------- общий тултип
    // Панель настроек обрезается капсулой (clip), и подпись, выходящая за её
    // левый край, там просто исчезала. Поэтому тултип рисует сам корень:
    // вид сообщает текст и точку, от которой раскрываться влево.
    property string tipText: ""
    property real   tipX: 0
    property real   tipY: 0
    function showTip(text, x, y) { root.tipText = text; root.tipX = x; root.tipY = y; }
    function hideTip(text) { if (root.tipText === text) root.tipText = ""; }

    Rectangle {
        id: globalTip
        z: 200
        visible: opacity > 0.01
        opacity: root.tipText.length > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 130 } }

        width: globalTipText.implicitWidth + 20
        height: 26
        radius: 13
        x: Math.max(6, root.tipX - width - 10)
        y: root.tipY - height / 2
        color: Qt.rgba(0.04, 0.04, 0.05, 0.98)
        border.color: root.colLine
        border.width: 1

        scale: root.tipText.length > 0 ? 1 : 0.92
        transformOrigin: Item.Right
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        Text {
            id: globalTipText
            anchors.centerIn: parent
            text: root.tipText
            color: root.colFg
            font { family: root.fontFam; pixelSize: 11 }
        }
    }

    // ------------------------------------ плавное примыкание к кромке экрана
    // Два вогнутых уголка по бокам: переход от кромки к пилюле без ступеньки.
    // Вогнутые уголки примыкания: цепляются к той же кромке, что и остров, и
    // стоят с двух его сторон. Форма выбирается по кромке: у вертикального
    // острова та же четверть круга, только развёрнутая — заливка должна
    // прижиматься к краю экрана и к торцу капсулы.
    NotchCorner {
        id: notchBefore
        // «до» острова: слева от него, а у боковых кромок — над ним
        side: root.pillSide ? (root.pillAtLeft ? "right" : "left") : "left"
        fill: root.colBg
        r: root.cornerR
        transform: Scale {
            origin.y: root.cornerR / 2
            yScale: root.pillSide ? -1 : (root.pillAtBottom ? -1 : 1)
        }
        // Округляем: уголок — отдельный элемент со своими координатами, и на
        // полпикселя от капсулы он расходится с ней сглаженной серой щелью.
        x: root.pillAtLeft  ? 0
         : root.pillAtRight ? parent.width - width
                            : Math.round(capsule.x) - width
        y: root.pillSide ? capsule.y - height
         : root.pillAtBottom ? parent.height - height : 0
        // Уголки уходят вместе с островом: в настройках он отрывается от
        // кромки, а на карусели обоев прячется целиком.
        opacity: root.cornersOn ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.animFast } }
    }
    NotchCorner {
        id: notchAfter
        // «после» острова: справа от него, а у боковых кромок — под ним
        side: root.pillSide ? (root.pillAtLeft ? "right" : "left") : "right"
        fill: root.colBg
        r: root.cornerR
        transform: Scale {
            origin.y: root.cornerR / 2
            yScale: root.pillSide ? 1 : (root.pillAtBottom ? -1 : 1)
        }
        // Здесь дробность копится вдвое — из x капсулы и из её ширины, —
        // поэтому именно правый уголок и отходил заметнее левого.
        x: root.pillAtLeft  ? 0
         : root.pillAtRight ? parent.width - width
                            : Math.round(capsule.x + capsule.width)
        y: root.pillSide ? capsule.y + capsule.height
         : root.pillAtBottom ? parent.height - height : 0
        opacity: root.cornersOn ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.animFast } }
    }
}

// Обзор рабочих столов — отдельный полноэкранный слой: пилюля тут ни при
// чём, а клавиатура нужна целиком.
LazyLoader {
    activeAsync: root.overviewOpen

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.overviewOpen ? WlrKeyboardFocus.Exclusive
                                                       : WlrKeyboardFocus.None
        visible: root.overviewOpen

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            opacity: root.overviewOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        // Обзор столов создаётся сразу и живёт вместе с оболочкой.
        // Ленивая загрузка тут не прижилась: слой всплывает по Super+Tab, и
        // отдавать его создание на момент нажатия — значит рисковать самим
        // нажатием ради пары мегабайт. Тяжёлые превью окон и так живые только
        // пока слой открыт.
        OverviewView {
            anchors.fill: parent
            sys: root
        }
    }
}

// Обои — тоже свой полноэкранный слой: карусель раскрывается по центру
// экрана, а клавиатура нужна ей целиком (стрелки, Enter, Esc).
LazyLoader {
    // Собираем слой заранее — как только прочитан список обоев. Иначе первое
    // открытие уходило на создание трёх сотен карточек, и полсекунды экран
    // был пустым.
    activeAsync: root.wallsOpen || root.wallListReady

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.wallsOpen ? WlrKeyboardFocus.Exclusive
                                                    : WlrKeyboardFocus.None
        // окно живёт всё время, но показывается только на открытии
        visible: root.wallsOpen || wallsFade.opacity > 0.01

        Rectangle {
            id: wallsFade
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.62)
            opacity: root.wallsOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animMs } }
        }

        // Раскрывается из острова: точка роста — та кромка, где он висит,
        // поэтому карусель выглядит развернувшейся пилюлей, а не отдельным
        // окном, приехавшим со стороны.
        // Карусель обоев. Слой над ней уже ленивый (LazyLoader выше строит
        // его только когда прочитан список обоев), а сами картинки грузятся
        // по мере показа — второй уровень ленивости лишь ломал открытие.
        WallpapersView {
            anchors.fill: parent
            sys: root
        }
    }
}

// Клавиши (Super + /) — свой полноэкранный слой, а не тайлящееся окно:
// раскрывается из острова по центру экрана и так же складывается обратно.
LazyLoader {
    activeAsync: root.keysWindowOpen

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.keysWindowOpen ? WlrKeyboardFocus.Exclusive
                                                         : WlrKeyboardFocus.None
        visible: root.keysWindowOpen || keysScrim.opacity > 0.01

        Rectangle {
            id: keysScrim
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.62)
            opacity: root.keysWindowOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animMs } }
        }

        // клик мимо карточки закрывает — как у обзора столов и карусели обоев
        MouseArea {
            anchors.fill: parent
            onClicked: root.keysWindowOpen = false
        }

        // Карточка начинает ровно в геометрии капсулы и растёт до своего
        // размера по центру: получается развернувшийся остров, а не окно,
        // приехавшее со стороны.
        Rectangle {
            id: keysCard
            readonly property real fullW: Math.min(1280, parent.width - 80)
            readonly property real fullH: Math.min(940, parent.height - 80)

            color: root.colBg
            clip: true
            x: root.keysWindowOpen ? (parent.width - fullW) / 2 : root.pillRectX
            y: root.keysWindowOpen ? (parent.height - fullH) / 2 : root.pillRectY
            width:  root.keysWindowOpen ? fullW : Math.max(8, root.pillRectW)
            height: root.keysWindowOpen ? fullH : Math.max(8, root.pillRectH)
            radius: root.keysWindowOpen ? 26 : Math.min(width, height) / 2

            Behavior on x      { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }
            Behavior on y      { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }
            Behavior on width  { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }
            Behavior on height { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }
            Behavior on radius { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }

            // Прокрутки нет: список разложен в три колонки и целиком
            // помещается в карточку, а сама она занимает почти весь экран.
            // За сочетанием заглядывают на секунду, посреди другой работы —
            // искать его колесом дольше, чем вспоминать самому.
            SetKeys {
                id: keysBody
                anchors.fill: parent
                anchors.margins: 26
                sys: root
                // содержимое проявляется вслед за карточкой: на первых кадрах
                // она ещё размером с пилюлю, и список в неё не влезает
                opacity: root.keysWindowOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.animMs } }
            }
        }
    }
}

// Экран «что нового» после обновления. Отдельным слоем поверх всего: его
// показывают один раз, и он должен перехватывать клавиатуру.
PanelWindow {
    visible: root.whatsNewOpen
    anchors { top: true; bottom: true; left: true; right: true }
    screen: root.screen
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.whatsNewOpen ? WlrKeyboardFocus.Exclusive
                                                   : WlrKeyboardFocus.None

    Loader {
        anchors.fill: parent
        active: root.whatsNewOpen
        sourceComponent: WhatsNewView {
            sys: root
            lines: root.whatsNew
        }
    }
}


// Проводник отдельным окном. Живёт на уровне ShellRoot, а не внутри
// пилюли: окно не может быть ребёнком другого окна.
Instantiator {
    model: filesWindows

    FloatingWindow {
        required property var model
        title: "Panacea · " + root.tr("Проводник")
        color: root.colBg
        minimumSize.width: 720
        minimumSize.height: 460
        visible: true
        // крестик в заголовке — окно должно уйти и из списка
        onVisibleChanged: if (!visible) root.closeFilesWindow(model.wid)

        FilesView {
            anchors.fill: parent
            anchors.margins: 15
            sys: root
            // папка, с которой окно открылось (пусто — домашняя)
            dir: model.startDir
            // в оконном режиме закрывать надо своё окно, а не пилюлю
            windowMode: true
            windowId: model.wid
        }
    }
}

// Стоп-кадр под выделение области скриншота.
//
// Обычное «выдели область и сними» выделяет по живому экрану, и снять то,
// что закрывается от первого движения мыши — меню, всплывающую подсказку,
// список автодополнения — нечем: пока тянешь рамку, снимать уже нечего.
// Поэтому shot.sh сначала снимает экран целиком, показывает снимок этим
// слоем поверх всего, и только потом запускает выделение. Итоговый кадр
// снимается с замершего слоя, так что обрезать исходный файл не нужно —
// иначе понадобился бы ещё и ImageMagick.
//
// Окно детального прогноза погоды на несколько дней
PanelWindow {
    id: weatherDetailsWin
    visible: root.weatherDetailsOpen
    anchors { top: true; bottom: true; left: true; right: true }
    screen: root.screen
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.weatherDetailsOpen ? WlrKeyboardFocus.Exclusive
                                                         : WlrKeyboardFocus.None

    // Затемнение фона при клике на которое окно закрывается
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: root.weatherDetailsOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.weatherDetailsOpen = false
        }
    }

    Keys.onEscapePressed: root.weatherDetailsOpen = false

    WeatherDetailsView {
        anchors.centerIn: parent
        sys: root
        forecastData: root.weatherForecastData
        scale: root.weatherDetailsOpen ? 1 : 0.93
        opacity: root.weatherDetailsOpen ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }
}

// ---------------------------------------------------- настольные виджеты
// Карточки на обоях: дата, погода, часы. Раскладка у них общая для тем, а
// начертание своё: на Nothing числа точками, на остальных обычным шрифтом.
// Выбирает его сама карточка — слою достаточно знать, включены ли виджеты.
//
// Слой Bottom: над обоями, но под окнами.
// Область ввода ограничена карточками виджетов: клик по карточке погоды
// открывает подробный прогноз, а пустой рабочий стол остаётся свободным.
PanelWindow {
    id: widgetsWin

    visible: root.cfg.featWidgets
    screen: root.screen
    anchors { top: true; left: true }
    implicitWidth:  widgets.implicitWidth + 56
    implicitHeight: widgets.implicitHeight + 56
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: widgets }

    WidgetsView {
        id: widgets
        sys: root
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 28
        // ниже острова: тот стоит по центру верхней кромки и до левого
        // угла не достаёт, но запас нужен под его вогнутый уголок
        anchors.topMargin: 28
    }
}

// Слой на каждый экран, а не один на root.screen: grim снимает всю раскладку
// одной картинкой, и каждое окно показывает свой её кусок, сдвинув снимок на
// начало своего экрана.
Variants {
    model: root.freezeShot !== "" ? Quickshell.screens : []

    PanelWindow {
        id: freezeWin
        required property var modelData

        screen: freezeWin.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        color: "black"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        // Кадр только показывается. Клавиатура и мышь целиком достаются
        // выделению: с непустой областью ввода клики уходили бы в этот слой,
        // и рамку было бы нечем тянуть.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Image {
            // grim снимает раскладку в физических пикселях, а поверхности
            // экранов — логические (при масштабе 200% вдвое меньше). Рисовать
            // кадр «пиксель в пиксель» нельзя: на масштабированном экране виден
            // был бы только верхний левый угол — экран будто «зумило», и снять
            // весь экран не получалось. Поэтому растягиваем весь кадр в
            // логические границы раскладки и сдвигаем на начало своего экрана —
            // получается ровно 1:1 с тем, что на экране, при любом масштабе.
            x: root.freezeBounds.x - freezeWin.modelData.x
            y: root.freezeBounds.y - freezeWin.modelData.y
            width: root.freezeBounds.width
            height: root.freezeBounds.height
            source: root.freezeShot
            fillMode: Image.Stretch
            smooth: true
            // Файл временный и каждый раз новый, но имя может повториться —
            // кэш отдал бы прошлый снимок.
            cache: false
        }
    }
}

}
