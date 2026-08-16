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

    // Иконки из одного семейства Material Design и, что важнее, одной
    // весовой группы: перезагрузка и выключение существуют только штрихом,
    // поэтому замок и выход тоже взяты штриховые. Залитые силуэты рядом с
    // ними выбивались и выглядели наклеенными из другого набора.
    // Блокировка исчезает из меню, если экран блокировки выключен: жать на
    // кнопку, которая ничего не делает, хуже, чем её отсутствие.
    readonly property var actions: view.sys.cfg.featLock ? view.allActions
                                 : view.allActions.filter(a => a.id !== "lock")
    readonly property var allActions: [
        { id: "sleep", icon: "", label: view.sys.tr("Сон"),          cmd: "systemctl suspend",     accent: view.sys.tint("#38bdf8") },  // рисуется буквами, см. ниже
        // instant: срабатывает с первого нажатия. Подтверждение нужно там, где
        // ошибка стоит несохранённой работы, — выключение, перезагрузка, сон.
        // Блокировка не стоит ничего: она отменяется тем же паролем, которым
        // и снимается. Требовать на неё второе нажатие значило делать вид,
        // что кнопка не работает: первое-то не делает ничего.
        { id: "lock", instant: true, icon: String.fromCodePoint(0xF033E), label: view.sys.tr("Блокировка"), cmd: view.sys.scriptDir + "/lock.sh", accent: view.sys.tint("#a78bfa") },  // md-lock_outline
        { icon: String.fromCodePoint(0xF0343), label: view.sys.tr("Выйти"),        cmd: "out=$(hyprctl dispatch 'hl.dsp.exit()' 2>&1); "
              + "case \"$out\" in ok*) ;; *) hyprctl dispatch exit ;; esac", accent: view.sys.colWarn },  // md-logout
        { icon: String.fromCodePoint(0xF0709), label: view.sys.tr("Перезагрузка"), cmd: "systemctl reboot",      accent: view.sys.tint("#fb923c") },  // md-restart
        { icon: String.fromCodePoint(0xF0425), label: view.sys.tr("Выключить"),    cmd: "systemctl poweroff",    accent: view.sys.colCrit }   // md-power
    ]

    function trigger(i) {
        if (i < 0 || i >= actions.length) return;
        if (!actions[i].instant && view.armed !== i) {
            view.armed = i;
            view.current = i;
            disarm.restart();
            return;
        }
        disarm.stop();
        // Запускаем через корень оболочки, а не своим Process.
        //
        // setsid -f уводит команду в собственный сеанс, но этого мало:
        // строкой ниже панель закрывается, страница уничтожается, а вместе с
        // ней и её Process — до того, как команда успеет отделиться. Быстрым
        // хватало мгновения, а блокировке нет: её скрипт сперва готовит фон
        // из обоев. Со стороны это выглядело как неработающая кнопка.
        view.sys.runDetached(actions[i].cmd);
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

                        // Голый значок без круга под ним. Круг со своей
                        // заливкой, обводкой и свечением спорил с плиткой, на
                        // которой стоит: два вложенных выделения одного и того
                        // же действия. Взведённость показывает сама плитка.
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40

                            readonly property color ink: modelData.accent

                            // Сон рисуется буквами, а не глифом: у месяца в
                            // Nerd Font нет пары к остальным — он про ночь, а
                            // не про сон, и рядом с замком и стрелкой читался
                            // как погода. Три «z» треугольником говорят прямо.
                            Item {
                                anchors.fill: parent
                                visible: modelData.id === "sleep"

                                Text {
                                    x: 1; y: 15
                                    text: "Z"
                                    color: parent.parent.ink
                                    font { family: view.sys.fontBody; pixelSize: 19; bold: true }
                                }
                                Text {
                                    x: 17; y: 1
                                    text: "z"
                                    color: parent.parent.ink
                                    font { family: view.sys.fontBody; pixelSize: 10; bold: true }
                                }
                                Text {
                                    x: 24; y: 8
                                    text: "z"
                                    color: parent.parent.ink
                                    font { family: view.sys.fontBody; pixelSize: 14; bold: true }
                                }
                            }

                            Glyph {
                                anchors.fill: parent
                                visible: modelData.id !== "sleep"
                                glyph: modelData.icon
                                color: parent.ink
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize + 8
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
