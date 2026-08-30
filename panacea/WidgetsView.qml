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

    // Число: точками на Nothing, обычным шрифтом на остальных темах.
    //
    // Раскладка карточек у тем общая, разное только начертание — поэтому
    // выбор спрятан сюда, а не размазан по каждому месту, где стоит цифра.
    // Кегль шрифта берётся с запасом от высоты точечной цифры: у той высота
    // и есть весь рост, а у буквы pixelSize считается по всей строке, вместе
    // с надстрочным и подстрочным просветом.
    component Num: Item {
        id: num
        property string value: ""
        property real size: 14
        property real gapRatio: 0.22
        property color color: view.sys.colFg

        implicitWidth:  view.sys.themeNothing ? dots.implicitWidth  : plain.implicitWidth
        implicitHeight: view.sys.themeNothing ? dots.implicitHeight : plain.implicitHeight

        DotText {
            id: dots
            visible: view.sys.themeNothing
            value: num.value
            size: num.size
            gapRatio: num.gapRatio
            color: num.color
        }
        Text {
            id: plain
            visible: !view.sys.themeNothing
            text: num.value
            color: num.color
            font { family: view.sys.fontFam; pixelSize: Math.round(num.size * 1.35) }
        }
    }

    // Значок погоды тем же порядком: точечный на Nothing, знак шрифта иначе.
    component WIcon: Item {
        id: wico
        property real size: 20
        property color color: view.sys.colFg

        implicitWidth:  view.sys.themeNothing ? wdots.implicitWidth  : wglyph.implicitWidth
        implicitHeight: view.sys.themeNothing ? wdots.implicitHeight : wglyph.implicitHeight

        DotIcon {
            id: wdots
            visible: view.sys.themeNothing
            code: view.sys.weatherIcon
            size: wico.size
            color: wico.color
        }
        Text {
            id: wglyph
            visible: !view.sys.themeNothing
            text: view.sys.weatherGlyph
            color: wico.color
            font { family: view.sys.fontFam; pixelSize: Math.round(wico.size * 1.3) }
        }
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
            // Число по центру карточки, а подписи разведены по углам: день
            // недели в верхний правый, месяц в нижний левый. Так число ни с
            // одной из них не соседствует вплотную и читается само по себе.
            Num {
                anchors.centerIn: parent
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
                anchors.leftMargin: 16
                anchors.bottomMargin: 12
                width: parent.width - 30
                // Ярче общего приглушённого: тот рассчитан на подписи под
                // значением, а здесь месяц — сам по себе, второй половиной
                // даты, и в приглушённом тонет.
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g,
                               view.sys.colFg.b, 0.85)
                text: view.sys.monthText
            }
        }

        // ------------------------------- погода: большая карточка и соседи
        RowLayout {
            Layout.preferredWidth: view.fullW
            spacing: view.gap

            // Градусы, значок и город. Единственное место, где показана
            // температура.
            // Высота ровно та, что складывается справа: карточка описания
            // 62, просвет 12 и кружки 66. Было 132 против 140, и правый
            // столбец на восемь пикселей не сходился с левым — в наборе из
            // прямоугольников такой перекос видно сразу.
            Card {
                id: mainWeatherCard
                Layout.preferredWidth: view.col
                Layout.preferredHeight: 62 + view.gap + 66
                Layout.alignment: Qt.AlignTop
                color: wCardMa.containsMouse ? Qt.rgba(0.13, 0.13, 0.14, 0.98) : Qt.rgba(0.09, 0.09, 0.09, 0.96)
                border.color: wCardMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

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

                    WIcon {
                        Layout.alignment: Qt.AlignHCenter
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

                MouseArea {
                    id: wCardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.openWeatherDetails()
                }
            }

            ColumnLayout {
                Layout.preferredWidth: view.col
                Layout.alignment: Qt.AlignTop
                spacing: view.gap

                // Что за погода — словами. Градусов здесь нет намеренно:
                // они уже сказаны слева.
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
                            color: view.sys.colFg
                        }

                        // В две строки, а не в одну с многоточием. Описание
                        // приходит от сервиса и бывает длинным — «overcast
                        // clouds» в одну строку не влезало и обрывалось на
                        // «overcast …», то есть теряло ровно то слово, ради
                        // которого карточка и стоит.
                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: view.sys.weatherReady ? view.sys.weatherDesc : "—"
                            color: view.sys.colFg
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            lineHeight: 0.95
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }

                    MouseArea {
                        id: descCardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.openWeatherDetails()
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
                            // Единица у ветра стоит в подписи, а не при
                            // числе: в кружок «5 м/с» не помещается, а без
                            // единицы число ничего не значит.
                            { v: view.sys.weatherWind, suffix: "",
                              cap: view.sys.tr("Ветер") + " " + view.sys.weatherWindUnit }
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
                                    text: view.sys.weatherReady
                                          ? circleCard.modelData.v + circleCard.modelData.suffix : "--"
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
                                    text: circleCard.modelData.cap
                                }
                            }

                            MouseArea {
                                id: circleMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.sys.openWeatherDetails()
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

            Num {
                anchors.centerIn: parent
                value: view.sys.timeText
                size: 30
                gapRatio: 0.14
                color: view.sys.colFg
            }
        }
    }
}
