import QtQuick
import QtQuick.Shapes

// Тот же вогнутый уголок примыкания, что и NotchCorner, но нарисованный
// геометрией, а не на Canvas.
//
// Зачем второй компонент: в макетах настроек содержимое лежит внутри
// невидимого слоя (visible: false + layer.enabled) — так работает скруглённая
// маска. Canvas в таком слое не получает запроса на отрисовку и остаётся
// пустым: уголки в макете просто не появлялись. Shape — это геометрия в графе
// сцены, ей отдельный проход рисования не нужен.
Shape {
    id: corner

    // "left"  — заливка вдоль верхней кромки и правого бока (вырез снизу слева)
    // "right" — зеркально: верх и левый бок (вырез снизу справа)
    property string side: "left"
    property color fill: "#000000"
    property real r: 12

    width: corner.r
    height: corner.r
    // Страховка: путь не должен вылезать за пределы уголка ни при каком
    // раскладе — иначе заливка расползается за пилюлю.
    clip: true
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: corner.fill
        strokeWidth: 0
        strokeColor: "transparent"

        // Обе фигуры — квадрат r×r, из которого вырезана четверть круга с
        // центром во внешнем нижнем углу.
        startX: corner.side === "left" ? 0 : corner.r
        startY: 0

        PathLine { x: corner.side === "left" ? corner.r : 0; y: 0 }
        PathLine { x: corner.side === "left" ? corner.r : 0; y: corner.r }
        PathArc {
            x: corner.side === "left" ? 0 : corner.r
            y: 0
            radiusX: corner.r
            radiusY: corner.r
            // Короткая дуга, а не длинная: экранные координаты идут вниз,
            // поэтому «внутрь квадрата» — это против часовой для левого
            // уголка и по часовой для правого. С обратным направлением
            // рисовалась дуга на 270°, и уголок превращался в широкий блок
            // за островом.
            useLargeArc: false
            direction: corner.side === "left" ? PathArc.Counterclockwise
                                              : PathArc.Clockwise
        }
    }
}
