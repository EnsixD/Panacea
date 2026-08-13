import QtQuick
import QtQuick.Layouts

// Плагины — то, что оболочка умеет, но не навязывает. Каждый выключен по
// умолчанию и включается здесь; выключенный не создаётся вовсе, а не прячется.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Задачи") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Вторая капсула у кромки: разделы, а в них задачи по номерам. "
                              + "Раздел считается сделанным, когда отмечены все его задачи.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Включить")
            on: page.sys.cfg.todoEnabled
            onToggled: value => { page.sys.cfg.todoEnabled = value; page.sys.saveCfg(); }
        }

        SetSelect {
            sys: page.sys
            label: page.sys.tr("Кромка")
            enabled: page.sys.cfg.todoEnabled
            value: page.sys.cfg.todoPos
            options: [
                { id: "top",    text: page.sys.tr("Сверху") },
                { id: "bottom", text: page.sys.tr("Снизу") },
                { id: "left",   text: page.sys.tr("Слева") },
                { id: "right",  text: page.sys.tr("Справа") }
            ]
            onPicked: id => { page.sys.cfg.todoPos = id; page.sys.saveCfg(); }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("На одной кромке с островом блокнот встаёт рядом с ним, "
                              + "на своей — держится середины.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Ширина")
            from: 220; to: 480
            value: page.sys.cfg.todoW
            enabled: page.sys.cfg.todoEnabled
            onMoved: v => { page.sys.cfg.todoW = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Высота")
            from: 240; to: 720
            value: page.sys.cfg.todoH
            enabled: page.sys.cfg.todoEnabled
            onMoved: v => { page.sys.cfg.todoH = v; page.sys.saveCfg(); }
        }
    }
}
