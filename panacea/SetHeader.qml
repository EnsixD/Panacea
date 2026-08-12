import QtQuick
import QtQuick.Layouts

// Шапка раздела: кружок с иконкой, название и строка о том, чем раздел
// занимается. Стоит над карточками и повторяет их скругление.
Rectangle {
    id: head

    property var sys
    property string glyph: ""
    property string title: ""
    property string sub: ""

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + 44
    radius: 18
    color: Qt.rgba(head.sys.colFg.r, head.sys.colFg.g, head.sys.colFg.b, 0.045)

    ColumnLayout {
        id: body
        anchors.centerIn: parent
        width: parent.width - 48
        spacing: 10

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 58
            height: 58
            radius: 29
            color: Qt.rgba(head.sys.colOn.r, head.sys.colOn.g, head.sys.colOn.b, 0.16)

            Text {
                anchors.centerIn: parent
                text: head.glyph
                color: head.sys.colOn
                font { family: head.sys.fontFam; pixelSize: 26 }
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: head.title
            color: head.sys.colFg
            font { family: head.sys.fontDisplay; pixelSize: head.sys.fontSize + 6 }
        }

        Text {
            Layout.fillWidth: true
            visible: head.sub.length > 0
            horizontalAlignment: Text.AlignHCenter
            text: head.sub
            color: head.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: head.sys.fontBody; pixelSize: head.sys.fontSize - 3 }
        }
    }
}
