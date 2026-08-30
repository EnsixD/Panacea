import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

// Буфер обмена (Super+V) — история cliphist прямо в пилюле.
// Поиск сверху, стрелки двигают выбор, Enter копирует, Escape закрывает.
//
// Корень именно FocusScope, а не Item: панель отдаёт фокус загруженному виду
// целиком, и только FocusScope передаёт его дальше — полю поиска. С обычным
// Item фокус оставался на корне, и печатать сразу было нельзя.
FocusScope {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    ListModel { id: model }
    property string query: ""

    // строки cliphist: "<id>\t<превью>"
    Process {
        id: pList
        command: ["sh", "-c", "cliphist list"]
        stdout: SplitParser {
            onRead: line => {
                var t = line.indexOf("\t");
                if (t < 0) return;
                var id = line.substring(0, t);
                var preview = line.substring(t + 1).trim();
                if (!preview.length) return;
                if (view.query.length &&
                    preview.toLowerCase().indexOf(view.query.toLowerCase()) < 0) return;
                if (model.count >= 60) return;
                model.append({
                    cid: id,
                    preview: preview,
                    isImage: /^\[\[\s*binary data/.test(preview)
                });
            }
        }
    }

    Process { id: pCopy }
    Process { id: pWipe; command: ["sh", "-c", "cliphist wipe"] }

    function reload() {
        model.clear();
        list.currentIndex = 0;
        pList.running = false;
        pList.running = true;
    }

    function copyAt(i) {
        if (i < 0 || i >= model.count) return;
        var id = model.get(i).cid;
        pCopy.command = ["sh", "-c",
            "printf '%s\\t' \"$1\" | cliphist decode | wl-copy", "_", id];
        pCopy.running = true;
        view.sys.collapse();
    }

    Component.onCompleted: view.reload()
    FocusGrabber { target: input }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 9

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: input.activeFocus ? Qt.rgba(1, 1, 1, 0.22) : view.sys.colLine
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 9

                    Text {
                        text: "󰅍"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 2 }
                    }

                    TextField {
                        id: input
                        // область фокуса переадресует его сюда
                        focus: true
                        Layout.fillWidth: true
                        placeholderText: view.sys.tr("Поиск в буфере")
                        color: view.sys.colFg
                        placeholderTextColor: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                        background: null
                        onTextEdited: { view.query = text; view.reload(); }

                        Keys.onEscapePressed: view.sys.collapse()
                        Keys.onReturnPressed: view.copyAt(list.currentIndex)
                        Keys.onDownPressed:
                            if (list.currentIndex < model.count - 1) list.currentIndex++
                        Keys.onUpPressed:
                            if (list.currentIndex > 0) list.currentIndex--
                    }

                    // доступ к хранилищу паролей (Vault)
                    Text {
                        visible: view.sys.cfg.featVault
                        text: String.fromCodePoint(view.sys.vaultUnlocked ? 0xF0FC6 : 0xF033E)
                        color: view.sys.vaultUnlocked ? view.sys.colOk : (vaultMa.containsMouse ? view.sys.colFg : view.sys.colMuted)
                        font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 3 }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        MouseArea {
                            id: vaultMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.sys.togglePage("vault")
                        }
                    }

                    // очистить историю
                    Text {
                        text: "󰩹"
                        color: wipeMa.containsMouse ? view.sys.colCrit : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 3 }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        MouseArea {
                            id: wipeMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { pWipe.running = true; view.reload(); }
                        }
                    }
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 300)
            clip: true
            model: model
            spacing: 3
            boundsBehavior: Flickable.StopAtBounds
            // плавная прокрутка колесом
            flickDeceleration: 3000
            maximumFlickVelocity: 2600

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
            }

            delegate: Rectangle {
                width: list.width
                height: 38
                radius: 10
                color: index === list.currentIndex ? Qt.rgba(1, 1, 1, 0.11)
                     : rowMa.containsMouse ? view.sys.colHover : "transparent"
                Behavior on color { ColorAnimation { duration: 130 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 11
                    anchors.rightMargin: 11
                    spacing: 10

                    Text {
                        text: model.isImage ? "󰋩" : "󰈙"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 3 }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: model.isImage ? view.sys.tr("Изображение") : model.preview
                        color: view.sys.colFg
                        elide: Text.ElideRight
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: list.currentIndex = index
                    onClicked: view.copyAt(index)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: model.count === 0
            text: view.query.length ? view.sys.tr("Ничего не найдено") : view.sys.tr("Буфер пуст")
            color: view.sys.colMuted
            horizontalAlignment: Text.AlignHCenter
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }
    }
}
