import QtQuick
import QtQuick.Layouts

// «Сохранить пароль?» — предложение, которое пилюля показывает, заметив
// в буфере обмена строку, похожую на пароль.
FocusScope {
    id: view
    property var sys

    readonly property var prompt: sys.vaultPrompt

    implicitHeight: col.implicitHeight

    Component.onCompleted: view.forceActiveFocus()
    FocusGrabber { target: view.sys.vaultUnlocked ? name : pw }

    Keys.onEscapePressed: view.sys.dismissVaultPrompt()

    function save() {
        if (!view.prompt) return;
        view.sys.vaultAdd(name.text.length ? name.text : view.sys.tr("Без названия"),
                          login.text, view.prompt.pw);
        view.sys.vaultPrompt = null;
        view.sys.collapse();
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 13

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 12
                color: Qt.rgba(0.23, 0.51, 0.96, 0.16)
                Glyph {
                    anchors.fill: parent
                    glyph: String.fromCodePoint(0xF0306)          // ключ
                    color: view.sys.colOn
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize + 2
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: view.sys.tr("Сохранить пароль?")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: view.sys.vaultUnlocked
                          ? view.sys.tr("Он попадёт в менеджер паролей")
                          : view.sys.tr("Сначала откройте хранилище своим паролем")
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }
        }

        // ------------------------------------- хранилище закрыто: просим пароль
        Rectangle {
            visible: !view.sys.vaultUnlocked
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: pw.activeFocus ? view.sys.colOn : view.sys.colLine

            TextInput {
                id: pw
                anchors.fill: parent
                anchors.leftMargin: 13
                anchors.rightMargin: 13
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: view.sys.colFg
                selectByMouse: true
                enabled: !view.sys.vaultBusy
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                onAccepted: { view.sys.unlockVault(text); text = ""; }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pw.text.length === 0
                    text: view.sys.tr("Пароль пользователя")
                    color: Qt.rgba(1, 1, 1, 0.28)
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                }
            }
        }

        Text {
            visible: !view.sys.vaultUnlocked && view.sys.vaultError.length > 0
            Layout.fillWidth: true
            text: view.sys.vaultError
            color: view.sys.colCrit
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
        }

        // --------------------------------------------- хранилище открыто: поля
        RowLayout {
            visible: view.sys.vaultUnlocked
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 11
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: name.activeFocus ? view.sys.colOn : view.sys.colLine
                TextInput {
                    id: name
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: view.sys.colFg
                    selectByMouse: true
                    text: view.prompt ? String(view.prompt.label || "") : ""
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    onAccepted: view.save()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: name.text.length === 0
                        text: view.sys.tr("Откуда пароль")
                        color: Qt.rgba(1, 1, 1, 0.28)
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 11
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: login.activeFocus ? view.sys.colOn : view.sys.colLine
                TextInput {
                    id: login
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: view.sys.colFg
                    selectByMouse: true
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    onAccepted: view.save()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: login.text.length === 0
                        text: view.sys.tr("Логин (необязательно)")
                        color: Qt.rgba(1, 1, 1, 0.28)
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    }
                }
            }
        }

        // сам пароль показываем только точками — на случай чужих глаз рядом
        Text {
            Layout.fillWidth: true
            text: view.prompt ? "•".repeat(Math.min(24, String(view.prompt.pw).length)) : ""
            color: view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 11
                color: noMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
                Text {
                    anchors.centerIn: parent
                    text: view.sys.tr("Не сохранять")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                }
                MouseArea {
                    id: noMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.dismissVaultPrompt()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 11
                enabled: view.sys.vaultUnlocked
                opacity: view.sys.vaultUnlocked ? 1 : 0.4
                color: yesMa.containsMouse ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.30)
                                           : Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.17)
                Text {
                    anchors.centerIn: parent
                    text: view.sys.tr("Сохранить")
                    color: view.sys.colOk
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                }
                MouseArea {
                    id: yesMa
                    anchors.fill: parent
                    enabled: view.sys.vaultUnlocked
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.save()
                }
            }
        }
    }
}
