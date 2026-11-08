pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ColumnLayout {
    id: view
    property var sys
    spacing: 8
    readonly property var info: sys.batteryDetails || ({})
    readonly property var history: info.history || []
    function duration(seconds) {
        var mins = Math.round(seconds / 60);
        var hours = Math.floor(mins / 60), minutes = mins % 60;
        return (hours ? hours + " " + sys.tr("ч") + " " : "") + minutes + " " + sys.tr("мин");
    }
    Text {
        Layout.fillWidth: true
        text: sys.batteryRemainingSeconds > 60
              ? (sys.batteryCharging ? sys.tr("До полной зарядки: ") : sys.tr("Осталось примерно: ")) + view.duration(sys.batteryRemainingSeconds)
              : sys.tr("Время работы пока недоступно")
        color: sys.colFg
        font { family: sys.fontFam; pixelSize: 12; bold: true }
    }
    Text {
        Layout.fillWidth: true
        text: sys.powerProfile === "power-saver" ? sys.tr("Экономия снижает энергопотребление.")
            : sys.powerProfile === "performance" ? sys.tr("Максимум отдаёт приоритет производительности.")
            : sys.tr("Баланс сочетает производительность и расход энергии.")
        color: sys.colMuted; wrapMode: Text.WordWrap
        font { family: sys.fontFam; pixelSize: 10 }
    }
    Text {
        Layout.fillWidth: true
        text: sys.tr("История заряда · последние 24 часа")
        color: sys.colFg
        font { family: sys.fontFam; pixelSize: 11; bold: true }
    }
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 60
        radius: 10; color: Qt.rgba(1,1,1,0.04); border.color: sys.colLine
        Canvas {
            id: chart; anchors.fill: parent; anchors.margins: 7
            onPaint: {
                var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                var xs = view.history;
                if (xs.length < 2) return;
                var end = Date.now() / 1000, start = end - 86400;
                ctx.strokeStyle = view.sys.colOn; ctx.lineWidth = 2; ctx.beginPath();
                for (var i = 0; i < xs.length; ++i) {
                    var x = Math.max(0, Math.min(width, (xs[i][0] - start) / 86400 * width));
                    var y = height * (1 - Math.max(0, Math.min(100, xs[i][1])) / 100);
                    if (i === 0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
                }
                ctx.stroke();
            }
            Connections { target: view; function onHistoryChanged() { chart.requestPaint(); } }
        }
        Text {
            anchors.centerIn: parent; visible: view.history.length < 2
            text: view.sys.tr("История накапливается во время работы оболочки")
            color: view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: 10 }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: view.info.cycle !== null && view.info.cycle !== undefined && view.info.cycle >= 0
        text: view.sys.tr("Циклы зарядки: ") + view.info.cycle
        color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 10 }
    }
    ColumnLayout {
        Layout.fillWidth: true; spacing: 5
        visible: view.info.start !== null && view.info.start !== undefined && view.info.end !== null && view.info.end !== undefined
        Text {
            Layout.fillWidth: true
            text: view.sys.tr("Пороги зарядки: ") + view.info.start + "–" + view.info.end + "%"
            color: view.sys.colFg; font { family: view.sys.fontFam; pixelSize: 11; bold: true }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [ { start: 75, end: 80 }, { start: 95, end: 100 } ]
                Rectangle {
                    id: preset
                    required property var modelData
                    readonly property bool selected: view.info.start === modelData.start && view.info.end === modelData.end
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 10
                    color: selected ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                                    : hit.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: selected ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.55) : view.sys.colLine
                    Behavior on color { ColorAnimation { duration: view.sys.animFast } }
                    Behavior on border.color { ColorAnimation { duration: view.sys.animFast } }
                    Text {
                        anchors.centerIn: parent
                        text: preset.modelData.start + "–" + preset.modelData.end + "%"
                        color: preset.selected || hit.containsMouse ? view.sys.colFg : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 11; bold: preset.selected }
                    }
                    MouseArea {
                        id: hit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.setBatteryThreshold(preset.modelData.start, preset.modelData.end)
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: view.sys.tr("Изменение требует прав администратора; TLP может восстановить свои настройки.")
            color: view.sys.colMuted; font { family: view.sys.fontFam; pixelSize: 10 }
        }
    }
}
