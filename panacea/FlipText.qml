import QtQuick

// Текст, который перелистывается при смене значения:
// старое уезжает вверх и гаснет, новое приезжает снизу.
// Ширина тоже едет плавно, чтобы соседние элементы не дёргались.
Item {
    id: ft

    property string value: ""
    property color  textColor: "#ffffff"
    property string fontFam: "monospace"
    property int    pixelSize: 15
    property bool   bold: true
    property int    dur: 190
    // Минимальная ширина: не даём пилюле дёргаться при переходе 9 -> 10
    property real   minWidth: 0

    // то, что реально нарисовано: подменяется в середине анимации
    property string shown: value

    implicitWidth: Math.max(minWidth, label.implicitWidth)
    implicitHeight: label.implicitHeight
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: ft.dur; easing.type: Easing.InOutCubic }
    }

    Text {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        text: ft.shown
        color: ft.textColor
        font { family: ft.fontFam; pixelSize: ft.pixelSize; bold: ft.bold }
    }

    onValueChanged: {
        if (value === shown) return;
        flip.restart();
    }

    SequentialAnimation {
        id: flip

        // старое значение уходит вверх
        ParallelAnimation {
            NumberAnimation {
                target: label; property: "opacity"; to: 0
                duration: Math.round(ft.dur * 0.45); easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: label; property: "y"; to: -ft.implicitHeight
                duration: Math.round(ft.dur * 0.45); easing.type: Easing.InCubic
            }
        }

        // подмена + новое значение ставится снизу, за пределами clip
        ScriptAction {
            script: {
                ft.shown = ft.value;
                label.y = ft.implicitHeight;
            }
        }

        // новое значение приезжает на место
        ParallelAnimation {
            NumberAnimation {
                target: label; property: "opacity"; to: 1
                duration: Math.round(ft.dur * 0.55); easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: label; property: "y"; to: 0
                duration: Math.round(ft.dur * 0.55); easing.type: Easing.OutCubic
            }
        }
    }
}
