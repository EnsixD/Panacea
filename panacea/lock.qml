//@ pragma UseQApplication
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "Themes.js" as Themes

// Экран блокировки в стиле динамического острова.
//
// Два состояния:
//   покой  — текущие обои резко, часы и замок по центру
//   ввод   — фон уходит в размытие, снизу выезжает капсула с точками пароля
//
// Запускается как отдельный процесс:  quickshell --path ~/.config/panacea/lock.qml
// Пока процесс жив, ext-session-lock держит сессию закрытой.
ShellRoot {
    id: root

    // ------------------------------------------------------------- состояние
    // Пароль живёт здесь, а не в TextInput: поле лежит внутри компонента
    // поверхности (своя на каждый экран) и снаружи по id не видно.
    property string password: ""
    property bool authMode: false          // показана капсула ввода
    property bool checking: false          // PAM проверяет пароль
    property string errorText: ""
    property int attempts: 0

    readonly property string user: Quickshell.env("USER") || "user"
    // Ник для приветствия: Ensi вместо системного ensi
    readonly property string nick:
        user.charAt(0).toUpperCase() + user.slice(1)

    readonly property string fontFam: "JetBrainsMono Nerd Font"

    // Экран блокировки — отдельная программа, у неё нет доступа к состоянию
    // оболочки. Настройки читаем из того же файла: только те, что нужны здесь.
    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/panacea/settings.json"
        watchChanges: true
        onFileChanged: reload()
        adapter: JsonAdapter {
            property int  lockBlur: 32
            property bool lockShowMedia: true
            property bool lockShowNotif: true
            property string lockHint: ""
        }
    }
    readonly property var cfg: cfgFile.adapter

    // Аварийная разблокировка для отладки: включается только тем,
    // кто запустил процесс с PANACEA_LOCK_TEST=1. В боевом запуске
    // такого канала нет.
    readonly property bool testMode: Quickshell.env("PANACEA_LOCK_TEST") === "1"

    // ------------------------------------------------- обои и акцент из темы
    property string wallpaper: ""

    // Палитра берётся из той же темы, что и оболочка. Раньше экран
    // блокировки жил своей жизнью: акцент он читал из hypr/palette.conf, и
    // при чёрно-белой теме оболочки встречал терракотовым кружком ввода.
    //
    // Тема читается из settings.json тем же разбором, что и язык, а таблица
    // цветов общая — Themes.js. Держать здесь свою копию нельзя: она
    // разошлась бы с оболочкой на первой же правке палитры.
    property string themeId: "default"
    readonly property var theme: Themes.of(root.themeId)
    // у «default» акцент остаётся за настройками, как и в оболочке
    property color cfgOn: "#3b82f6"
    readonly property color accent: root.themeId === "default" ? root.cfgOn
                                                               : root.theme.on
    readonly property color colFg:   root.theme.fg
    readonly property color colCrit: root.theme.crit
    // Фон нужен для надписей поверх залитого акцентом: на светлом акценте
    // белым по белому не видно ничего, а у темы Nothing он как раз белый.
    readonly property color colBg:   root.theme.bg
    function fgOn(c) {
        return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) > 0.6
               ? root.colBg : "#ffffff";
    }

    // ------------------------------------------------------------------ язык
    // Экран блокировки — отдельный процесс и до настроек пилюли не дотягивается,
    // поэтому читает тот же settings.json сам. Без этого он оставался
    // русскоязычным даже при английском интерфейсе.
    property bool isEn: true
    function tr(k) { return root.isEn && root.dictEn[k] !== undefined ? root.dictEn[k] : k; }
    readonly property var dictEn: ({
        "Слишком много попыток": "Too many attempts",
        "Неверный пароль": "Wrong password",
        "Ошибка проверки": "Verification error",
        "PAM недоступен": "PAM unavailable",
        "Нажмите Enter": "Press Enter",
        "Пароль": "Password"
    })

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/panacea/settings.json"
        blockLoading: true
    }

    FileView {
        id: wallFile
        path: Quickshell.env("HOME") + "/.config/hypr/wallpaper.conf"
        // читаем синхронно: обои нужны в первом же кадре, иначе на долю
        // секунды мелькает чёрный экран
        blockLoading: true
    }

    Component.onCompleted: {
        try {
            var cfg = JSON.parse(settingsFile.text() || "{}");
            if (cfg && typeof cfg.lang === "string") root.isEn = cfg.lang !== "ru";
            if (cfg && typeof cfg.themeId === "string") root.themeId = cfg.themeId;
            if (cfg && typeof cfg.colOn === "string") root.cfgOn = cfg.colOn;
        } catch (e) { /* настроек нет — остаёмся на английском и на теме по умолчанию */ }

        // scripts/lock.sh отдаёт уже ужатую под экран копию обоев
        var cached = Quickshell.env("PANACEA_LOCK_BG") || "";
        if (cached.length) { root.wallpaper = cached; }

        var w = /^\$wallpaper\s*=\s*(.+)$/m.exec(wallFile.text() || "");
        if (w && !cached.length) {
            var p = w[1].trim();
            if (p.indexOf("~") === 0) p = Quickshell.env("HOME") + p.slice(1);
            root.wallpaper = (p === "black" || p.length === 0) ? "" : p;
        }
    }

    // ------------------------------------------------------------------ часы
    property string timeText: "--:--"
    property string dateText: ""
    function tick() {
        var d = new Date();
        root.timeText = Qt.formatDateTime(d, "HH:mm");
        root.dateText = Qt.formatDateTime(d, "dddd, d MMMM");
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.tick()
    }

    // ------------------------------------------------------------------- PAM
    PamContext {
        id: pam
        // /etc/pam.d/swaylock — штатный профиль для экранов блокировки
        config: "swaylock"
        user: root.user

        onPamMessage: {
            if (responseRequired) respond(root.password);
        }
        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success) {
                root.password = "";
                lock.locked = false;
                quitTimer.start();
            } else {
                root.attempts++;
                root.errorText = result === PamResult.MaxTries
                                 ? root.tr("Слишком много попыток")
                                 : root.tr("Неверный пароль");
                root.password = "";
            }
        }
        onError: {
            root.checking = false;
            root.errorText = root.tr("Ошибка проверки");
            root.password = "";
        }
    }

    // даём композитору кадр на снятие блокировки, потом выходим
    Timer { id: quitTimer; interval: 220; onTriggered: Qt.quit() }

    function submit() {
        if (root.checking) return;
        if (!root.password.length) return;
        root.errorText = "";
        root.checking = true;
        if (!pam.start()) {
            root.checking = false;
            root.errorText = root.tr("PAM недоступен");
        }
    }

    IpcHandler {
        target: "lock"
        // работает только в тестовом запуске, см. testMode
        function unlock(): void {
            if (!root.testMode) return;
            lock.locked = false;
            quitTimer.start();
        }
        // тоже только для отладки: посмотреть режим ввода без клавиатуры
        function auth(): void {
            if (!root.testMode) return;
            root.authMode = true;
        }
    }

    // ---------------------------------------------------------------- экраны
    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            id: surface
            color: "#000000"

            Item {
                anchors.fill: parent

                // ---------------------------------------------------- фон
                Image {
                    id: bg
                    anchors.fill: parent
                    source: root.wallpaper.length ? "file://" + root.wallpaper : ""
                    fillMode: Image.PreserveAspectCrop
                    cache: true
                    asynchronous: false
                    // Обои бывают на десятки мегапикселей (ember_stripes.jpg — 10667x7111),
                    // и Qt отказывается их декодировать: лимит 256 МБ на картинку.
                    // sourceSize заставляет JPEG декодироваться сразу уменьшенным;
                    // двойной запас по размеру экрана — чтобы кроп не мылил.
                    sourceSize: Qt.size(surface.width * 2, surface.height * 2)
                    layer.enabled: true
                    layer.smooth: true
                }

                // размытие включается только в режиме ввода
                MultiEffect {
                    anchors.fill: parent
                    source: bg
                    visible: bg.status === Image.Ready
                    blurEnabled: true
                    // сила размытия задаётся во вкладке Lock Screen
                    blurMax: root.cfg ? root.cfg.lockBlur : 32
                    blurMultiplier: 0.85
                    blur: root.authMode ? 1.0 : 0.0
                    Behavior on blur {
                        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
                    }
                }

                // затемнение: в покое лёгкое, при вводе заметнее
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: root.authMode ? 0.55 : 0.35
                    Behavior on opacity { NumberAnimation { duration: 420 } }
                }

                // ------------------------------------------------ часы и замок
                Column {
                    id: idleBlock
                    anchors.centerIn: parent
                    spacing: 18
                    // при вводе блок уезжает вверх и бледнеет
                    y: parent.height / 2 - height / 2 - (root.authMode ? 60 : 0)
                    Behavior on y {
                        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
                    }

                    // замок в матовом круге
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 96; height: 96; radius: 48
                        color: Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.16)
                        border.width: 1
                        opacity: root.authMode ? 0 : 1
                        scale: root.authMode ? 0.9 : 1
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        Behavior on scale { NumberAnimation { duration: 300 } }

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(0xF033E)
                            color: "#ffffff"
                            font { family: root.fontFam; pixelSize: 40 }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.timeText
                        color: "#ffffff"
                        font { family: root.fontFam; pixelSize: 84; bold: true }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.dateText
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font { family: root.fontFam; pixelSize: 17 }
                    }

                    // Своя строка хозяина машины: чей это компьютер, куда
                    // звонить, если нашли. Пустая — её просто нет.
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: text.length > 0
                        text: root.cfg ? root.cfg.lockHint : ""
                        color: Qt.rgba(1, 1, 1, 0.50)
                        font { family: root.fontFam; pixelSize: 14 }
                    }

                    // подсказка мигает, пока не начали вводить
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.tr("Нажмите Enter")
                        color: Qt.rgba(1, 1, 1, 0.40)
                        opacity: root.authMode ? 0 : 1
                        visible: opacity > 0.01
                        font { family: root.fontFam; pixelSize: 13; letterSpacing: 1 }
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        SequentialAnimation on scale {
                            running: !root.authMode
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.04; duration: 1100; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.00; duration: 1100; easing.type: Easing.InOutSine }
                        }
                    }
                }

                // ------------------------------------------------- капсула ввода
                Item {
                    id: island
                    width: root.authMode ? 420 : 150
                    height: 62
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height / 2 + 130
                    opacity: root.authMode ? 1 : 0
                    visible: opacity > 0.01
                    scale: root.authMode ? 1 : 0.92

                    Behavior on width {
                        NumberAnimation { duration: 380; easing.type: Easing.OutBack }
                    }
                    Behavior on opacity { NumberAnimation { duration: 260 } }
                    Behavior on scale {
                        NumberAnimation { duration: 380; easing.type: Easing.OutBack }
                    }

                    // тряска при неверном пароле: двигаем трансформ, чтобы
                    // не воевать с anchors.horizontalCenter
                    transform: Translate { id: shakeT }
                    SequentialAnimation {
                        id: shake
                        loops: 2
                        NumberAnimation { target: shakeT; property: "x"; to: -9; duration: 55 }
                        NumberAnimation { target: shakeT; property: "x"; to:  9; duration: 55 }
                        NumberAnimation { target: shakeT; property: "x"; to:  0; duration: 55 }
                    }
                    Connections {
                        target: root
                        function onErrorTextChanged() {
                            if (root.errorText.length) shake.restart();
                        }
                    }

                    Rectangle {
                        id: capsule
                        anchors.fill: parent
                        radius: height / 2
                        color: Qt.rgba(0.04, 0.04, 0.05, 0.92)
                        border.width: 1
                        border.color: root.errorText.length
                                      ? Qt.rgba(0.94, 0.27, 0.27, 0.75)
                                      : Qt.rgba(1, 1, 1, 0.14)
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 14

                            // замок / галочка / спиннер
                            Item {
                                width: 26; height: 26
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    visible: !root.checking
                                    text: String.fromCodePoint(0xF033E)
                                    color: root.errorText.length ? root.colCrit : root.accent
                                    font { family: root.fontFam; pixelSize: 19 }
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                Text {
                                    id: spinner
                                    anchors.centerIn: parent
                                    visible: root.checking
                                    text: String.fromCodePoint(0xF0772)
                                    color: root.accent
                                    font { family: root.fontFam; pixelSize: 19 }
                                    RotationAnimator on rotation {
                                        running: spinner.visible
                                        loops: Animation.Infinite
                                        from: 0; to: 360; duration: 900
                                    }
                                }
                            }

                            // точки по числу введённых символов
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7
                                Repeater {
                                    model: Math.min(root.password.length, 16)
                                    Rectangle {
                                        width: 9; height: 9; radius: 5
                                        color: "#ffffff"
                                        opacity: 0.9
                                        // каждая точка появляется с отскоком
                                        scale: 0
                                        Component.onCompleted: scale = 1
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 180; easing.type: Easing.OutBack
                                            }
                                        }
                                    }
                                }
                                // пустое поле — подсказка вместо точек
                                Text {
                                    visible: root.password.length === 0
                                    text: root.errorText.length ? root.errorText : root.tr("Пароль")
                                    color: root.errorText.length
                                           ? root.colCrit : Qt.rgba(1, 1, 1, 0.35)
                                    font { family: root.fontFam; pixelSize: 14 }
                                }
                            }
                        }
                    }
                }

                // имя пользователя под капсулой
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: island.y + island.height + 16
                    text: root.nick
                    color: Qt.rgba(1, 1, 1, 0.55)
                    opacity: root.authMode ? 1 : 0
                    visible: opacity > 0.01
                    font { family: root.fontFam; pixelSize: 14; letterSpacing: 1 }
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }

                // ------------------------------------------------------- ввод
                // Настоящее поле спрятано: рисуем точки сами, а раскладки,
                // Backspace и вставку пусть обрабатывает TextInput.
                TextInput {
                    id: pwInput
                    focus: true
                    width: 1; height: 1
                    opacity: 0
                    echoMode: TextInput.Password
                    activeFocusOnPress: false

                    Component.onCompleted: forceActiveFocus()
                    onTextChanged: {
                        root.password = text;
                        if (text.length) root.errorText = "";
                    }
                    onAccepted: root.submit()

                    // очистку инициирует корень (после проверки пароля)
                    Connections {
                        target: root
                        function onPasswordChanged() {
                            if (root.password === "" && pwInput.text !== "") pwInput.text = "";
                        }
                    }

                    Keys.onEscapePressed: {
                        if (root.authMode && !root.checking) {
                            pwInput.text = "";
                            root.errorText = "";
                            root.authMode = false;
                        }
                    }
                    Keys.onPressed: event => {
                        if (root.checking) { event.accepted = true; return; }
                        if (!root.authMode) {
                            root.authMode = true;
                            // Enter только раскрывает капсулу, печатать не должен
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                || event.key === Qt.Key_Space)
                                event.accepted = true;
                        }
                    }
                }

                // фокус не должен теряться ни при каких обстоятельствах
                Timer {
                    interval: 400; running: true; repeat: true
                    onTriggered: if (!pwInput.activeFocus) pwInput.forceActiveFocus()
                }
            }
        }
    }
}
