import QtQuick 2.15

// Экран входа в стиле Panacea: размытые обои системы, капсула-остров с
// полем пароля, выбор сессии и кнопки питания. Тот же язык форм, что у
// пилюли и локскрина.
//
// Напрямую из ~/ обои не читаются: greeter работает от пользователя sddm,
// а домашний каталог закрыт (drwx------). Поэтому switch_theme.sh при
// каждой смене темы кладёт готовую размытую копию текущих обоев в
// /var/lib/panacea, откуда greeter её и берёт. Нет файла — остаётся
// прежний градиент.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#050506"

    readonly property string fontFam: "JetBrainsMono Nerd Font"
    // Акцент текущей темы, положенный рядом с обоями. Значение по умолчанию
    // остаётся, пока файла нет — например до первой смены темы.
    //
    // Забирается именно Loader'ом: Process в greeter'е недоступен, а XHR к
    // file:// Qt 6 молча блокирует без QML_XHR_ALLOW_FILE_READ, которую
    // greeter'у не выставить. Загрузка крошечного QML-фрагмента работает.
    Loader {
        id: accentLoader
        source: "file:///var/lib/panacea/accent.qml"
        asynchronous: false
    }
    // Палитру пишет сама оболочка при смене темы — она одна знает, какая
    // тема выбрана. Значения читаем по одному и с запасными: файл мог
    // остаться от прежней версии, где в нём был только акцент.
    readonly property color accent:
        accentLoader.item ? accentLoader.item.value : "#c65a47"

    // Язык — оттуда же и тем же способом. Пишет его сама пилюля, когда
    // язык меняют в настройках (SUPER + I): экран входа не должен говорить
    // по-русски, если вся остальная система переключена на английский.
    Loader {
        id: localeLoader
        source: "file:///var/lib/panacea/locale.qml"
        asynchronous: false
    }
    // По умолчанию английский — как и у пилюли, пока файла ещё нет.
    readonly property bool isEn:
        localeLoader.item ? localeLoader.item.lang === "en" : true

    // Ключ — русский текст, как в пилюле: исходник остаётся читаемым, а
    // словарь нужен только для английского.
    readonly property var dictEn: ({
        "Пароль": "Password",
        "Неверный пароль": "Wrong password",
        "Сон": "Sleep",
        "Перезагрузка": "Restart",
        "Выключить": "Shut down"
    })
    function tr(k) { return isEn && dictEn[k] !== undefined ? dictEn[k] : k; }
    readonly property color fg:
        (accentLoader.item && accentLoader.item.fg !== undefined)
            ? accentLoader.item.fg : "#f2f2f2"
    readonly property color muted:
        (accentLoader.item && accentLoader.item.muted !== undefined)
            ? accentLoader.item.muted : "#8a8a8a"
    readonly property color line: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
    // Красный «неверный пароль» остаётся красным на любой теме: это цвет
    // отказа, а не украшение.
    readonly property color crit: "#ef4444"

    // Отображаемое имя. Системный логин уходит в sddm.login() как есть.
    readonly property string loginName: userModel.lastUser || "ensi"
    readonly property string nick:
        loginName.charAt(0).toUpperCase() + loginName.slice(1)

    // имена сессий: роли модели у SDDM нумеруются по-разному между версиями,
    // поэтому забираем их обычным делегатом, а не через data(index, role)
    property var sessionNames: []

    Repeater {
        model: sessionModel
        Item {
            Component.onCompleted: {
                var a = root.sessionNames.slice();
                a[index] = name;
                root.sessionNames = a;
            }
        }
    }

    property string errorText: ""
    property bool busy: false

    // ------------------------------------------------------------------ фон
    // Текущие обои системы, размытые заранее скриптом темы.
    Image {
        id: wallpaper
        anchors.fill: parent
        source: "file:///var/lib/panacea/sddm-bg.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: status === Image.Ready
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 320 } }
    }

    // Затемнение поверх обоев: капсула и часы должны читаться и на светлой
    // картинке. Слабое — темы у нас и без того тёмные, на 0.45 экран входа
    // превращался в сплошной чёрный и обоев было не видно вовсе.
    Rectangle {
        anchors.fill: parent
        visible: wallpaper.visible
        color: Qt.rgba(0, 0, 0, 0.28)
    }

    // мягкое пятно акцента, чтобы чёрный не был плоским
    // (запасной фон, когда картинки нет — например на первой загрузке)
    Rectangle {
        anchors.fill: parent
        visible: !wallpaper.visible
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.10) }
            GradientStop { position: 0.55; color: "#050506" }
            GradientStop { position: 1.0; color: "#000000" }
        }
    }

    // ---------------------------------------------------------------- часы
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(root.height * 0.14)
        spacing: 6

        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.fg
            font { family: root.fontFam; pixelSize: 76; bold: true }
            text: Qt.formatDateTime(new Date(), "HH:mm")
        }
        Text {
            id: dateLabel
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.rgba(1, 1, 1, 0.45)
            font { family: root.fontFam; pixelSize: 16 }
            text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            var d = new Date();
            clock.text = Qt.formatDateTime(d, "HH:mm");
            dateLabel.text = Qt.formatDateTime(d, "dddd, d MMMM");
        }
    }

    // -------------------------------------------------------------- центр
    Column {
        anchors.centerIn: parent
        spacing: 18

        // аватар: первая буква ника
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 84; height: 84; radius: 42
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: root.line
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: root.nick.charAt(0)
                color: root.accent
                font { family: root.fontFam; pixelSize: 34; bold: true }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.nick
            color: root.fg
            font { family: root.fontFam; pixelSize: 20; bold: true }
        }

        // ----------------------------------------------- капсула с паролем
        Rectangle {
            id: capsule
            anchors.horizontalCenter: parent.horizontalCenter
            width: 420
            height: 60
            radius: 30
            color: Qt.rgba(0.04, 0.04, 0.05, 0.95)
            border.width: 1
            border.color: root.errorText.length
                          ? Qt.rgba(0.94, 0.27, 0.27, 0.75)
                          : (password.activeFocus ? Qt.rgba(root.accent.r, root.accent.g,
                                                            root.accent.b, 0.65)
                                                  : root.line)
            Behavior on border.color { ColorAnimation { duration: 200 } }

            // тряска при неверном пароле
            transform: Translate { id: shakeT }
            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: shakeT; property: "x"; to: -9; duration: 55 }
                NumberAnimation { target: shakeT; property: "x"; to:  9; duration: 55 }
                NumberAnimation { target: shakeT; property: "x"; to:  0; duration: 55 }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 16
                spacing: 12

                // Иконка в собственной коробке: у глифов Material Design
                // чернила шире advance, и по одному только verticalCenter
                // замок съезжал наполовину за край строки.
                Item {
                    width: 26; height: 26
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: capsuleIcon
                        anchors.centerIn: parent
                        text: String.fromCodePoint(root.busy ? 0xF0772 : 0xF033E)
                        color: root.errorText.length ? "#ef4444" : root.accent
                        font { family: root.fontFam; pixelSize: 20 }

                        RotationAnimator on rotation {
                            running: root.busy
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 900
                        }
                    }
                }

                TextInput {
                    id: password
                    width: parent.width - 90
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    passwordMaskDelay: 0
                    color: root.fg
                    selectionColor: root.accent
                    clip: true
                    font { family: root.fontFam; pixelSize: 16 }
                    focus: true
                    enabled: !root.busy

                    onTextChanged: root.errorText = ""
                    onAccepted: root.doLogin()
                    Keys.onEnterPressed: root.doLogin()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: password.text.length === 0
                        text: root.errorText.length ? root.errorText : root.tr("Пароль")
                        color: root.errorText.length ? root.crit : Qt.rgba(1, 1, 1, 0.32)
                        font { family: root.fontFam; pixelSize: 15 }
                    }
                }

                // кнопка входа
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40; radius: 20
                    color: password.text.length ? root.accent : Qt.rgba(1, 1, 1, 0.08)
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF0142)
                        color: password.text.length ? "#ffffff" : root.muted
                        font { family: root.fontFam; pixelSize: 16 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.doLogin()
                    }
                }
            }
        }

        // ------------------------------------------------- выбор сессии (WM)
        Rectangle {
            id: sessionBtn
            anchors.horizontalCenter: parent.horizontalCenter
            width: sessionRow.implicitWidth + 34
            height: 34
            radius: 17
            color: sessionMa.containsMouse || sessionList.visible
                   ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
            border.color: root.line
            border.width: 1
            Behavior on color { ColorAnimation { duration: 150 } }

            property int index: sessionModel.lastIndex

            Row {
                id: sessionRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xF0379)
                    color: root.muted
                    font { family: root.fontFam; pixelSize: 13 }
                }
                Text {
                    id: sessionLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sessionNames[sessionBtn.index] || "Hyprland"
                    color: root.fg
                    font { family: root.fontFam; pixelSize: 12 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xF0140)
                    color: root.muted
                    font { family: root.fontFam; pixelSize: 11 }
                }
            }

            MouseArea {
                id: sessionMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sessionList.visible = !sessionList.visible
            }

            // список доступных оконных менеджеров
            Rectangle {
                id: sessionList
                visible: false
                width: 260
                height: Math.min(sessionModel.rowCount(), 6) * 34 + 12
                radius: 16
                color: Qt.rgba(0.04, 0.04, 0.05, 0.97)
                border.color: root.line
                border.width: 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 8

                ListView {
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    model: sessionModel
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 34
                        radius: 10
                        color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                             : (index === sessionBtn.index ? Qt.rgba(1, 1, 1, 0.06)
                                                           : "transparent")

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            text: model.name
                            color: index === sessionBtn.index ? root.fg : root.muted
                            font {
                                family: root.fontFam; pixelSize: 12
                                bold: index === sessionBtn.index
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            visible: index === sessionBtn.index
                            text: String.fromCodePoint(0xF012C)
                            color: root.accent
                            font { family: root.fontFam; pixelSize: 12 }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sessionBtn.index = index;
                                sessionLabel.text = model.name;
                                sessionList.visible = false;
                                password.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- питание
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        spacing: 14

        Repeater {
            model: [
                { glyph: String.fromCodePoint(0xF0904), tip: root.tr("Сон"),          act: "suspend" },
                { glyph: String.fromCodePoint(0xF0709), tip: root.tr("Перезагрузка"), act: "reboot"  },
                { glyph: String.fromCodePoint(0xF0425), tip: root.tr("Выключить"),    act: "power"   }
            ]

            Rectangle {
                width: 46; height: 46; radius: 23
                color: pwrMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                border.color: root.line
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                scale: pwrMa.pressed ? 0.92 : 1.0
                Behavior on scale { NumberAnimation { duration: 130 } }

                Text {
                    anchors.centerIn: parent
                    text: modelData.glyph
                    color: pwrMa.containsMouse ? root.fg : root.muted
                    font { family: root.fontFam; pixelSize: 18 }
                }

                MouseArea {
                    id: pwrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var a = modelData.act;
                        if (a === "suspend") sddm.suspend();
                        else if (a === "reboot") sddm.reboot();
                        else sddm.powerOff();
                    }
                }
            }
        }
    }

    // раскладка клавиатуры — мелочь, но без неё легко ввести пароль не в той
    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 22
        text: keyboard.layouts.length > 0
              ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase() : ""
        color: root.muted
        font { family: root.fontFam; pixelSize: 12; bold: true; letterSpacing: 1 }
    }

    // --------------------------------------------------------------- логин
    function doLogin() {
        if (root.busy || password.text.length === 0) return;
        root.errorText = "";
        root.busy = true;
        sddm.login(root.loginName, password.text, sessionBtn.index);
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            root.busy = false;
            root.errorText = "";
        }
        function onLoginFailed() {
            root.busy = false;
            root.errorText = root.tr("Неверный пароль");
            password.text = "";
            shake.restart();
            password.forceActiveFocus();
        }
        function onInformationMessage(message) {
            root.busy = false;
            root.errorText = message;
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
