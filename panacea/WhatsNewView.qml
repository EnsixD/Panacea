import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

// Экран «что нового». Показывается один раз — сразу после того, как оболочка
// перезапустилась на свежей версии, — и закрывается кнопкой. Список изменений
// кладёт update.sh в ~/.config/panacea/.whatsnew; закрытие стирает файл, и
// второй раз экран не появится.
Item {
    id: view

    property var sys
    // первая строка файла — версия, остальные — заголовки коммитов
    property var lines: []
    readonly property string version: view.lines.length ? String(view.lines[0]).substring(0, 7) : ""
    readonly property var changes: view.lines.slice(1)

    // Сколько строк поместится, чтобы окно осталось окном, а не полосой во
    // весь экран: считаем от его высоты и от того, каким шрифтом писать.
    readonly property int maxRows: Math.max(4, Math.min(14,
        Math.floor((view.height - 380) / (view.sys.fontSize + 9))))
    readonly property int fontPx: view.changes.length > 9 ? view.sys.fontSize - 3
                                                          : view.sys.fontSize - 2
    readonly property var shown: view.changes.slice(0, view.maxRows)
    readonly property int hidden: Math.max(0, view.changes.length - view.maxRows)

    // ------------------------------------------------------------ переводы
    // История репозитория ведётся по-английски, а экран должен говорить на
    // языке системы. Поэтому здесь лежат заголовки коммитов и их перевод:
    // ключ — ровно та строка, что уходит в .whatsnew (первая строка
    // сообщения), значение — как её прочитает человек.
    //
    // Это работает и для коммитов, о которых экран рассказывает впервые:
    // update.sh пишет .whatsnew уже после того, как install.sh положил новую
    // версию оболочки, так что словарь приезжает вместе с изменениями,
    // которые он описывает.
    //
    // ВАЖНО: новый коммит — новая строка сюда. Без неё заголовок покажется
    // по-английски: не сломается, но выпадет из языка интерфейса.
    readonly property var dictRu: ({
        "voxtype: hold Right Alt to dictate — voice becomes text in the field":
            "Голос в текст: зажми правый Alt и говори — на отпускании распознанное вставляется в активное поле (офлайн, через voxtype). Пока зажато, остров показывает «Слушаю…»/«Расшифровываю…»; сочетание есть в списке Super+/ и меняется в настройках",
        "media: round the cover art's corners and keep it through pause":
            "Медиаплеер: у обложки теперь скруглённые углы (раньше картинка ложилась острыми углами поверх скруглённого квадрата), и она не пропадает после паузы/возобновления — в острове и в быстрых настройках",
        "record: hand the panel straight to the screen picker without a flash":
            "Запись: при старте из быстрых настроек панель сразу сворачивается в карточку выбора экрана, а после выбора — в обычный вид с часами; содержимое панели больше не «проблёскивает» позади карточки",
        "record: ask which screen to record when more than one is connected":
            "Запись: при нескольких экранах (ноутбук + HDMI-телевизор) остров спрашивает карточкой, какой писать — раньше wf-recorder ждал выбор в невидимой консоли и запись просто не начиналась",
        "record: try codecs until one works, and say out loud why it failed":
            "Запись: перебирает кодеки, пока какой-то не заведётся (libx264 → vp9 → vp8 → кодек по умолчанию), а если запись всё же не началась — показывает уведомление с причиной, видно и из быстрых настроек",
        "shot: fit the freeze frame to a scaled screen instead of zooming in":
            "Скриншот: стоп-кадр под выделение области теперь верно ложится на экранах с масштабом (например 200%) — раньше был виден только угол, экран будто «зумило» и снять его целиком не удавалось",
        "record: find wf-recorder wherever it lives, so recording starts everywhere":
            "Запись: wf-recorder теперь находится где угодно (PATH при запуске из оболочки бывает урезан) — кнопка записи больше не «нажимается впустую»; если бинарника нет вовсе, об этом прямо говорится",
        "island: don't flash the volume OSD when the audio output switches":
            "Остров: при подключении Bluetooth-наушников или смене устройства вывода больше не мигает полоса громкости — OSD гасится на время переключения",
        "island: keep the charge wave inside the pill's rounded corners":
            "Остров: волна заряда на карточке зарядки больше не вылезает острыми уголками за скругления пилюли; заодно в карточке наушников иконка чуть левее, а кольцо заряда чуть правее",
        "island: a charging card with the battery's charge wave behind it":
            "Остров: при подключении зарядки к ноутбуку на пару секунд показывается карточка по центру — значок зарядки, «Заряжается» и процент, а фоном идёт та же волна заряда, что на кнопке батареи в быстрых настройках",
        "island: a connect card for Bluetooth earbuds, with the battery in a ring":
            "Остров: при подключении Bluetooth-наушников на пару секунд показывается карточка — иконка наушников, имя устройства и кольцо с зарядом в процентах",
        "update: snapshot the live screen scale so one set outside the panel survives too":
            "Обновление: масштаб экрана снимается с живого состояния перед установкой — теперь переживает обновление, даже если выставлен мимо панели настроек",
        "update: keep the settings you changed, and stop leaving .bak copies behind":
            "Обновление: выставленные настройки — масштаб и частота экрана, прозрачность терминала, вибранс — больше не сбрасываются к заводским, а копии .bak в ~/.config не плодятся с каждым разом",
        "update: stop restoring old shipped files over new ones":
            "Обновление: свои файлы оболочки больше не перезаписываются сохранёнными копиями",
        "assets: a new logo":
            "Новый логотип: диафрагма из пяти лепестков вместо горизонтальной капсулы",
        "wifi: read the network name from whatever is available":
            "Wi-Fi: имя сети берётся у iw, iwd или NetworkManager — что есть, и сразу после подключения",
        "wifi: disconnect and forget a network from its own page":
            "Wi-Fi: по правой кнопке на сети — отключиться или забыть её",
        "wifi: find the interface, and re-ask once the link is up":
            "Wi-Fi: интерфейс определяется сам, имя сети появляется сразу после подключения",
        "control center: even tiles, and names that elide instead of escaping":
            "Быстрые настройки: карточки поровну, длинные имена обрезаются многоточием",
        "island: actually shrink the wired icon in the collapsed bar":
            "Значок сети в свёрнутом острове наконец уменьшился: размер задавался мимо раскладки, и та его не замечала",
        "theme: the same layout on Default, in its own type":
            "Раскладка Nothing перенесена на Default: звук в строке с сетью, сводка нагрузки, плашка записи, виджеты на обоях — точками набирает только Nothing",
        "weather: plain type for the temperature, and wind in m/s":
            "Градусы в острове и в карточках набраны обычным шрифтом, описание погоды переносится на две строки, у ветра подписана единица",
        "weather: a taller right flank on the cloud":
            "У облака правый бок выше левого — четыре точки против трёх",
        "weather: a cloud with two bumps, not a single rise":
            "Точечное облако перерисовано: два небольших бугорка на плоском теле вместо одного склона",
        "widgets: date, weather and clock cards on the desktop":
            "Настольные виджеты для темы Nothing: число с месяцем, погода со значком точками, влажность и ветер кружками, часы. Включаются во вкладке Appearance",
        "weather: accept a postcode as well as a city name":
            "В поле города принимается и почтовый индекс — сплошные цифры оболочка отличает от названия сама",
        "theme: two themes instead of eight":
            "В Appearance остались Default и Nothing: шесть остальных отличались лишь оттенком акцента, который правится ползунками там же",
        "weather: a Weather tab, and the temperature in the island":
            "Вкладка Weather: ключ OpenWeatherMap, город и шкала. Погода со значком встала в свёрнутый остров на обеих темах",
        "island: show the keyboard layout next to the network icon":
            "Раскладка клавиатуры встала рядом со значком сети в свёрнутом острове темы Nothing",
        "theme: keep the palette table in one shared file":
            "Таблица тем вынесена в общий файл: её читают два разных процесса, и двух копий цветов быть не должно",
        "lock: follow the shell theme":
            "Экран блокировки берёт цвета из выбранной темы, а не из палитры Hyprland: на чёрно-белой теме он больше не встречает терракотовым кружком",
        "theme: the last colours that ignored the theme":
            "Последние места, где цвет был прописан числом: щит проверки, режим «Максимум», меню питания и макет острова в настройках",
        "toggles: keep the knob visible on a light track":
            "Кружок тумблера и ручка ползунка громкости перестали пропадать на белой дорожке — включённый тумблер выглядел сплошной белой плашкой",
        "controls: a recorder panel with a button and a timer on the Nothing theme":
            "Запись экрана в быстрых настройках: круглая кнопка, подпись и отсчёт точками вместо частоты кадров",
        "theme: status colours follow the theme everywhere":
            "Зелёный замок, янтарная пауза и синяя раскладка больше не прописаны числом: на теме Nothing всё это белое, красный «внимание» остаётся",
        "net: a smaller wired icon again":
            "Значок проводной сети уменьшен ещё: в плитке 13 пикселей, в острове 11",
        "net: back to square branches on the wired icon":
            "Значок проводной сети снова с прямыми углами — наклонные ветки не прижились; уменьшенный размер оставлен",
        "net: branch the wired icon diagonally, and make it smaller":
            "Значок проводной сети: ветки идут наискось от одной точки — настоящая перевёрнутая Y вместо вилки с прямыми углами, и сам значок мельче",
        "dots: bolder numerals by default":
            "Точечные числа стали плотнее по всей оболочке: у такой цифры жирность — это плотность точек, другого рычага нет",
        "net: draw the wired icon instead of borrowing a font glyph":
            "Значок проводной сети нарисован фигурой: три квадрата и перевёрнутая Y, без перекладины во всю ширину",
        "island: a bolder clock in the collapsed bar":
            "Часы в свёрнутом острове набраны плотнее — точки крупнее при той же высоте, и цифра читается ярко-белой",
        "controls: smaller numerals in the load summary":
            "Проценты и температуры в сводке нагрузки стали мельче, а точки в них плотнее — иначе на такой высоте они расплываются",
        "controls: coffee mode lights up in the theme colour":
            "Coffee mode на теме Nothing загорается белым, а не янтарным, и кружок переключателя на белой дорожке остаётся виден",
        "hypr: a monochrome window border":
            "Рамка активного окна больше не уходит в красный: белый с серым вместо синего с красным",
        "island: content spans the collapsed bar instead of huddling in the middle":
            "Содержимое свёрнутого острова разошлось по краям: точки столов слева, часы по центру, сеть и звук справа",
        "island: a smaller clock in the collapsed bar":
            "Часы в свёрнутом острове стали ещё мельче",
        "island: a longer collapsed bar on Nothing, and corners without a seam":
            "Свёрнутый остров на теме Nothing стал длиннее, а вогнутые уголки по бокам перестали отходить от него серой щёлкой",
        "net: a cable plug for the wired connection, not a network tree":
            "Проводная сеть показывается штекером: прежний значок рисовал схему сети из кружков и читался как что угодно, кроме кабеля",
        "controls: an active tile turns solid on the Nothing theme":
            "Включённая плитка на теме Nothing наливается белым целиком, кружок значка выворачивается в чёрный, подписи становятся тёмными",
        "dots: size the numerals by height instead of by dot diameter":
            "Точечные числа задаются высотой в пикселях, как обычный текст: часы и проценты стали заметно мельче, а «100%» в сводке больше не налезает на полоску",
        "controls: give the load summary its share of the row":
            "Сводка нагрузки больше не сплющена в полоску у края: плитка записи забирала строку целиком",
        "controls: bluetooth and the recorder take their accent from the theme":
            "Плитки Bluetooth и записи больше не держат свой цвет числом: на теме Nothing синий уступает белому, а красный у записи берётся у темы",
        "controls: readable labels on a light accent":
            "Значок включённой плитки и число на колокольчике больше не пропадают: на светлом акценте они рисуются тёмным, а не белым по белому",
        "island: smaller dotted numerals":
            "Числа точками стали мельче: часы в панели были вдвое крупнее подписи рядом, время в плеере — тоже",
        "controls: load and temperature beside the recorder on the Nothing theme":
            "Быстрые настройки на теме Nothing: рядом с записью встала сводка — загрузка и температура процессора, памяти и видео",
        "media: the spectrum alone is the seek bar on the Nothing theme":
            "Плеер на теме Nothing: дорожка — только спектр, без черты и подчёркивания; перематывается по-прежнему, метка появляется под курсором",
        "controls: sound joins the Wi-Fi row on the Nothing theme":
            "Быстрые настройки на теме Nothing: звук встал третьим к сети и Bluetooth, часы набраны точками, секунды — мелким числом сбоку",
        "island: workspace dots and a dotted clock on the Nothing theme":
            "Остров на теме Nothing: точки столов вместо номера, часы точками по центру, справа сеть, звук и заряд",
        "settings: size buttons by their label, not by a guessed number":
            "Надписи больше не вылезают за края кнопок: ширина считается по содержимому, а прежняя остаётся нижней границей",
        "theme: match the terminal background to the widget cards on Nothing":
            "Фон терминала на теме Nothing совпал с карточками виджетов; на остальных темах цвет остаётся из общей палитры",
        "power: let the compositor start the lock screen":
            "Блокировка из меню питания работает: её запускает компоновщик, и она больше не умирает вместе с закрывшейся панелью",
        "lock: leave a trace of the last launch":
            "Экран блокировки оставляет след последнего запуска — из панели не видно ни вывода, ни кода возврата",
        "greeter: draw sleep as zZz, like the power menu":
            "Сон на экране входа обозначен буквами zZz — тем же рисунком, что и в меню питания оболочки",
        "power: launch actions from the shell root so they survive the panel closing":
            "Блокировка из меню питания наконец срабатывает: её процесс убивали вместе с закрывающейся панелью раньше, чем он успевал отделиться",
        "appearance: a button that restarts the terminal server":
            "Кнопка «Перезапустить терминал» в Appearance: убить сервер мало — без него терминал вообще перестаёт открываться",
        "install: say when the terminal server needs a restart":
            "Установщик говорит, что серверу терминала нужен перезапуск: без него свежие настройки до окон не доходят",
        "install: never spend sudo attempts when there is no terminal to ask in":
            "Обновление больше не блокирует sudo: без терминала пароль не запрашивается вовсе, а шаг просто пропускается",
        "update: refresh the login screen theme too":
            "Обновление доносит и тему экрана входа — раньше она замирала на той версии, с которой её поставили однажды",
        "greeter: give the login screen the same keyboard layouts as the shell":
            "На экране входа появилась вторая раскладка: Alt+Shift теперь есть что переключать",
        "greeter: keep the login arrow visible on a light accent":
            "Стрелка входа не пропадает на белом кружке",
        "update: stop copying the wallpaper pack through RAM":
            "Обновление больше не гоняет набор обоев через оперативную память — на машинах без её запаса это и было долгим ожиданием",
        "sliders: fix the scale on ranges narrower than one":
            "Ползунки с диапазоном уже единицы больше не упираются на середине шкалы — прозрачность и приглушённый текст доходят до края",
        "power: plain icons, zZz for sleep, a solid lock":
            "Меню питания: значки без кругов и обводок, сон обозначен буквами zZz, замок сплошной",
        "widgets: line the weather cards up to the same height":
            "Карточки погоды выровнены: правый столбец больше не выше левого на восемь пикселей",
        "brightness: follow the laptop keys in the panel slider":
            "Ползунок яркости следует за клавишами ноутбука, а не показывает прежнее значение",
        "greeter: take the login screen colours from the shell theme":
            "Экран входа берёт цвета из выбранной темы: на чёрно-белой теме больше нет терракотового кружка аватара",
        "greeter: draw the spinner, brighten the buttons, animate the layout":
            "Экран входа: ровный кружок загрузки вместо кривого глифа, заметные кнопки внизу, раскладка перелистывается",
        "island: reveal the notch corners only after the capsule lands":
            "Уголки острова появляются, когда капсула доехала, — а не слетаются к ней с разных сторон",
        "appearance: a slider for terminal transparency":
            "Прозрачность терминала правится ползунком в Appearance",
        "power: lock on the first press, not the second":
            "Блокировка в меню питания срабатывает сразу — подтверждение нужно выключению и перезагрузке, а не ей",
        "island: stop the workspace dots flickering on an empty desktop":
            "Точки столов больше не мигают при переходе на пустой рабочий стол",
        "controls: let the charging wave show through on the battery tile":
            "Плитка батареи при зарядке не заливается белым — волна снова видна",
        "update: keep the changelog fetch the same size however far behind you are":
            "Обновление: список изменений больше не тянет диффы — при большом отставании оно ускорилось втрое и перестало обрезаться на 250 коммитах",
        "update: fill the progress bar smoothly instead of jumping":
            "Обновление: полоса заполняется плавно — этапы взвешены по длительности, и внутри долгого шага она подползает сама",
        "weather: a toggle for the temperature in the island":
            "Погода в острове включается отдельным тумблером во вкладке Weather",
        "controls: no duplicate seconds in the panel clock":
            "Быстрые настройки: секунды не показываются дважды, когда они включены в настройках часов",
        "theme: a black-and-white Nothing palette":
            "Тема Nothing: чёрно-белая палитра без цветного акцента — выбирается в настройках, вкладка Appearance",
        "display: match the shader version Hyprland actually uses":
            "Дисплей: шейдер вибранса пишется в той версии GLSL, что и у Hyprland",
        "install: keep only the last few backups of a config directory":
            "Установщик: хранит три последние копии конфигов вместо всех — иначе за десяток установок в ~/.config набегали сотни мегабайт",
        "screenshot: crop the captured frame instead of shooting the screen twice":
            "Скриншот: область вырезается из снятого кадра — цвета ровно те, что были на экране, и снимок сохраняется файлом",
        "screenshot: freeze the screen before selecting a region":
            "Скриншот: экран замирает на время выделения — снять можно и то, что закрывается от движения мыши",
        "install: make the shell the default handler for files it can open":
            "Установщик: оболочка становится обработчиком по умолчанию для того, что умеет открывать",
        "files: open-with actually opens, and stops filling the whole panel":
            "Проводник: «чем открыть» действительно открывает, список стал уже и слушается стрелок",
        "agents: follow the account, and refresh whenever the panel opens":
            "Агенты: следят за аккаунтом и перечитывают статистику при каждом открытии",
        "i18n: russian titles for the newest changes":
            "Перевод: русские заголовки для свежих изменений",
        "agents: say how to make the numbers appear, not just that they are missing":
            "Агенты: сказано, как получить цифры, а не только что их нет",
        "settings: read the update output as it arrives, not when it ends":
            "Настройки: ход обновления виден сразу, а не после его конца",
        "install: fonts for emoji and the scripts Noto covers":
            "Установщик: шрифты для эмодзи и письменностей, которые закрывает Noto",
        "launcher: keep the reboot alive after the launcher closes":
            "Лаунчер: перезагрузка в другую систему больше не срывается при закрытии окна",
        "settings: show the update check spinning and the download progressing":
            "Настройки: видно, что проверка обновления идёт, и как оно скачивается",
        "files: no menu when a drop changes nothing, and ask before overwriting":
            "Проводник: меню не появляется, если файл отпустили там же, а совпавшие имена теперь спрашивают",
        "files: list what is inside gvfs, not the gvfs mount itself":
            "Проводник: в съёмных больше не висит пустая запись gvfs",
        "files: a grid view beside the list, and no scrolling by drag":
            "Проводник: вид сеткой рядом со списком, и список больше не уезжает при перетаскивании",
        "launcher: restart straight into another installed system":
            "Лаунчер: перезагрузка сразу в другую установленную систему",
        "agents: plans and limits for every installed AI agent":
            "Агенты: тарифы и лимиты установленных ИИ-агентов",
        "install: ask about the AUR helper up front, mask rival notifiers":
            "Установщик: спрашивает про помощник AUR заранее и убирает чужой демон уведомлений",
        "terminals: keep foot, drop kitty and ghostty":
            "Терминалы: остался один foot, kitty и ghostty убраны",
        "settings: drop the Plugins tab and the task pad":
            "Настройки: убран раздел Plugins вместе с блокнотом задач",
        "install: check where GRUB actually reads its config from":
            "Установщик: проверяет, откуда GRUB на самом деле читает конфиг",
        "fish: hide dotfiles unless -a asks for them":
            "Терминал: скрытые файлы показываются только по -a",
        "monitors: put the saved screen mode into the compositor config":
            "Экраны: сохранённый режим прописывается в конфиг компоновщика",
        "install: start the shell with the threaded render loop after installing":
            "Установщик: оболочка запускается с потоковым циклом отрисовки",
        "island: stop restarting the height animation while the page settles":
            "Остров: анимация высоты не дёргается, пока страница устаканивается",
        "controls: sliders land on exact values instead of fighting the hardware":
            "Быстрые настройки: ползунки встают на точные значения",
        "display: write the vibrance shader atomically and wait for the slider to settle":
            "Экран: шейдер насыщенности пишется целиком, без баннера с ошибкой",
        "grub: name the theme fonts the way they are stored inside the .pf2":
            "GRUB: имена шрифтов темы совпадают с тем, как они лежат в .pf2",
        "i18n: english strings for the new settings":
            "Перевод: английские строки для новых настроек",
        "install: build an AUR helper, add missing deps, offer fish as the login shell":
            "Установщик: собирает помощник AUR, ставит недостающее и предлагает fish оболочкой входа",
        "cursor: software cursors on NVIDIA, and a black minimal theme":
            "Курсор: программные курсоры на NVIDIA и чёрная минималистичная тема",
        "clock: 24-hour format everywhere, not just in the shell":
            "Часы: 24-часовой формат везде, а не только в оболочке",
        "fish: show dotfiles, add c/upd/ins, and stop fastfetch on startup":
            "Терминал: скрытые файлы, алиасы c/upd/ins и fastfetch больше не лезет при запуске",
        "files: fill the window and show dotfiles":
            "Проводник: список занимает всё окно и показывает скрытые файлы",
        "controls: hide the battery and power profiles on a desktop machine":
            "Быстрые настройки: на стационарной машине нет батареи и режимов питания",
        "controls: volume and brightness share one row":
            "Быстрые настройки: громкость и яркость встали в одну строку",
        "controls: show the wired network instead of Wi-Fi when a cable is in":
            "Быстрые настройки: при подключённом кабеле видно проводную сеть, а не Wi-Fi",
        "settings: language switch for the shell and the system":
            "Настройки: переключение языка оболочки и системы",
        "settings: pointer speed and raw input":
            "Настройки: скорость указателя и прямой ввод",
        "display: digital vibrance through a compositor shader":
            "Экран: цифровая насыщенность через шейдер компоновщика",
        "brightness: one control for the laptop backlight and desktop monitors":
            "Яркость: одна настройка для подсветки ноутбука и внешних мониторов",
        "settings: new keys for hidden files, screen colour and the pointer":
            "Настройки: новые ключи для скрытых файлов, цвета экрана и указателя",
        "install: kernel headers, or the Nvidia module never gets built":
            "Установщик: заголовки ядра, без которых модуль Nvidia не собирается",
        "install: open modules for Turing and newer, vendors by PCI id":
            "Установщик: открытые модули Nvidia для Turing и новее, вендор по PCI-идентификатору",
        "hypr: bring back a fallback config for Hyprland without Lua":
            "Hyprland: возвращён запасной конфиг для версий без поддержки Lua",
        "system: read the GPU temperature where hwmon has none":
            "Система: температура видеокарты читается и там, где hwmon её не даёт",
        "island: no battery block on a machine without a battery":
            "Остров: на машине без батареи блок заряда не показывается",
        "install: count finished downloads, not created files":
            "Установщик: считает завершённые загрузки, а не созданные файлы",
        "install: drivers, dual boot, plain qs, and a reboot at the end":
            "Установщик: драйверы, дуалбут, запуск через qs и перезагрузка в конце",
        "hypr: launch the shell by absolute path, not through a tilde":
            "Hyprland: оболочка запускается по полному пути, а не через «~»",
        "install: show the wallpaper pack downloading":
            "Установщик: видно, как скачивается пак обоев",
        "plugins: a tab of its own, and a task pad for the desktop":
            "Плагины: своя вкладка и блокнот задач",
        "settings: the update notice opens System":
            "Настройки: уведомление об обновлении открывает раздел System",
        "todo: finish it the way the island behaves":
            "Задачи: капсула ведёт себя как остров — ширина, разворот, кромка",
        "todo: a second capsule at the edge, not a window on the desktop":
            "Задачи: вторая капсула у кромки вместо окна на рабочем столе",
        "update: name the packages that are no longer needed":
            "Обновление: называет пакеты, которые больше не нужны",
        "install: drop configs for programs that never run":
            "Установщик: убраны конфиги программ, которые не запускаются",
        "island: with auto-hide on, hovering shows the pill and a click opens it":
            "Остров: при автопрятании наведение показывает пилюлю, а раскрывает клик",
        "battery mode: keep the pill, drop the second set of panels":
            "Режим батареи: остаётся пилюля, второй набор панелей убран",
        "install: fix the dependency list, and name what an update still needs":
            "Установщик: список зависимостей исправлен, обновление называет недостающие пакеты",
        "wob: colour it from the palette and stop leaking readers":
            "wob: цвета из палитры, и он больше не плодит процессы",
        "settings: finish the move off the legacy panel":
            "Настройки: старая панель убрана, клавиши переехали на новую",
        "shell: one FocusGrabber instead of six copies of it":
            "Оболочка: фокус в полях ввода — один общий механизм вместо шести",
        "files: show copying in the island, and queue what waits":
            "Проводник: копирование видно в острове, операции встают в очередь",
        "scripts: check QML syntax without starting the shell":
            "Скрипты: проверка синтаксиса QML до запуска оболочки",
        "hypr: drop program entries nothing points at":
            "Hyprland: убраны записи о программах, которые никто не вызывает",
        "shell: move the dictionary out of the way":
            "Оболочка: словарь интерфейса вынесен в отдельный файл",
        "island: show any long job, not just copying":
            "Остров: показывает любую долгую работу, не только копирование",
        "hypr: delete the config Hyprland does not read":
            "Hyprland: удалён конфиг, который не читается",
        "settings: one SetButton for Apply and Reset":
            "Настройки: общая кнопка для «Применить» и «Сбросить»",
        "whatsnew: say what changed in the language of the interface":
            "Что нового: список изменений на языке интерфейса",
        "wallpaper: write hyprpaper's new config format":
            "Обои: новый формат конфигурации hyprpaper",
        "install: leave the shell alone while an update is running":
            "Установщик: не трогает оболочку, пока идёт обновление",
        "update: hand the job to the freshly cloned script":
            "Обновление: работу доводит свежескачанный скрипт",
        "update: keep housekeeping commits out of the changelog":
            "Обновление: служебные коммиты не попадают в список изменений",
        "island: don't expand just because auto-hide revealed it":
            "Остров: не разворачивается только оттого, что выехал из-под края",
        "power menu: one icon weight for the whole row":
            "Меню питания: одинаковая толщина значков в ряду"
    })

    // Плашка с готовой командой: перечислять пакеты словами бессмысленно,
    // всё равно набирать руками. По нажатию команда уходит в буфер.
    component DepsNotice: Rectangle {
        id: notice
        property string text: ""
        property string cmd: ""
        property bool shown: false
        property color tone: view.sys.colMuted

        Layout.fillWidth: true
        visible: notice.shown
        implicitHeight: noticeCol.implicitHeight + 24
        radius: 14
        color: Qt.rgba(notice.tone.r, notice.tone.g, notice.tone.b, 0.10)
        border.width: 1
        border.color: Qt.rgba(notice.tone.r, notice.tone.g, notice.tone.b, 0.35)

        ColumnLayout {
            id: noticeCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 5

            Text {
                Layout.fillWidth: true
                text: notice.text
                color: view.sys.colFg
                wrapMode: Text.WordWrap
                font { family: view.sys.fontBody; pixelSize: view.fontPx; bold: true }
            }

            Text {
                Layout.fillWidth: true
                text: notice.cmd
                color: view.sys.colMuted
                wrapMode: Text.WrapAnywhere
                font { family: view.sys.fontFam; pixelSize: view.fontPx - 1 }
            }

            Text {
                Layout.fillWidth: true
                text: noticeMa.containsMouse ? view.sys.tr("Нажмите, чтобы скопировать")
                                             : view.sys.tr("Скопировать команду")
                color: view.sys.colOn
                font { family: view.sys.fontBody; pixelSize: view.fontPx - 2 }
            }
        }

        MouseArea {
            id: noticeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.sys.copyText(notice.cmd)
        }
    }

    function changeText(subject) {
        if (view.sys.isEn) return subject;
        var t = view.dictRu[subject];
        return t !== undefined ? t : subject;
    }

    anchors.fill: parent

    // клик мимо карточки не закрывает: человек должен увидеть, что изменилось,
    // и закрыть это осознанно
    MouseArea { anchors.fill: parent }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(620, parent.width - 80)
        // высота строго по содержимому: списку тесно быть не должно
        height: Math.min(body.implicitHeight + 56, parent.height - 60)
        radius: 26
        color: view.sys.colBg
        border.width: 1
        border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)

        // выезжает снизу и проявляется: тот же почерк, что у остальных окон
        opacity: 0
        transform: Translate { id: rise; y: 24 }
        Component.onCompleted: { card.opacity = 1; rise.y = 0; }
        Behavior on opacity { NumberAnimation { duration: view.sys.animMs } }

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            // ------------------------------------------------- шапка
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Image {
                    Layout.alignment: Qt.AlignHCenter
                    source: Quickshell.env("HOME") + "/.config/panacea/assets/logo-128.png"
                    sourceSize.width: 72
                    sourceSize.height: 72
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: view.sys.tr("Panacea обновлена")
                    color: view.sys.colFg
                    font { family: view.sys.fontDisplay; pixelSize: view.sys.fontSize + 8 }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: view.version.length > 0
                    text: view.sys.tr("Сборка") + " " + view.version
                    color: view.sys.colMuted
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                }
            }

            // ------------------------------------------------- изменения
            // Без прокрутки: окно растёт под список целиком. Прокрутка здесь
            // означала бы, что часть изменений человек не увидит, — а ради
            // них экран и показывают. Длинный список ужимается шрифтом, а
            // совсем длинный сворачивается в хвост «и ещё N».
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: changeCol.implicitHeight + 28
                radius: 18
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.045)

                ColumnLayout {
                    id: changeCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 7

                    Repeater {
                        model: view.shown

                        RowLayout {
                            required property string modelData
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 6
                                width: 5; height: 5; radius: 3
                                color: view.sys.colOn
                            }
                            Text {
                                Layout.fillWidth: true
                                text: view.changeText(modelData)
                                color: view.sys.colFg
                                wrapMode: Text.WordWrap
                                font { family: view.sys.fontBody; pixelSize: view.fontPx }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        visible: view.hidden > 0
                        text: view.sys.tr("и ещё") + " " + view.hidden
                              + (view.sys.cfg.lang === "en" ? " more" : "")
                        color: view.sys.colMuted
                        font { family: view.sys.fontBody; pixelSize: view.fontPx - 1 }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: view.changes.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        text: view.sys.tr("Список изменений недоступен")
                        color: view.sys.colMuted
                        font { family: view.sys.fontBody; pixelSize: view.fontPx }
                    }
                }
            }

            // ------------------------------------------- пакеты системы
            // Обновление ставит только конфиги: пакеты — дело человека.
            // Молчать нельзя ни в ту, ни в другую сторону — иначе часть
            // оболочки не работает без объяснения, а ненужное остаётся
            // висеть в системе навсегда.
            DepsNotice {
                text: view.sys.tr("Не хватает пакетов")
                cmd: "sudo pacman -S --needed " + view.sys.missingDeps
                shown: view.sys.missingDeps.length > 0
                tone: view.sys.colCrit
            }

            DepsNotice {
                text: view.sys.tr("Больше не нужны")
                cmd: "sudo pacman -Rns " + view.sys.obsoleteDeps
                shown: view.sys.obsoleteDeps.length > 0
                tone: view.sys.colMuted
            }

            // ------------------------------------------------- кнопка
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 14
                color: okMa.containsMouse
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.36)
                       : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.24)
                border.width: 1
                border.color: view.sys.colOn
                Behavior on color { ColorAnimation { duration: view.sys.animFade } }

                Text {
                    anchors.centerIn: parent
                    text: view.sys.tr("Хорошо")
                    color: view.sys.colFg
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize; bold: true }
                }
                MouseArea {
                    id: okMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.dismissWhatsNew()
                }
            }
        }
    }

    focus: true
    Keys.onEscapePressed: view.sys.dismissWhatsNew()
    Keys.onReturnPressed: view.sys.dismissWhatsNew()
    Component.onCompleted: forceActiveFocus()
}
