import QtQuick
import Quickshell.Io

// Живой эквалайзер.
//
// Если в системе есть cava — рисуем настоящий спектр звука.
// Если нет — мягкая синтетическая волна, чтобы капсула не выглядела мёртвой.
// Как только cava установят, он подхватится сам при следующем запуске.
Item {
    id: wave

    property color barColor: "#ffffff"
    property bool  active: true
    property int   barCount: 7
    property real  gap: 2

    // уровни 0..1 для каждой полосы
    property var levels: []

    Component.onCompleted: {
        var a = [];
        for (var i = 0; i < barCount; i++) a.push(0.2);
        levels = a;
    }

    // ------------------------------------------------------------- настоящий
    Process {
        id: cava
        // -1 = бесконечный вывод; ascii-режим даёт числа 0..100 через ';'
        command: ["sh", "-c",
            "command -v cava >/dev/null || exit 1; " +
            "cfg=$(mktemp); " +
            "printf '[general]\\nbars=%d\\nframerate=60\\n" +
            "[smoothing]\\nnoise_reduction=0.77\\nmonstercat=1.5\\n" +
            "[output]\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\nascii_max_range=100\\n' " +
            wave.barCount + " > \"$cfg\"; " +
            "exec cava -p \"$cfg\""]
        running: wave.active
        stdout: SplitParser {
            onRead: line => {
                var parts = line.trim().split(";");
                var a = [];
                for (var i = 0; i < wave.barCount; i++) {
                    var v = parseInt(parts[i]);
                    a.push(isNaN(v) ? 0 : Math.min(1, v / 100));
                }
                wave.levels = a;
                wave.hasCava = true;
            }
        }
    }
    property bool hasCava: false

    // -------------------------------------------------------------- запасной
    Timer {
        // 30 кадров/с: на 90 мс волна заметно ступенчатая
        interval: 33
        running: wave.active && !wave.hasCava
        repeat: true
        onTriggered: {
            var a = [];
            var t = Date.now() / 260;
            for (var i = 0; i < wave.barCount; i++) {
                // две несинхронные синусоиды -> волна выглядит живой, а не строгой
                var v = 0.45 + 0.34 * Math.sin(t + i * 0.85)
                             + 0.18 * Math.sin(t * 1.7 + i * 1.9);
                a.push(Math.max(0.08, Math.min(1, v)));
            }
            wave.levels = a;
        }
    }

    // затухание, когда пауза
    Timer {
        interval: 33
        running: !wave.active
        repeat: true
        onTriggered: {
            var a = [];
            var changed = false;
            for (var i = 0; i < wave.levels.length; i++) {
                var v = Math.max(0.08, wave.levels[i] * 0.92);
                if (Math.abs(v - wave.levels[i]) > 0.001) changed = true;
                a.push(v);
            }
            if (changed) wave.levels = a;
        }
    }

    Row {
        anchors.fill: parent
        spacing: wave.gap

        Repeater {
            model: wave.barCount
            Rectangle {
                required property int index
                width: (wave.width - wave.gap * (wave.barCount - 1)) / wave.barCount
                radius: width / 2
                color: wave.barColor
                opacity: 0.55 + 0.45 * height / Math.max(1, wave.height)
                height: Math.max(2, (wave.levels[index] || 0.1) * wave.height)
                anchors.verticalCenter: parent.verticalCenter

                // Кадры приходят каждые ~33 мс, а кривая длиннее — движение
                // получается непрерывным, без рывков между значениями.
                Behavior on height {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
