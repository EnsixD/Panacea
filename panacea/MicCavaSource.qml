pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Общий поток спектра с микрофона для визуализации голосового ввода (voxtype).
Singleton {
    id: src

    readonly property int resolution: 16
    property var levels: []
    property bool hasCava: false
    property int consumers: 0

    function acquire() { consumers += 1; }
    function release() { if (consumers > 0) consumers -= 1; }

    Timer {
        id: linger
        interval: 2500
        running: src.consumers === 0 && cava.running
        onTriggered: cava.running = false
    }

    onConsumersChanged: if (consumers > 0) cava.running = true

    Component.onCompleted: {
        var a = [];
        for (var i = 0; i < resolution; i++) a.push(0);
        levels = a;
    }

    Process {
        id: cava
        command: ["sh", "-c",
            "command -v cava >/dev/null || exit 1; " +
            "cfg=$(mktemp); " +
            "printf '[general]\\nbars=%d\\nframerate=60\\nsensitivity=260\\n" +
            "[input]\\nmethod=pulse\\nsource=@DEFAULT_SOURCE@\\n" +
            "[output]\\nchannels=mono\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\nascii_max_range=100\\n" +
            "[smoothing]\\nnoise_reduction=0.25\\nmonstercat=1.6\\n' " +
            src.resolution + " > \"$cfg\"; " +
            "exec cava -p \"$cfg\""]
        running: false
        stdout: SplitParser {
            onRead: line => {
                var parts = line.trim().split(";");
                var a = [];
                for (var i = 0; i < src.resolution; i++) {
                    var v = parseInt(parts[i]);
                    a.push(isNaN(v) ? 0 : Math.min(1, (v / 100) * 1.4));
                }
                src.levels = a;
                src.hasCava = true;
            }
        }
    }
}
