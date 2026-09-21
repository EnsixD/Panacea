import QtQuick
import QtQuick.Layouts

// Настольные виджеты темы Nothing — карточки поверх обоев.
//
// Дизайн в стиле Nothing OS:
// - Дата с точечным числом и днем недели (красный в выходные)
// - Аналоговые минималистичные часы Nothing с точечным циферблатом и красной
//   секундной точкой colCrit (по клику переключаются в цифровой точечный режим)
// - Погода с точечными иконками и круглыми индикаторами влажности/ветра
// - Концентрический системный монитор RAM и SSD (по клику на правый блок)
// - Шкала прогресса (Life Bar): 24-сегментный прогресс дня с пульсирующим
//   текущим часом или 12-сегментный прогресс года.
//
// Клик по карточкам переключает их режимы с сохранением настроек.
Item {
    id: view

    property var sys

    // Ширина колонки и просвет между карточками. Из них считается всё
    // остальное, поэтому размер набора правится этими двумя числами.
    readonly property real col: 144
    readonly property real gap: 12
    readonly property real fullW: view.col * 2 + view.gap

    implicitWidth: view.fullW
    implicitHeight: stack.implicitHeight

    // Режимы карточек
    readonly property string clockMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetClockMode) || "analog"
    readonly property string rightMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetRightMode) || "weather"
    readonly property string progressMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetProgressMode) || "day"

    // Реактивный пересчёт прогресса дня и года по view.sys.timeText
    readonly property int curHour: { var _ = (view.sys && view.sys.timeText); return (new Date()).getHours(); }
    readonly property int curMin: { var _ = (view.sys && view.sys.timeText); return (new Date()).getMinutes(); }
    readonly property int curMonth: { var _ = (view.sys && view.sys.dayNum); return (new Date()).getMonth(); }

    readonly property int curDayOfYear: {
        var _ = (view.sys && view.sys.dayNum);
        var now = new Date();
        var start = new Date(now.getFullYear(), 0, 1);
        return Math.floor((now - start) / (1000 * 60 * 60 * 24));
    }
    readonly property int totalDaysInYear: {
        var _ = (view.sys && view.sys.dayNum);
        var now = new Date();
        var start = new Date(now.getFullYear(), 0, 1);
        var end = new Date(now.getFullYear() + 1, 0, 1);
        return Math.max(1, Math.round((end - start) / (1000 * 60 * 60 * 24)));
    }

    readonly property int dayPct: Math.min(100, Math.max(0, Math.floor((curHour * 60 + curMin) / 1440 * 100)))
    readonly property int yearPct: Math.min(100, Math.max(0, Math.floor(curDayOfYear / totalDaysInYear * 100)))

    readonly property int remainDayMins: Math.max(0, 1440 - (curHour * 60 + curMin))
    readonly property string remainDayText: Math.floor(remainDayMins / 60) + (view.sys && view.sys.isEn ? "h " : "ч ") + (remainDayMins % 60) + (view.sys && view.sys.isEn ? "m" : "м")
    readonly property int remainYearDays: Math.max(0, totalDaysInYear - curDayOfYear)

    // Пульсация текущего сегмента времени в стиле глифов Nothing
    property real pulseOpacity: 1.0
    SequentialAnimation on pulseOpacity {
        loops: Animation.Infinite
        running: view.visible
        NumberAnimation { to: 0.30; duration: 750; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutQuad }
    }

    // Общий вид карточки: тёмная плашка со скруглением
    component Card: Rectangle {
        radius: 22
        color: Qt.rgba(0.09, 0.09, 0.09, 0.96)
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
    }

    // Точечное число
    component Num: Item {
        id: num
        property string value: ""
        property real size: 14
        property real gapRatio: 0.22
        property color color: view.sys ? view.sys.colFg : "#ffffff"

        implicitWidth:  dots.implicitWidth
        implicitHeight: dots.implicitHeight

        DotText {
            id: dots
            value: num.value
            size: num.size
            gapRatio: num.gapRatio
            color: num.color
        }
    }

    // Значок погоды: точечный DotIcon
    component WIcon: Item {
        id: wico
        property real size: 20
        property color color: view.sys ? view.sys.colFg : "#ffffff"

        implicitWidth:  wdots.implicitWidth
        implicitHeight: wdots.implicitHeight

        DotIcon {
            id: wdots
            code: view.sys ? view.sys.weatherIcon : 0
            size: wico.size
            color: wico.color
        }
    }

    // Мелкая подпись заглавными вразрядку
    component Caption: Text {
        color: view.sys ? view.sys.colMuted : "#888888"
        elide: Text.ElideRight
        font {
            family: view.sys ? view.sys.fontFam : "sans-serif"
            pixelSize: 9
            capitalization: Font.AllUppercase
            letterSpacing: 1.1
        }
    }

    ColumnLayout {
        id: stack
        width: view.fullW
        spacing: view.gap

        // ------------------------------------------------------ Ряд 1: Дата и Часы
        RowLayout {
            Layout.preferredWidth: view.fullW
            spacing: view.gap

            // Карточка даты (144x140)
            Card {
                id: dateCard
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 140
                color: dateMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
                border.color: dateMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Num {
                    anchors.centerIn: parent
                    value: view.sys ? view.sys.dayNum : ""
                    size: 50
                    gapRatio: 0.14
                    color: view.sys ? view.sys.colFg : "#ffffff"
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: 16
                    anchors.topMargin: 13
                    text: view.sys ? view.sys.dayText : ""
                    color: (view.sys && view.sys.weekend) ? view.sys.colCrit : (view.sys ? view.sys.colMuted : "#888888")
                    font {
                        family: view.sys ? view.sys.fontFam : "sans-serif"
                        pixelSize: 11
                        bold: true
                    }
                }

                Caption {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 16
                    anchors.bottomMargin: 13
                    width: parent.width - 32
                    color: view.sys ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.85) : "#dddddd"
                    text: view.sys ? view.sys.monthText : ""
                }

                MouseArea {
                    id: dateMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }
            }

            // Карточка часов Nothing OS (144x140) — переключает аналоговые / цифровые
            Card {
                id: clockCard
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 140
                color: clockMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
                border.color: clockMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                // Режим аналоговых часов Nothing
                Item {
                    anchors.fill: parent
                    visible: view.clockMode === "analog"

                    Canvas {
                        id: clockCanvas
                        anchors.fill: parent

                        Timer {
                            interval: 1000
                            running: view.visible && view.clockMode === "analog"
                            repeat: true
                            triggeredOnStart: true
                            onTriggered: clockCanvas.requestPaint()
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var cx = width / 2;
                            var cy = height / 2;
                            var r = Math.min(cx, cy) - 13;

                            // 12 точечных маркеров
                            for (var i = 0; i < 12; i++) {
                                var ang = i * (Math.PI / 6) - Math.PI / 2;
                                var x = cx + Math.cos(ang) * r;
                                var y = cy + Math.sin(ang) * r;
                                ctx.beginPath();
                                if (i === 0) {
                                    // 12 часов: двойная точка Nothing
                                    var x2 = cx + Math.cos(ang) * (r - 4.5);
                                    var y2 = cy + Math.sin(ang) * (r - 4.5);
                                    ctx.arc(x, y, 1.8, 0, Math.PI * 2);
                                    ctx.fillStyle = "rgba(255, 255, 255, 0.95)";
                                    ctx.fill();
                                    ctx.beginPath();
                                    ctx.arc(x2, y2, 1.8, 0, Math.PI * 2);
                                    ctx.fillStyle = "rgba(255, 255, 255, 0.95)";
                                    ctx.fill();
                                    continue;
                                } else if (i % 3 === 0) {
                                    ctx.arc(x, y, 2.2, 0, Math.PI * 2);
                                    ctx.fillStyle = "rgba(255, 255, 255, 0.9)";
                                } else {
                                    ctx.arc(x, y, 1.3, 0, Math.PI * 2);
                                    ctx.fillStyle = "rgba(255, 255, 255, 0.35)";
                                }
                                ctx.fill();
                            }

                            var now = new Date();
                            var s = now.getSeconds();
                            var m = now.getMinutes();
                            var h = now.getHours();

                            // Часовая стрелка
                            var hAng = ((h % 12) + m / 60) * (Math.PI / 6) - Math.PI / 2;
                            ctx.beginPath();
                            ctx.lineWidth = 3.2;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.95)";
                            ctx.moveTo(cx - Math.cos(hAng) * 4, cy - Math.sin(hAng) * 4);
                            ctx.lineTo(cx + Math.cos(hAng) * (r * 0.50), cy + Math.sin(hAng) * (r * 0.50));
                            ctx.stroke();

                            // Минутная стрелка
                            var mAng = (m + s / 60) * (Math.PI / 30) - Math.PI / 2;
                            ctx.beginPath();
                            ctx.lineWidth = 2.0;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.95)";
                            ctx.moveTo(cx - Math.cos(mAng) * 5, cy - Math.sin(mAng) * 5);
                            ctx.lineTo(cx + Math.cos(mAng) * (r * 0.74), cy + Math.sin(mAng) * (r * 0.74));
                            ctx.stroke();

                            // Центральная втулка
                            ctx.beginPath();
                            ctx.arc(cx, cy, 3.2, 0, Math.PI * 2);
                            ctx.fillStyle = "#ffffff";
                            ctx.fill();

                            // Секундная стрелка: культовая красная точка Nothing OS
                            var sAng = s * (Math.PI / 30) - Math.PI / 2;
                            ctx.beginPath();
                            ctx.arc(cx + Math.cos(sAng) * (r * 0.88), cy + Math.sin(sAng) * (r * 0.88), 3.0, 0, Math.PI * 2);
                            ctx.fillStyle = view.sys ? String(view.sys.colCrit) : "#d71921";
                            ctx.fill();
                        }
                    }
                }

                // Режим цифровых часов
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: view.clockMode !== "analog"
                    spacing: 6

                    Caption {
                        Layout.alignment: Qt.AlignHCenter
                        text: "NOTHING"
                        color: view.sys ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.4) : "#666666"
                    }

                    Num {
                        Layout.alignment: Qt.AlignHCenter
                        value: view.sys ? view.sys.timeText : ""
                        size: 32
                        gapRatio: 0.14
                        color: view.sys ? view.sys.colFg : "#ffffff"
                    }

                    Caption {
                        Layout.alignment: Qt.AlignHCenter
                        text: view.sys && view.sys.clockSeconds ? (new Date()).getSeconds() : "LOCAL"
                        color: view.sys ? view.sys.colMuted : "#888888"
                    }
                }

                MouseArea {
                    id: clockMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.sys && view.sys.cfg) {
                            view.sys.cfg.widgetClockMode = (view.clockMode === "analog" ? "digital" : "analog");
                            view.sys.saveCfg();
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------ Ряд 2: Погода / Система
        RowLayout {
            Layout.preferredWidth: view.fullW
            spacing: view.gap

            // Главная карточка погоды (144x140)
            Card {
                id: mainWeatherCard
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 140
                Layout.alignment: Qt.AlignTop
                color: wCardMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
                border.color: wCardMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (view.sys && view.sys.weatherReady) ? view.sys.weatherTemp + "°" : "--°"
                        color: view.sys ? view.sys.colFg : "#ffffff"
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 26 }
                    }

                    WIcon {
                        Layout.alignment: Qt.AlignHCenter
                        size: 28
                        color: view.sys ? view.sys.colFg : "#ffffff"
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: view.col - 20
                        text: (view.sys && view.sys.weatherReady)
                              ? view.sys.weatherPlace : (view.sys ? view.sys.tr("Нет данных") : "--")
                        color: view.sys ? view.sys.colMuted : "#888888"
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11 }
                    }
                }

                MouseArea {
                    id: wCardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (view.sys) view.sys.openWeatherDetails(); }
                }
            }

            // Правая колонка: Детали погоды ИЛИ Системный монитор RAM/SSD
            Item {
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 140
                Layout.alignment: Qt.AlignTop

                // Блок погоды (описание + влажность/ветер)
                ColumnLayout {
                    anchors.fill: parent
                    spacing: view.gap
                    visible: view.rightMode === "weather"

                    Card {
                        Layout.preferredWidth: view.col
                        Layout.preferredHeight: 62
                        color: descCardMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
                        border.color: descCardMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.06)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            WIcon {
                                Layout.alignment: Qt.AlignVCenter
                                size: 18
                                color: view.sys ? view.sys.colFg : "#ffffff"
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: (view.sys && view.sys.weatherReady) ? view.sys.weatherDesc : "—"
                                color: view.sys ? view.sys.colFg : "#ffffff"
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                lineHeight: 0.95
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11 }
                            }

                            // Значок переключения на монитор системы
                            Text {
                                text: "󰍛"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 13 }
                                color: toggleSysMa.containsMouse ? (view.sys ? view.sys.colCrit : "#d71921") : (view.sys ? view.sys.colMuted : "#888888")
                                MouseArea {
                                    id: toggleSysMa
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (view.sys && view.sys.cfg) {
                                            view.sys.cfg.widgetRightMode = "system";
                                            view.sys.saveCfg();
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: descCardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (view.sys) view.sys.openWeatherDetails(); }
                        }
                    }

                    RowLayout {
                        Layout.preferredWidth: view.col
                        spacing: view.gap

                        Repeater {
                            model: [
                                { v: (view.sys ? view.sys.weatherHumidity : "--"), suffix: "%",
                                  cap: (view.sys ? view.sys.tr("Влажность") : "HUMIDITY") },
                                { v: (view.sys ? view.sys.weatherWind : "--"), suffix: "",
                                  cap: (view.sys ? view.sys.tr("Ветер") + " " + view.sys.weatherWindUnit : "WIND") }
                            ]

                            Rectangle {
                                id: circleCard
                                required property var modelData
                                Layout.preferredWidth: 66
                                Layout.preferredHeight: 66
                                radius: 33
                                color: circleMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
                                border.color: circleMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.06)
                                Behavior on color { ColorAnimation { duration: 120 } }
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: (view.sys && view.sys.weatherReady)
                                              ? circleCard.modelData.v + circleCard.modelData.suffix : "--"
                                        color: view.sys ? view.sys.colFg : "#ffffff"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 15 }
                                    }

                                    Caption {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.maximumWidth: 58
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: 8
                                        font.letterSpacing: 0.3
                                        text: circleCard.modelData.cap
                                    }
                                }

                                MouseArea {
                                    id: circleMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (view.sys) view.sys.openWeatherDetails(); }
                                }
                            }
                        }
                    }
                }

                // Блок системного монитора RAM и SSD (концентрические дуги)
                Card {
                    anchors.fill: parent
                    visible: view.rightMode === "system"
                    color: sysCardMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
                    border.color: sysCardMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 12
                        anchors.topMargin: 10

                        Caption {
                            Layout.fillWidth: true
                            text: view.sys ? view.sys.tr("СИСТЕМА") : "SYSTEM"
                            color: view.sys ? view.sys.colMuted : "#888888"
                        }

                        Text {
                            text: "󰖐"
                            font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 12 }
                            color: toggleWthMa.containsMouse ? (view.sys ? view.sys.colFg : "#ffffff") : (view.sys ? view.sys.colMuted : "#888888")
                            MouseArea {
                                id: toggleWthMa
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (view.sys && view.sys.cfg) {
                                        view.sys.cfg.widgetRightMode = "weather";
                                        view.sys.saveCfg();
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        width: 78
                        height: 78

                        Canvas {
                            id: ringsCanvas
                            anchors.fill: parent

                            Connections {
                                target: view.sys
                                function onLoadMemChanged() { ringsCanvas.requestPaint(); }
                                function onLoadDiskChanged() { ringsCanvas.requestPaint(); }
                            }

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                var cx = width / 2;
                                var cy = height / 2;

                                var ram = (view.sys && view.sys.loadMem >= 0) ? view.sys.loadMem : 0;
                                var disk = (view.sys && view.sys.loadDisk >= 0) ? view.sys.loadDisk : 0;

                                // Внешнее кольцо: RAM (radius 32, lineWidth 4)
                                var r1 = 32;
                                ctx.lineWidth = 4;
                                ctx.lineCap = "round";

                                ctx.beginPath();
                                ctx.arc(cx, cy, r1, 0, Math.PI * 2);
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.10)";
                                ctx.stroke();

                                if (ram > 0) {
                                    ctx.beginPath();
                                    var aStart = -Math.PI / 2;
                                    var aEnd = aStart + (Math.min(100, ram) / 100) * Math.PI * 2;
                                    ctx.arc(cx, cy, r1, aStart, aEnd);
                                    ctx.strokeStyle = ram > 85 ? (view.sys ? String(view.sys.colCrit) : "#d71921") : "rgba(255, 255, 255, 0.95)";
                                    ctx.stroke();
                                }

                                // Внутреннее кольцо: SSD (radius 22, lineWidth 4)
                                var r2 = 22;
                                ctx.beginPath();
                                ctx.arc(cx, cy, r2, 0, Math.PI * 2);
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.08)";
                                ctx.stroke();

                                if (disk > 0) {
                                    ctx.beginPath();
                                    var aStart = -Math.PI / 2;
                                    var aEnd = aStart + (Math.min(100, disk) / 100) * Math.PI * 2;
                                    ctx.arc(cx, cy, r2, aStart, aEnd);
                                    ctx.strokeStyle = view.sys ? String(view.sys.colCrit) : "#d71921";
                                    ctx.stroke();
                                }
                            }
                        }

                        Num {
                            anchors.centerIn: parent
                            value: (view.sys && view.sys.loadMem >= 0) ? String(view.sys.loadMem) : "--"
                            size: 11
                            gapRatio: 0.18
                            color: view.sys ? view.sys.colFg : "#ffffff"
                        }
                    }

                    RowLayout {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 14
                        anchors.bottomMargin: 8

                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: (view.sys && view.sys.loadMem >= 0) ? view.sys.loadMem + "%" : "--%"
                                color: view.sys ? view.sys.colFg : "#ffffff"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; bold: true }
                            }
                            Caption { text: "RAM"; font.pixelSize: 8 }
                        }

                        Item { Layout.fillWidth: true }

                        ColumnLayout {
                            spacing: 1
                            Layout.alignment: Qt.AlignRight
                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: (view.sys && view.sys.loadDisk >= 0) ? view.sys.loadDisk + "%" : "--%"
                                color: view.sys ? view.sys.colCrit : "#d71921"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; bold: true }
                            }
                            Caption { Layout.alignment: Qt.AlignRight; text: "SSD"; font.pixelSize: 8 }
                        }
                    }

                    MouseArea {
                        id: sysCardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (view.sys && view.sys.cfg) {
                                view.sys.cfg.widgetRightMode = "weather";
                                view.sys.saveCfg();
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------ Ряд 3: Life Bar / Day & Year Progress (300x72)
        Card {
            id: progressCard
            Layout.preferredWidth: view.fullW
            Layout.preferredHeight: 72
            color: progMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
            border.color: progMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.06)
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Caption {
                        Layout.fillWidth: true
                        text: view.progressMode === "day"
                              ? (view.sys ? view.sys.tr("ПРОГРЕСС ДНЯ") : "DAY PROGRESS")
                              : (view.sys ? view.sys.tr("ПРОГРЕСС ГОДА") : "YEAR PROGRESS")
                        font.bold: true
                        font.pixelSize: 9
                        font.letterSpacing: 1.2
                        color: view.sys ? view.sys.colMuted : "#888888"
                    }

                    Num {
                        value: (view.progressMode === "day" ? view.dayPct : view.yearPct) + "%"
                        size: 13
                        gapRatio: 0.15
                        color: view.sys ? view.sys.colFg : "#ffffff"
                    }
                }

                // 24 сегмента для 24 часов
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    spacing: 3
                    visible: view.progressMode === "day"

                    Repeater {
                        model: 24
                        Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: index < view.curHour
                                   ? Qt.rgba(1, 1, 1, 0.88)
                                   : (index === view.curHour
                                      ? (view.sys ? view.sys.colCrit : "#d71921")
                                      : Qt.rgba(1, 1, 1, 0.12))
                            opacity: index === view.curHour ? view.pulseOpacity : 1.0
                        }
                    }
                }

                // 12 сегментов для 12 месяцев года
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    spacing: 5
                    visible: view.progressMode === "year"

                    Repeater {
                        model: 12
                        Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: index < view.curMonth
                                   ? Qt.rgba(1, 1, 1, 0.88)
                                   : (index === view.curMonth
                                      ? (view.sys ? view.sys.colCrit : "#d71921")
                                      : Qt.rgba(1, 1, 1, 0.12))
                            opacity: index === view.curMonth ? view.pulseOpacity : 1.0
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: (view.sys ? view.sys.tr("Осталось ") : "Remaining ") +
                              (view.progressMode === "day"
                               ? view.remainDayText
                               : (view.remainYearDays + " " + (view.sys ? view.sys.tr("дн.") : "days")))
                        color: view.sys ? view.sys.colMuted : "#888888"
                        font {
                            family: view.sys ? view.sys.fontFam : "sans-serif"
                            pixelSize: 10
                        }
                    }

                    Caption {
                        text: "󰔛 " + (view.progressMode === "day" ? "24H" : "365D")
                        font.pixelSize: 8
                        color: view.sys ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.4) : "#666666"
                    }
                }
            }

            MouseArea {
                id: progMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (view.sys && view.sys.cfg) {
                        view.sys.cfg.widgetProgressMode = (view.progressMode === "day" ? "year" : "day");
                        view.sys.saveCfg();
                    }
                }
            }
        }
    }
}
