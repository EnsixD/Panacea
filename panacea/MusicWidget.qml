import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// Compact desktop player. Fixed geometry keeps metadata steady during playback.
Rectangle {
    id: card
    property var sys
    readonly property var player: sys ? sys.player : null
    readonly property bool playing: player ? player.isPlaying : false
    readonly property bool hasTrack: player && String(player.trackTitle || "").trim().length > 0
    property real position: 0
    readonly property real duration: player ? Math.max(0, player.length) : 0
    readonly property real progress: duration > 0 ? Math.max(0, Math.min(1, position / duration)) : 0
    implicitWidth: 300
    implicitHeight: 156
    radius: 22
    color: "#171719"
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1

    Timer {
        interval: 500; repeat: true
        running: card.visible && card.player !== null
        triggeredOnStart: true
        onTriggered: {
            if (card.player) {
                card.player.positionChanged();
                card.position = card.player.position || 0;
            }
        }
    }
    Connections {
        target: card.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { card.position = 0; }
    }
    function time(sec) {
        var n = Math.max(0, Math.floor(sec || 0));
        return Math.floor(n / 60) + ":" + (n % 60 < 10 ? "0" : "") + (n % 60);
    }
    component Action: Rectangle {
        id: button
        property string glyph: ""
        property bool available: false
        property bool primary: false
        signal triggered()
        implicitWidth: primary ? 36 : 30
        implicitHeight: 30
        radius: 15
        color: primary ? (hit.containsMouse ? "#eeeeef" : "#d8d8da")
                       : (hit.containsMouse ? "#414144" : "#2b2b2e")
        opacity: available ? 1 : 0.35
        Text {
            anchors.centerIn: parent
            text: button.glyph
            color: button.primary ? "#19191b" : "#f0f0f0"
            font { family: card.sys ? card.sys.fontFam : "sans-serif"; pixelSize: 15 }
        }
        MouseArea {
            id: hit
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.available
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }

    Rectangle {
        id: cover
        x: 14; y: 14; width: 82; height: 82; radius: 14
        color: "#303034"
        Image {
            id: art
            anchors.fill: parent
            source: card.sys ? card.sys.mediaArt : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 164; sourceSize.height: 164
            visible: false; layer.enabled: true
        }
        Item {
            id: artMask
            anchors.fill: parent
            visible: false; layer.enabled: true
            Rectangle { anchors.fill: parent; radius: 14; color: "white" }
        }
        MultiEffect {
            anchors.fill: parent
            source: art
            maskEnabled: true
            maskSource: artMask
            visible: art.status === Image.Ready
        }
        Text {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            text: "󰝚"
            color: "#a3a3a7"
            font { family: card.sys ? card.sys.fontFam : "sans-serif"; pixelSize: 32 }
        }
    }

    Rectangle { x: 108; y: 16; width: 5; height: 5; radius: 3; color: card.playing ? "#e53c3c" : "#77777b" }
    Text {
        x: 119; y: 11; width: 164; height: 14
        text: card.playing ? "NOW PLAYING" : (card.hasTrack ? "PAUSED" : "NOTHING MUSIC")
        color: "#99999e"
        font { family: card.sys ? card.sys.fontFam : "sans-serif"; pixelSize: 8; bold: true; letterSpacing: 1.2 }
        elide: Text.ElideRight
    }
    Text {
        x: 108; y: 32; width: 178; height: 20
        text: card.hasTrack ? card.player.trackTitle : (card.sys ? card.sys.tr("Нет музыки") : "No media")
        color: "#f4f4f4"; elide: Text.ElideRight
        font { family: card.sys ? card.sys.fontFam : "sans-serif"; pixelSize: 13; bold: true }
    }
    Text {
        x: 108; y: 53; width: 178; height: 18
        text: card.hasTrack ? (card.player.trackArtist || "") : (card.sys ? card.sys.tr("Запустите плеер") : "Start playing")
        color: "#a1a1a6"; elide: Text.ElideRight
        font { family: card.sys ? card.sys.fontFam : "sans-serif"; pixelSize: 10 }
    }
    Row {
        x: 108; y: 76; spacing: 8
        Action { glyph: "󰒮"; available: card.player && card.player.canGoPrevious; onTriggered: card.player.previous() }
        Action { primary: true; glyph: card.playing ? "󰏤" : "󰐊"; available: card.player && card.player.canTogglePlaying; onTriggered: card.player.togglePlaying() }
        Action { glyph: "󰒭"; available: card.player && card.player.canGoNext; onTriggered: card.player.next() }
    }
    Rectangle {
        id: progressTrack
        x: 14; y: 124; width: card.width - 28; height: 3; radius: 1.5
        color: "#3a3a3e"
        Rectangle { width: parent.width * card.progress; height: parent.height; radius: 1.5; color: "#e53c3c" }
    }
    Text {
        x: 14; y: 132; text: card.time(card.position); color: "#919196"
        font { family: card.sys ? card.sys.fontFam : "sans-serif"; pixelSize: 9 }
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 14; y: 132
        text: card.time(card.duration); color: "#919196"
        font { family: card.sys ? card.sys.fontFam : "sans-serif"; pixelSize: 9 }
    }
}
