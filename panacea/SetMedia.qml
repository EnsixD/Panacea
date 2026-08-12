import QtQuick
import QtQuick.Layouts

// Media. Настроек здесь немного: плеер либо есть, либо нет, а всё остальное
// — что именно он показывает в свёрнутом острове.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Плеер") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Страница медиа")
            sub: page.sys.tr("Обложка, перемотка и переключение источника звука.")
            on: page.sys.cfg.featMedia
            onToggled: v => { page.sys.cfg.featMedia = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Что играет — в свёрнутом острове")
            on: page.sys.cfg.featPlayer
            onToggled: v => { page.sys.cfg.featPlayer = v; page.sys.saveCfg(); }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Звук") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Громкость и устройства")
            on: page.sys.cfg.featAudio
            onToggled: v => { page.sys.cfg.featAudio = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Показывать всплеск при смене громкости")
            sub: page.sys.tr("Полоска поверх экрана на клавиши громкости и яркости.")
            on: page.sys.cfg.featOsd
            onToggled: v => { page.sys.cfg.featOsd = v; page.sys.saveCfg(); }
        }
    }

    // Настроек записи здесь нет намеренно: частота кадров, звук системы
    // и микрофон правятся прямо на странице записи, где их и видно во время
    // работы. Дубль в настройках только расходился бы с ней.
}
