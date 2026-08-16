import QtQuick
import QtQuick.Layouts

// Остров для макетов настроек: тот же набор сегментов, те же правила
// скругления и те же вогнутые уголки примыкания, что и на живом экране.
//
// Живёт отдельным компонентом, потому что макетов уже два — рабочий стол во
// вкладке «Пилюля» и слайдер режимов проводника, — и остров в них должен
// выглядеть одинаково, иначе один макет начинает врать.
Item {
    id: mock
    property var sys
    property string pos: "top"          // top | bottom | left | right
    property color fgCol: "#ffffff"
    property color onCol: "#3b82f6"
    // во сколько раз макет меньше настоящего экрана
    property real k: 0.4
    // запас читаемости: 1:1 при таком масштабе даёт нечитаемые 8 px
    property real boost: 1.5

    readonly property bool side: mock.pos === "left" || mock.pos === "right"
    readonly property real thick: Math.max(20, (mock.sys ? mock.sys.pillH : 38)
                                               * mock.k * mock.boost)
    readonly property real fs: Math.max(9, (mock.sys ? mock.sys.fontSize : 15)
                                            * mock.k * mock.boost)
    readonly property real cr: Math.max(5, (mock.sys ? mock.sys.cornerR : 14)
                                             * mock.k * mock.boost)

    Rectangle {
        id: pill
        readonly property real len: mock.side
                ? vertRow.implicitHeight + mock.thick * 0.7
                : horizRow.implicitWidth + mock.thick * 0.9

        width:  mock.side ? mock.thick : pill.len
        height: mock.side ? pill.len : mock.thick
        // Обводки нет: у настоящего острова border.width = 0, а с ней уголки
        // читаются отдельными наклейками.
        color: mock.sys ? mock.sys.colBg : "#0a0a0a"

        // углы у прижатой кромки срезаны — как у живого острова
        readonly property real freeR: mock.thick / 2
        topLeftRadius:     mock.pos === "top"    || mock.pos === "left"  ? 0 : pill.freeR
        topRightRadius:    mock.pos === "top"    || mock.pos === "right" ? 0 : pill.freeR
        bottomLeftRadius:  mock.pos === "bottom" || mock.pos === "left"  ? 0 : pill.freeR
        bottomRightRadius: mock.pos === "bottom" || mock.pos === "right" ? 0 : pill.freeR

        x: mock.pos === "left"  ? 0
         : mock.pos === "right" ? mock.width - width
                                : (mock.width - width) / 2
        y: mock.pos === "top"    ? 0
         : mock.pos === "bottom" ? mock.height - height
                                 : (mock.height - height) / 2
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on width  { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        // --- горизонтальный вид
        RowLayout {
            id: horizRow
            anchors.centerIn: parent
            // Прозрачностью, а не visible: скрытая раскладка перестаёт считать
            // ширину, и остров схлопывается в пустую капсулу.
            opacity: mock.side ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 160 } }
            spacing: mock.thick * 0.3

            Text {
                text: mock.sys ? mock.sys.dayText : ""
                color: Qt.rgba(mock.fgCol.r, mock.fgCol.g, mock.fgCol.b, 0.5)
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs - 1; bold: true }
            }
            Text {
                text: mock.sys ? mock.sys.timeText : ""
                color: mock.fgCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs; bold: true }
            }
            Text {
                text: mock.sys ? String(mock.sys.wsId) : "1"
                color: mock.fgCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs - 1; bold: true }
            }
            Text {
                text: mock.sys ? mock.sys.kbLayout : "US"
                color: (mock.sys && mock.sys.kbLayout === "RU") ? mock.sys.tint("#7FB3FF")
                     : Qt.rgba(mock.fgCol.r, mock.fgCol.g, mock.fgCol.b, 0.5)
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs - 2; bold: true }
            }
            Text {
                text: mock.sys ? mock.sys.batteryIcon : ""
                color: mock.onCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"; pixelSize: mock.fs }
            }
            Text {
                text: (mock.sys ? mock.sys.batteryPct : 0) + "%"
                color: Qt.rgba(mock.fgCol.r, mock.fgCol.g, mock.fgCol.b, 0.5)
                font { family: mock.sys ? mock.sys.fontFam : "monospace"; pixelSize: mock.fs - 2 }
            }
        }

        // --- вертикальный вид: столбиком, текст прямой
        ColumnLayout {
            id: vertRow
            anchors.centerIn: parent
            opacity: mock.side ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            spacing: mock.thick * 0.14

            // день недели — буква под буквой
            Column {
                Layout.alignment: Qt.AlignHCenter
                spacing: -2
                Repeater {
                    model: String(mock.sys ? mock.sys.dayText : "").split("")
                    Text {
                        required property string modelData
                        text: modelData
                        color: Qt.rgba(mock.fgCol.r, mock.fgCol.g, mock.fgCol.b, 0.5)
                        font { family: mock.sys ? mock.sys.fontFam : "monospace"
                               pixelSize: mock.fs - 2; bold: true }
                    }
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: mock.sys ? (mock.sys.timeText.split(":")[0] || "") : ""
                color: mock.fgCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: mock.sys
                      ? (mock.sys.timeText.split(":")[1] || "").replace(/[^0-9]/g, "") : ""
                color: mock.fgCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: mock.sys ? String(mock.sys.wsId) : "1"
                color: mock.fgCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs - 1; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: mock.sys ? mock.sys.kbLayout : "US"
                color: (mock.sys && mock.sys.kbLayout === "RU") ? mock.sys.tint("#7FB3FF")
                     : Qt.rgba(mock.fgCol.r, mock.fgCol.g, mock.fgCol.b, 0.5)
                font { family: mock.sys ? mock.sys.fontFam : "monospace"
                       pixelSize: mock.fs - 3; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: mock.sys ? mock.sys.batteryIcon : ""
                color: mock.onCol
                font { family: mock.sys ? mock.sys.fontFam : "monospace"; pixelSize: mock.fs - 1 }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: mock.sys ? mock.sys.batteryPct : ""
                color: Qt.rgba(mock.fgCol.r, mock.fgCol.g, mock.fgCol.b, 0.5)
                font { family: mock.sys ? mock.sys.fontFam : "monospace"; pixelSize: mock.fs - 3 }
            }
        }
    }

    // Вогнутые уголки примыкания: стоят с двух сторон острова и цепляются к
    // той же кромке. Сторона выбирается так, чтобы заливка прижималась к краю
    // экрана, вертикальное отражение делает Scale.
    NotchShape {
        id: notchA
        side: mock.side ? (mock.pos === "left" ? "right" : "left") : "left"
        fill: mock.sys ? mock.sys.colBg : "#0a0a0a"
        r: mock.cr
        transform: Scale {
            origin.y: mock.cr / 2
            yScale: mock.side ? -1 : (mock.pos === "bottom" ? -1 : 1)
        }
        x: mock.pos === "left"  ? 0
         : mock.pos === "right" ? mock.width - width
                                : pill.x - width
        y: mock.side ? pill.y - height
         : mock.pos === "bottom" ? mock.height - height : 0
    }
    NotchShape {
        id: notchB
        side: mock.side ? (mock.pos === "left" ? "right" : "left") : "right"
        fill: mock.sys ? mock.sys.colBg : "#0a0a0a"
        r: mock.cr
        transform: Scale {
            origin.y: mock.cr / 2
            yScale: mock.side ? 1 : (mock.pos === "bottom" ? -1 : 1)
        }
        x: mock.pos === "left"  ? 0
         : mock.pos === "right" ? mock.width - width
                                : pill.x + pill.width
        y: mock.side ? pill.y + pill.height
         : mock.pos === "bottom" ? mock.height - height : 0
    }
}
