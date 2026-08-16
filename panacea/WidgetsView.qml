import QtQuick
import QtQuick.Layouts

// Настольные виджеты темы Nothing — карточки поверх обоев.
//
// Дата, погода и часы. Точками набраны число даты и часы — как на
// образце темы; погодные числа обычным шрифтом. Градус в точечной
// сетке выходит квадратным кружком из четырёх точек, а он должен быть
// гладким, и тянуть за собой всю карточку ради него незачем.
//
// Показатели по карточкам разведены нарочно, без повторов. Градусы стоят
// один раз — в большой карточке погоды; в соседней словами сказано, что за
// погода, а в кружках то, чего больше нигде нет: влажность и ветер.
// Одно и то же число в трёх местах занимает три места, а сообщает одно.
//
// Карточки ничего не ловят мышью — слой под них создаётся с пустой областью
// ввода. Это украшение рабочего стола: перехватывать по нему клики значило
// бы отбирать их у окон и у самих обоев.
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

    // Общий вид карточки: тёмная плашка со скруглением. Фон непрозрачный,
    // а не полупрозрачный: обои под ним бывают любые, и на светлой картинке
    // сквозь полупрозрачную плашку не читались бы ни цифры, ни подписи.
    component Card: Rectangle {
        radius: 22
        color: Qt.rgba(0.09, 0.09, 0.09, 0.96)
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
    }

    // Мелкая подпись под значением — заглавными вразрядку, как в теме.
    component Caption: Text {
        color: view.sys.colMuted
        elide: Text.ElideRight
        font {
            family: view.sys.fontFam
            pixelSize: 9
            capitalization: Font.AllUppercase
            letterSpacing: 1.1
        }
    }

    ColumnLayout {
        id: stack
        width: view.fullW
        spacing: view.gap

        // ------------------------------------------------------ дата
        Card {
            Layout.preferredWidth: view.col
            Layout.preferredHeight: 112

            // Число крупно, день недели мелко в углу. Красный здесь
            // единственный на весь набор — им отмечены выходные, и больше
            // ему на рабочем столе делать нечего.
            DotText {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 6
                value: view.sys.dayNum
                size: 52
                gapRatio: 0.14
                color: view.sys.colFg
            }

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 16
                anchors.topMargin: 13
                text: view.sys.dayText
                color: view.sys.weekend ? view.sys.colCrit : view.sys.colMuted
                font {
                    family: view.sys.fontFam; pixelSize: 11; bold: true
                }
            }

            // Месяц словом под числом. Обычным шрифтом: точками набраны
            // цифры, а слово по той же сетке пришлось бы рисовать по букве.
            Caption {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 19
                anchors.bottomMargin: 12
                width: parent.width - 30
                text: view.sys.monthText
            }
        }

        // ------------------------------- погода: большая карточка и соседи
        RowLayout {
            Layout.preferredWidth: view.fullW
            spacing: view.gap

            // Градусы, значок и город. Единственное место, где показана
            // температура.
            Card {
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 132

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    // Погодные числа обычным шрифтом, а не точками. Точки
                    // оставлены числу даты и часам — тем, что и на макете
                    // набрано ими. Градус в точечной сетке выходит квадратным
                    // кружком из четырёх точек, а он должен быть гладким.
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: view.sys.weatherReady ? view.sys.weatherTemp + "°" : "--°"
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: 26 }
                    }

                    DotIcon {
                        Layout.alignment: Qt.AlignHCenter
                        code: view.sys.weatherIcon
                        size: 30
                        color: view.sys.colFg
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: view.col - 20
                        text: view.sys.weatherReady
                              ? view.sys.weatherPlace : view.sys.tr("Нет данных")
                        color: view.sys.colMuted
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font { family: view.sys.fontFam; pixelSize: 11 }
                    }
                }
            }

            ColumnLayout {
                Layout.preferredWidth: view.col
                spacing: view.gap

                // Что за погода — словами. Градусов здесь нет намеренно:
                // они уже сказаны слева.
                Card {
                    Layout.preferredWidth: view.col
                    Layout.preferredHeight: 56

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        DotIcon {
                            Layout.alignment: Qt.AlignVCenter
                            code: view.sys.weatherIcon
                            size: 20
                            color: view.sys.colFg
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: view.sys.weatherReady ? view.sys.weatherDesc : "—"
                            color: view.sys.colFg
                            elide: Text.ElideRight
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }
                }

                // Два кружка: влажность и ветер. Круглые, чтобы не спорить
                // с прямоугольниками вокруг, и мелкие — это подробности, а
                // не главное на столе.
                RowLayout {
                    Layout.preferredWidth: view.col
                    spacing: view.gap

                    Repeater {
                        model: [
                            { v: view.sys.weatherHumidity, suffix: "%",
                              cap: view.sys.tr("Влажность") },
                            { v: view.sys.weatherWind, suffix: "",
                              cap: view.sys.tr("Ветер") }
                        ]

                        Rectangle {
                            required property var modelData
                            Layout.preferredWidth: 66
                            Layout.preferredHeight: 66
                            radius: 33
                            color: Qt.rgba(0.09, 0.09, 0.09, 0.96)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: view.sys.weatherReady
                                          ? modelData.v + modelData.suffix : "--"
                                    color: view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: 15 }
                                }
                                // Подпись мельче и без разрядки: «HUMIDITY»
                                // вразрядку не помещалось в круг и лезло на
                                // его край. Кружок заодно подрос.
                                Caption {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.maximumWidth: 58
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: 8
                                    font.letterSpacing: 0.3
                                    text: modelData.cap
                                }
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------ часы
        Card {
            Layout.preferredWidth: view.fullW
            Layout.preferredHeight: 62

            DotText {
                anchors.centerIn: parent
                value: view.sys.timeText
                size: 30
                gapRatio: 0.14
                color: view.sys.colFg
            }
        }
    }
}
