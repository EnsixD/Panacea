import QtQuick
import QtQuick.Layouts

// Motion. Длительности живут порознь, потому что правят разное: движение
// острова, проявление цвета и отклик на наведение мешать в одну «скорость
// анимации» нельзя — от этого либо тормозит панель, либо дёргается подсветка.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Reduce motion")
            sub: page.sys.tr("Оболочка перестаёт двигаться совсем: длительности считаются нулевыми.")
            on: page.sys.cfg.reduceMotion
            onToggled: value => { page.sys.cfg.reduceMotion = value; page.sys.saveCfg(); }
        }

        // Ползунки при выключенном движении не прячем, а гасим: иначе
        // карточка схлопывается и настройки будто исчезают насовсем.
        SetSlider {
            sys: page.sys
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Movement (size / position)")
            from: 80; to: 900; step: 10
            value: page.sys.cfg.animMove
            suffix: "ms"
            onMoved: v => { page.sys.cfg.animMove = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Fades & colour")
            from: 40; to: 600; step: 10
            value: page.sys.cfg.animFade
            suffix: "ms"
            onMoved: v => { page.sys.cfg.animFade = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Hover response")
            from: 20; to: 400; step: 10
            value: page.sys.cfg.animHover
            suffix: "ms"
            onMoved: v => { page.sys.cfg.animHover = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Bounce")
            from: 0; to: 100; step: 1
            value: page.sys.cfg.animBounce
            suffix: "%"
            onMoved: v => { page.sys.cfg.animBounce = v; page.sys.saveCfg(); }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Bounce — насколько смоделированный осциллятор перелетает цель, прежде чем осесть на ней.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }
}
