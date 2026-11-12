import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: mascot
    property var sys
    property bool showing: sys.cfg.mascotEnabled
    property real gazeX: 0
    property real gazeY: 0
    property real lastX: -99999
    property real lastY: -99999
    property double lastMovement: Date.now()
    property real monitorX: 0
    property real monitorY: 0
    property bool blinking: false

    property bool active: showing && sys.cfg.mascotEnabled && !sys.expanded
                          && !sys.toastActive && !sys.osdActive && !sys.btToastActive
                          && !sys.wifiToastActive && !sys.acToastActive
                          && !sys.recPickActive && !sys.voxActive && !sys.fileOverIsland
    property int sleepDuration: 120000 + Math.floor(Math.random() * 240000)
    width: 46
    height: sys.pillH

    function showNow() {
        showing = true;
        lastMovement = Date.now();
        cycle.restart();
        monitorQuery.running = true;
    }
    Connections {
        target: sys.cfg
        function onMascotEnabledChanged() {
            if (sys.cfg.mascotEnabled) mascot.showNow();
            else { mascot.showing = false; cycle.stop(); }
        }
    }
    Timer {
        id: cycle
        interval: mascot.showing ? 150000 : mascot.sleepDuration
        running: sys.cfg.mascotEnabled
        repeat: false
        onTriggered: {
            mascot.showing = !mascot.showing;
            if (mascot.showing) { mascot.lastMovement = Date.now(); monitorQuery.running = true; }
            else { mascot.gazeX = 0; mascot.gazeY = 0; mascot.blinking = false; mascot.sleepDuration = 120000 + Math.floor(Math.random() * 240000); }
            restart();
        }
    }
    Process {
        id: monitorQuery
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var monitors = JSON.parse(text);
                    for (var i = 0; i < monitors.length; i++) {
                        if (sys.screen && monitors[i].name === sys.screen.name) {
                            mascot.monitorX = monitors[i].x;
                            mascot.monitorY = monitors[i].y;
                            break;
                        }
                    }
                } catch (e) {}
            }
        }
    }
    Connections { target: sys; function onScreenChanged() { if (sys.cfg.mascotEnabled && !monitorQuery.running) monitorQuery.running = true } }
    Component.onCompleted: if (sys.cfg.mascotEnabled) monitorQuery.running = true
    Process {
        id: cursorQuery
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var p = JSON.parse(text);
                    if (p.x !== mascot.lastX || p.y !== mascot.lastY) {
                        mascot.lastX = p.x; mascot.lastY = p.y;
                        mascot.lastMovement = Date.now();
                        var eyeCenter = mascot.mapToItem(null, mascot.width / 2, mascot.height / 2);
                        var cx = mascot.monitorX + eyeCenter.x;
                        var cy = mascot.monitorY + eyeCenter.y;
                        mascot.gazeX = Math.max(-1, Math.min(1, (p.x - cx) / 300));
                        mascot.gazeY = Math.max(-1, Math.min(1, (p.y - cy) / 240));
                    }
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 60; repeat: true
        running: mascot.active && !sys.noMotion && !Compositor.isNiri
        triggeredOnStart: true
        onTriggered: if (!cursorQuery.running) cursorQuery.running = true
    }
    Timer {
        interval: 2400; repeat: true
        running: mascot.active && !sys.noMotion
        onTriggered: {
            if (Date.now() - mascot.lastMovement > 4500) {
                mascot.gazeX = Math.random() * 2 - 1;
                mascot.gazeY = Math.random() * 1.5 - 0.75;
            }
        }
    }

    Timer {
        interval: 3700; repeat: true
        running: mascot.active && !sys.noMotion
        onTriggered: { mascot.blinking = true; blinkEnd.restart(); }
    }
    Timer { id: blinkEnd; interval: 150; onTriggered: mascot.blinking = false }

    Row {
        anchors.centerIn: parent
        spacing: 7
        Repeater {
            model: 2
            delegate: Item {
                required property int index
                width: 15; height: 29
                Item {
                    x: mascot.gazeX * 4
                    y: mascot.gazeY * 3
                    width: 15; height: 29
                    Behavior on x { NumberAnimation { duration: 85; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 85; easing.type: Easing.OutCubic } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: mascot.showing ? 7 : 11; height: !mascot.showing || mascot.blinking ? 3 : 21
                        radius: width / 2; color: sys.colFg
                        Behavior on height { NumberAnimation { duration: 150 } }
                        Behavior on width { NumberAnimation { duration: 150 } }
                    }
                }
            }
        }
    }
}
