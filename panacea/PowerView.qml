import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Меню питания (Super+N) в стиле пилюли.
// Первое нажатие выделяет действие, второе подтверждает — чтобы
// случайное касание не выключило машину. Escape отменяет.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    property int armed: -1          // индекс действия, ждущего подтверждения
    property int current: 0

    Timer {
        id: disarm
        interval: 2600
        onTriggered: view.armed = -1
    }

    Process { id: pRun }

    readonly property var actions: [
        { icon: "󰤄", label: view.sys.tr("Сон"),         cmd: "systemctl suspend",  accent: "#38bdf8" },
        { icon: "󰌾", label: view.sys.tr("Блокировка"),  cmd: "hyprlock",           accent: "#a78bfa" },
        { icon: "󰗽", label: view.sys.tr("Выйти"),       cmd: "hyprctl dispatch exit", accent: "#fbbf24" },
        { icon: "󰜉", label: view.sys.tr("Перезагрузка"), cmd: "systemctl reboot",   accent: "#fb923c" },
        { icon: "󰐥", label: view.sys.tr("Выключить"),   cmd: "systemctl poweroff", accent: "#ef4444" }
    ]

    function trigger(i) {
        if (i < 0 || i >= actions.length) return;
        if (view.armed !== i) {
            view.armed = i;
            view.current = i;
            disarm.restart();
            return;
        }
        disarm.stop();
        pRun.command = ["sh", "-c", actions[i].cmd];
        pRun.running = true;
        view.sys.collapse();
    }

    focus: true
    Keys.onEscapePressed: view.sys.collapse()
    Keys.onReturnPressed: trigger(current)
    Keys.onLeftPressed:  if (current > 0) { current--; armed = -1 }
    Keys.onRightPressed: if (current < actions.length - 1) { current++; armed = -1 }
    Component.onCompleted: forceActiveFocus()

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        Text {
            Layout.fillWidth: true
            text: view.armed >= 0
                  ? view.sys.tr("Ещё раз, чтобы подтвердить: ") + view.actions[view.armed].label
                  : view.sys.tr("Завершение работы")
            color: view.armed >= 0 ? view.actions[view.armed].accent : view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize; bold: true }
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 11

            Repeater {
                model: view.actions

                Rectangle {
                    required property int index
                    required property var modelData

                    readonly property bool isArmed: view.armed === index
                    readonly property bool isCurrent: view.current === index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 86
                    radius: 16

                    // база всегда нейтральная; подтверждение красит верхний слой
                    color: btnMa.containsMouse || isCurrent
                           ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)

                    // отдельный слой для подсветки подтверждения
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: modelData.accent
                        opacity: parent.isArmed ? 0.22 : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }

                    border.color: isArmed ? modelData.accent
                                : isCurrent ? Qt.rgba(1, 1, 1, 0.22)
                                            : view.sys.colLine
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    scale: btnMa.pressed ? 0.94 : (btnMa.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 7

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.icon
                            color: parent.parent.isArmed ? modelData.accent : view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.iconSize + 6 }
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label
                            color: parent.parent.isArmed ? view.sys.colFg : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                    }

                    MouseArea {
                        id: btnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: { view.current = index; view.forceActiveFocus() }
                        onClicked: view.trigger(index)
                    }
                }
            }
        }
    }
}
