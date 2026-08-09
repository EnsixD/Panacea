import QtQuick

// Вогнутый угол примыкания к кромке экрана — как у выреза на macOS.
//
// Заливка занимает квадрат r×r, из которого вырезана четверть круга
// с центром в нижнем внешнем углу. Получается плавный переход от
// верхней кромки экрана к боку пилюли, без «ступеньки».
Canvas {
    id: corner

    // "left"  — угол слева от пилюли (выемка смотрит влево-вниз)
    // "right" — зеркально
    property string side: "left"
    property color fill: "#000000"
    property real r: 12

    width: r
    height: r

    onFillChanged: requestPaint()
    onRChanged: requestPaint()
    onSideChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = corner.fill;
        ctx.beginPath();

        if (side === "left") {
            // центр выреза — в точке (0, r): нижний внешний угол
            ctx.moveTo(0, 0);
            ctx.lineTo(r, 0);
            ctx.lineTo(r, r);
            ctx.arc(0, r, r, 0, -Math.PI / 2, true);
        } else {
            // зеркально: центр выреза в (r, r)
            ctx.moveTo(r, 0);
            ctx.lineTo(0, 0);
            ctx.lineTo(0, r);
            ctx.arc(r, r, r, Math.PI, -Math.PI / 2, false);
        }

        ctx.closePath();
        ctx.fill();
    }
}
