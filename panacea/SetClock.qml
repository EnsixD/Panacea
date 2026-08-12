import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Clock & Date. Часовой пояс по умолчанию берётся у системы — регион нужен
// только тем, у кого он определился неверно. Дату и время меняем через
// timedatectl: сначала приходится выключить синхронизацию, иначе система
// вернёт своё через несколько секунд и правка будет выглядеть как сбой.
ColumnLayout {
    id: page

    property var sys

    // текущее состояние службы времени
    property string tzNow: ""
    property bool ntp: true
    property var zones: []
    // черновик ручной установки: "ГГГГ-ММ-ДД ЧЧ:ММ"
    property string draft: ""
    property string note: ""

    Layout.fillWidth: true
    spacing: 12

    Component.onCompleted: { pStatus.running = true; pZones.running = true; }

    Process {
        id: pStatus
        command: ["sh", "-c",
            "timedatectl show -p Timezone -p NTP --value | tr '\\n' '|'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var a = text.trim().split("|");
                page.tzNow = a[0] || "";
                page.ntp = (a[1] || "").trim() === "yes";
            }
        }
    }

    Process {
        id: pZones
        command: ["sh", "-c", "timedatectl list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: {
                var a = text.trim().split("\n").filter(x => x.length);
                if (a.length) page.zones = ["auto"].concat(a);
            }
        }
    }

    // Смена пояса и времени — операции для root, поэтому через pkexec.
    Process {
        id: pApply
        property string args: ""
        command: ["sh", "-c", pApply.args]
        onExited: code => {
            page.note = code === 0 ? page.sys.tr("Применено")
                                   : page.sys.tr("Не удалось: нужен пароль администратора");
            noteTimer.restart();
            pStatus.running = true;
        }
    }
    Timer { id: noteTimer; interval: 4000; onTriggered: page.note = "" }

    function run(cmd) { pApply.args = cmd; pApply.running = true; }

    // ------------------------------------------------------------- формат
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Формат") }

        SetSelect {
            sys: page.sys
            label: page.sys.tr("Часы")
            options: [
                { id: "24", text: "13:45" },
                { id: "12", text: "1:45 PM" }
            ]
            value: page.sys.cfg.clock12 ? "12" : "24"
            onPicked: id => { page.sys.cfg.clock12 = (id === "12"); page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Показывать секунды")
            on: page.sys.cfg.clockSeconds
            onToggled: v => { page.sys.cfg.clockSeconds = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("День недели рядом с датой")
            on: page.sys.cfg.clockWeekday
            onToggled: v => { page.sys.cfg.clockWeekday = v; page.sys.saveCfg(); }
        }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Формат даты")
            options: [
                { id: "d MMMM",      text: Qt.formatDate(new Date(), "d MMMM") },
                { id: "d MMM",       text: Qt.formatDate(new Date(), "d MMM") },
                { id: "dd.MM.yyyy",  text: Qt.formatDate(new Date(), "dd.MM.yyyy") },
                { id: "yyyy-MM-dd",  text: Qt.formatDate(new Date(), "yyyy-MM-dd") },
                { id: "MMM d, yyyy", text: Qt.formatDate(new Date(), "MMM d, yyyy") }
            ]
            value: page.sys.cfg.clockDateFmt
            onPicked: id => { page.sys.cfg.clockDateFmt = id; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- пояс
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Регион") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Синхронизировать время по сети")
            sub: page.ntp ? page.sys.tr("Время приходит с сервера времени.")
                          : page.sys.tr("Время стоит так, как выставили вручную.")
            on: page.ntp
            onToggled: v => page.run("pkexec timedatectl set-ntp " + (v ? "true" : "false"))
        }

        SetPick {
            sys: page.sys
            label: page.sys.tr("Часовой пояс")
            visibleRows: 8
            options: page.zones.length ? page.zones.map(z => ({
                id: z,
                text: z === "auto" ? page.sys.tr("Автоматически") + " · " + page.tzNow : z
            })) : []
            value: page.sys.cfg.clockTz
            onPicked: id => {
                page.sys.cfg.clockTz = id;
                page.sys.saveCfg();
                if (id !== "auto") page.run("pkexec timedatectl set-timezone " + id);
            }
        }
    }

    // ------------------------------------------------------------- вручную
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Дата и время вручную") }

        Text {
            Layout.fillWidth: true
            visible: page.ntp
            text: page.sys.tr("Пока время синхронизируется по сети, ручная правка ничего не изменит — выключите синхронизацию выше.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            enabled: !page.ntp
            opacity: enabled ? 1 : 0.4

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 10
                color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.07)

                TextInput {
                    id: stampInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    color: page.sys.colFg
                    clip: true
                    selectByMouse: true
                    text: page.draft
                    onTextChanged: page.draft = text
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                    Component.onCompleted: text = Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm")

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: stampInput.text.length === 0
                        text: "yyyy-MM-dd hh:mm"
                        color: page.sys.colMuted
                        font: stampInput.font
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 110
                Layout.preferredHeight: 32
                radius: 10
                color: setMa.containsMouse
                       ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.34)
                       : Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.22)
                border.width: 1
                border.color: page.sys.colOn
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                Text {
                    anchors.centerIn: parent
                    text: page.sys.tr("Установить")
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                }

                MouseArea {
                    id: setMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.run("pkexec timedatectl set-time '" + page.draft + "'")
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: page.note.length > 0
            text: page.note
            color: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }
}
