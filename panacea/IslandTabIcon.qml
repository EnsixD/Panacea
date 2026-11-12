import QtQuick
import QtQuick.Shapes

Item {
    id: icon
    property string kind: "home"
    property color tint: "white"
    implicitWidth: 19
    implicitHeight: 19
    Shape {
        width: 20; height: 20
        scale: Math.min(icon.width, icon.height) / 20
        transformOrigin: Item.TopLeft
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"; strokeColor: icon.tint; strokeWidth: 1.5
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.kind === "home" ? "M 3.5 9 L 10 3.8 L 16.5 9 L 16.5 16.2 Q 16.5 17 15.7 17 L 4.3 17 Q 3.5 17 3.5 16.2 Z M 8 17 L 8 12 L 12 12 L 12 17" : "M 16.8 9.2 C 16.8 5.5 13.8 2.7 10.1 2.7 C 6.3 2.7 3.3 5.5 3.3 9.2 C 3.3 10.7 3.8 12.1 4.7 13.2 L 3.9 16.7 L 7.3 15.3 C 8.2 15.7 9.1 15.8 10.1 15.8 C 13.8 15.8 16.8 12.9 16.8 9.2 Z" }
        }
    }
}
