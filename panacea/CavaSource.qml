pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Один общий поток спектра на всю оболочку.
//
// Раньше каждый WaveBars поднимал свой cava. Пока процесс стартовал
// (несколько сотен миллисекунд), полосы крутили синтетическую заглушку —
// поэтому при раскрытии капсулы в плеер сначала мелькала «зацикленная»
// волна и только потом появлялся настоящий спектр.
//
// Теперь cava один, живёт, пока его кто-то смотрит, и отдаёт спектр в
// высоком разрешении: любой WaveBars усредняет его до своего barCount и
// с первого же кадра показывает настоящий звук.
Singleton {
    id: src

    // Разрешение общего спектра: делится и на 7 (капсула), и на 22 (плеер)
    // достаточно ровно, чтобы усреднение не «съедало» отдельные полосы.
    readonly property int resolution: 32

    // уровни 0..1, длина == resolution
    property var levels: []

    // true, как только пришёл первый настоящий кадр от cava
    property bool hasCava: false

    // ------------------------------------------------------- учёт зрителей
    property int consumers: 0

    function acquire() { consumers += 1; }
    function release() { if (consumers > 0) consumers -= 1; }

    // Гасим cava не сразу: на паузе или при перескоке между экранами
    // процесс должен пережить перерыв, иначе возвращается тот же лаг старта.
    Timer {
        id: linger
        interval: 20000
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
        // -1 = бесконечный вывод; ascii-режим даёт числа 0..100 через ';'
        command: ["sh", "-c",
            "command -v cava >/dev/null || exit 1; " +
            "cfg=$(mktemp); " +
            // channels=mono обязателен: при stereo cava требует чётное число
            // полос и с нашими семью молча падал — отсюда «мёртвый» эквалайзер.
            // Выше sensitivity и monstercat + меньше сглаживания — полосы
            // отзываются резче и заметнее скачут под музыку.
            "printf '[general]\\nbars=%d\\nframerate=60\\nsensitivity=140\\n" +
            "[output]\\nchannels=mono\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\nascii_max_range=100\\n" +
            "[smoothing]\\nnoise_reduction=0.45\\nmonstercat=2.2\\n' " +
            src.resolution + " > \"$cfg\"; " +
            "exec cava -p \"$cfg\""]
        running: false
        stdout: SplitParser {
            onRead: line => {
                var parts = line.trim().split(";");
                var a = [];
                for (var i = 0; i < src.resolution; i++) {
                    var v = parseInt(parts[i]);
                    // небольшой разгон: тихие места тоже дают заметное движение
                    a.push(isNaN(v) ? 0 : Math.min(1, (v / 100) * 1.25));
                }
                src.levels = a;
                src.hasCava = true;
            }
        }
    }
}
