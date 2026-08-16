import QtQuick

// Погодный значок точками — пара к DotText.
//
// Той же сеткой в семь рядов и теми же кружками, что и цифры: значок стоит
// с ними в одной строке, и любой другой рисунок читался бы как вставка из
// чужого набора. Размер задаётся высотой в пикселях — как у текста.
//
// Рисунки нарочно грубые. На высоте в полтора десятка пикселей подробности
// всё равно съедаются, а узнаётся погода по силуэту: облако — горб, солнце
// — круг с лучами, дождь — облако и капли под ним.
Item {
    id: ico

    // Код вида "04d" от OpenWeatherMap — день и ночь здесь не различаются:
    // луна вместо солнца на семи рядах превращается в тот же круг.
    property string code: ""
    property real size: 16
    property real gapRatio: 0.22
    property color color: "#ffffff"

    readonly property real dotSize: ico.size / (7 + 6 * ico.gapRatio)
    readonly property real gap: ico.dotSize * ico.gapRatio
    readonly property real pitch: ico.dotSize + ico.gap

    readonly property var shapes: ({
        "clear": ["000010000", "001111100", "011111110", "111111111",
                  "011111110", "001111100", "000010000"],
        "few":   ["000001110", "000011111", "000011111", "011100110",
                  "111111111", "111111111", "011111110"],
        "cloud": ["000011100", "000111110", "001111111", "011111111",
                  "111111111", "111111111", "011111110"],
        "rain":  ["000011100", "001111110", "011111111", "111111111",
                  "011111110", "010010010", "001001000"],
        "snow":  ["000011100", "001111110", "011111111", "111111111",
                  "011111110", "010101010", "001000100"],
        "storm": ["000011100", "001111110", "011111111", "111111111",
                  "011111110", "000111000", "001100000"],
        "mist":  ["000000000", "011111110", "000000000", "111111111",
                  "000000000", "011111110", "000000000"]
    })

    // Первые две цифры кода — сама погода, третья буква — время суток.
    readonly property string shapeName: {
        var k = String(ico.code).slice(0, 2);
        return k === "01" ? "clear"
             : k === "02" ? "few"
             : (k === "03" || k === "04") ? "cloud"
             : (k === "09" || k === "10") ? "rain"
             : k === "11" ? "storm"
             : k === "13" ? "snow"
             : k === "50" ? "mist"
             // Незнакомый код — облако: сервис завёл новый вид погоды, и
             // облако врёт меньше, чем пустое место или солнце.
             : "cloud";
    }

    readonly property var grid: ico.shapes[ico.shapeName]

    readonly property var cells: {
        var out = [];
        var g = ico.grid;
        if (!g) return out;
        for (var r = 0; r < g.length; r++)
            for (var c = 0; c < g[r].length; c++)
                if (g[r][c] === "1")
                    out.push({ x: c * ico.pitch, y: r * ico.pitch });
        return out;
    }

    implicitWidth: (ico.grid ? ico.grid[0].length : 9) * ico.pitch - ico.gap
    implicitHeight: 7 * ico.pitch - ico.gap

    Repeater {
        model: ico.cells

        Rectangle {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: ico.dotSize
            height: ico.dotSize
            radius: ico.dotSize / 2
            color: ico.color
        }
    }
}
