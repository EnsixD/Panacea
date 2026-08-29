import QtQuick

// Живой эквалайзер голоса для голосового ввода voxtype.
Item {
    id: wave

    property color barColor: "#ef4444"
    property bool  active: true
    property int   barCount: 9
    property real  gap: 2.5
    property var   levels: []

    onActiveChanged: active ? MicCavaSource.acquire() : MicCavaSource.release()
    Component.onDestruction: if (active) MicCavaSource.release()

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
        target: MicCavaSource
        enabled: wave.active && MicCavaSource.hasCava
        function onLevelsChanged() { wave.resample(MicCavaSource.levels); }
    }

    Component.onCompleted: {
        var a = [];
        for (var i = 0; i < barCount; i++) a.push(0.15);
        levels = a;
        if (active) MicCavaSource.acquire();
        if (MicCavaSource.hasCava) resample(MicCavaSource.levels);
    }

    // Мягкая анимация волны, если тишина или cava ещё инициализируется
    Timer {
        interval: 33
        running: wave.active && !MicCavaSource.hasCava
        repeat: true
        onTriggered: {
            var a = [];
            var t = Date.now() / 200;
            for (var i = 0; i < wave.barCount; i++) {
                var v = 0.35 + 0.25 * Math.sin(t + i * 0.9) + 0.15 * Math.sin(t * 2.1 + i * 1.5);
                a.push(Math.max(0.08, Math.min(1, v)));
            }
            wave.levels = a;
        }
    }

    // Плавное затухание при остановке
    Timer {
        interval: 33
        running: !wave.active
        repeat: true
        onTriggered: {
            var a = [];
            var changed = false;
            for (var i = 0; i < wave.levels.length; i++) {
                var v = Math.max(0.08, wave.levels[i] * 0.85);
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
                opacity: 0.75 + 0.25 * height / Math.max(1, wave.height)
                height: Math.max(3, Math.pow(Math.min(1, (wave.levels && wave.levels[index]) || 0.08), 0.55) * wave.height)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
