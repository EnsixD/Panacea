import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
            // разрешено ли переносить остров мышью прямо на экране
            property bool   pillDrag: false
            property int    panelW: 540
            property int    cornerR: 14
            property int    animMs: 230
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
        "Настройки": "Settings",
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
        "Запись экрана": "Screen recording",
        "Проводник": "File manager",
        "Домашняя": "Home",
        "Просто печатайте": "Just type",
        "Ничего не найдено": "Nothing found",
        "Пусто": "Empty",
        "Чем открыть": "Open with",
        "по умолчанию": "default",
        "Подходящих программ не нашлось": "No matching apps",
        "В корзину: ": "Trashed: ",
        "В корзину": "Move to trash",
        "Открыть": "Open",
        "Открыть папку": "Open folder",
        "Открыть с помощью…": "Open with…",
        "Копировать": "Copy",
        "Вырезать": "Cut",
        "Вставить": "Paste",
        "Переименовать": "Rename",
        "Копировать путь": "Copy path",
        "Свойства": "Properties",
        "Тип": "Type",
        "Внутри": "Contains",
        "элементов": "items",
        "Размер": "Size",
        "байт": "bytes",
        "Разрешение": "Resolution",
        "Длительность": "Duration",
        "Изменён": "Modified",
        "Создан": "Created",
        "Права": "Permissions",
        "Владелец": "Owner",
        "Путь": "Path",
        "Создать папку": "New folder",
        "Обновить": "Refresh",
        "Новая папка": "New folder",
        "Имя": "Name",
        "Загрузки": "Downloads",
        "Документы": "Documents",
        "Изображения": "Pictures",
        "Видео": "Videos",
        "Музыка": "Music",
        "Рабочий стол": "Desktop",
        "Корзина": "Trash",
        "Очистить корзину": "Empty trash",
        "Корзина очищена": "Trash emptied",
        "Сохранено: ": "Saved: ",
        "Режу…": "Cutting…",
        "Выделите область мышью": "Drag to select an area",
        "Начало здесь": "Start here",
        "Конец здесь": "End here",
        "Куда": "Where",
        "Рядом": "Next to original",
        "Сохранить кусок": "Save clip",
        "Сохранить область": "Save selection",
        "Скопировано: ": "Copied: ",
        "Вырезано: ": "Cut: ",
        "Вставлено: ": "Pasted: ",
        "Перемещено: ": "Moved: ",
        "Путь скопирован": "Path copied",
        "Переименовано": "Renamed",
        "Папка создана": "Folder created",
        "ПКМ — меню · Enter — открыть · Backspace — назад · Esc — закрыть":
            "Right-click for menu · Enter to open · Backspace to go up · Esc to close",
        "Enter — открыть · Backspace — назад · Delete — в корзину · Esc — закрыть":
            "Enter to open · Backspace to go up · Delete to trash · Esc to close",
        "Запись": "Recording",
        "Идёт запись": "Recording",
        "Готово к записи": "Ready to record",
        "Начать запись": "Start recording",
        "Пауза": "Pause",
        "Продолжить": "Resume",
        "Закончить": "Finish",
        "Звук системы": "System audio",
        "Микрофон": "Microphone",
        "По умолчанию": "Default",
        "Открыть папку с записями": "Open recordings folder",
        "Папка": "Folder",
        "Файл ляжет в ": "Saves to ",
        "Запись уже идёт": "Already recording",
        "Не удалось начать запись": "Could not start recording",
        "Меню": "Menu",
        "Меню пустое": "Menu is empty",
        "Закрыть окно": "Close window",
        "Пароли": "Passwords",
        "Менеджер паролей": "Password manager",
        "записей": "entries",
        "Введите пароль пользователя": "Enter your user password",
        "Пароль": "Password",
        "Пароль пользователя": "User password",
        "Проверка…": "Checking\u2026",
        "Неверный пароль": "Wrong password",
        "Не удалось проверить пароль": "Could not verify the password",
        "Хранилище не открылось": "The vault did not open",
        "Ошибка хранилища": "Vault error",
        "Не удалось сохранить": "Could not save",
        "Хранилище шифруется этим же паролем и закрывается само через 15 минут простоя.": "The vault is encrypted with that same password and locks itself after 15 idle minutes.",
        "Поиск": "Search",
        "Новая запись": "New entry",
        "Без названия": "Untitled",
        "Название": "Name",
        "Логин": "Login",
        "Логин (необязательно)": "Login (optional)",
        "Откуда пароль": "Where it is from",
        "Пока ни одного пароля": "No passwords yet",
        "Сохранить": "Save",
        "Из браузеров": "From browsers",
        "Из браузера": "From a browser",
        "Ищем в браузерах…": "Searching browsers…",
        "Не удалось прочитать браузеры": "Could not read the browsers",
        "В браузерах ничего нового": "Nothing new in the browsers",
        "Найдено в браузерах": "Found in browsers",
        "Добавить все": "Add all",
        "Добавить": "Add",
        "Скрыть": "Hide",
        "обои": "wallpapers",
        "Темы": "Themes",
        " · сохранена": " · saved",
        "Кроп": "Crop",
        "Сохранить кусок с кропом": "Save the crop",
        "Система": "System",
        "О системе": "About",
        "автор Panacea": "author of Panacea",
        "Ядро": "Kernel",
        "Композитор": "Compositor",
        "Оболочка": "Shell",
        "Процессор": "CPU",
        "Память": "Memory",
        "Экран": "Display",
        "Аптайм": "Uptime",
        "Кадров в секунду": "Frames per second",
        "Писать звук системы": "Record system audio",
        "Писать микрофон": "Record microphone",
        "Что включено": "Enabled features",
        "Выключенная страница пропадает из пилюли вместе со своей кнопкой.": "A disabled page leaves the pill together with its button.",
        "Громкость и яркость на экране": "Volume and brightness overlay",
        "Быстрые клавиши": "Shortcuts cheat sheet",
        "Проводник отдельным окном": "File manager as a window",
        "Тайлится в Hyprland, живёт на своём рабочем столе и не трогает пилюлю.": "Tiled by Hyprland, stays on its workspace and leaves the pill alone.",
        "Диски": "Disks",
        "Съёмные": "Removable",
        "Скопировать сюда": "Copy here",
        "Переместить сюда": "Move here",
        "Перенесите файлы сюда": "Drop files here",
        "Рабочие столы": "Workspaces",
        "Обзор столов": "Workspace overview",
        "Стрелки — выбрать · Enter — перейти · Esc — закрыть": "Arrows to pick · Enter to switch · Esc to close",
        "Сортировка": "Sort",
        "Имя": "Name",
        "Дата": "Date",
        "Размер": "Size",
        "Тип": "Type",
        "Папки сверху": "Folders first",
        "Свои обои": "Your wallpaper",
        "Название обоев": "Wallpaper name",
        "Например, Закат": "e.g. Sunset",
        "Сохранить пароль?": "Save this password?",
        "Он попадёт в менеджер паролей": "It will go to the password manager",
        "Сначала откройте хранилище своим паролем": "Unlock the vault with your password first",
        "Не сохранять": "Don\u0027t save",
        "Предлагать сохранять пароли": "Offer to save passwords",
        "ОК": "OK",
        "Во весь экран": "Fullscreen",
        "Уведомления": "Notifications",
        "Заблокировано": "Locked",
        "колесо": "wheel",
        "ЛКМ": "left click",
        "ПКМ": "right click",
        "Листать рабочие столы": "Cycle workspaces",
        "Перетащить окно": "Drag window",
        "Средняя кнопка мыши": "Middle mouse button",
        "Плавающее окно": "Floating window",
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
        "оформление системы": "system appearance",
        "Применяю…": "Applying…",
        "Результат скопирован": "Result copied",
        "Требуются права": "Authentication required",
        "Подтвердить": "Authenticate",
        "Отмена": "Cancel",
        "Календарь": "Calendar",
        "Сегодня": "Today",
        "Звук": "Sound",
        "Устройство вывода": "Output device",
        "Нет устройств": "No devices",
        "Громкость": "Volume",
        "Трей": "Tray",
        "Активные": "Active",
        "История": "History",
        "Нет активных": "Nothing active",
        "Уведомления": "Notifications",
        "Не беспокоить": "Do not disturb",
        "Очистить": "Clear",
        "Пока ничего нет": "Nothing yet",
        "Режим «не беспокоить» включён": "Do not disturb is on",
        "с": "s",
        "Нажмите сочетание…": "Press a shortcut…",
        "Нажмите на сочетание, чтобы изменить. × убирает клавишу.":
            "Click a shortcut to change it. \u00d7 removes it.",
        "Сочетания правятся в ~/.config/hypr/lua/keybindings.lua":
            "Shortcuts live in ~/.config/hypr/lua/keybindings.lua",
        "Поиск в буфере": "Search clipboard",
        "Изображение": "Image",
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
        "Батарея": "Battery",
        "Режим": "Mode",
        "Ёмкость": "Capacity",
        "Износ": "Health",
        "От сети": "On AC",
        "Заряжается": "Charging",
        "Поиск приложений": "Search apps",
        "Сети": "Networks",
        "Устройства": "Devices",
        "Назад": "Back",
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
        "Сопряжение…": "Pairing…",
        "Подключение…": "Connecting…",
        "Устройства не найдены": "No devices found",
        "мс": "ms",
        "Сохранено": "Saved",
        "Обои": "Wallpapers",
        "Положение": "Position",
        "Переносить остров мышью": "Drag the island with the mouse",
        "Раскройте быстрые настройки и потяните за полосу над часами. У кромки остров прицепится к её центру, в пустоте — вернётся на место.":
            "Open quick settings and drag the bar above the clock. Near an edge the island snaps to its centre; in open space it returns where it was.",
        "Сейчас: ": "Now: ",
        "Живые обои": "Live wallpapers",
        "Папка живых обоев": "Live wallpaper folder",
        "Папка живых обоев пуста": "The live wallpaper folder is empty",
        // подписи макета проводника в настройках
        "Картинки": "Pictures",
        "объектов": "items",
        "вчера": "yesterday",
        "сегодня": "today",
        "9 авг": "9 Aug",
        "8 авг": "8 Aug",
        "7 авг": "7 Aug",
        "ГБ": "GB",
        "МБ": "MB",
        "КБ": "KB",
        "По центру экрана": "Centred panel",
        "раскрывается из острова": "unfolds from the island",
        "Отдельным окном": "Separate window",
        "тайлится в Hyprland": "tiled by Hyprland",
        "Читаю…": "Reading…",
        "Положение на экране": "Screen position",
        "Раскрытие всегда идёт к центру экрана.": "It always opens towards the centre.",
        "Обоев не найдено": "No wallpapers found",
        "выбрать": "choose",
        "поставить": "apply",
        "закрыть": "close",
        "Экраны": "Displays",
        "Настроить": "Configure",
        "Раскладка": "Arrangement",
        "Расширить": "Extend",
        "общий стол": "one desktop",
        "Дублировать": "Duplicate",
        "одна картинка": "same picture",
        "Только один": "Single",
        "остальные погасить": "others off",
        "Показывать на": "Show on",
        "Второй экран": "Second display",
        "Справа": "Right",
        "Слева": "Left",
        "Сверху": "Above",
        "Снизу": "Below",
        "Разрешение": "Resolution",
        "Частота": "Refresh rate",
        "родное": "native",
        "Масштаб": "Scale",
        "Ориентация": "Orientation",
        "Обычная": "Landscape",
        "Повёрнут вправо": "Rotated right",
        "Повёрнут влево": "Rotated left",
        "Вверх ногами": "Upside down",
        "Экран включён": "Display on",
        "Переменная частота (VRR)": "Variable refresh rate",
        "Определить экраны": "Detect displays",
        "Экраны не найдены": "No displays found",
        "Основной": "Primary",
        "Дубль": "Mirror",
        "Изменения применятся по кнопке «Применить».":
            "Changes take effect on Apply.",
        "Такой масштаб даёт нецелый размер стола — Hyprland его не примет.":
            "This scale gives a fractional desktop size — Hyprland will reject it.",
        "Дубли повторяют картинку основного экрана: у них своё разрешение, но общая раскладка.":
            "Mirrors repeat the primary display: own resolution, shared layout."
    })

    readonly property bool isEn: cfg.lang === "en"
    function tr(k) { return isEn && dictEn[k] !== undefined ? dictEn[k] : k; }

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
    function syncGreeterLocale() {
        pGreeterLocale.running = false;
        pGreeterLocale.running = true;
    }
    onIsEnChanged: syncGreeterLocale()

    readonly property string scriptDir:
        Quickshell.env("HOME") + "/.config/panacea/scripts"

    // capture.sh off зовёт этот IPC, чтобы панель сняла режим захвата
    signal cancelCaptureRequested()

    // Какая вкладка настроек откроется: 0 — пилюля, 2 — экран, 3 — клавиши.
    property int settingsTab: 0

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
    Connections {
        target: cfgFile
        function onSaved() { root.runGenBinds(); }
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
    }

    // Где именно сейчас стоит капсула. Нужно карусели обоев: она начинает
    // разворот ровно из острова, поэтому ей нужны его координаты.
    property real pillRectX: 0
    property real pillRectY: 0
    property real pillRectW: 0
    property real pillRectH: 0
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
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
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
        }
    }
    Component.onCompleted: {
        fsProbe.restart();
        syncGreeterLocale();
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
        // Страницу НЕ сбрасываем сразу: панель ещё едет вниз, и подмена
        // содержимого на «главную» успевала мелькнуть. Сбросим, когда
        // капсула действительно схлопнется.
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
                 : (wideSettings ? 1300 : 720);
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
    property var stickyPlayer: null
    readonly property var player: {
        var list = Mpris.players ? Mpris.players.values : [];
        var playing = null, any = null, stickyAlive = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p) continue;
            if (!any) any = p;
            if (p === root.stickyPlayer) stickyAlive = p;
            if (p.isPlaying && !playing) playing = p;
        }
        // играющий побеждает; иначе прежний, если он ещё жив; иначе любой
        return playing || stickyAlive || any;
    }
    onPlayerChanged: { if (player) stickyPlayer = player; refreshMediaArt(); }
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
    // По ready сводного устройства, а не по isLaptopBattery: у displayDevice
    // это составной агрегат, и признак ноутбучной батареи на нём не выставлен.
    readonly property bool batteryPresent: battDev !== null && battDev.ready

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

    // ------------------------------------------------------- звук: устройства
    // Список выходов и переключение между ними. Раньше сменить устройство
    // было нечем: pavucontrol в системе нет.
    readonly property var audioSinks: {
        var out = [];
        var all = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && n.isSink && !n.isStream) out.push(n);
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
    property bool dnd: false                 // не беспокоить
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
        root.focusApp(hint);
        root.dismissToast();
        if (id >= 0) root.dropNotification(id);
        // не раскрываемся под курсором после клика — до тех пор, пока курсор
        // не уйдёт с пилюли
        root.hoverExpandArmed = false;
        root.collapse();
    }

    readonly property bool toastActive: notifCurrent !== null && !expanded
    readonly property string notifSummary: notifCurrent ? String(notifCurrent.summary || "") : ""
    readonly property string notifBody:    notifCurrent ? String(notifCurrent.body || "") : ""
    readonly property string notifApp:     notifCurrent ? String(notifCurrent.appName || "") : ""
    readonly property string notifImage:   notifCurrent ? String(notifCurrent.image || "") : ""
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

            notifModel.insert(0, {
                nId: Number(n.id),
                nSummary: String(n.summary || ""),
                nBody: String(n.body || ""),
                nApp: String(n.appName || ""),
                nImage: String(n.image || ""),
                nUrgent: n.urgency === NotificationUrgency.Critical,
                nTime: Qt.formatDateTime(new Date(), "HH:mm")
            });
            while (notifModel.count > 50) notifModel.remove(notifModel.count - 1);

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
        var ms = n.expireTimeout > 0 ? n.expireTimeout * 1000 : 4500;
        toastTimer.interval = Math.max(2000, Math.min(12000, ms));
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

    Connections {
        target: root.sinkAudio
        enabled: root.sinkAudio !== null
        function onVolumeChanged() {
            if (root.osdReady) root.showOsd("vol", root.sinkAudio.volume, root.sinkAudio.muted);
        }
        function onMutedChanged() {
            if (root.osdReady) root.showOsd("vol", root.sinkAudio.volume, root.sinkAudio.muted);
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
    Timer { interval: 10000; running: true; repeat: true; onTriggered: pPowerGet.running = true }

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
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            // 12-часовой формат — с AM/PM, 24-часовой — без
            root.timeText = root.cfg.clock12
                ? Qt.formatDateTime(d, "h:mm AP")
                : Qt.formatDateTime(d, "HH:mm");
            root.dateLong = root.isEn
                ? Qt.formatDateTime(d, "dddd, d MMMM")
                : Qt.formatDateTime(d, "dddd, d MMMM");
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
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            root.recNow = Math.floor(Date.now() / 1000);
            // пока не пишем — опрашиваем реже, чтобы не дёргать скрипт зря
            if (root.recActive || (root.recNow % 5) === 0) pRecStatus.running = true;
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
                              : t === "failed"  ? root.tr("Не удалось начать запись")
                                                : t;
                recErrorClear.restart();
            }
        }
    }
    Timer { id: recErrorClear; interval: 4000; onTriggered: root.recError = "" }

    function startRecord() {
        if (root.recActive) return;
        root.recError = "";
        pRecCmd.command = ["sh", "-c",
            root.recScript + " start \"$1\" \"$2\" \"$3\" \"$4\" \"$5\"", "_",
            String(root.cfg.recFps), String(root.cfg.recDir),
            root.cfg.recSysAudio ? "1" : "0",
            root.cfg.recMic ? "1" : "0",
            String(root.cfg.recMicDevice)];
        pRecCmd.running = true;
    }
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
    readonly property string btConnectedName: {
        if (!btDevices) return "";
        var list = btDevices.values;
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].connected) return list[i].name || "Устройство";
        return "";
    }
    // Заряд подключённого устройства (наушников). -1, если батарею не сообщают.
    readonly property int btConnectedBattery: {
        if (!btDevices) return -1;
        var list = btDevices.values;
        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            if (d && d.connected && d.batteryAvailable)
                return Math.round(d.battery * 100);
        }
        return -1;
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
        function shortcuts(): void { root.toggleKeysWindow(); }
        function clipboard(): void { root.togglePage("clip"); }
        function powermenu(): void { root.togglePage("power"); }
        function cancelCapture(): void { root.cancelCaptureRequested(); }
        function notifications(): void { root.togglePage("notif"); }
        function audio(): void { root.togglePage("audio"); }
        function calendar(): void { root.togglePage("cal"); }
        function theme(): void { root.toggleWalls(); }
        function record(): void { root.togglePage("record"); }
        function files(): void { root.togglePage("files"); }
        function passwords(): void { root.togglePage("vault"); }
        function media(path: string): void { root.openMedia(path); }
        // переключить выделение области в плеере (то же, что кнопка «Кроп»)
        function mediaCrop(): void { root.mediaCropToggle(); }
        function recordToggle(): void { root.toggleRecord(); }
        function dnd(): void { root.dnd = !root.dnd; }
        // яркость приходит от smart_brightness.sh: службы для неё нет
        function brightness(pct: string): void {
            root.showOsd("bright", parseFloat(pct) / 100.0, false);
        }
        function close(): void { root.collapse(); }
    }

    // ----------------------------------------------------------------- окно
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
    // зазор между пилюлей и окнами
    exclusiveZone: (root.fullscreenActive && !root.expanded) ? 0 : pillH + gap
    WlrLayershell.layer: WlrLayer.Overlay
    // Пока поверх экрана развёрнутое окно, пилюли не видно совсем.
    // Показываем её обратно, если панель раскрыли клавишами или если
    // нужно показать уровень громкости/яркости.
    visible: !root.fullscreenActive || root.expanded || root.osdActive
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

    // Снимок прежних обоев: лежит ниже пилюли и выше рабочего стола,
    // клики не ловит — маска окна всё равно пропускает их насквозь.
    Image {
        anchors.fill: parent
        z: -5
        source: root.themeFadeWall
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
        readonly property real edgeMargin: root.settingsMode && !root.pillSide
                                           ? Math.max(24, (root.height - targetH) / 2)
                                           : 0
        // у боковых положений от кромки отрывает уже горизонтальный отступ
        readonly property real sideMargin: root.settingsMode && root.pillSide
                                           ? Math.max(24, (root.width - width) / 2)
                                           : 0
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
        readonly property real idleLen: root.toastActive ? 440
                : root.osdActive ? osdCapsule.implicitWidth + 32
                : root.pillSide  ? vertCapsule.implicitHeight + 30
                                 : idleCapsule.implicitWidth + 32
        readonly property real idleThick: root.toastActive
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
            if (it && it.implicitHeight > 40) contentH = it.implicitHeight + 30;
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

        readonly property real targetH: root.expanded
                ? contentH
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
        readonly property real edgeR: root.settingsMode ? 26 : 0
        readonly property real freeR: root.expanded ? 26 : root.pillH / 2
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
                else {
                    expandTimer.stop();
                    collapseTimer.restart();
                    // курсор ушёл — наведение снова может раскрывать панель
                    root.hoverExpandArmed = true;
                }
            }
        }
        Timer {
            id: expandTimer; interval: 0
            onTriggered: {
                if (!capsuleHover.hovered || root.launcherOpen) return;
                if (!root.hoverExpandArmed) return;
                // пока висит уведомление, наведение не раскрывает панель:
                // иначе до крестика не добраться
                if (root.toastActive) return;
                // страницу трогаем только если панель ещё закрыта: иначе
                // наведение сбрасывало бы уже открытый список сетей
                if (!root.expanded) {
                    pageResetTimer.stop();
                    // Наведение всегда открывает плитки. Ни музыка, ни идущая
                    // запись своей страницы больше не подсовывают: трек живёт
                    // карточкой прямо здесь, а до пульта записи один клик по
                    // плитке — зато не приходится гадать, что откроется.
                    root.page = "main";
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
            visible: root.toastActive
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
                    anchors.fill: parent
                    anchors.margins: 5
                    source: root.notifImage
                    visible: source != ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.notifImage === ""
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
                    visible: root.notifBody.length > 0
                    text: root.notifBody
                    color: root.colMuted
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
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

        // ------------------------------------------- свёрнутое: уровень (OSD)
        RowLayout {
            id: osdCapsule
            anchors.centerIn: parent
            height: root.pillH
            spacing: 12
            visible: root.osdActive && !root.toastActive
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
                    color: root.osdKind === "bright" ? "#fbbf24" : root.colOn
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
            text: root.cfg.clock12 ? "12:00 PM" : "00:00"
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
            visible: !root.expanded && !root.osdActive && !root.toastActive
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
                    clip: true
                    Image {
                        id: capsuleArt
                        anchors.fill: parent
                        source: root.mediaArt
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 56
                        visible: status === Image.Ready
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

            // идёт запись — мигающая точка и таймер слева от даты
            RowLayout {
                spacing: 6
                visible: root.recActive

                Rectangle {
                    Layout.preferredWidth: 9
                    Layout.preferredHeight: 9
                    Layout.alignment: Qt.AlignVCenter
                    radius: 5
                    color: root.recPaused ? "#fbbf24" : "#ef4444"
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
                    color: root.recPaused ? "#fbbf24" : "#ef4444"
                    font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
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
                textColor: root.kbLayout === "RU" ? "#7FB3FF" : root.colMuted
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
                Layout.preferredWidth: mBattIcon.width + battPair.spacing + mBatt.width
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
                visible: !root.expanded
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
                        clip: true

                        Image {
                            id: vertArt
                            anchors.fill: parent
                            source: root.mediaArt
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 64
                            visible: status === Image.Ready
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
                    color: root.recPaused ? "#fbbf24" : "#ef4444"
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
                    color: root.kbLayout === "RU" ? "#7FB3FF" : root.colMuted
                    font { family: root.fontFam; pixelSize: root.fontSize - 4; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.batteryIcon
                    color: root.batteryCharging || root.acOnline ? root.colOk
                         : root.batteryPct <= 15 ? root.colCrit : root.colMuted
                    font { family: root.fontFam; pixelSize: root.fontSize - 1 }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
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
            active: root.expanded || capsule.height > root.pillH + 4
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
        x: root.pillAtLeft  ? 0
         : root.pillAtRight ? parent.width - width
                            : capsule.x - width
        y: root.pillSide ? capsule.y - height
         : root.pillAtBottom ? parent.height - height : 0
        // Уголки уходят вместе с островом: в настройках он отрывается от
        // кромки, а на карусели обоев прячется целиком.
        opacity: root.settingsMode || root.wallsOpen ? 0 : 1
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
        x: root.pillAtLeft  ? 0
         : root.pillAtRight ? parent.width - width
                            : capsule.x + capsule.width
        y: root.pillSide ? capsule.y + capsule.height
         : root.pillAtBottom ? parent.height - height : 0
        opacity: root.settingsMode || root.wallsOpen ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: root.animFast } }
    }
}

// Обзор рабочих столов — отдельный полноэкранный слой: пилюля тут ни при
// чём, а клавиатура нужна целиком.
LazyLoader {
    activeAsync: root.overviewOpen

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
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

            // Список сочетаний длиннее любого экрана, поэтому он в прокрутке:
            // раньше нижние разделы просто обрезались краем карточки.
            Flickable {
                anchors.fill: parent
                anchors.margins: 22
                clip: true
                contentWidth: width
                contentHeight: keysBody.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 3000
                // содержимое проявляется вслед за карточкой: на первых кадрах
                // она ещё размером с пилюлю, и список в неё не влезает
                opacity: root.keysWindowOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.animMs } }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
                }

                SettingsView {
                    id: keysBody
                    width: parent.width
                    sys: root
                    keysOnly: true
                    tab: 3
                }
            }
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

}
