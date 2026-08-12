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

    // Иконки из одного семейства Material Design и, что важнее, одной
    // весовой группы: перезагрузка и выключение существуют только штрихом,
    // поэтому замок и выход тоже взяты штриховые. Залитые силуэты рядом с
    // ними выбивались и выглядели наклеенными из другого набора.
    // Блокировка исчезает из меню, если экран блокировки выключен: жать на
    // кнопку, которая ничего не делает, хуже, чем её отсутствие.
    readonly property var actions: view.sys.cfg.featLock ? view.allActions
                                 : view.allActions.filter(a => a.id !== "lock")
    readonly property var allActions: [
        { icon: String.fromCodePoint(0xF0904), label: view.sys.tr("Сон"),          cmd: "systemctl suspend",     accent: "#38bdf8" },  // md-power_sleep
        { id: "lock", icon: String.fromCodePoint(0xF0341), label: view.sys.tr("Блокировка"), cmd: view.sys.scriptDir + "/lock.sh", accent: "#a78bfa" },  // md-lock_outline
        { icon: String.fromCodePoint(0xF0343), label: view.sys.tr("Выйти"),        cmd: "out=$(hyprctl dispatch 'hl.dsp.exit()' 2>&1); "
              + "case \"$out\" in ok*) ;; *) hyprctl dispatch exit ;; esac", accent: "#fbbf24" },  // md-logout
        { icon: String.fromCodePoint(0xF0709), label: view.sys.tr("Перезагрузка"), cmd: "systemctl reboot",      accent: "#fb923c" },  // md-restart
        { icon: String.fromCodePoint(0xF0425), label: view.sys.tr("Выключить"),    cmd: "systemctl poweroff",    accent: "#ef4444" }   // md-power
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
        // setsid -f: команда уходит в собственный сеанс и переживает
        // закрытие панели. Без этого Process умирал вместе со страницей
        // раньше, чем успевал сделать своё дело, — и блокировка, которой
        // на запуск нужны сотни миллисекунд, просто не срабатывала.
        pRun.command = ["setsid", "-f", "sh", "-c", actions[i].cmd];
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
                    Layout.preferredHeight: 104
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
                        id: body
                        anchors.centerIn: parent
                        spacing: 9

                        // иконка в круге своего цвета — читается лучше голого глифа
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 20
                            color: body.parent.isArmed
                                   ? modelData.accent
                                   : Qt.rgba(modelData.accent.r, modelData.accent.g,
                                             modelData.accent.b, btnMa.containsMouse ? 0.34 : 0.20)
                            border.color: Qt.rgba(modelData.accent.r, modelData.accent.g,
                                                  modelData.accent.b,
                                                  body.parent.isArmed ? 0 : 0.45)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 180 } }
                            Behavior on border.color { ColorAnimation { duration: 180 } }

                            // мягкое свечение под кругом
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 10
                                height: parent.height + 10
                                radius: width / 2
                                z: -1
                                color: Qt.rgba(modelData.accent.r, modelData.accent.g,
                                               modelData.accent.b,
                                               btnMa.containsMouse || body.parent.isArmed ? 0.10 : 0)
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }

                            Glyph {
                                anchors.fill: parent
                                glyph: modelData.icon
                                color: body.parent.isArmed ? "#0b0b0b" : modelData.accent
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize + 6
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label
                            color: body.parent.isArmed ? view.sys.colFg : view.sys.colMuted
                            font {
                                family: view.sys.fontFam
                                pixelSize: view.sys.fontSize - 4
                                bold: body.parent.isArmed
                            }
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
