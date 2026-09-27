import QtQuick
import QtQuick.Layouts

// Motion. Длительности живут порознь, потому что правят разное: движение
// острова, проявление цвета и отклик на наведение мешать в одну «скорость
// анимации» нельзя — от этого либо тормозит панель, либо дёргается подсветка.
ColumnLayout {
    id: page

    property var sys
    property bool detailsOpen: false

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Уменьшить анимацию")
            sub: page.sys.tr("Оболочка перестаёт двигаться совсем: длительности считаются нулевыми.")
            on: page.sys.cfg.reduceMotion
            onToggled: value => { page.sys.cfg.reduceMotion = value; page.sys.saveCfg(); }
        }

        SetButton {
            sys: page.sys
            text: page.detailsOpen ? page.sys.tr("Скрыть подробности") : page.sys.tr("Подробные настройки")
            onClicked: page.detailsOpen = !page.detailsOpen
        }

        // Ползунки при выключенном движении не прячем, а гасим: иначе
        // карточка схлопывается и настройки будто исчезают насовсем.
        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Движение (размер и положение)")
            from: 80; to: 900; step: 10
            value: page.sys.cfg.animMove
            suffix: "ms"
            onMoved: v => { page.sys.cfg.animMove = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Плавное появление и цвет")
            from: 40; to: 600; step: 10
            value: page.sys.cfg.animFade
            suffix: "ms"
            onMoved: v => { page.sys.cfg.animFade = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Реакция на наведение")
            from: 20; to: 400; step: 10
            value: page.sys.cfg.animHover
            suffix: "ms"
            onMoved: v => { page.sys.cfg.animHover = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            visible: page.detailsOpen
            enabled: !page.sys.cfg.reduceMotion
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Отскок")
            from: 0; to: 100; step: 1
            value: page.sys.cfg.animBounce
            suffix: "%"
            onMoved: v => { page.sys.cfg.animBounce = v; page.sys.saveCfg(); }
        }

        Text {
            Layout.fillWidth: true
            visible: page.detailsOpen
            text: page.sys.tr("Bounce — насколько смоделированный осциллятор перелетает цель, прежде чем осесть на ней.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }
}
