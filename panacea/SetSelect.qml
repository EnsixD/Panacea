import QtQuick
import QtQuick.Layouts

// Строка выбора: подпись слева, справа — сегменты вариантов. Годится для
// коротких списков (2–4 значения); длинные лучше через SetPick.
RowLayout {
    id: sel

    property var sys
    property string label: ""
    // [{ id, text }] — id уходит в настройку, text показывается
    property var options: []
    property string value: ""
    signal picked(string id)

    Layout.fillWidth: true
    spacing: 12

    Text {
        Layout.fillWidth: true
        text: sel.label
        color: sel.sys.colFg
        elide: Text.ElideRight
        font { family: sel.sys.fontBody; pixelSize: sel.sys.fontSize - 1 }
    }

    Rectangle {
        Layout.preferredWidth: segs.implicitWidth + 6
        Layout.preferredHeight: 30
        radius: 10
        color: Qt.rgba(sel.sys.colFg.r, sel.sys.colFg.g, sel.sys.colFg.b, 0.07)

        RowLayout {
            id: segs
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: sel.options
                Rectangle {
                    id: seg
                    required property var modelData
                    readonly property bool active: sel.value === seg.modelData.id

                    Layout.preferredWidth: segText.implicitWidth + 20
                    Layout.preferredHeight: 24
                    radius: 8
                    color: seg.active
                           ? Qt.rgba(sel.sys.colOn.r, sel.sys.colOn.g, sel.sys.colOn.b, 0.30)
                           : (segMa.containsMouse
                              ? Qt.rgba(sel.sys.colFg.r, sel.sys.colFg.g, sel.sys.colFg.b, 0.08)
                              : "transparent")
                    Behavior on color { ColorAnimation { duration: sel.sys.animFade } }

                    Text {
                        id: segText
                        anchors.centerIn: parent
                        text: seg.modelData.text
                        color: seg.active ? sel.sys.colFg : sel.sys.colMuted
                        font { family: sel.sys.fontBody; pixelSize: sel.sys.fontSize - 3 }
                    }

                    MouseArea {
                        id: segMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sel.picked(seg.modelData.id)
                    }
                }
            }
        }
    }
}
