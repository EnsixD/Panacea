import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

// Экран «что нового». Показывается один раз — сразу после того, как оболочка
// перезапустилась на свежей версии, — и закрывается кнопкой. Список изменений
// кладёт update.sh в ~/.config/panacea/.whatsnew; закрытие стирает файл, и
// второй раз экран не появится.
Item {
    id: view

    property var sys
    // первая строка файла — версия, остальные — заголовки коммитов
    property var lines: []
    readonly property string version: view.lines.length ? String(view.lines[0]).substring(0, 7) : ""
    readonly property var changes: view.lines.slice(1)

    // Сколько строк поместится, чтобы окно осталось окном, а не полосой во
    // весь экран: считаем от его высоты и от того, каким шрифтом писать.
    readonly property int maxRows: Math.max(4, Math.min(14,
        Math.floor((view.height - 380) / (view.sys.fontSize + 9))))
    readonly property int fontPx: view.changes.length > 9 ? view.sys.fontSize - 3
                                                          : view.sys.fontSize - 2
    readonly property var shown: view.changes.slice(0, view.maxRows)
    readonly property int hidden: Math.max(0, view.changes.length - view.maxRows)

    anchors.fill: parent

    // клик мимо карточки не закрывает: человек должен увидеть, что изменилось,
    // и закрыть это осознанно
    MouseArea { anchors.fill: parent }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(620, parent.width - 80)
        // высота строго по содержимому: списку тесно быть не должно
        height: Math.min(body.implicitHeight + 56, parent.height - 60)
        radius: 26
        color: view.sys.colBg
        border.width: 1
        border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)

        // выезжает снизу и проявляется: тот же почерк, что у остальных окон
        opacity: 0
        transform: Translate { id: rise; y: 24 }
        Component.onCompleted: { card.opacity = 1; rise.y = 0; }
        Behavior on opacity { NumberAnimation { duration: view.sys.animMs } }

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            // ------------------------------------------------- шапка
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Image {
                    Layout.alignment: Qt.AlignHCenter
                    source: Quickshell.env("HOME") + "/.config/panacea/assets/logo-128.png"
                    sourceSize.width: 72
                    sourceSize.height: 72
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: view.sys.tr("Panacea обновлена")
                    color: view.sys.colFg
                    font { family: view.sys.fontDisplay; pixelSize: view.sys.fontSize + 8 }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: view.version.length > 0
                    text: view.sys.tr("Сборка") + " " + view.version
                    color: view.sys.colMuted
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3 }
                }
            }

            // ------------------------------------------------- изменения
            // Без прокрутки: окно растёт под список целиком. Прокрутка здесь
            // означала бы, что часть изменений человек не увидит, — а ради
            // них экран и показывают. Длинный список ужимается шрифтом, а
            // совсем длинный сворачивается в хвост «и ещё N».
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: changeCol.implicitHeight + 28
                radius: 18
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.045)

                ColumnLayout {
                    id: changeCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 7

                    Repeater {
                        model: view.shown

                        RowLayout {
                            required property string modelData
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 6
                                width: 5; height: 5; radius: 3
                                color: view.sys.colOn
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                color: view.sys.colFg
                                wrapMode: Text.WordWrap
                                font { family: view.sys.fontBody; pixelSize: view.fontPx }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        visible: view.hidden > 0
                        text: view.sys.tr("и ещё") + " " + view.hidden
                              + (view.sys.cfg.lang === "en" ? " more" : "")
                        color: view.sys.colMuted
                        font { family: view.sys.fontBody; pixelSize: view.fontPx - 1 }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: view.changes.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        text: view.sys.tr("Список изменений недоступен")
                        color: view.sys.colMuted
                        font { family: view.sys.fontBody; pixelSize: view.fontPx }
                    }
                }
            }

            // ------------------------------------------------- кнопка
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 14
                color: okMa.containsMouse
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.36)
                       : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.24)
                border.width: 1
                border.color: view.sys.colOn
                Behavior on color { ColorAnimation { duration: view.sys.animFade } }

                Text {
                    anchors.centerIn: parent
                    text: view.sys.tr("Хорошо")
                    color: view.sys.colFg
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize; bold: true }
                }
                MouseArea {
                    id: okMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.dismissWhatsNew()
                }
            }
        }
    }

    focus: true
    Keys.onEscapePressed: view.sys.dismissWhatsNew()
    Keys.onReturnPressed: view.sys.dismissWhatsNew()
    Component.onCompleted: forceActiveFocus()
}
