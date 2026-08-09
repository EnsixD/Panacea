import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Pipewire

// Звук: громкость и выбор устройства вывода.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onEscapePressed: view.sys.page = "main"

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            // назад к плиткам
            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 10
                color: backMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF004D)
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 4 }
                }
                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.page = "main"
                }
            }
            Text {
                Layout.fillWidth: true
                text: view.sys.tr("Звук")
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 1; bold: true }
            }
        }

        // ------------------------------------------------------- громкость
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.preferredWidth: 26
                horizontalAlignment: Text.AlignHCenter
                text: !view.sinkAudio ? String.fromCodePoint(0xF075F)
                    : view.sinkAudio.muted ? String.fromCodePoint(0xF075F)
                    : view.sinkAudio.volume < 0.34 ? String.fromCodePoint(0xF057F)
                    : view.sinkAudio.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                                   : String.fromCodePoint(0xF057E)
                color: view.sinkAudio && view.sinkAudio.muted ? view.sys.colMuted : view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: view.sys.iconSize }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (view.sinkAudio) view.sinkAudio.muted = !view.sinkAudio.muted
                }
            }

            Item {
                id: sl
                Layout.fillWidth: true
                Layout.preferredHeight: 26

                readonly property real pos: view.sinkAudio ? view.sinkAudio.volume : 0
                readonly property real usable: width - knob.width

                function setFromX(x) {
                    if (!view.sinkAudio) return;
                    var r = Math.max(0, Math.min(1, (x - knob.width / 2) / Math.max(1, usable)));
                    // шаг 5%, как у мультимедийных клавиш
                    view.sinkAudio.volume = Math.round(r * 20) / 20;
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: knob.width / 2
                    width: parent.usable
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.12)
                    Rectangle {
                        width: parent.width * sl.pos
                        height: parent.height
                        radius: 3
                        color: view.sys.colOn
                    }
                }
                Rectangle {
                    id: knob
                    width: 18; height: 18; radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    x: sl.pos * sl.usable
                    color: "#ffffff"
                    scale: drag.pressed ? 1.25 : (drag.containsMouse ? 1.1 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                }
                MouseArea {
                    id: drag
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => sl.setFromX(mouse.x)
                    onPositionChanged: mouse => { if (pressed) sl.setFromX(mouse.x); }
                }
            }

            Text {
                Layout.preferredWidth: 46
                horizontalAlignment: Text.AlignRight
                text: view.sinkAudio ? Math.round(view.sinkAudio.volume * 100) + "%" : "—"
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
            }
        }

        // -------------------------------------------------------- устройства
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: view.sys.tr("Устройство вывода")
            color: view.sys.colMuted
            font {
                family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
            }
        }

        Repeater {
            model: view.sys.audioSinks

            Rectangle {
                id: dev
                required property var modelData
                readonly property bool active: Pipewire.defaultAudioSink === dev.modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: 12
                color: dev.active
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                       : (devMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                border.color: dev.active
                              ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                              : view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 13
                    anchors.rightMargin: 13
                    spacing: 11

                    Text {
                        text: String.fromCodePoint(0xF057E)
                        color: dev.active ? view.sys.colOn : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 2 }
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: String(dev.modelData.nickname || dev.modelData.description
                                     || dev.modelData.name || "")
                        color: dev.active ? view.sys.colFg : view.sys.colMuted
                        elide: Text.ElideRight
                        font {
                            family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2
                            bold: dev.active
                        }
                    }
                    Text {
                        visible: dev.active
                        text: String.fromCodePoint(0xF012C)
                        color: view.sys.colOn
                        font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 4 }
                    }
                }

                MouseArea {
                    id: devMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.setSink(dev.modelData)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: view.sys.audioSinks.length === 0
            text: view.sys.tr("Нет устройств")
            color: view.sys.colMuted
            horizontalAlignment: Text.AlignHCenter
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }
    }
}
