import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

// Выбор темы: сетка карточек с превью обоев.
// Раньше это был список в tofi — единственное окно, выпадавшее из стиля.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    focus: true
    Component.onCompleted: { reload(); forceActiveFocus(); }
    Keys.onEscapePressed: view.sys.collapse()

    ListModel { id: themes }
    property string applying: ""

    Process {
        id: pList
        command: ["sh", "-c", view.sys.scriptDir + "/themes.sh list"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 3) return;
                themes.append({
                    tName: p[0],
                    tWall: p[1],
                    tActive: p[2] === "yes"
                });
            }
        }
    }
    Process {
        id: pSet
        onRunningChanged: if (!running) { view.applying = ""; view.reload(); }
    }

    function reload() {
        themes.clear();
        pList.running = false;
        pList.running = true;
    }
    function apply(name) {
        view.applying = name;
        pSet.command = ["sh", "-c", view.sys.scriptDir + "/themes.sh set \"$1\"", "_", name];
        pSet.running = true;
    }

    // название темы в читаемом виде: dark_mountains -> Dark mountains
    function pretty(n) {
        var s = String(n).replace(/_/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "Panacea"
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 5; bold: true }
            }
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBaseline
                text: view.sys.tr("оформление системы")
                color: Qt.rgba(1, 1, 1, 0.28)
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; italic: true }
            }
            Text {
                visible: view.applying.length > 0
                text: view.sys.tr("Применяю…")
                color: view.sys.colOn
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 12
            columnSpacing: 12

            Repeater {
                model: themes

                Rectangle {
                    id: card
                    required property string tName
                    required property string tWall
                    required property bool   tActive

                    Layout.fillWidth: true
                    Layout.preferredHeight: 132
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: card.tActive
                                  ? view.sys.colOn
                                  : (cardMa.containsMouse ? Qt.rgba(1, 1, 1, 0.25)
                                                          : view.sys.colLine)
                    border.width: card.tActive ? 2 : 1
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    scale: cardMa.pressed ? 0.96 : (cardMa.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        // превью обоев
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 84
                            radius: 10
                            clip: true
                            color: "#000000"

                            Image {
                                id: thumb
                                anchors.fill: parent
                                // это уже готовая миниатюра из ~/.cache/panacea/thumbs
                                source: card.tWall.indexOf("/") === 0 ? "file://" + card.tWall : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                }
                            }

                            // пока картинка грузится — мягкая пульсация вместо пустоты
                            Rectangle {
                                anchors.fill: parent
                                visible: thumb.status === Image.Loading
                                color: Qt.rgba(1, 1, 1, 0.06)
                                SequentialAnimation on opacity {
                                    running: parent.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.35; duration: 620 }
                                    NumberAnimation { to: 1.0;  duration: 620 }
                                }
                            }

                            // у темы без обоев (чёрная) — просто заливка
                            Text {
                                anchors.centerIn: parent
                                visible: card.tWall.indexOf("/") !== 0
                                text: String.fromCodePoint(0xF03E4)
                                color: Qt.rgba(1, 1, 1, 0.25)
                                font { family: view.sys.fontFam; pixelSize: 26 }
                            }

                            // отметка активной темы
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                width: 22; height: 22; radius: 11
                                visible: card.tActive
                                color: view.sys.colOn
                                Text {
                                    anchors.centerIn: parent
                                    text: String.fromCodePoint(0xF012C)
                                    color: "#ffffff"
                                    font { family: view.sys.fontFam; pixelSize: 12 }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: view.pretty(card.tName)
                            color: card.tActive ? view.sys.colFg : view.sys.colMuted
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font {
                                family: view.sys.fontFam
                                pixelSize: view.sys.fontSize - 3
                                bold: card.tActive
                            }
                        }
                    }

                    MouseArea {
                        id: cardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!card.tActive) view.apply(card.tName)
                    }
                }
            }
        }
    }
}
