import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Звук: общая громкость, выбор устройства вывода и раздельный микшер приложений.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    focus: true
    Component.onCompleted: {
        forceActiveFocus();
        pStreams.running = true;
    }
    function goBack() { view.sys.page = "main"; return true; }
    Keys.onEscapePressed: view.goBack()

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null

    // -------------------------------------------------- микшер приложений (pactl)
    property var streamsList: []
    property bool isUserDragging: false

    Process {
        id: pStreams
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/panacea/scripts/audio_streams.sh list"]
        stdout: SplitParser {
            onRead: data => {
                // Не перезаписываем список, если пользователь прямо сейчас тянет ползунок
                if (view.isUserDragging) return;
                try {
                    var parsed = JSON.parse(data.trim());
                    if (Array.isArray(parsed)) {
                        view.streamsList = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        id: streamsTimer
        interval: 1000
        repeat: true
        running: view.visible
        onTriggered: {
            if (!view.isUserDragging && !pStreams.running) pStreams.running = true;
        }
    }

    Process {
        id: pStreamAction
    }

    function setAppVolume(streamId, pct) {
        pStreamAction.command = ["sh", "-c", Quickshell.env("HOME")
                                 + "/.config/panacea/scripts/audio_streams.sh set-volume "
                                 + streamId + " " + pct];
        pStreamAction.running = true;
    }

    function toggleAppMute(streamId) {
        pStreamAction.command = ["sh", "-c", Quickshell.env("HOME")
                                 + "/.config/panacea/scripts/audio_streams.sh toggle-mute "
                                 + streamId];
        pStreamAction.running = true;
        quickRefresh.restart();
    }

    Timer {
        id: quickRefresh
        interval: 150
        onTriggered: {
            if (!pStreams.running) pStreams.running = true;
        }
    }

    function getStreamIcon(name, bin, icon) {
        var s = (String(name || "") + " " + String(bin || "") + " " + String(icon || "")).toLowerCase();

        if (s.indexOf("telegram") >= 0) return String.fromCodePoint(0xF2C6); // 
        if (s.indexOf("spotify") >= 0) return String.fromCodePoint(0xF1BC);  // 
        if (s.indexOf("firefox") >= 0) return String.fromCodePoint(0xF269);  // 
        if (s.indexOf("chrome") >= 0 || s.indexOf("chromium") >= 0 || s.indexOf("brave") >= 0 || s.indexOf("zen") >= 0) return String.fromCodePoint(0xF268); // 
        if (s.indexOf("discord") >= 0 || s.indexOf("vesktop") >= 0 || s.indexOf("webcord") >= 0) return String.fromCodePoint(0xF392); // 
        if (s.indexOf("steam") >= 0) return String.fromCodePoint(0xF1B6);    // 
        if (s.indexOf("vlc") >= 0 || s.indexOf("mpv") >= 0 || s.indexOf("video") >= 0 || s.indexOf("player") >= 0 || s.indexOf("music") >= 0) return String.fromCodePoint(0xF144); // 
        if (s.indexOf("game") >= 0 || s.indexOf("retroarch") >= 0 || s.indexOf("wine") >= 0 || s.indexOf("lutris") >= 0) return String.fromCodePoint(0xF11B); // 
        return String.fromCodePoint(0xF028); //  Speaker
    }

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

        // ------------------------------------------------------- общая громкость
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

                readonly property real pos: view.sinkAudio ? Math.max(0, Math.min(1, view.sinkAudio.volume)) : 0
                readonly property real usable: width - knob.width

                function setFromX(x) {
                    if (!view.sinkAudio) return;
                    var r = Math.max(0, Math.min(1, (x - knob.width / 2) / Math.max(1, usable)));
                    // Полностью плавная регулировка без ступенек
                    view.sinkAudio.volume = r;
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
                    border.color: view.sys.colBg
                    border.width: view.sys.themeNothing ? 2 : 0
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

        // ------------------------------------------ громкость приложений (микшер)
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            Text {
                text: view.sys.tr("Громкость приложений")
                color: view.sys.colMuted
                font {
                    family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                    bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                }
            }

            Rectangle {
                visible: view.streamsList.length > 0
                Layout.preferredHeight: 16
                Layout.preferredWidth: streamCountText.implicitWidth + 10
                radius: 8
                color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.2)

                Text {
                    id: streamCountText
                    anchors.centerIn: parent
                    text: String(view.streamsList.length)
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                }
            }

            Item { Layout.fillWidth: true }
        }

        Repeater {
            model: view.streamsList

            Rectangle {
                id: strCard
                required property var modelData
                required property int index

                property int currentVolPct: modelData.volume_pct !== undefined ? modelData.volume_pct : Math.round((modelData.volume || 1.0) * 100)
                property bool isMuted: modelData.muted || false

                Layout.fillWidth: true
                Layout.preferredHeight: 58
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: view.getStreamIcon(strCard.modelData.name, strCard.modelData.binary, strCard.modelData.icon)
                            color: strCard.isMuted ? view.sys.colMuted : view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 2 }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: strCard.modelData.name || strCard.modelData.binary || view.sys.tr("Приложение")
                            color: view.sys.colFg
                            elide: Text.ElideRight
                            font {
                                family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2
                                bold: true
                            }
                        }

                        Text {
                            text: strCard.currentVolPct + "%"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }

                        Text {
                            text: strCard.isMuted ? String.fromCodePoint(0xF075F)
                                : strCard.currentVolPct < 34 ? String.fromCodePoint(0xF057F)
                                : strCard.currentVolPct < 67 ? String.fromCodePoint(0xF0580)
                                                             : String.fromCodePoint(0xF057E)
                            color: strCard.isMuted ? view.sys.colMuted : view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 3 }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    strCard.isMuted = !strCard.isMuted;
                                    view.toggleAppMute(strCard.modelData.id);
                                }
                            }
                        }
                    }

                    // Ползунок громкости конкретного приложения (плавный, мгновенный прыжок)
                    Item {
                        id: appSl
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18

                        readonly property real pos: Math.max(0, Math.min(1, strCard.currentVolPct / 100))
                        readonly property real usable: width - appKnob.width

                        function setFromX(x) {
                            var r = Math.max(0, Math.min(1, (x - appKnob.width / 2) / Math.max(1, usable)));
                            var pct = Math.round(r * 100);
                            strCard.currentVolPct = pct;
                            view.setAppVolume(strCard.modelData.id, pct);
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: appKnob.width / 2
                            width: parent.usable
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.12)
                            Rectangle {
                                width: parent.width * appSl.pos
                                height: parent.height
                                radius: 2
                                color: strCard.isMuted ? view.sys.colMuted : view.sys.colOn
                            }
                        }

                        Rectangle {
                            id: appKnob
                            width: 14; height: 14; radius: 7
                            anchors.verticalCenter: parent.verticalCenter
                            x: appSl.pos * appSl.usable
                            color: "#ffffff"
                            border.color: view.sys.colBg
                            border.width: view.sys.themeNothing ? 2 : 0
                            scale: appDrag.pressed ? 1.25 : (appDrag.containsMouse ? 1.1 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                        }

                        MouseArea {
                            id: appDrag
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => {
                                view.isUserDragging = true;
                                appSl.setFromX(mouse.x);
                            }
                            onPositionChanged: mouse => {
                                if (pressed) {
                                    view.isUserDragging = true;
                                    appSl.setFromX(mouse.x);
                                }
                            }
                            onReleased: {
                                view.isUserDragging = false;
                            }
                            onCanceled: {
                                view.isUserDragging = false;
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: view.streamsList.length === 0
            text: view.sys.tr("Нет активных приложений со звуком")
            color: view.sys.colMuted
            horizontalAlignment: Text.AlignHCenter
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; italic: true }
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }
    }
}
