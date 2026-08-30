import QtQuick
import QtQuick.Layouts

// Bar & Island. Главный переключатель здесь — режим выреза: от него зависит,
// примыкает остров к кромке или висит отдельной капсулой, и часть ползунков
// имеет смысл только в одном из двух состояний.
ColumnLayout {
    id: page

    property var sys
    readonly property bool notch: page.sys.cfg.notchMode

    Layout.fillWidth: true
    spacing: 12

    // ------------------------------------------------------------- форма
    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Notch mode")
            sub: page.sys.tr("Остров прилегает к кромке экрана и растекается по ней вогнутыми уголками. Выключить — станет отдельной капсулой с отступом от кромки.")
            on: page.notch
            onToggled: value => { page.sys.cfg.notchMode = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Автоскрытие")
            sub: page.sys.tr("Остров уезжает за кромку и не занимает место под себя: окна получают весь экран. Возвращается наведением на край.")
            on: page.sys.cfg.pillAutoHide
            onToggled: value => { page.sys.cfg.pillAutoHide = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Режим оверлея (Floating)")
            sub: page.sys.tr("Остров парит поверх окон без резервирования верхней строки: окна приложений не сжимаются и не прыгают при открытии или скрытии.")
            on: page.sys.cfg.pillOverlay
            onToggled: value => { page.sys.cfg.pillOverlay = value; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Закрывать окна Panacea по Super+Q")
            sub: page.sys.tr("При открытых панелях или настройках Panacea нажатие Super+Q закрывает оверлей. Выключить — Super+Q всегда закрывает активное приложение на фоне.")
            on: page.sys.cfg.closePanaceaFirst
            onToggled: value => { page.sys.cfg.closePanaceaFirst = value; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: page.notch
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Notch flare")
            from: 0; to: 32; step: 1
            value: page.sys.cfg.notchFlare
            suffix: "px"
            onMoved: v => { page.sys.cfg.notchFlare = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: !page.notch
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Edge gap")
            from: 0; to: 48; step: 1
            value: page.sys.cfg.islandGap
            suffix: "px"
            onMoved: v => { page.sys.cfg.islandGap = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            enabled: !page.notch
            opacity: enabled ? 1 : 0.4
            label: page.sys.tr("Capsule radius")
            from: 0; to: 40; step: 1
            value: page.sys.cfg.islandRadius
            // ноль читается как «скругление по половине высоты», а не как
            // прямые углы: именно так капсула и выглядит по умолчанию
            valueText: page.sys.cfg.islandRadius === 0
                       ? page.sys.tr("по высоте") : page.sys.cfg.islandRadius + " px"
            onMoved: v => { page.sys.cfg.islandRadius = v; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- размеры
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Размеры") }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Bar height")
            from: 24; to: 72; step: 1
            value: page.sys.cfg.pillH
            suffix: "px"
            onMoved: v => { page.sys.cfg.pillH = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Collapsed width")
            from: 120; to: 640; step: 4
            value: page.sys.cfg.collapsedW
            suffix: "px"
            onMoved: v => { page.sys.cfg.collapsedW = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Expanded width")
            from: 380; to: 900; step: 10
            value: page.sys.cfg.panelW
            suffix: "px"
            onMoved: v => { page.sys.cfg.panelW = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Expanded height")
            from: 260; to: 1000; step: 10
            value: page.sys.cfg.expandedH
            suffix: "px"
            onMoved: v => { page.sys.cfg.expandedH = v; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------------------- поведение
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Поведение") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Переносить остров мышью")
            sub: page.sys.tr("Остров можно взять прямо на экране и перетащить к другой кромке.")
            on: page.sys.cfg.pillDrag
            onToggled: value => { page.sys.cfg.pillDrag = value; page.sys.saveCfg(); }
        }
    }
}
