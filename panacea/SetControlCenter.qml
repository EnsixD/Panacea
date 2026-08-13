import QtQuick
import QtQuick.Layouts

// Control Center. В макете стоит сама панель, а не её рисунок: тот же
// ControlsView, только неживой. Копия рано или поздно разошлась бы с
// оригиналом — а так человек двигает ровно то, что потом увидит.
//
// Порядок хранится строкой из идентификаторов через запятую. Пустая строка
// означает «как с завода» — так сброс не приходится описывать отдельно, и
// новые блоки в будущих версиях встают на своё место сами.
ColumnLayout {
    id: page

    property var sys

    readonly property var blocks: [
        { id: "clock",   name: page.sys.tr("Часы и дата") },
        { id: "toggles", name: page.sys.tr("Wi-Fi · Bluetooth") },
        { id: "sliders", name: page.sys.tr("Громкость и яркость") },
        { id: "media",   name: page.sys.tr("Что играет") },
        { id: "power",   name: page.sys.tr("Запись и режим батареи") },
        { id: "quick",   name: page.sys.tr("Не спать и кнопки") },
        { id: "tray",    name: page.sys.tr("Системный трей") }
    ]
    readonly property var defOrder: page.blocks.map(b => b.id)

    // черновик: применяется кнопкой, чтобы панель не прыгала на каждый сдвиг
    property var order: []
    property bool dirty: false

    function load() {
        var saved = String(page.sys.cfg.ccLayout || "").split(",").filter(x => x.length);
        // Идентификаторы сверяем со списком блоков: настройка могла остаться
        // от версии, где блоков было меньше или звались они иначе.
        var out = saved.filter(id => page.defOrder.indexOf(id) >= 0);
        page.defOrder.forEach(id => { if (out.indexOf(id) < 0) out.push(id); });
        page.order = out;
        page.dirty = false;
    }
    function nameOf(id) {
        for (var i = 0; i < page.blocks.length; i++)
            if (page.blocks[i].id === id) return page.blocks[i].name;
        return id;
    }
    function move(from, to) {
        if (to < 0 || to >= page.order.length || from === to) return;
        var a = page.order.slice();
        a.splice(to, 0, a.splice(from, 1)[0]);
        page.order = a;
        page.dirty = true;
    }

    Component.onCompleted: load()

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Раскладка панели") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Возьмите блок и перетащите — панель встанет в этом порядке после «Применить».")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        // Сама панель во всю свою ширину. Если места в окне меньше, чем
        // занимает панель, макет ужимается целиком — пропорции важнее
        // натуральной величины.
        Item {
            id: stage
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            readonly property real scale: Math.min(1, width / Math.max(1, page.sys.panelW))
            implicitHeight: mock.implicitHeight * stage.scale

            ControlsView {
                id: mock
                sys: page.sys
                preview: true
                // панель слушается черновика, а не сохранённого порядка:
                // перетащил — увидел, ещё до «Применить»
                ccOrderOverride: page.order
                width: page.sys.panelW
                height: implicitHeight
                // неживая: ни одна плитка внутри не должна нажиматься
                enabled: false
                transformOrigin: Item.TopLeft
                scale: stage.scale
            }

            // Накладки поверх блоков: сама панель их не знает, двигать надо
            // здесь. Ставятся ровно по прямоугольнику своего блока.
            Repeater {
                model: page.order

                Item {
                    id: grip
                    required property int index
                    required property string modelData
                    readonly property var blk: mock.ccBlock(grip.modelData)
                    property bool held: false

                    // пока блок не построился, накладке нечего накрывать
                    visible: grip.blk !== null && grip.blk.height > 0
                    width: stage.width
                    height: grip.blk ? grip.blk.height * stage.scale : 0
                    y: grip.blk ? grip.blk.y * stage.scale : 0
                    z: grip.held ? 10 : 1

                    Behavior on y {
                        enabled: !grip.held
                        NumberAnimation { duration: page.sys.animFade; easing.type: Easing.OutCubic }
                    }

                    // Подсветка только под курсором и при переносе: иначе
                    // накладки закрасили бы панель и смотреть было бы не на что.
                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: grip.held
                               ? Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.22)
                               : (gripMa.containsMouse
                                  ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.08)
                                  : "transparent")
                        border.width: grip.held ? 1 : 0
                        border.color: page.sys.colOn
                        Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: gripMa.containsMouse || grip.held
                            text: String.fromCodePoint(0xF01DD)   // ручка перетаскивания
                            color: page.sys.colFg
                            font { family: page.sys.fontFam; pixelSize: page.sys.fontSize }
                        }
                    }

                    MouseArea {
                        id: gripMa
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: grip.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: grip
                        drag.axis: Drag.YAxis
                        drag.minimumY: 0
                        drag.maximumY: Math.max(0, stage.height - grip.height)

                        onPressed: grip.held = true
                        onReleased: {
                            grip.held = false;
                            page.move(grip.index, page.dropIndex(grip.y + grip.height / 2));
                            // Перетаскивание присвоило y напрямую и порвало
                            // привязку к месту блока. Возвращаем её: иначе
                            // накладка останется там, где её бросили.
                            grip.y = Qt.binding(() => grip.blk ? grip.blk.y * stage.scale : 0);
                        }
                    }
                }
            }
        }
    }

    // Куда попадёт блок, брошенный на высоте y: считаем по серединам самих
    // блоков, а не по равным долям — они разной высоты.
    function dropIndex(y) {
        for (var i = 0; i < page.order.length; i++) {
            var b = mock.ccBlock(page.order[i]);
            if (!b) continue;
            if (y < (b.y + b.height / 2) * mockScale()) return i;
        }
        return page.order.length - 1;
    }
    function mockScale() { return mock.scale; }

    // ------------------------------------------------------------- кнопки
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Item { Layout.fillWidth: true }

        SetButton {
            sys: page.sys
            text: page.sys.tr("Сбросить")
            onClicked: {
                page.sys.cfg.ccLayout = "";
                page.sys.saveCfg();
                page.load();
            }
        }

        SetButton {
            sys: page.sys
            text: page.sys.tr("Применить")
            primary: true
            enabled: page.dirty
            onClicked: {
                page.sys.cfg.ccLayout = page.order.join(",");
                page.sys.saveCfg();
                page.dirty = false;
            }
        }
    }
}
