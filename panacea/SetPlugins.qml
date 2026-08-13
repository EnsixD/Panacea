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

        SetLabel { sys: page.sys; text: page.sys.tr("Задачи на рабочем столе") }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Маленький блокнот на обоях: разделы, а в них задачи по номерам. "
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

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Поверх окон")
            sub: page.sys.tr("Иначе лежит на обоях и виден только на пустом столе.")
            enabled: page.sys.cfg.todoEnabled
            on: page.sys.cfg.todoOnTop
            onToggled: value => { page.sys.cfg.todoOnTop = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Закрепить на месте")
            sub: page.sys.tr("То же, что пипетка на самом блокноте: пока закреплён, "
                             + "его не сдвинуть мышью.")
            enabled: page.sys.cfg.todoEnabled
            on: page.sys.cfg.todoPinned
            onToggled: value => { page.sys.cfg.todoPinned = value; page.sys.saveCfg(); }
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
