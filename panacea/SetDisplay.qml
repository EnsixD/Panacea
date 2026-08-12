import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Display. Схемы расположения экранов здесь нет намеренно: её двигают мышью
// на самом рабочем столе, а сюда приходят за цифрами — разрешением, частотой
// и масштабом. Настройки применяются к одному экрану сразу, без общей кнопки:
// иначе непонятно, что именно применится.
ColumnLayout {
    id: page

    property var sys

    // [{ name, desc, w, h, rr, scale, transform, vrr, disabled, modes: [] }]
    property var mons: []

    Layout.fillWidth: true
    spacing: 12

    Component.onCompleted: pMons.running = true

    Process {
        id: pMons
        command: ["sh", "-c", "hyprctl -j monitors all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var raw = JSON.parse(text);
                    page.mons = raw.map(m => ({
                        name: m.name,
                        desc: m.description || "",
                        w: m.width, h: m.height,
                        rr: m.refreshRate,
                        scale: m.scale,
                        transform: m.transform,
                        vrr: !!m.vrr,
                        disabled: !!m.disabled,
                        modes: m.availableModes || []
                    }));
                } catch (e) {
                    page.mons = [];
                }
            }
        }
    }

    Process { id: pApply; property string args: ""; command: ["sh", "-c", pApply.args] }

    // hyprctl keyword monitor NAME,ШИРИНАxВЫСОТА@ЧАСТОТА,POS,МАСШТАБ,…
    // Позицию не трогаем: её задаёт раскладка экранов, и подставлять сюда
    // «auto» значило бы каждый раз пересобирать расположение заново.
    function apply(m, over) {
        var w  = over.w  !== undefined ? over.w  : m.w;
        var h  = over.h  !== undefined ? over.h  : m.h;
        var rr = over.rr !== undefined ? over.rr : m.rr;
        var sc = over.scale !== undefined ? over.scale : m.scale;
        var tr = over.transform !== undefined ? over.transform : m.transform;
        var vrr = over.vrr !== undefined ? over.vrr : m.vrr;
        var off = over.disabled !== undefined ? over.disabled : m.disabled;

        var line = off
            ? m.name + ",disable"
            : m.name + "," + w + "x" + h + "@" + Number(rr).toFixed(2)
              + ",auto," + Number(sc).toFixed(6)
              + ",transform," + tr + ",vrr," + (vrr ? 1 : 0);

        pApply.args = "hyprctl keyword monitor '" + line + "'";
        pApply.running = true;
        reload.restart();
    }
    Timer { id: reload; interval: 700; onTriggered: pMons.running = true }

    // разрешения и частоты вытаскиваем из списка режимов «1920x1080@144.00Hz»
    function resList(m) {
        var seen = {}, out = [];
        (m.modes || []).forEach(s => {
            var r = s.split("@")[0];
            if (!seen[r]) { seen[r] = true; out.push(r); }
        });
        if (!out.length) out.push(m.w + "x" + m.h);
        return out;
    }
    function rrList(m, res) {
        var out = [];
        (m.modes || []).forEach(s => {
            var p = s.split("@");
            if (p[0] !== res) return;
            var hz = parseFloat(p[1]);
            if (out.indexOf(hz) < 0) out.push(hz);
        });
        if (!out.length) out.push(m.rr);
        return out.sort((a, b) => b - a);
    }

    Text {
        Layout.fillWidth: true
        visible: page.mons.length === 0
        text: page.sys.tr("Экраны не читаются: hyprctl не ответил.")
        color: page.sys.colMuted
        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
    }

    Repeater {
        model: page.mons

        SetCard {
            id: card
            required property var modelData
            readonly property string res: card.modelData.w + "x" + card.modelData.h

            sys: page.sys

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: card.modelData.name
                        color: page.sys.colFg
                        font { family: page.sys.fontDisplay; pixelSize: page.sys.fontSize }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: card.modelData.desc.length > 0
                        text: card.modelData.desc
                        color: page.sys.colMuted
                        elide: Text.ElideRight
                        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                    }
                }

                Text {
                    text: card.modelData.disabled
                          ? page.sys.tr("выключен")
                          : card.res + " · " + Number(card.modelData.rr).toFixed(0) + " Hz"
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                }
            }

            SetToggle {
                sys: page.sys
                label: page.sys.tr("Экран включён")
                on: !card.modelData.disabled
                onToggled: v => page.apply(card.modelData, { disabled: !v })
            }

            SetPick {
                sys: page.sys
                enabled: !card.modelData.disabled
                opacity: enabled ? 1 : 0.4
                label: page.sys.tr("Разрешение")
                options: page.resList(card.modelData)
                value: card.res
                onPicked: id => {
                    var wh = id.split("x");
                    // частота из старого режима может не поддерживаться новым
                    // разрешением — берём наибольшую доступную для него
                    var hz = page.rrList(card.modelData, id)[0];
                    page.apply(card.modelData, { w: +wh[0], h: +wh[1], rr: hz });
                }
            }

            SetPick {
                sys: page.sys
                enabled: !card.modelData.disabled
                opacity: enabled ? 1 : 0.4
                label: page.sys.tr("Частота обновления")
                options: page.rrList(card.modelData, card.res).map(hz => ({
                    id: String(hz), text: hz.toFixed(2) + " Hz"
                }))
                value: String(page.rrList(card.modelData, card.res)
                              .find(hz => Math.abs(hz - card.modelData.rr) < 0.6)
                              || card.modelData.rr)
                onPicked: id => page.apply(card.modelData, { rr: parseFloat(id) })
            }

            SetSlider {
                sys: page.sys
                enabled: !card.modelData.disabled
                opacity: enabled ? 1 : 0.4
                label: page.sys.tr("Масштаб")
                from: 1; to: 3; step: 0.05
                decimals: 2
                value: card.modelData.scale
                suffix: "×"
                onMoved: v => page.apply(card.modelData, { scale: v })
            }

            SetSelect {
                sys: page.sys
                enabled: !card.modelData.disabled
                opacity: enabled ? 1 : 0.4
                label: page.sys.tr("Поворот")
                options: [
                    { id: "0", text: "0°" },
                    { id: "1", text: "90°" },
                    { id: "2", text: "180°" },
                    { id: "3", text: "270°" }
                ]
                value: String(card.modelData.transform)
                onPicked: id => page.apply(card.modelData, { transform: +id })
            }

            SetToggle {
                sys: page.sys
                enabled: !card.modelData.disabled
                opacity: enabled ? 1 : 0.4
                label: page.sys.tr("Переменная частота (VRR)")
                on: card.modelData.vrr
                onToggled: v => page.apply(card.modelData, { vrr: v })
            }
        }
    }
}
