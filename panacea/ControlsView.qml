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

    // «м:сс» для полосы продолжительности; часы появляются только если нужны
    function fmtTime(sec) {
        var t = Math.max(0, Math.floor(sec));
        var h = Math.floor(t / 3600);
        var m = Math.floor((t % 3600) / 60);
        var s = t % 60;
        var mm = h > 0 && m < 10 ? "0" + m : String(m);
        return (h > 0 ? h + ":" : "") + mm + ":" + (s < 10 ? "0" + s : String(s));
    }

    implicitHeight: stack.implicitHeight

    focus: true
    Component.onCompleted: forceActiveFocus()

    // Возврат на плитки. Вынесено в функцию, потому что Escape не всегда
    // доходит сюда: фокус может сидеть в поле пароля Wi-Fi или в списке, и
    // тогда событие всплывает мимо — до Loader'а в shell.qml. Он зовёт
    // goBack() сам, и подстраница закрывается вместо всей панели.
    function goBack() {
        if (view.sys.page === "wifi" || view.sys.page === "bt"
            || view.sys.page === "battery") {
            view.sys.page = "main";
            return true;
        }
        if (view.sys.page === "traymenu") {
            view.sys.page = "main";
            view.sys.trayMenuItem = null;
            return true;
        }
        return false;
    }

    Keys.onEscapePressed: {
        // с подстраниц Esc возвращает назад, с главной — закрывает панель
        if (!view.goBack()) view.sys.collapse();
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

    // Кнопка-иконка нижнего ряда: замок, уведомления, настройки.
    // Тултип — та же чёрная капсула, что всплывает над значками трея.
    component IconBtn: Rectangle {
        property string glyph: ""
        property string tip: ""
        property color glyphColor: view.sys.colMuted
        property color activeColor: view.sys.colFg
        property bool active: false
        property int badge: 0
        signal act()

        implicitWidth: 44
        implicitHeight: 44
        radius: 13
        z: ibMa.containsMouse ? 10 : 0
        color: ibMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
        border.color: active ? Qt.rgba(0.13, 0.77, 0.37, 0.5) : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 160 } }

        scale: ibMa.pressed ? 0.9 : (ibMa.containsMouse ? 1.06 : 1.0)
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

        Glyph {
            anchors.fill: parent
            glyph: parent.glyph
            color: parent.active ? parent.activeColor
                 : ibMa.containsMouse ? view.sys.colFg : parent.glyphColor
            fontFam: view.sys.fontFam
            size: view.sys.iconSize - 2
        }

        // счётчик непрочитанных — только у колокольчика
        Rectangle {
            width: 15; height: 15; radius: 8
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 2
            visible: parent.badge > 0
            color: view.sys.colOn
            Text {
                anchors.centerIn: parent
                text: parent.parent.badge > 9 ? "9+" : parent.parent.badge
                color: "#ffffff"
                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
            }
        }

        MouseArea {
            id: ibMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.act()
        }

        Rectangle {
            id: ibTip
            visible: opacity > 0.01
            opacity: (ibMa.containsMouse && parent.tip.length) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }

            width: ibTipText.implicitWidth + 20
            height: 26
            radius: 13
            x: (parent.width - width) / 2
            y: -height - 8
            color: Qt.rgba(0.04, 0.04, 0.05, 0.96)
            border.color: view.sys.colLine
            border.width: 1

            scale: ibMa.containsMouse ? 1 : 0.92
            transformOrigin: Item.Bottom
            Behavior on scale {
                NumberAnimation { duration: 160; easing.type: Easing.OutBack }
            }

            Text {
                id: ibTipText
                anchors.centerIn: parent
                text: ibTip.parent.tip
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 11 }
            }
        }
    }

    // Волна «идёт зарядка»: две несинхронные синусоиды, налитые до уровня
    // заряда и медленно ползущие вбок. Скругление рисуем прямо в канве и
    // используем как маску — обычный clip у Item только прямоугольный.
    component ChargeWave: Canvas {
        property color tint: view.sys.colOk
        property real level: 0.5        // доля высоты, до которой налито
        property real radius: 14
        property bool running: false
        property real phase: 0

        opacity: running ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        onPhaseChanged: requestPaint()
        onLevelChanged: requestPaint()

        Timer {
            interval: 45
            running: parent.running && parent.visible
            repeat: true
            onTriggered: parent.phase += 0.16
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (width <= 0 || height <= 0) return;

            // маска — скруглённый прямоугольник плитки
            var r = Math.min(radius, Math.min(width, height) / 2);
            ctx.beginPath();
            ctx.moveTo(r, 0);
            ctx.arcTo(width, 0, width, height, r);
            ctx.arcTo(width, height, 0, height, r);
            ctx.arcTo(0, height, 0, 0, r);
            ctx.arcTo(0, 0, width, 0, r);
            ctx.closePath();
            ctx.clip();

            // Уровень держим в стороне от краёв: у самого верха волна
            // срезается маской и выглядит как ровная полоса.
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

    // Компактная плитка для верхней строки: Wi-Fi и Bluetooth стоят рядом,
    // а не двумя полосами друг под другом. Иконка меньше, подпись в две
    // строки, шеврон убран — на треть ширины он только съедал место.
    component MiniTile: Rectangle {
        property string icon: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        property color accent: view.sys.colOn
        // плитка батареи наливается волной, пока идёт зарядка
        property bool wave: false
        property real waveLevel: 0.5
        signal iconClicked()
        signal bodyClicked()

        // implicitWidth обязателен: содержимое прижато якорями, поэтому своей
        // ширины у плитки нет, и RowLayout отдавал всю строку соседу — три
        // карточки схлопывались друг на друга в точке 0,0.
        implicitWidth: 140
        implicitHeight: 56
        radius: 14
        color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.16) : Qt.rgba(1, 1, 1, 0.05)
        border.color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.35) : view.sys.colLine
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        // под содержимым: волна не должна перекрывать подписи
        ChargeWave {
            anchors.fill: parent
            radius: parent.radius
            tint: parent.accent
            level: parent.waveLevel
            running: parent.wave
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 10
            spacing: 8

            Rectangle {
                id: miniIcon
                // крупнее прежних 30: в одном ряду с замком и шестернёй
                // мелкие кружки выглядели вдавленными
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                color: miniIcon.parent.parent.on ? miniIcon.parent.parent.accent
                                                 : Qt.rgba(1, 1, 1, 0.10)
                Behavior on color { ColorAnimation { duration: 180 } }
                scale: miniIconMa.pressed ? 0.9 : (miniIconMa.containsMouse ? 1.07 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: miniIcon.parent.parent.icon
                    color: "#ffffff"
                    font { family: view.sys.fontFam; pixelSize: 17 }
                }
                MouseArea {
                    id: miniIconMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: miniIcon.parent.parent.iconClicked()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: miniIcon.parent.parent.label
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: miniIcon.parent.parent.sub
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.leftMargin: 44     // не перекрываем круглую кнопку
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.bodyClicked()
        }
    }

    // Мелкая плашка с цифрой на странице батареи
    component BattStat: Rectangle {
        property string label: ""
        property string value: ""

        implicitWidth: 90
        implicitHeight: 44
        Layout.fillWidth: true
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: 10 }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.value
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: 12; bold: true }
            }
        }
    }

    // Круглая кнопка управления плеером в карточке трека.
    component MediaBtn: Rectangle {
        property string icon: ""
        property bool primary: false
        property bool enabledAction: true
        signal act()

        implicitWidth: primary ? 42 : 34
        implicitHeight: primary ? 42 : 34
        radius: width / 2
        color: primary ? view.sys.colFg
              : (mbMa.containsMouse ? view.sys.colHover : Qt.rgba(1, 1, 1, 0.08))
        opacity: enabledAction ? 1 : 0.35
        Behavior on color { ColorAnimation { duration: 140 } }
        scale: mbMa.pressed ? 0.9 : (mbMa.containsMouse ? 1.08 : 1.0)
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent
            text: parent.icon
            color: parent.primary ? view.sys.colBg : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: parent.primary ? 17 : 14 }
        }
        MouseArea {
            id: mbMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: parent.enabledAction
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.act()
        }
    }

    // Карточка звука той же высоты: название устройства сверху, под ним
    // ползунок прямо в плитке — громкость правится не уходя на страницу.
    component VolCard: Rectangle {
        implicitWidth: 190
        implicitHeight: 56
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: view.sys.colLine
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            anchors.topMargin: 7
            anchors.bottomMargin: 8
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: view.sys.tr("Звук")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("audio")
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    Layout.maximumWidth: 130
                    text: view.sys.sinkName.length ? view.sys.sinkName
                                                   : view.sys.tr("Нет устройств")
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("audio")
                    }
                }
            }

            // Ползунок-дорожка: заполнение и есть «ручка», как в iOS —
            // отдельный кружок на такой высоте некуда было бы поставить.
            Item {
                id: vol
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                readonly property var a: view.sys.sinkAudio
                readonly property real pos: vol.a ? vol.a.volume : 0
                function setFromX(x) {
                    if (!vol.a) return;
                    var r = Math.max(0, Math.min(1, x / Math.max(1, width)));
                    // шаг 5%, как у мультимедийных клавиш
                    vol.a.volume = Math.round(r * 20) / 20;
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.12)
                    clip: true

                    Rectangle {
                        width: Math.max(parent.height, parent.width * vol.pos)
                        height: parent.height
                        radius: height / 2
                        color: view.sys.colFg
                        Behavior on width {
                            NumberAnimation { duration: volMa.pressed ? 0 : 120 }
                        }
                    }
                }

                // значок слева — он же кнопка «без звука»
                Text {
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: !vol.a ? String.fromCodePoint(0xF075F)
                        : vol.a.muted ? String.fromCodePoint(0xF075F)
                        : vol.a.volume < 0.34 ? String.fromCodePoint(0xF057F)
                        : vol.a.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                              : String.fromCodePoint(0xF057E)
                    color: view.sys.colBg
                    font { family: view.sys.fontFam; pixelSize: 15 }
                }

                MouseArea {
                    id: volMa
                    anchors.fill: parent
                    // клик по самому значку — не тянуть, а заглушить
                    anchors.leftMargin: 22
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => vol.setFromX(mouse.x + 22)
                    onPositionChanged: mouse => { if (pressed) vol.setFromX(mouse.x + 22); }
                }
                MouseArea {
                    width: 22
                    height: parent.height
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (vol.a) vol.a.muted = !vol.a.muted
                }
            }
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
                      : view.sys.page === "battery" ? battPage.implicitHeight
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
                        hoverEnabled: view.sys.cfg.featCalendar
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.togglePage("cal")
                    }
                }

            }

            // ------------------------------- Wi-Fi · Bluetooth · звук в строчку
            // Три самых частых переключателя занимали три полосы подряд.
            // Теперь это одна строка, а громкость правится прямо в плитке.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MiniTile {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    icon: view.sys.wifiOn ? (view.sys.wifiQuality > 66 ? "󰤨"
                                           : view.sys.wifiQuality > 33 ? "󰤥" : "󰤟") : "󰤮"
                    // подключены — в заголовке имя сети, иначе обычное «Wi-Fi»
                    label: (view.sys.wifiOn && view.sys.wifiSsid.length)
                           ? view.sys.wifiSsid : "Wi-Fi"
                    sub: !view.sys.wifiOn ? view.sys.tr("Выключен")
                       : (view.sys.wifiSsid.length
                          ? view.sys.wifiQuality + "%"
                          : view.sys.tr("Не подключено"))
                    on: view.sys.wifiOn
                    onIconClicked: view.sys.toggleWifi()
                    onBodyClicked: {
                        // страница сетей могла быть отключена установщиком —
                        // тогда плитка только переключает Wi-Fi
                        if (!view.sys.wifiOn || !view.sys.cfg.featWifi) return;
                        view.sys.openSub("wifi");
                        view.sys.refreshWifiList();
                        view.sys.scanWifi();
                    }
                }

                MiniTile {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    icon: view.sys.btOn ? "󰂯" : "󰂲"
                    // подключено устройство — его имя вместо «Bluetooth»
                    label: (view.sys.btOn && view.sys.btConnectedName.length)
                           ? view.sys.btConnectedName : "Bluetooth"
                    sub: !view.sys.btOn ? view.sys.tr("Выключен")
                       : (view.sys.btConnectedName.length
                          ? (view.sys.btConnectedBattery >= 0
                             ? "󰥉 " + view.sys.btConnectedBattery + "%"
                             : view.sys.tr("Подключено"))
                          : view.sys.tr("Нет подключений"))
                    on: view.sys.btOn
                    accent: "#0ea5e9"
                    onIconClicked: view.sys.toggleBt()
                    onBodyClicked: {
                        if (!view.sys.btOn || !view.sys.cfg.featBluetooth) return;
                        view.sys.openSub("bt");
                        view.sys.scanBt();
                    }
                }

                VolCard {
                    visible: view.sys.cfg.featAudio
                    Layout.fillWidth: true
                    Layout.preferredWidth: 190
                    Layout.preferredHeight: 56
                }
            }

            // ----------------------------------------------- играющий трек
            // Стоит под переключателями: пока что-то играет, трек с кнопками
            // и эквалайзером во всю ширину заменяет отдельную страницу
            // плеера, которая раньше открывалась по наведению.
            Rectangle {
                id: mediaCard
                readonly property var p: view.sys.player

                visible: view.sys.mediaActive && view.sys.cfg.featPlayer
                Layout.fillWidth: true
                Layout.preferredHeight: 124
                radius: 16
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 12
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 11

                        // обложка — клик открывает подробную страницу плеера
                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.07)
                            clip: true

                            Image {
                                id: cardArt
                                anchors.fill: parent
                                source: view.sys.mediaArt
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 120
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: cardArt.status !== Image.Ready
                                text: "󰝚"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 18 }
                            }
                            // клик по обложке — пауза: отдельной страницы
                            // плеера больше нет, всё управление здесь
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (mediaCard.p) mediaCard.p.togglePlaying()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: mediaCard.p ? mediaCard.p.trackTitle : ""
                                color: view.sys.colFg
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: mediaCard.p ? mediaCard.p.trackArtist : ""
                                color: view.sys.colMuted
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                        }

                        MediaBtn {
                            icon: "󰒮"
                            enabledAction: mediaCard.p ? mediaCard.p.canGoPrevious : false
                            onAct: if (mediaCard.p) mediaCard.p.previous()
                        }
                        MediaBtn {
                            icon: mediaCard.p && mediaCard.p.isPlaying ? "󰏤" : "󰐊"
                            primary: true
                            enabledAction: mediaCard.p ? mediaCard.p.canTogglePlaying : false
                            onAct: if (mediaCard.p) mediaCard.p.togglePlaying()
                        }
                        MediaBtn {
                            icon: "󰒭"
                            enabledAction: mediaCard.p ? mediaCard.p.canGoNext : false
                            onAct: if (mediaCard.p) mediaCard.p.next()
                        }
                    }

                    // ------------------- полоса продолжительности с cava
                    // Эквалайзер и есть ползунок: пройденная часть спектра
                    // светится акцентом, остаток — приглушённый. Так плашка
                    // не растёт на две отдельные полосы, а перемотка видна
                    // прямо по звуку.
                    //
                    // Оба слоя берут один и тот же поток из CavaSource,
                    // поэтому полосы в них совпадают кадр в кадр, и стык
                    // между «сыграно» и «осталось» не видно.
                    Item {
                        id: seek
                        readonly property var p: mediaCard.p
                        readonly property real dur: seek.p ? Math.max(0, seek.p.length) : 0
                        readonly property bool usable:
                            seek.p !== null && seek.dur > 0
                            && seek.p.positionSupported && seek.p.canSeek
                        readonly property real frac: seek.dur > 0
                                ? Math.max(0, Math.min(1, seek.pos / seek.dur)) : 0

                        // позиция, которую показываем: секунды
                        property real pos: 0
                        property bool dragging: false
                        // до первого опроса анимация выключена: иначе на
                        // раскрытии полоса ехала от нуля к текущему месту
                        property bool primed: false

                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        visible: seek.p !== null
                        // панель закрыли — при следующем раскрытии позиция
                        // должна встать на место сразу, а не доезжать
                        Component.onDestruction: seek.primed = false

                        // MPRIS отдаёт позицию только по запросу: между
                        // опросами полосу двигает линейная анимация, иначе
                        // она прыгала бы раз в полсекунды. На перетаскивании
                        // анимация выключена — ручка идёт точно за курсором.
                        Behavior on pos {
                            enabled: seek.primed && !seek.dragging
                            NumberAnimation { duration: 520; easing.type: Easing.Linear }
                        }
                        Timer {
                            interval: 500
                            repeat: true
                            running: seek.visible && seek.p !== null
                            triggeredOnStart: true
                            onTriggered: {
                                if (seek.p === null) return;
                                seek.p.positionChanged();
                                if (seek.dragging) return;
                                seek.pos = seek.p.position;
                                seek.primed = true;
                            }
                        }
                        Connections {
                            target: mediaCard.p
                            ignoreUnknownSignals: true
                            // сменился трек — начинаем с нуля, без переезда
                            function onTrackTitleChanged() {
                                seek.dragging = false;
                                seek.primed = false;   // новый трек — снова без переезда
                                seek.pos = 0;
                            }
                        }

                        function fracOf(x) {
                            return Math.max(0, Math.min(1, x / Math.max(1, seek.width)));
                        }

                        // остаток трека — приглушённые полосы
                        WaveBars {
                            id: barsRest
                            anchors.fill: parent
                            barCount: 46
                            gap: 3
                            barColor: Qt.rgba(1, 1, 1, 0.22)
                            active: seek.p ? seek.p.isPlaying : false
                        }

                        // сыграно — те же полосы акцентом, обрезанные по позиции
                        Item {
                            width: seek.width * seek.frac
                            height: seek.height
                            clip: true
                            WaveBars {
                                width: seek.width
                                height: seek.height
                                barCount: 46
                                gap: 3
                                barColor: view.sys.colOn
                                // Оба слоя живые: с active: false верхние полосы
                                // стояли на месте, и в ритм двигались только
                                // серые из-под них. Поток у CavaSource общий и
                                // считается по ссылкам, второго процесса нет.
                                active: seek.p ? seek.p.isPlaying : false
                            }
                        }

                        // тонкая линия по низу: без неё пустые паузы в звуке
                        // выглядели бы обрывом полосы
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 2
                            radius: 1
                            color: Qt.rgba(1, 1, 1, 0.12)
                            Rectangle {
                                width: parent.width * seek.frac
                                height: parent.height
                                radius: 1
                                color: view.sys.colOn
                            }
                        }

                        // ручка — вертикальная риска на позиции
                        Rectangle {
                            x: seek.width * seek.frac - width / 2
                            width: seekMa.pressed ? 3 : 2
                            height: parent.height
                            radius: 1.5
                            color: "#ffffff"
                            opacity: seek.usable ? (seekMa.containsMouse || seekMa.pressed
                                                    ? 1 : 0.75) : 0.3
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                            Behavior on width { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: seekMa
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            preventStealing: true
                            enabled: seek.usable
                            cursorShape: seek.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: mouse => {
                                seek.dragging = true;
                                seek.pos = seek.fracOf(mouse.x) * seek.dur;
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                seek.pos = seek.fracOf(mouse.x) * seek.dur;
                            }
                            onReleased: mouse => {
                                // отправляем плееру уже на отпускании: на каждом
                                // кадре MPRIS-клиент начинает спорить и дёргать
                                // позицию назад
                                if (seek.usable) seek.p.position = seek.pos;
                                seek.dragging = false;
                            }
                            onCanceled: seek.dragging = false
                        }
                    }

                    // время: прошло и всего
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: -6
                        visible: seek.visible && seek.dur > 0
                        Text {
                            text: view.fmtTime(seek.pos)
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 10 }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: view.fmtTime(seek.dur)
                            color: Qt.rgba(1, 1, 1, 0.28)
                            font { family: view.sys.fontFam; pixelSize: 10 }
                        }
                    }
                }
            }

            // ------------------------------- запись экрана · режим батареи
            // Режимы питания больше не занимают отдельную полосу из трёх
            // сегментов: они уехали на страницу батареи, а сюда встала одна
            // плитка рядом с записью.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MiniTile {
                    visible: view.sys.cfg.featRecord
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    icon: String.fromCodePoint(view.sys.recActive ? 0xF04DB : 0xF044A)
                    label: view.sys.recActive
                           ? view.sys.tr("Запись") + " · " + view.sys.recTimeText
                           : view.sys.tr("Запись экрана")
                    sub: !view.sys.recActive
                         ? view.sys.cfg.recFps + " FPS"
                         : (view.sys.recPaused ? view.sys.tr("Пауза")
                                               : view.sys.recFile.split("/").pop())
                    on: view.sys.recActive
                    accent: "#ef4444"
                    onIconClicked: view.sys.toggleRecord()
                    onBodyClicked: view.sys.togglePage("record")
                }

                MiniTile {
                    visible: view.sys.cfg.featPowerProfiles || view.sys.batteryPresent
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    icon: view.sys.batteryPresent ? view.sys.batteryLevelIcon
                                                  : String.fromCodePoint(0xF0241)
                    label: view.sys.batteryPresent
                           ? view.sys.batteryPct + "%" : view.sys.tr("Батарея")
                    // подпись — состояние питания и текущий режим, без
                    // прогнозов «сколько осталось»: UPower врёт на глазах
                    sub: view.sys.batteryCharging ? view.sys.tr("Заряжается")
                       : view.sys.acOnline ? view.sys.tr("От сети")
                                           : view.sys.profileLabel
                    on: view.sys.batteryCharging || view.sys.acOnline
                    wave: view.sys.batteryCharging
                    waveLevel: view.sys.batteryPct / 100
                    accent: view.sys.batteryPct <= 15 && !view.sys.acOnline
                            ? view.sys.colCrit : view.sys.colOk
                    onIconClicked: view.sys.openSub("battery")
                    onBodyClicked: view.sys.openSub("battery")
                }
            }

            // -------------------------------- не спать + кнопки-иконки
            // Замок, уведомления и настройки уехали сюда из правого верхнего
            // угла: одна нижняя полоса вместо значков, спорящих с часами.
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
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        glyph: String.fromCodePoint(view.sys.keepAwake ? 0xF0176 : 0xF0177)
                        color: view.sys.keepAwake ? "#f59e0b" : view.sys.colMuted
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize + 2
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

            // менеджер паролей: замок открыт, когда хранилище разблокировано
            IconBtn {
                visible: view.sys.cfg.featVault
                glyph: String.fromCodePoint(view.sys.vaultUnlocked ? 0xF0FC6 : 0xF033E)
                tip: view.sys.tr("Пароли")
                active: view.sys.vaultUnlocked
                activeColor: "#22c55e"
                onAct: view.sys.togglePage("vault")
            }

            // колокольчик: активные уведомления и история
            IconBtn {
                visible: view.sys.cfg.featNotifications
                glyph: String.fromCodePoint(view.sys.dnd ? 0xF009B : 0xF009A)
                tip: view.sys.dnd ? view.sys.tr("Не беспокоить") : view.sys.tr("Уведомления")
                badge: view.sys.notifications.count
                onAct: view.sys.togglePage("notif")
            }

            IconBtn {
                glyph: String.fromCodePoint(0xF0493)
                tip: view.sys.tr("Настройки")
                onAct: view.sys.togglePage("settings")
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

        // ---------------------------------------------------------- батарея
        // Режимы питания плюс всё, что UPower знает про заряд: сколько
        // осталось работы (или до полной зарядки), ёмкость и износ.
        ColumnLayout {
            id: battPage
            width: parent.width
            spacing: 8
            opacity: view.sys.page === "battery" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: view.sys.animFast } }

            Header {
                title: view.sys.tr("Батарея")
                onBack: view.sys.page = "main"
            }

            // крупная строка состояния: процент и что происходит сейчас
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1

                readonly property color tint:
                    view.sys.batteryCharging || view.sys.acOnline ? view.sys.colOk
                  : view.sys.batteryPct <= 15 ? view.sys.colCrit
                  : view.sys.colFg

                // пока подключена зарядка — плашка налита живой волной
                ChargeWave {
                    anchors.fill: parent
                    radius: parent.radius
                    tint: view.sys.colOk
                    level: view.sys.batteryPct / 100
                    running: view.sys.batteryCharging
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Glyph {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        glyph: view.sys.batteryLevelIcon
                        color: parent.parent.tint
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize + 3
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: view.sys.batteryPct + "%"
                            color: parent.parent.parent.tint
                            font { family: view.sys.fontFam; pixelSize: 18; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: view.sys.batteryCharging
                                  ? view.sys.tr("Заряжается")
                                  : view.sys.acOnline ? view.sys.tr("От сети")
                                                      : view.sys.profileLabel
                            color: view.sys.colMuted
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }

                    // Индикатор питания вместо прогнозов времени: молния,
                    // когда идёт зарядка, вилка — когда просто от сети.
                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        radius: 15
                        visible: view.sys.batteryCharging || view.sys.acOnline
                        color: Qt.rgba(view.sys.colOk.r, view.sys.colOk.g,
                                       view.sys.colOk.b, 0.18)

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(
                                      view.sys.batteryCharging ? 0xF0241 : 0xF06A5)
                            color: view.sys.colOk
                            font { family: view.sys.fontFam; pixelSize: 15 }
                            // пока заряжается — молния мягко пульсирует
                            SequentialAnimation on opacity {
                                running: view.sys.batteryCharging
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: 750; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutSine }
                            }
                            onVisibleChanged: if (!visible) opacity = 1
                        }
                    }
                }
            }

            // режимы питания — те самые три сегмента, теперь живут здесь
            RowLayout {
                visible: view.sys.cfg.featPowerProfiles
                Layout.fillWidth: true
                spacing: 8

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

            // мелкие цифры — ёмкость, износ и текущий расход, в одну полосу
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: view.sys.batteryPresent

                BattStat {
                    label: view.sys.tr("Ёмкость")
                    value: view.sys.batteryCapacity > 0
                           ? view.sys.batteryCapacity.toFixed(1) + " Wh" : "—"
                }
                BattStat {
                    label: view.sys.tr("Износ")
                    value: view.sys.batteryHealth > 0
                           ? view.sys.batteryHealth + "%" : "—"
                }
                BattStat {
                    label: view.sys.batteryCharging ? "󰐥" : "󰚥"
                    value: Math.abs(view.sys.batteryRate) > 0.05
                           ? Math.abs(view.sys.batteryRate).toFixed(1) + " W" : "—"
                }
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
