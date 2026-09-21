import QtQuick
import QtQuick.Layouts

// Настольные виджеты темы Nothing — карточки поверх обоев.
//
// Дизайн в стиле Nothing OS:
// - Дата: день недели (красный в выходные), точечное число и месяц
// - Часы Nothing OS: 12-точечный циферблат с двойной точкой на 12, чётко различимые
//   стрелки (короткая часовая капсула 0.38*r и длинная минутная стрелка 0.78*r),
//   фирменная втулка-пончик Nothing, орбитальная красная точка colCrit и цифровая подсказка.
//   Клик переключает между аналоговыми и точечными цифровыми часами.
// - Главная карточка погоды (слева): температура, точечная иконка, город.
//   Клик открывает детальное окно прогноза погоды.
// - Вспомогательная карточка (справа): по клику переключается между подробностями
//   погоды (описание + влажность/ветер) и монитором системы (концентрические дуги RAM и SSD).
// - Шкала прогресса (Life Bar, снизу): 24-сегментный прогресс дня с пульсирующим
//   текущим часом. Клик переключает между прогрессом дня (24H) и года (365D).
Item {
    id: view

    property var sys

    // Ширина колонки и просвет между карточками
    readonly property real col: 144
    readonly property real gap: 12
    readonly property real fullW: view.col * 2 + view.gap

    implicitWidth: view.fullW
    implicitHeight: stack.implicitHeight

    // Режимы карточек
    readonly property string clockMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetClockMode) || "analog"
    readonly property string rightMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetRightMode) || "weather"
    readonly property string progressMode: (view.sys && view.sys.cfg && view.sys.cfg.widgetProgressMode) || "day"

    // Формат часов: 12-часовой или 24-часовой (из системных настроек)
    readonly property bool is12: view.sys && view.sys.cfg ? Boolean(view.sys.cfg.clock12) : false

    // Синхронизация с системным временем через view.sys
    readonly property int curHour: (view.sys && view.sys.timeHour !== undefined) ? view.sys.timeHour : (new Date()).getHours()
    readonly property int curMin: (view.sys && view.sys.timeMinute !== undefined) ? view.sys.timeMinute : (new Date()).getMinutes()
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

                        Connections {
                            target: view.sys
                            function onTimeSecondChanged() { clockCanvas.requestPaint(); }
                            function onTimeTextChanged() { clockCanvas.requestPaint(); }
                            function onTimeHourChanged() { clockCanvas.requestPaint(); }
                        }

                        Connections {
                            target: view
                            function onIs12Changed() { clockCanvas.requestPaint(); }
                        }

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
                            var r = Math.min(cx, cy) - 16;

                            var is12 = view.is12;

                            if (is12) {
                                // 12-часовой циферблат: 12 точечных меток (шаг 30°)
                                for (var i = 0; i < 12; i++) {
                                    var ang = i * (Math.PI / 6) - Math.PI / 2;
                                    var x = cx + Math.cos(ang) * r;
                                    var y = cy + Math.sin(ang) * r;
                                    ctx.beginPath();
                                    if (i % 3 === 0) {
                                        // 12, 3, 6, 9 часов: акцентные белые точки
                                        ctx.arc(x, y, 2.0, 0, Math.PI * 2);
                                        ctx.fillStyle = "#ffffff";
                                    } else {
                                        // Промежуточные часы: полупрозрачные точки
                                        ctx.arc(x, y, 1.3, 0, Math.PI * 2);
                                        ctx.fillStyle = "rgba(255, 255, 255, 0.35)";
                                    }
                                    ctx.fill();
                                }
                            } else {
                                // 24-часовой циферблат: 24 точечные метки (шаг 15°)
                                for (var j = 0; j < 24; j++) {
                                    var ang24 = j * (Math.PI / 12) - Math.PI / 2;
                                    var x24 = cx + Math.cos(ang24) * r;
                                    var y24 = cy + Math.sin(ang24) * r;
                                    ctx.beginPath();
                                    if (j % 6 === 0) {
                                        // 00 (полночь/верх), 06 (утро/право), 12 (полдень/низ), 18 (вечер/лево)
                                        ctx.arc(x24, y24, 2.0, 0, Math.PI * 2);
                                        ctx.fillStyle = "#ffffff";
                                    } else if (j % 2 === 0) {
                                        // Четные часы: средние белые точки
                                        ctx.arc(x24, y24, 1.4, 0, Math.PI * 2);
                                        ctx.fillStyle = "rgba(255, 255, 255, 0.50)";
                                    } else {
                                        // Нечетные часы: тонкие деликатные точки
                                        ctx.arc(x24, y24, 1.0, 0, Math.PI * 2);
                                        ctx.fillStyle = "rgba(255, 255, 255, 0.25)";
                                    }
                                    ctx.fill();
                                }
                            }

                            // Синхронизация с системным временем через view.sys
                            var h = (view.sys && view.sys.timeHour !== undefined) ? view.sys.timeHour : (new Date()).getHours();
                            var m = (view.sys && view.sys.timeMinute !== undefined) ? view.sys.timeMinute : (new Date()).getMinutes();
                            var s = (view.sys && view.sys.timeSecond !== undefined) ? view.sys.timeSecond : (new Date()).getSeconds();

                            // 1. Часовая стрелка: элегантная белая капсула
                            // В 12-часовом формате оборот 12 часов (PI/6), в 24-часовом — 24 часа (PI/12)
                            var hAng = is12
                                ? (((h % 12) + m / 60 + s / 3600) * (Math.PI / 6) - Math.PI / 2)
                                : ((h + m / 60 + s / 3600) * (Math.PI / 12) - Math.PI / 2);

                            ctx.beginPath();
                            ctx.lineWidth = 3.6;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = "#ffffff";
                            ctx.moveTo(cx + Math.cos(hAng) * 3, cy + Math.sin(hAng) * 3);
                            ctx.lineTo(cx + Math.cos(hAng) * (r * 0.50), cy + Math.sin(hAng) * (r * 0.50));
                            ctx.stroke();

                            // 2. Минутная стрелка: тонкая изящная белая игла (1 оборот = 60 минут)
                            var mAng = (m + s / 60) * (Math.PI / 30) - Math.PI / 2;
                            ctx.beginPath();
                            ctx.lineWidth = 2.0;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.95)";
                            ctx.moveTo(cx + Math.cos(mAng) * 3, cy + Math.sin(mAng) * 3);
                            ctx.lineTo(cx + Math.cos(mAng) * (r * 0.78), cy + Math.sin(mAng) * (r * 0.78));
                            ctx.stroke();

                            // 3. Секундная стрелка Nothing Red: тонкая стрелка с противовесом (1 оборот = 60 секунд)
                            var sAng = s * (Math.PI / 30) - Math.PI / 2;
                            ctx.beginPath();
                            ctx.lineWidth = 1.2;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = view.sys ? String(view.sys.colCrit) : "#d71921";
                            ctx.moveTo(cx - Math.cos(sAng) * (r * 0.18), cy - Math.sin(sAng) * (r * 0.18));
                            ctx.lineTo(cx + Math.cos(sAng) * (r * 0.82), cy + Math.sin(sAng) * (r * 0.82));
                            ctx.stroke();

                            // 4. Фирменная центральная втулка Nothing OS
                            ctx.beginPath();
                            ctx.arc(cx, cy, 3.8, 0, Math.PI * 2);
                            ctx.fillStyle = "#141414";
                            ctx.fill();
                            ctx.lineWidth = 1.0;
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.25)";
                            ctx.stroke();

                            // Красная точка в самом центре
                            ctx.beginPath();
                            ctx.arc(cx, cy, 1.8, 0, Math.PI * 2);
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
                        value: {
                            if (!view.sys) return "";
                            if (view.is12) {
                                var d12 = new Date();
                                return Qt.formatDateTime(d12, "h:mm");
                            }
                            return view.sys.timeText;
                        }
                        size: 32
                        gapRatio: 0.14
                        color: view.sys ? view.sys.colFg : "#ffffff"
                    }

                    Caption {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            if (view.is12) {
                                var d = new Date();
                                return (d.getHours() >= 12 ? "PM" : "AM") + (view.sys && view.sys.clockSeconds ? " · " + d.getSeconds() : "");
                            }
                            return view.sys && view.sys.clockSeconds ? (new Date()).getSeconds() : "LOCAL";
                        }
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

            // Главная карточка погоды (144x140) — клик открывает полное окно прогноза
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

            // Правая карточка (144x140) — КЛИК ПЕРЕКЛЮЧАЕТ МЕЖДУ ПОГОДОЙ И СИСТЕМОЙ
            Card {
                id: rightToggleCard
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 140
                Layout.alignment: Qt.AlignTop
                color: rightCardMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
                border.color: rightCardMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                // Режим: ПОДРОБНОСТИ ПОГОДЫ
                Item {
                    anchors.fill: parent
                    visible: view.rightMode === "weather"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // Верхняя плашка с описанием погоды
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 14
                            color: Qt.rgba(1, 1, 1, 0.035)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
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

                                // Иконка-подсказка: клик переключит на монитор системы
                                Text {
                                    text: "󰍛"
                                    color: view.sys ? view.sys.colMuted : "#888888"
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 13 }
                                }
                            }
                        }

                        // Нижние кружки (Влажность и Ветер)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                radius: 16
                                color: Qt.rgba(1, 1, 1, 0.035)
                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: (view.sys && view.sys.weatherReady) ? (view.sys.weatherHumidity + "%") : "--"
                                        color: view.sys ? view.sys.colFg : "#ffffff"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 15; bold: true }
                                    }

                                    Caption {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: view.sys ? view.sys.tr("Влажность") : "HUMIDITY"
                                        font.pixelSize: 7
                                        font.letterSpacing: 0.2
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                radius: 16
                                color: Qt.rgba(1, 1, 1, 0.035)
                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: (view.sys && view.sys.weatherReady) ? String(view.sys.weatherWind) : "--"
                                        color: view.sys ? view.sys.colFg : "#ffffff"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 15; bold: true }
                                    }

                                    Caption {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: (view.sys ? view.sys.tr("Ветер") : "WIND") + " " + (view.sys ? view.sys.weatherWindUnit : "")
                                        font.pixelSize: 7
                                        font.letterSpacing: 0.2
                                    }
                                }
                            }
                        }
                    }
                }

                // Режим: СИСТЕМНЫЙ МОНИТОР (Концентрические дуги RAM и SSD)
                Item {
                    anchors.fill: parent
                    visible: view.rightMode === "system"

                    // Верхняя строка заголовка
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

                        // Иконка-подсказка: клик переключит на погоду
                        Text {
                            text: "󰖐"
                            font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 12 }
                            color: view.sys ? view.sys.colMuted : "#888888"
                        }
                    }

                    // Концентрические кольца: внешнее RAM, внутреннее SSD
                    Item {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        width: 76
                        height: 76

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

                                // Внешнее кольцо: RAM (radius 31, lineWidth 4)
                                var r1 = 31;
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

                                // Внутреннее кольцо: SSD (radius 21, lineWidth 4)
                                var r2 = 21;
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

                    // Нижняя строка: показатели RAM и SSD
                    RowLayout {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 14
                        anchors.bottomMargin: 8

                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: (view.sys && view.sys.loadMem >= 0) ? (view.sys.loadMem + "%") : "--%"
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
                                text: (view.sys && view.sys.loadDisk >= 0) ? (view.sys.loadDisk + "%") : "--%"
                                color: view.sys ? view.sys.colCrit : "#d71921"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; bold: true }
                            }
                            Caption { Layout.alignment: Qt.AlignRight; text: "SSD"; font.pixelSize: 8 }
                        }
                    }
                }

                // ЕДИНЫЙ клик по всей правой карточке: переключает Погода <-> Система
                MouseArea {
                    id: rightCardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (view.sys && view.sys.cfg) {
                            view.sys.cfg.widgetRightMode = (view.rightMode === "weather" ? "system" : "weather");
                            view.sys.saveCfg();
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
