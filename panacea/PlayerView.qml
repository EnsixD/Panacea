import QtQuick
import QtQuick.Layouts

// Раскрытая панель, когда играет музыка или видео.
// Обложка, название, исполнитель, прогресс и управление.
Item {
    id: view
    property var sys
    readonly property var p: sys.player

    implicitHeight: col.implicitHeight

    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onEscapePressed: view.sys.collapse()

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 13

            // обложка
            Rectangle {
                Layout.preferredWidth: 74
                Layout.preferredHeight: 74
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.07)
                clip: true

                Image {
                    id: art
                    anchors.fill: parent
                    source: view.p && view.p.trackArtUrl ? view.p.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 160
                    visible: status === Image.Ready
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !art.visible
                    text: "󰝚"
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 26 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: view.p ? view.p.trackTitle : ""
                    color: view.sys.colFg
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 14; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: view.p ? view.p.trackArtist : ""
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 12 }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: view.p ? (view.p.identity || "") : ""
                    color: Qt.rgba(1, 1, 1, 0.28)
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }

                Item { Layout.fillHeight: true }

                WaveBars {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18
                    barCount: 22
                    barColor: view.sys.colFg
                    active: view.p ? view.p.isPlaying : false
                }
            }
        }

        // -------------------------------------------------------- прогресс
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: view.p && view.p.lengthSupported && view.p.length > 0

            Rectangle {
                id: track
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.12)

                Rectangle {
                    width: parent.width * view.progress
                    height: parent.height
                    radius: 2
                    color: view.sys.colFg
                    Behavior on width { NumberAnimation { duration: 400 } }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -7
                    cursorShape: Qt.PointingHandCursor
                    enabled: view.p && view.p.canSeek
                    onClicked: mouse => {
                        if (!view.p || !view.p.length) return;
                        var frac = Math.max(0, Math.min(1, mouse.x / track.width));
                        view.p.position = frac * view.p.length;
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: view.fmt(view.p ? view.p.position : 0)
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: view.fmt(view.p ? view.p.length : 0)
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: 10 }
                }
            }
        }

        // -------------------------------------------------------- управление
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            component Ctl: Rectangle {
                property string icon: ""
                property bool primary: false
                property bool enabledAction: true
                signal act()

                width: primary ? 44 : 36
                height: primary ? 44 : 36
                radius: width / 2
                color: primary ? view.sys.colFg
                      : (ma.containsMouse ? view.sys.colHover : Qt.rgba(1, 1, 1, 0.06))
                opacity: enabledAction ? 1 : 0.35
                Behavior on color { ColorAnimation { duration: 140 } }
                scale: ma.pressed ? 0.9 : (ma.containsMouse ? 1.07 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: parent.icon
                    color: parent.primary ? view.sys.colBg : view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: parent.primary ? 17 : 14 }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: parent.enabledAction
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.act()
                }
            }

            Ctl {
                icon: "󰒮"
                enabledAction: view.p ? view.p.canGoPrevious : false
                onAct: if (view.p) view.p.previous()
            }
            Ctl {
                icon: view.p && view.p.isPlaying ? "󰏤" : "󰐊"
                primary: true
                enabledAction: view.p ? view.p.canTogglePlaying : false
                onAct: if (view.p) view.p.togglePlaying()
            }
            Ctl {
                icon: "󰒭"
                enabledAction: view.p ? view.p.canGoNext : false
                onAct: if (view.p) view.p.next()
            }
        }
    }

    // ------------------------------------------------------------ помощники
    readonly property real progress: {
        if (!p || !p.length || p.length <= 0) return 0;
        return Math.max(0, Math.min(1, p.position / p.length));
    }

    function fmt(sec) {
        if (!sec || sec < 0) return "0:00";
        var s = Math.floor(sec % 60);
        var m = Math.floor(sec / 60);
        return m + ":" + (s < 10 ? "0" + s : s);
    }

    // позиция обновляется только по запросу
    Timer {
        interval: 1000
        running: view.p && view.p.isPlaying
        repeat: true
        onTriggered: if (view.p) view.p.positionChanged()
    }
}
