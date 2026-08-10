import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// История уведомлений и режим «не беспокоить».
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onEscapePressed: view.sys.collapse()

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: view.sys.tr("Уведомления")
                color: view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 1; bold: true }
            }

            // не беспокоить
            Rectangle {
                Layout.preferredWidth: 132
                Layout.preferredHeight: 30
                radius: 10
                color: view.sys.dnd
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                       : (dndMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                border.color: view.sys.dnd ? view.sys.colOn : view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 7
                    Text {
                        text: String.fromCodePoint(view.sys.dnd ? 0xF009B : 0xF009A)
                        color: view.sys.dnd ? view.sys.colOn : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 4 }
                    }
                    Text {
                        text: view.sys.tr("Не беспокоить")
                        color: view.sys.dnd ? view.sys.colFg : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                    }
                }
                MouseArea {
                    id: dndMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.dnd = !view.sys.dnd
                }
            }

            // очистить историю
            Rectangle {
                Layout.preferredWidth: 90
                Layout.preferredHeight: 30
                radius: 10
                visible: view.sys.notifications.count > 0
                color: clearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: view.sys.tr("Очистить")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                }
                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.clearNotifications()
                }
            }
        }

        // ------------------------------------------------------ активные
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: view.sys.tr("Активные")
            color: view.sys.colMuted
            font {
                family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
            }
        }

        ListView {
            id: activeList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 200)
            clip: true
            spacing: 6
            model: view.sys.activeNotifications
            visible: count > 0
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: aRow
                required property var modelData
                width: activeList.width
                height: aInner.implicitHeight + 20
                radius: 12
                color: aMa.containsMouse ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.07)
                border.color: view.sys.colOn
                border.width: 1
                Behavior on color { ColorAnimation { duration: 140 } }

                RowLayout {
                    id: aInner
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 11

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignTop
                        radius: 9
                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                        Image {
                            anchors.fill: parent
                            anchors.margins: 5
                            source: String(aRow.modelData.image || "")
                            visible: source != ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: String(aRow.modelData.image || "") === ""
                            text: String.fromCodePoint(0xF009A)
                            color: view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 4 }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: String(aRow.modelData.summary || "")
                                color: view.sys.colFg
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                            }
                            Text {
                                text: String(aRow.modelData.appName || "")
                                color: Qt.rgba(1, 1, 1, 0.30)
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: String(aRow.modelData.body || "")
                            color: view.sys.colMuted
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignTop
                        text: "×"
                        color: aDel.containsMouse ? view.sys.colCrit : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        MouseArea {
                            id: aDel
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: aRow.modelData.dismiss()
                        }
                    }
                }

                MouseArea {
                    id: aMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: view.sys.activeNotifications.length === 0
            text: view.sys.tr("Нет активных")
            color: Qt.rgba(1, 1, 1, 0.28)
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
        }

        // ------------------------------------------------------- история
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: view.sys.tr("История")
            color: view.sys.colMuted
            font {
                family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 260)
            clip: true
            spacing: 6
            model: view.sys.notifications
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 3000

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
            }

            delegate: Rectangle {
                id: row
                required property int index
                required property int nId
                required property string nSummary
                required property string nBody
                required property string nApp
                required property string nImage
                required property bool   nUrgent
                required property string nTime

                width: list.width
                height: inner.implicitHeight + 20
                radius: 12
                color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
                border.color: row.nUrgent ? Qt.rgba(1, 0.27, 0.27, 0.35) : view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 140 } }

                RowLayout {
                    id: inner
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 11

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignTop
                        radius: 9
                        color: row.nUrgent ? Qt.rgba(1, 0.27, 0.27, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                        Image {
                            anchors.fill: parent
                            anchors.margins: 5
                            source: row.nImage
                            visible: source != ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: row.nImage === ""
                            text: String.fromCodePoint(row.nUrgent ? 0xF0026 : 0xF009A)
                            color: row.nUrgent ? view.sys.colCrit : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.iconSize - 4 }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: row.nSummary
                                color: view.sys.colFg
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                            }
                            Text {
                                text: row.nApp + "  " + row.nTime
                                color: Qt.rgba(1, 1, 1, 0.30)
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: row.nBody.length > 0
                            text: row.nBody
                            color: view.sys.colMuted
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignTop
                        text: "×"
                        color: delMa.containsMouse ? view.sys.colCrit : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.sys.forgetNotification(row.index)
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: view.sys.notifications.count === 0
            text: view.sys.dnd ? view.sys.tr("Режим «не беспокоить» включён")
                               : view.sys.tr("Пока ничего нет")
            color: view.sys.colMuted
            horizontalAlignment: Text.AlignHCenter
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }
    }
}
