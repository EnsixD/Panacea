import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth

// Раскрытая панель без музыки: Wi-Fi и Bluetooth.
//
// Три страницы внутри одной панели (sys.page):
//   main — две плитки-переключателя
//   wifi — список сетей + ввод пароля
//   bt   — список устройств
Item {
    id: view
    property var sys

    implicitHeight: stack.implicitHeight

    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onEscapePressed: {
        // с подстраниц Esc возвращает назад, с главной — закрывает панель
        if (view.sys.page === "wifi" || view.sys.page === "bt") view.sys.page = "main";
        else if (view.sys.page === "traymenu") {
            view.sys.page = "main";
            view.sys.trayMenuItem = null;
        }
        else view.sys.collapse();
    }

    // ------------------------------------------------------- общие компоненты

    // Сегмент выбора режима питания: иконка + подпись, активный подсвечен
    component PowerSeg: Rectangle {
        property string icon: ""
        property string label: ""
        property string profile: ""
        property color accent: view.sys.colOn
        readonly property bool active: view.sys.powerProfile === profile

        Layout.fillWidth: true
        Layout.preferredHeight: 54
        radius: 14
        color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.18)
                      : (segMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09)
                                             : Qt.rgba(1, 1, 1, 0.05))
        border.color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.40)
                             : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        scale: segMa.pressed ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.icon
                color: parent.parent.active ? parent.parent.accent : "#ffffff"
                font { family: view.sys.fontFam; pixelSize: 17 }
                Behavior on color { ColorAnimation { duration: 180 } }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                color: parent.parent.active ? view.sys.colFg : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 11; bold: parent.parent.active }
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }

        MouseArea {
            id: segMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.sys.setPowerProfile(parent.profile)
        }
    }

    // Плитка: слева иконка (переключает), справа название (открывает список)
    component Tile: Rectangle {
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        property color accent: view.sys.colOn
        signal iconClicked()
        signal bodyClicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 62
        radius: 16
        color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.16) : Qt.rgba(1, 1, 1, 0.05)
        border.color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.35) : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 11

            // круглая кнопка-иконка — включить/выключить
            Rectangle {
                id: iconBtn
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: parent.parent.on ? parent.parent.accent : Qt.rgba(1, 1, 1, 0.10)
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: iconMa.pressed ? 0.9 : (iconMa.containsMouse ? 1.06 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: iconBtn.parent.parent.icon
                    color: "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 17 }
                }
                MouseArea {
                    id: iconMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: iconBtn.parent.parent.iconClicked()
                }
            }

            // подпись — открывает список
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: iconBtn.parent.parent.label
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: iconBtn.parent.parent.sub
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 11 }
                }
            }

            Text {
                text: ""
                color: bodyMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 13 }
                Behavior on color { ColorAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: bodyMa
            anchors.fill: parent
            anchors.leftMargin: 58     // не перекрываем круглую кнопку
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.bodyClicked()
        }
    }

    // Шапка страницы-списка: назад + заголовок + обновить
    component Header: RowLayout {
        property string title: ""
        property bool busy: false
        signal back()
        signal refresh()

        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 28; Layout.preferredHeight: 28
            radius: 14
            color: backMa.containsMouse ? view.sys.colHover : "transparent"
            Behavior on color { ColorAnimation { duration: 130 } }
            Text {
                anchors.centerIn: parent; text: ""
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 13 }
            }
            MouseArea {
                id: backMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.back()
            }
        }
        Text {
            Layout.fillWidth: true
            text: parent.title
            color: view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: 13; bold: true }
        }
        Rectangle {
            Layout.preferredWidth: 28; Layout.preferredHeight: 28
            radius: 14
            color: refMa.containsMouse ? view.sys.colHover : "transparent"
            Behavior on color { ColorAnimation { duration: 130 } }
            Text {
                id: refIcon
                anchors.centerIn: parent; text: "󰑐"
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 13 }
                RotationAnimator on rotation {
                    running: refIcon.parent.parent.busy
                    loops: Animation.Infinite
                    from: 0; to: 360; duration: 900
                }
            }
            MouseArea {
                id: refMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.refresh()
            }
        }
    }

    // Строка списка
    component Row1: Rectangle {
        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool highlight: false
        signal activated()

        Layout.fillWidth: true
        Layout.preferredHeight: 42
        radius: 12
        color: rowMa.containsMouse ? view.sys.colHover
             : (highlight ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
        Behavior on color { ColorAnimation { duration: 130 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            spacing: 10
            Text {
                text: rowMa.parent.icon
                color: rowMa.parent.highlight ? view.sys.colOn : view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 15 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: rowMa.parent.title
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 12; bold: rowMa.parent.highlight }
                }
                Text {
                    text: rowMa.parent.sub
                    visible: text.length > 0
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }
            Text {
                visible: rowMa.parent.highlight
                text: "󰄬"
                color: view.sys.colOn
                font { family: view.sys.fontFam; pixelSize: 13 }
            }
        }
        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.activated()
        }
    }

    // ------------------------------------------------------------- страницы
    Item {
        id: stack
        width: parent.width
        implicitHeight: view.sys.page === "main" ? mainPage.implicitHeight
                      : view.sys.page === "wifi" ? wifiPage.implicitHeight
                      : view.sys.page === "traymenu" ? trayPage.implicitHeight
                      : btPage.implicitHeight
        // Высоту анимирует сама капсула в shell.qml. Вторая анимация здесь
        // складывалась с ней: капсула догоняла уже анимируемое значение,
        // и панель расширялась заметно дольше, чем нужно.

        // ---------------------------------------------------------- главная
        ColumnLayout {
            id: mainPage
            width: parent.width
            spacing: 9
            opacity: view.sys.page === "main" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            // заголовок с шестернёй: быстрый переход в настройки
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // часы: клик открывает календарь
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 12
                    color: clockMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 4
                        spacing: 10

                        Text {
                            text: view.sys.timeText
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 8; bold: true }
                        }
                        ColumnLayout {
                            spacing: -1
                            Text {
                                text: view.sys.dateLong
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                            }
                            Text {
                                visible: view.sys.cfg.featCalendar
                                text: view.sys.tr("Календарь")
                                color: clockMa.containsMouse ? view.sys.colOn
                                                            : Qt.rgba(1, 1, 1, 0.28)
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                    }

                    MouseArea {
                        id: clockMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("cal")
                    }
                }

                // колокольчик: активные уведомления и история
                Rectangle {
                    id: bellBtn
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: bellMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: view.sys.colLine
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 160 } }

                    scale: bellMa.pressed ? 0.9 : (bellMa.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                    Glyph {
                        anchors.fill: parent
                        glyph: String.fromCodePoint(view.sys.dnd ? 0xF009B : 0xF009A)
                        color: view.sys.dnd ? view.sys.colMuted
                             : bellMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize - 3
                    }

                    // счётчик непрочитанных
                    Rectangle {
                        width: 15; height: 15; radius: 8
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: -3
                        visible: view.sys.notifications.count > 0
                        color: view.sys.colOn
                        Text {
                            anchors.centerIn: parent
                            text: view.sys.notifications.count > 9 ? "9+" : view.sys.notifications.count
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                        }
                    }

                    MouseArea {
                        id: bellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("notif")
                    }
                }

                Rectangle {
                    id: gearBtn
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 16
                    color: gearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: view.sys.colLine
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 160 } }

                    scale: gearMa.pressed ? 0.9 : (gearMa.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                    Glyph {
                        anchors.fill: parent
                        glyph: String.fromCodePoint(0xF0493)
                        color: gearMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize - 2
                        rotation: gearMa.containsMouse ? 60 : 0
                        Behavior on rotation {
                            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        id: gearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("settings")
                    }
                }
            }

            Tile {
                icon: view.sys.wifiOn ? (view.sys.wifiQuality > 66 ? "󰤨"
                                       : view.sys.wifiQuality > 33 ? "󰤥" : "󰤟") : "󰤮"
                // подключены — в заголовке имя сети, иначе обычное «Wi-Fi»
                label: (view.sys.wifiOn && view.sys.wifiSsid.length)
                       ? view.sys.wifiSsid : "Wi-Fi"
                sub: !view.sys.wifiOn ? view.sys.tr("Выключен")
                   : (view.sys.wifiSsid.length
                      ? view.sys.tr("Подключено") + " · " + view.sys.wifiQuality + "%"
                      : view.sys.tr("Не подключено"))
                on: view.sys.wifiOn
                onIconClicked: view.sys.toggleWifi()
                onBodyClicked: {
                    // страница сетей могла быть отключена установщиком —
                    // тогда плитка только переключает Wi-Fi
                    if (!view.sys.wifiOn || !view.sys.cfg.featWifi) return;
                    view.sys.page = "wifi";
                    view.sys.refreshWifiList();
                    view.sys.scanWifi();
                }
            }

            Tile {
                icon: view.sys.btOn ? "󰂯" : "󰂲"
                // подключено устройство — его имя вместо «Bluetooth»
                label: (view.sys.btOn && view.sys.btConnectedName.length)
                       ? view.sys.btConnectedName : "Bluetooth"
                sub: !view.sys.btOn ? view.sys.tr("Выключен")
                   : (view.sys.btConnectedName.length
                      ? (view.sys.tr("Подключено")
                         + (view.sys.btConnectedBattery >= 0
                            ? " · 󰥉 " + view.sys.btConnectedBattery + "%" : ""))
                      : view.sys.tr("Нет подключений"))
                on: view.sys.btOn
                accent: "#0ea5e9"
                onIconClicked: view.sys.toggleBt()
                onBodyClicked: {
                    if (!view.sys.btOn || !view.sys.cfg.featBluetooth) return;
                    view.sys.page = "bt";
                    view.sys.scanBt();
                }
            }

            // ------------------------------------------------------ звук
            Tile {
                visible: view.sys.cfg.featAudio
                icon: String.fromCodePoint(0xF057E)
                label: view.sys.tr("Звук")
                sub: view.sys.sinkName.length ? view.sys.sinkName
                                              : view.sys.tr("Нет устройств")
                on: false
                accent: "#a855f7"
                onIconClicked: view.sys.togglePage("audio")
                onBodyClicked: view.sys.togglePage("audio")
            }

            // ---------------------------------------------- запись экрана
            Tile {
                visible: view.sys.cfg.featRecord
                icon: String.fromCodePoint(view.sys.recActive ? 0xF04DB : 0xF044A)
                label: view.sys.recActive
                       ? view.sys.tr("Запись") + " · " + view.sys.recTimeText
                       : view.sys.tr("Запись экрана")
                sub: !view.sys.recActive
                     ? view.sys.cfg.recFps + " FPS · " + view.sys.cfg.recDir
                     : (view.sys.recPaused ? view.sys.tr("Пауза")
                                           : view.sys.recFile.split("/").pop())
                on: view.sys.recActive
                accent: "#ef4444"
                onIconClicked: view.sys.toggleRecord()
                onBodyClicked: view.sys.togglePage("record")
            }

            // ------------------------------------------- режимы питания
            RowLayout {
                visible: view.sys.cfg.featPowerProfiles
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 9

                PowerSeg {
                    icon: "󰾆"
                    label: view.sys.tr("Экономия")
                    profile: "power-saver"
                    accent: view.sys.colOk
                }
                PowerSeg {
                    icon: "󰾅"
                    label: view.sys.tr("Баланс")
                    profile: "balanced"
                    accent: view.sys.colOn
                }
                PowerSeg {
                    icon: "󰓅"
                    label: view.sys.tr("Максимум")
                    profile: "performance"
                    accent: "#f59e0b"
                }
            }

            // ------------------------------------------- не спать + батарея
            // Заряд стоит компактной плашкой справа от Coffee mode: обе
            // строчки про «сколько машина ещё протянет», и вместе они
            // занимают одну полосу вместо двух.
            RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 12
                color: view.sys.keepAwake
                       ? Qt.rgba(0.96, 0.62, 0.04, 0.16)
                       : (awakeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                border.color: view.sys.keepAwake ? Qt.rgba(0.96, 0.62, 0.04, 0.40)
                                                 : view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 13
                    anchors.rightMargin: 13
                    spacing: 11

                    Glyph {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        glyph: String.fromCodePoint(view.sys.keepAwake ? 0xF0176 : 0xF0177)
                        color: view.sys.keepAwake ? "#f59e0b" : view.sys.colMuted
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize - 2
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Coffee mode"
                        color: view.sys.keepAwake ? view.sys.colFg : view.sys.colMuted
                        font {
                            family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2
                            bold: view.sys.keepAwake
                        }
                    }
                    // переключатель
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 21
                        radius: 11
                        color: view.sys.keepAwake ? "#f59e0b" : Qt.rgba(1, 1, 1, 0.14)
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Rectangle {
                            width: 17; height: 17; radius: 9
                            y: 2
                            x: view.sys.keepAwake ? parent.width - width - 2 : 2
                            color: "#ffffff"
                            Behavior on x {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }

                MouseArea {
                    id: awakeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.keepAwake = !view.sys.keepAwake
                }
            }

            // ------------------------------------------------------ батарея
            Rectangle {
                id: battChip
                visible: view.sys.batteryPresent
                // По содержимому, а не на всю строку: Coffee mode тянется,
                // плашка остаётся ровно такой, какой нужна.
                Layout.preferredWidth: battRow.implicitWidth + 24
                Layout.preferredHeight: 44
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1

                readonly property color tint:
                    view.sys.batteryCharging || view.sys.acOnline ? view.sys.colOk
                  : view.sys.batteryPct <= 15 ? view.sys.colCrit
                  : view.sys.colFg

                RowLayout {
                    id: battRow
                    anchors.centerIn: parent
                    spacing: 5

                    Glyph {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        glyph: view.sys.batteryLevelIcon
                        color: battChip.tint
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize - 2
                    }
                    Glyph {
                        visible: view.sys.batteryCharging
                        Layout.preferredWidth: visible ? 12 : 0
                        Layout.preferredHeight: 22
                        glyph: String.fromCodePoint(0xF0241)  // молния
                        color: view.sys.colOk
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize - 6
                    }
                    Text {
                        text: view.sys.batteryPct + "%"
                        color: battChip.tint
                        font {
                            family: view.sys.fontFam
                            pixelSize: view.sys.fontSize - 2
                            bold: true
                        }
                    }
                }
            }
            }

            // ------------------------------------------------ системный трей
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8
                visible: view.sys.trayItems.values.length > 0

                Text {
                    text: view.sys.tr("Трей")
                    color: view.sys.colMuted
                    font {
                        family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                        bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                    }
                }

                Repeater {
                    model: view.sys.trayItems

                    Rectangle {
                        id: trayBtn
                        required property var modelData

                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        z: trayMa.containsMouse ? 10 : 0
                        radius: 10
                        color: trayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: view.sys.colLine
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        scale: trayMa.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 7
                            source: String(trayBtn.modelData.icon || "")
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        MouseArea {
                            id: trayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: mouse => {
                                // ПКМ — контекстное меню приложения (Telegram и т.п.)
                                if (mouse.button === Qt.RightButton) {
                                    if (!trayBtn.modelData.hasMenu) return;
                                    view.sys.trayMenuItem = trayBtn.modelData;
                                    view.sys.page = "traymenu";
                                    view.sys.holdOpen = true;
                                    return;
                                }
                                if (mouse.button === Qt.MiddleButton)
                                    trayBtn.modelData.secondaryActivate();
                                else
                                    trayBtn.modelData.activate();
                                view.sys.collapse();
                            }
                        }

                        // Свой тултип вместо системного: та же чёрная капсула,
                        // что и вся пилюля.
                        Rectangle {
                            id: tip
                            readonly property string label:
                                String(trayBtn.modelData.tooltipTitle
                                       || trayBtn.modelData.title || "")

                            visible: opacity > 0.01
                            opacity: (trayMa.containsMouse && label.length) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }

                            width: tipText.implicitWidth + 20
                            height: 26
                            radius: 13
                            x: (parent.width - width) / 2
                            y: -height - 8
                            color: Qt.rgba(0.04, 0.04, 0.05, 0.96)
                            border.color: view.sys.colLine
                            border.width: 1

                            scale: trayMa.containsMouse ? 1 : 0.92
                            transformOrigin: Item.Bottom
                            Behavior on scale {
                                NumberAnimation { duration: 160; easing.type: Easing.OutBack }
                            }

                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                text: tip.label
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        // ------------------------------------------------------------ Wi-Fi
        ColumnLayout {
            id: wifiPage
            width: parent.width
            spacing: 7
            opacity: view.sys.page === "wifi" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: view.sys.tr("Сети Wi-Fi")
                busy: view.sys.wifiBusy
                onBack: { view.sys.page = "main"; passwordFor = ""; }
                onRefresh: view.sys.scanWifi()
            }

            // ввод пароля для выбранной сети
            property string passwordFor: ""

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                visible: wifiPage.passwordFor.length > 0
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: view.sys.colLine
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 7
                    spacing: 8

                    Text {
                        text: "󰌾"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 14 }
                    }
                    TextField {
                        id: pwField
                        Layout.fillWidth: true
                        placeholderText: view.sys.tr("Пароль от «") + wifiPage.passwordFor + "»"
                        echoMode: TextInput.Password
                        color: view.sys.colFg
                        placeholderTextColor: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 12 }
                        background: null
                        onAccepted: connectBtn.go()
                    }
                    Rectangle {
                        id: connectBtn
                        function go() {
                            if (!pwField.text.length) return;
                            view.sys.connectWifi(wifiPage.passwordFor, pwField.text);
                            wifiPage.passwordFor = "";
                            pwField.text = "";
                            view.sys.holdOpen = false;
                        }
                        Layout.preferredWidth: 34; Layout.preferredHeight: 32
                        radius: 10
                        color: pwField.text.length ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.10)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent; text: ""
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 13 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: connectBtn.go()
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: view.sys.wifiError.length > 0
                text: view.sys.wifiError
                color: view.sys.colCrit
                font { family: view.sys.fontFam; pixelSize: 11 }
            }

            // список сетей
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: view.sys.wifiNetworks
                    Row1 {
                        required property var model
                        icon: model.quality > 66 ? "󰤨" : model.quality > 33 ? "󰤥" : "󰤟"
                        title: model.ssid
                        sub: (model.security === "open" ? view.sys.tr("Открытая") : view.sys.tr("Защищённая"))
                             + " · " + model.quality + "%"
                             + (model.known ? view.sys.tr(" · сохранена") : "")
                        highlight: model.connected
                        onActivated: {
                            if (model.connected) return;
                            if (model.security === "open" || model.known) {
                                view.sys.connectWifi(model.ssid, "");
                            } else {
                                wifiPage.passwordFor = model.ssid;
                                view.sys.holdOpen = true;
                                pwFocus.restart();
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: view.sys.wifiNetworks.count === 0
                text: view.sys.wifiBusy ? view.sys.tr("Поиск сетей…") : view.sys.tr("Сети не найдены")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }

            Timer { id: pwFocus; interval: 80; onTriggered: pwField.forceActiveFocus() }
        }

        // ------------------------------------------- контекстное меню трея
        ColumnLayout {
            id: trayPage
            width: parent.width
            spacing: 3
            opacity: view.sys.page === "traymenu" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            // цепочка вложенных подменю: последний элемент — текущее меню
            property var chain: []
            readonly property var rootHandle:
                view.sys.trayMenuItem ? view.sys.trayMenuItem.menu : null
            readonly property var handle:
                chain.length > 0 ? chain[chain.length - 1] : rootHandle

            // новая иконка — начинаем с её корневого меню.
            // Присваиваем только когда есть что сбрасывать: иначе QML видит
            // цикл chain -> handle -> chain и ругается на каждом открытии.
            onRootHandleChanged: if (chain.length > 0) chain = []

            QsMenuOpener {
                id: menuOpener
                menu: trayPage.handle
            }

            Header {
                title: view.sys.trayMenuItem
                       ? String(view.sys.trayMenuItem.tooltipTitle
                                || view.sys.trayMenuItem.title || view.sys.tr("Меню"))
                       : view.sys.tr("Меню")
                busy: false
                onBack: {
                    if (trayPage.chain.length > 0) {
                        var c = trayPage.chain.slice();
                        c.pop();
                        trayPage.chain = c;
                    } else {
                        view.sys.page = "main";
                        view.sys.trayMenuItem = null;
                    }
                }
                onRefresh: {}
            }

            Repeater {
                model: menuOpener.children

                // разделитель и обычный пункт — в одном делегате: Repeater
                // не умеет выбирать компонент по данным модели
                Item {
                    id: entry
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: modelData.isSeparator ? 9 : 34

                    Rectangle {
                        visible: entry.modelData.isSeparator
                        height: 1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: view.sys.colLine
                    }

                    Rectangle {
                        visible: !entry.modelData.isSeparator
                        anchors.fill: parent
                        radius: 10
                        color: entryMa.containsMouse && entry.modelData.enabled
                               ? view.sys.colHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            spacing: 9

                            // галочка/радио для переключаемых пунктов
                            Text {
                                visible: entry.modelData.buttonType !== QsMenuButtonType.None
                                text: entry.modelData.checkState === Qt.Checked
                                      ? "󰄬" : "󰝦"
                                color: entry.modelData.checkState === Qt.Checked
                                       ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }

                            Image {
                                visible: String(entry.modelData.icon || "").length > 0
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                source: String(entry.modelData.icon || "")
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: String(entry.modelData.text || "")
                                color: entry.modelData.enabled
                                       ? view.sys.colFg : view.sys.colMuted
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }

                            // стрелка у подменю
                            Text {
                                visible: entry.modelData.hasChildren
                                text: ""
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                        }

                        MouseArea {
                            id: entryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entry.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entry.modelData.hasChildren) {
                                    var c = trayPage.chain.slice();
                                    c.push(entry.modelData);
                                    trayPage.chain = c;
                                    return;
                                }
                                entry.modelData.triggered();
                                view.sys.collapse();
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !menuOpener.children || menuOpener.children.values.length === 0
                text: view.sys.tr("Меню пустое")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }

        // -------------------------------------------------------- Bluetooth
        ColumnLayout {
            id: btPage
            width: parent.width
            spacing: 7
            opacity: view.sys.page === "bt" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: view.sys.tr("Устройства Bluetooth")
                busy: view.sys.btAdapter ? view.sys.btAdapter.discovering : false
                onBack: view.sys.page = "main"
                onRefresh: view.sys.scanBt()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: view.sys.btDevices
                    Row1 {
                        id: row1
                        required property var modelData
                        icon: modelData.icon === "audio-headset" ? "󰋋"
                            : modelData.icon === "input-mouse" ? "󰦋"
                            : modelData.icon === "input-keyboard" ? "󰌌"
                            : modelData.icon === "phone" ? "󰄞" : "󰂯"
                        title: modelData.name || modelData.address
                        // Статус проходит через «Сопряжение…» и «Подключение…»,
                        // чтобы было видно, что происходит, а не «моргало».
                        sub: modelData.pairing ? view.sys.tr("Сопряжение…")
                           : modelData.state === BluetoothDeviceState.Connecting ? view.sys.tr("Подключение…")
                           : modelData.connected ? view.sys.tr("Подключено")
                           : (modelData.paired || modelData.bonded ? view.sys.tr("Сопряжено") : view.sys.tr("Доступно"))
                             + (modelData.batteryAvailable
                                ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                        highlight: modelData.connected || modelData.pairing
                                   || modelData.state === BluetoothDeviceState.Connecting
                        onActivated: {
                            if (modelData.connected) { modelData.disconnect(); return; }
                            // Недоверенное устройство BlueZ подключает и тут же
                            // роняет; несопряжённое вообще не держится. Делаем
                            // доверенным, сопрягаем, а после сопряжения — сами
                            // подключаемся (pair не всегда доводит до звука).
                            modelData.trusted = true;
                            if (modelData.paired || modelData.bonded) modelData.connect();
                            else modelData.pair();
                        }
                        // как только сопряжение завершилось — подключаемся
                        property var dev: modelData
                        Connections {
                            target: row1.dev
                            function onPairedChanged() {
                                if (row1.dev.paired && !row1.dev.connected) row1.dev.connect();
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !view.sys.btDevices || view.sys.btDevices.values.length === 0
                text: (view.sys.btAdapter && view.sys.btAdapter.discovering)
                      ? view.sys.tr("Поиск устройств…") : view.sys.tr("Устройства не найдены")
                color: view.sys.colMuted
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }
    }

}
