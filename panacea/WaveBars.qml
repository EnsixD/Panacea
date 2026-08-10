import QtQuick

// Живой эквалайзер.
//
// Сам спектр не считает: берёт общий поток из CavaSource и усредняет его
// до своего barCount. Благодаря этому раскрытие капсулы в плеер сразу
// показывает настоящий звук — cava уже крутится ради полос в капсуле,
// стартовать заново и мелькать заглушкой больше нечему.
//
// Если cava в системе нет — мягкая синтетическая волна, чтобы капсула не
// выглядела мёртвой. Как только cava установят, он подхватится сам.
Item {
    id: wave

    property color barColor: "#ffffff"
    property bool  active: true
    property int   barCount: 7
    property real  gap: 2

    // уровни 0..1 для каждой полосы
    property var levels: []

    // ------------------------------------------------------------- настоящий
    // Пока полосы видимы и звучат, держим общий cava живым.
    onActiveChanged: active ? CavaSource.acquire() : CavaSource.release()
    Component.onDestruction: if (active) CavaSource.release()

    // Усреднение общего спектра до barCount полос.
    function resample(src) {
        var n = src.length;
        if (n === 0) return;
        var a = [];
        for (var i = 0; i < wave.barCount; i++) {
            var from = Math.floor(i * n / wave.barCount);
            var to   = Math.max(from + 1, Math.floor((i + 1) * n / wave.barCount));
            var sum = 0;
            for (var j = from; j < to; j++) sum += src[j];
            a.push(sum / (to - from));
        }
        wave.levels = a;
    }

    Connections {
        target: CavaSource
        enabled: wave.active && CavaSource.hasCava
        function onLevelsChanged() { wave.resample(CavaSource.levels); }
    }

    Component.onCompleted: {
        var a = [];
        for (var i = 0; i < barCount; i++) a.push(0.2);
        levels = a;
        if (active) CavaSource.acquire();
        // Первый кадр — сразу, не дожидаясь следующего пакета от cava:
        // иначе на раскрытии успевал мигнуть стартовый уровень 0.2.
        if (CavaSource.hasCava) resample(CavaSource.levels);
    }

    // -------------------------------------------------------------- запасной
    Timer {
        // 30 кадров/с: на 90 мс волна заметно ступенчатая
        interval: 33
        running: wave.active && !CavaSource.hasCava
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
                // Степенная кривая (0.6) поднимает средние значения: тихие
                // места ещё видны, а на музыке полосы уверенно бьют почти
                // во всю высоту, а не жмутся к низу.
                height: Math.max(2,
                    Math.pow(Math.min(1, wave.levels[index] || 0.06), 0.6) * wave.height)
                anchors.verticalCenter: parent.verticalCenter

                // Кадры приходят каждые ~33 мс, а кривая длиннее — движение
                // получается непрерывным, без рывков между значениями.
                Behavior on height {
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
