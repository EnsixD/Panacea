import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Запрос прав polkit прямо в пилюле.
Item {
    id: view
    property var sys

    readonly property var flow: sys.authFlow

    implicitHeight: col.implicitHeight

    focus: true
    Component.onCompleted: view.forceActiveFocus()
    FocusGrabber { target: pw }

    Keys.onEscapePressed: view.cancel()

    function submit() {
        if (!view.flow) return;
        view.flow.submit(pw.text);
        pw.text = "";
    }
    function cancel() {
        if (view.flow) view.flow.cancelAuthenticationRequest();
        view.sys.collapse();
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 12
                color: Qt.rgba(0.96, 0.62, 0.04, 0.16)
                Glyph {
                    anchors.fill: parent
                    glyph: String.fromCodePoint(0xF0BC4)      // щит с ключом
                    color: view.sys.colWarn
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize + 2
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: view.sys.tr("Требуются права")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: view.flow ? String(view.flow.message || "") : ""
                    color: view.sys.colMuted
                    wrapMode: Text.WordWrap
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }
        }

        // поле пароля
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: view.flow && view.flow.failed ? view.sys.colCrit
                        : pw.activeFocus ? Qt.rgba(1, 1, 1, 0.25)
                                         : view.sys.colLine
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 160 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 13
                anchors.rightMargin: 13
                spacing: 10

                Glyph {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    glyph: String.fromCodePoint(0xF033E)
                    color: view.sys.colMuted
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize - 3
                }

                TextField {
                    id: pw
                    Layout.fillWidth: true
                    // responseVisible=true означает, что ввод можно не скрывать
                    echoMode: (view.flow && view.flow.responseVisible) ? TextInput.Normal
                                                                       : TextInput.Password
                    placeholderText: view.flow && view.flow.inputPrompt
                                     ? String(view.flow.inputPrompt)
                                     : view.sys.tr("Пароль")
                    color: view.sys.colFg
                    placeholderTextColor: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    background: null
                    enabled: view.flow ? view.flow.isResponseRequired : false

                    Keys.onReturnPressed: view.submit()
                    Keys.onEnterPressed:  view.submit()
                    Keys.onEscapePressed: view.cancel()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: view.flow ? (view.flow.failed
                                 || String(view.flow.supplementaryMessage || "").length > 0) : false
            text: view.flow && String(view.flow.supplementaryMessage || "").length > 0
                  ? String(view.flow.supplementaryMessage)
                  : view.sys.tr("Неверный пароль")
            color: view.sys.colCrit
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 104
                Layout.preferredHeight: 34
                radius: 11
                color: cancelMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: view.sys.tr("Отмена")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
                MouseArea {
                    id: cancelMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.cancel()
                }
            }

            Rectangle {
                Layout.preferredWidth: 128
                Layout.preferredHeight: 34
                radius: 11
                color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b,
                               okMa.containsMouse ? 0.34 : 0.22)
                border.color: view.sys.colOn
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: view.sys.tr("Подтвердить")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true }
                }
                MouseArea {
                    id: okMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.submit()
                }
            }
        }
    }
}
