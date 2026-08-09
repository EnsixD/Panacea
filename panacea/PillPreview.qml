import QtQuick
import QtQuick.Layouts

// Макет пилюли для предпросмотра настроек.
// Рисуется теми же правилами, что настоящая, но берёт значения из draft,
// поэтому изменения видно до нажатия «Применить».
Item {
    id: prev

    property var sys
    property var d                     // черновик настроек

    readonly property color fg:    d.colFg
    readonly property color muted: Qt.rgba(fg.r, fg.g, fg.b, d.mutedAlpha)
    readonly property color accent: d.colOn

    implicitHeight: 96

    // подложка, чтобы был виден край экрана и примыкание
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: prev.sys.colLine
        border.width: 1

        // имитация «обоев», чтобы вогнутые уголки читались
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 13
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#1e293b" }
                GradientStop { position: 0.5; color: "#334155" }
                GradientStop { position: 1.0; color: "#1e293b" }
            }
            opacity: 0.55
        }

        // сама пилюля
        Item {
            id: pillWrap
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 18
            width: parent.width
            height: prev.d.pillH

            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                height: prev.d.pillH
                width: row.implicitWidth + 32
                color: "#000000"
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: prev.d.pillH / 2
                bottomRightRadius: prev.d.pillH / 2
                clip: true

                Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on width  { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                RowLayout {
                    id: row
                    anchors.centerIn: parent
                    height: parent.height
                    spacing: 14

                    Text {
                        text: prev.sys.isEn ? "Sat" : "Сб"
                        color: prev.muted
                        font { family: prev.d.fontFam; pixelSize: prev.d.fontSize - 1; bold: true }
                    }
                    Text {
                        text: prev.d.clock12 ? "2:34 PM" : "14:34"
                        color: prev.fg
                        font { family: prev.d.fontFam; pixelSize: prev.d.fontSize; bold: true }
                    }
                    Text {
                        text: "2"
                        color: prev.fg
                        font { family: prev.d.fontFam; pixelSize: prev.d.fontSize - 1; bold: true }
                    }
                    Text {
                        text: "RU"
                        color: "#7FB3FF"
                        font { family: prev.d.fontFam; pixelSize: prev.d.fontSize - 2; bold: true }
                    }
                    RowLayout {
                        spacing: 5
                        Text {
                            text: String.fromCodePoint(0xF0079)
                            color: prev.accent
                            font { family: prev.d.fontFam; pixelSize: prev.d.iconSize }
                        }
                        Text {
                            text: "87%"
                            color: prev.muted
                            font { family: prev.d.fontFam; pixelSize: prev.d.fontSize - 1; bold: true }
                        }
                    }
                }
            }

            // вогнутые уголки примыкания — как у настоящей
            NotchCorner {
                side: "left"
                fill: "#000000"
                r: prev.d.cornerR
                anchors.top: parent.top
                anchors.right: pill.left
            }
            NotchCorner {
                side: "right"
                fill: "#000000"
                r: prev.d.cornerR
                anchors.top: parent.top
                anchors.left: pill.right
            }
        }
    }
}
