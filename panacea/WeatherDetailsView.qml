import QtQuick
import QtQuick.Layouts

// Окно детального прогноза погоды в стиле Nothing OS
// Премиальный двухколоночный Bento-Grid дизайн:
// Слева (520px): текущая погода, крупные карточки ключевых параметров и 24-часовая карусель
// Справа (340px): полный 7-дневный прогноз с графическими температурными шкалами (все 7 дней видны сразу без обрезки)
// Полная поддержка локализации (English / Русский) согласно системному языку
Item {
    id: view

    property var sys
    property var forecastData: null
    property int selectedDayIndex: 0

    implicitWidth: 920
    implicitHeight: 560

    readonly property bool isEn: view.sys ? view.sys.isEn : false

    function dayName(dateStr, idx) {
        if (idx === 0) return view.isEn ? "Today" : "Сегодня";
        if (idx === 1) return view.isEn ? "Tomorrow" : "Завтра";
        if (!dateStr) return "";
        var parts = dateStr.split("-");
        if (parts.length < 3) return dateStr;
        var d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
        var daysRu = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"];
        var daysEn = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        var monthsRu = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"];
        var monthsEn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        var dayArr = view.isEn ? daysEn : daysRu;
        var monArr = view.isEn ? monthsEn : monthsRu;
        return dayArr[d.getDay()] + ", " + d.getDate() + " " + monArr[d.getMonth()];
    }

    function iconGlyph(code) {
        var k = String(code).slice(0, 2);
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

    readonly property var currentObj: (view.forecastData && view.forecastData.current) ? view.forecastData.current : null
    readonly property var dailyList: (view.forecastData && view.forecastData.daily) ? view.forecastData.daily : []
    readonly property var hourlyList: (view.forecastData && view.forecastData.hourly) ? view.forecastData.hourly : []
    readonly property var activeDay: (dailyList.length > selectedDayIndex) ? dailyList[selectedDayIndex] : null

    // Экстремумы недели для графических полосок температур
    readonly property int weekMinTemp: {
        if (!dailyList || !dailyList.length) return 0;
        var m = dailyList[0].tempMin;
        for (var i = 1; i < dailyList.length; i++) {
            if (dailyList[i].tempMin < m) m = dailyList[i].tempMin;
        }
        return m;
    }

    readonly property int weekMaxTemp: {
        if (!dailyList || !dailyList.length) return 30;
        var m = dailyList[0].tempMax;
        for (var i = 1; i < dailyList.length; i++) {
            if (dailyList[i].tempMax > m) m = dailyList[i].tempMax;
        }
        return m;
    }

    readonly property int weekRange: Math.max(1, weekMaxTemp - weekMinTemp)

    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: 26
        color: Qt.rgba(0.065, 0.065, 0.075, 0.98)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        clip: true

        // Блокировка кликов сквозь карточку
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // ---------------------------------------------------- Шапка
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Фирменная красная точка Nothing OS
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: view.sys ? view.sys.colCrit : "#d71921"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: (view.forecastData && view.forecastData.city)
                              ? view.forecastData.city : (view.sys && view.sys.weatherPlace ? view.sys.weatherPlace : "...")
                        color: view.sys ? view.sys.colFg : "#ffffff"
                        font {
                            family: view.sys ? view.sys.fontFam : "sans-serif"
                            pixelSize: 17
                            bold: true
                        }
                        elide: Text.ElideRight
                    }

                    Text {
                        text: (view.isEn ? "Weather forecast" : "Прогноз погоды") +
                              (activeDay ? " · " + view.dayName(activeDay.date, selectedDayIndex) : "")
                        color: view.sys ? view.sys.colMuted : "#888888"
                        font {
                            family: view.sys ? view.sys.fontFam : "sans-serif"
                            pixelSize: 11
                        }
                    }
                }

                // Кнопка обновления с вращением
                Rectangle {
                    id: refBtn
                    width: 32; height: 32; radius: 16
                    color: refMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: refIcon
                        anchors.centerIn: parent
                        text: "󰑐"
                        color: (view.sys && view.sys.weatherBusy) ? (view.sys ? view.sys.colCrit : "#d71921") : (view.sys ? view.sys.colFg : "#ffffff")
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 14 }

                        RotationAnimation on rotation {
                            running: view.sys && view.sys.weatherBusy
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 900
                        }
                    }

                    MouseArea {
                        id: refMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (view.sys) view.sys.refreshWeatherForecast(); }
                    }
                }

                // Кнопка закрытия
                Rectangle {
                    id: closeBtn
                    width: 32; height: 32; radius: 16
                    color: closeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMa.containsMouse ? (view.sys ? view.sys.colCrit : "#d71921") : (view.sys ? view.sys.colFg : "#ffffff")
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 12; bold: true }
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (view.sys) view.sys.weatherDetailsOpen = false; }
                    }
                }
            }

            // ---------------------------------------------------- Основной двухколоночный контент
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 18

                // =============================================== ЛЕВАЯ КОЛОНКА (520px)
                ColumnLayout {
                    Layout.preferredWidth: 520
                    Layout.minimumWidth: 520
                    Layout.maximumWidth: 520
                    Layout.fillHeight: true
                    spacing: 10

                    // 1. Главная Hero-карточка погоды
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        radius: 16
                        color: Qt.rgba(1, 1, 1, 0.035)
                        border.color: Qt.rgba(1, 1, 1, 0.07)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 14

                            Text {
                                text: view.iconGlyph(activeDay ? activeDay.icon : (currentObj ? currentObj.icon : (view.sys ? view.sys.weatherIcon : "03d")))
                                color: view.sys ? view.sys.colFg : "#ffffff"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 42 }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    spacing: 10
                                    Text {
                                        text: (activeDay ? activeDay.tempMax : (currentObj ? currentObj.temp : (view.sys && view.sys.weatherTemp ? view.sys.weatherTemp : "--"))) + "°"
                                        color: view.sys ? view.sys.colFg : "#ffffff"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 36; bold: true }
                                    }

                                    // Плашка диапазона температур дня
                                    Rectangle {
                                        visible: activeDay !== null
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: 6
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        implicitWidth: rangeText.implicitWidth + 12
                                        implicitHeight: 20
                                        Text {
                                            id: rangeText
                                            anchors.centerIn: parent
                                            text: activeDay ? (activeDay.tempMin + "° … " + activeDay.tempMax + "°") : ""
                                            color: view.sys ? view.sys.colMuted : "#888"
                                            font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 10; bold: true }
                                        }
                                    }
                                }

                                Text {
                                    text: activeDay
                                          ? activeDay.desc
                                          : (currentObj ? currentObj.desc : (view.sys && view.sys.weatherDesc ? view.sys.weatherDesc : "—"))
                                    color: view.sys ? view.sys.colFg : "#ffffff"
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 12; bold: true }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    // 2. Bento Grid ключевых показателей (6 карточек с КРУПНЫМ текстом и иконками)
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 168
                        columns: 3
                        rowSpacing: 8
                        columnSpacing: 8

                        // 1. Ощущается / Feels like
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 14
                            color: Qt.rgba(1, 1, 1, 0.035)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4
                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: "󰔄"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 15 }
                                    }
                                    Text {
                                        text: view.isEn ? "FEELS LIKE" : "ОЩУЩАЕТСЯ"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; letterSpacing: 0.9; bold: true }
                                    }
                                }
                                Text {
                                    text: (activeDay ? activeDay.feelsMax : (currentObj ? currentObj.feels : (view.sys && view.sys.weatherTemp ? view.sys.weatherTemp : "--"))) + "°"
                                    color: view.sys ? view.sys.colFg : "#fff"
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 26; bold: true }
                                }
                            }
                        }

                        // 2. Влажность / Осадки (Humidity / Rain)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 14
                            color: Qt.rgba(1, 1, 1, 0.035)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4
                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: activeDay ? "󰖖" : "󰖉"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 15 }
                                    }
                                    Text {
                                        text: activeDay ? (view.isEn ? "RAIN" : "ОСАДКИ") : (view.isEn ? "HUMIDITY" : "ВЛАЖНОСТЬ")
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; letterSpacing: 0.9; bold: true }
                                    }
                                }
                                Text {
                                    text: activeDay ? (activeDay.pop + "%") : ((currentObj ? currentObj.humidity : (view.sys && view.sys.weatherHumidity ? view.sys.weatherHumidity : "--")) + "%")
                                    color: (activeDay && activeDay.pop > 40) ? (view.sys ? view.sys.colCrit : "#d71921") : (view.sys ? view.sys.colFg : "#fff")
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 26; bold: true }
                                }
                            }
                        }

                        // 3. Ветер / Wind
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 14
                            color: Qt.rgba(1, 1, 1, 0.035)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4
                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: "󰖝"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 15 }
                                    }
                                    Text {
                                        text: view.isEn ? "WIND" : "ВЕТЕР"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; letterSpacing: 0.9; bold: true }
                                    }
                                }
                                RowLayout {
                                    spacing: 4
                                    Text {
                                        text: String(activeDay ? activeDay.wind : (currentObj ? currentObj.wind : (view.sys && view.sys.weatherWind ? view.sys.weatherWind : "--")))
                                        color: view.sys ? view.sys.colFg : "#fff"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 26; bold: true }
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignBaseline
                                        text: view.isEn ? "m/s" : "м/с"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 13; bold: true }
                                    }
                                }
                            }
                        }

                        // 4. Давление / Pressure
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 14
                            color: Qt.rgba(1, 1, 1, 0.035)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4
                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: "󰈵"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 15 }
                                    }
                                    Text {
                                        text: view.isEn ? "PRESSURE" : "ДАВЛЕНИЕ"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; letterSpacing: 0.9; bold: true }
                                    }
                                }
                                RowLayout {
                                    spacing: 4
                                    Text {
                                        text: currentObj ? String(currentObj.pressure) : "--"
                                        color: view.sys ? view.sys.colFg : "#fff"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 26; bold: true }
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignBaseline
                                        text: view.isEn ? "hPa" : "гПа"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 13; bold: true }
                                    }
                                }
                            }
                        }

                        // 5. УФ-индекс / UV Index
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 14
                            color: Qt.rgba(1, 1, 1, 0.035)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4
                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: "󰋘"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 15 }
                                    }
                                    Text {
                                        text: view.isEn ? "UV INDEX" : "УФ-ИНДЕКС"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; letterSpacing: 0.9; bold: true }
                                    }
                                }
                                RowLayout {
                                    spacing: 8
                                    Text {
                                        text: activeDay ? String(activeDay.uv) : "--"
                                        color: (activeDay && activeDay.uv >= 6) ? (view.sys ? view.sys.colCrit : "#d71921") : (view.sys ? view.sys.colFg : "#fff")
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 26; bold: true }
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignBaseline
                                        visible: activeDay !== null
                                        text: (activeDay && activeDay.uv >= 6) ? (view.isEn ? "High" : "Высокий") : (view.isEn ? "Moderate" : "Умерен.")
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 12; bold: true }
                                    }
                                }
                            }
                        }

                        // 6. Восход / Закат (Sun)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 14
                            color: Qt.rgba(1, 1, 1, 0.035)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4
                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: "󰖚"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 15 }
                                    }
                                    Text {
                                        text: view.isEn ? "SUN" : "СОЛНЦЕ"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; letterSpacing: 0.9; bold: true }
                                    }
                                }
                                RowLayout {
                                    spacing: 5
                                    Text {
                                        text: (activeDay && activeDay.sunrise) ? activeDay.sunrise : "--:--"
                                        color: view.sys ? view.sys.colFg : "#fff"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 15; bold: true }
                                    }
                                    Text {
                                        text: "/"
                                        color: view.sys ? view.sys.colMuted : "#888"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 13 }
                                    }
                                    Text {
                                        text: (activeDay && activeDay.sunset) ? activeDay.sunset : "--:--"
                                        color: view.sys ? view.sys.colFg : "#fff"
                                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 15; bold: true }
                                    }
                                }
                            }
                        }
                    }

                    // 3. Почасовой прогноз (24 часа карусель)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 130
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: view.isEn ? "HOURLY FORECAST" : "ПОЧАСОВОЙ ПРОГНОЗ"
                                color: view.sys ? view.sys.colMuted : "#888"
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 10; letterSpacing: 1.1; bold: true }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "◀  ▶"
                                color: Qt.rgba(1, 1, 1, 0.25)
                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 9 }
                            }
                        }

                        Flickable {
                            id: hourlyFlick
                            implicitWidth: 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 104
                            contentWidth: hourlyRow.implicitWidth
                            contentHeight: height
                            clip: true
                            interactive: true
                            boundsBehavior: Flickable.StopAtBounds

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                orientation: Qt.Horizontal
                                onWheel: ev => {
                                    var step = ev.pixelDelta.x !== 0 ? ev.pixelDelta.x : (ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x);
                                    var max = Math.max(0, hourlyFlick.contentWidth - hourlyFlick.width);
                                    hourlyFlick.contentX = Math.max(0, Math.min(max, hourlyFlick.contentX - step));
                                }
                            }

                            RowLayout {
                                id: hourlyRow
                                spacing: 8
                                height: parent.height

                                Repeater {
                                    model: hourlyList
                                    Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: 66
                                        height: 100
                                        radius: 13
                                        color: index === 0 ? Qt.rgba(1, 1, 1, 0.10)
                                                           : (hMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.025))
                                        border.color: index === 0 ? (view.sys ? view.sys.colCrit : "#d71921") : Qt.rgba(1, 1, 1, 0.06)
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: index === 0 ? (view.isEn ? "Now" : "Сейчас") : modelData.time
                                                color: index === 0 ? (view.sys ? view.sys.colCrit : "#d71921") : (view.sys ? view.sys.colMuted : "#888")
                                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 10; bold: index === 0 }
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: view.iconGlyph(modelData.icon)
                                                color: view.sys ? view.sys.colFg : "#ffffff"
                                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 18 }
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modelData.temp + "°"
                                                color: view.sys ? view.sys.colFg : "#ffffff"
                                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 12; bold: true }
                                            }

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modelData.pop > 0 ? ("💧" + modelData.pop + "%") : " "
                                                color: modelData.pop > 40 ? (view.sys ? view.sys.colCrit : "#d71921") : (view.sys ? view.sys.colMuted : "#888")
                                                font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 9 }
                                            }
                                        }

                                        MouseArea {
                                            id: hMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =============================================== ПРАВАЯ КОЛОНКА (7 ДНЕЙ)
                ColumnLayout {
                    id: rightCol
                    Layout.fillWidth: true
                    Layout.minimumWidth: 320
                    Layout.fillHeight: true
                    spacing: 8

                    Text {
                        text: view.isEn ? "7-DAY FORECAST" : "ПРОГНОЗ НА 7 ДНЕЙ"
                        color: view.sys ? view.sys.colMuted : "#888"
                        font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 10; letterSpacing: 1.1; bold: true }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        Repeater {
                            model: dailyList

                            Rectangle {
                                id: dayItem
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 14
                                color: view.selectedDayIndex === index
                                       ? Qt.rgba(1, 1, 1, 0.12)
                                       : (dayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.025))
                                border.color: view.selectedDayIndex === index ? (view.sys ? view.sys.colCrit : "#d71921") : Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                // Название дня
                                Text {
                                    id: dayLbl
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 74
                                    text: view.dayName(dayItem.modelData.date, dayItem.index)
                                    color: dayItem.index === 0 ? (view.sys ? view.sys.colCrit : "#d71921") : (view.sys ? view.sys.colFg : "#ffffff")
                                    font {
                                        family: view.sys ? view.sys.fontFam : "sans-serif"
                                        pixelSize: 11
                                        bold: dayItem.index === 0 || view.selectedDayIndex === dayItem.index
                                    }
                                    elide: Text.ElideRight
                                }

                                // Иконка погоды
                                Text {
                                    id: dayIcon
                                    anchors.left: dayLbl.right
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    text: view.iconGlyph(dayItem.modelData.icon)
                                    color: view.sys ? view.sys.colFg : "#ffffff"
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 16 }
                                }

                                // Осадки
                                Text {
                                    id: dayPop
                                    anchors.left: dayIcon.right
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 34
                                    horizontalAlignment: Text.AlignRight
                                    text: dayItem.modelData.pop > 0 ? (dayItem.modelData.pop + "%") : ""
                                    color: dayItem.modelData.pop > 40 ? (view.sys ? view.sys.colCrit : "#d71921") : (view.sys ? view.sys.colMuted : "#888888")
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 10 }
                                }

                                // Мин. температура
                                Text {
                                    id: dayMin
                                    anchors.left: dayPop.right
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20
                                    horizontalAlignment: Text.AlignRight
                                    text: dayItem.modelData.tempMin + "°"
                                    color: view.sys ? view.sys.colMuted : "#888"
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11 }
                                }

                                // Макс. температура (прижата к правому краю карточки)
                                Text {
                                    id: dayMax
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20
                                    horizontalAlignment: Text.AlignLeft
                                    text: dayItem.modelData.tempMax + "°"
                                    color: view.sys ? view.sys.colFg : "#fff"
                                    font { family: view.sys ? view.sys.fontFam : "sans-serif"; pixelSize: 11; bold: true }
                                }

                                // Графическая температурная полоска дня
                                Item {
                                    id: dayBar
                                    anchors.left: dayMin.right
                                    anchors.leftMargin: 6
                                    anchors.right: dayMax.left
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 5

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 2.5
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                    }

                                    Rectangle {
                                        x: Math.max(0, Math.min(parent.width - 8, ((dayItem.modelData.tempMin - view.weekMinTemp) / view.weekRange) * parent.width))
                                        width: Math.max(10, Math.min(parent.width - x, ((dayItem.modelData.tempMax - dayItem.modelData.tempMin) / view.weekRange) * parent.width))
                                        height: parent.height
                                        radius: 2.5
                                        color: view.selectedDayIndex === dayItem.index
                                               ? (view.sys ? view.sys.colCrit : "#d71921")
                                               : Qt.rgba(1, 1, 1, 0.75)
                                    }
                                }

                                MouseArea {
                                    id: dayMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: view.selectedDayIndex = dayItem.index
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
