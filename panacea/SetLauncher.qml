import QtQuick
import QtQuick.Layouts

// Launcher. Сам поиск приложений плюс то, что живёт рядом с ним отдельными
// страницами: буфер обмена, менеджер паролей, обзор столов.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Поиск приложений")
            sub: page.sys.tr("Список установленного по Super+A.")
            on: page.sys.cfg.featLauncher
            onToggled: v => { page.sys.cfg.featLauncher = v; page.sys.saveCfg(); }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Соседние страницы") }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Буфер обмена")
            on: page.sys.cfg.featClipboard
            onToggled: v => { page.sys.cfg.featClipboard = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Менеджер паролей")
            on: page.sys.cfg.featVault
            onToggled: v => { page.sys.cfg.featVault = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Предлагать сохранять пароли из буфера")
            sub: page.sys.tr("Скопированный пароль можно убрать в хранилище одной кнопкой.")
            on: page.sys.cfg.vaultCapture
            onToggled: v => { page.sys.cfg.vaultCapture = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Проводник")
            on: page.sys.cfg.featFiles
            onToggled: v => { page.sys.cfg.featFiles = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Проводник отдельным окном")
            sub: page.sys.tr("Открывается окном Hyprland, а не страницей острова.")
            on: page.sys.cfg.filesWindow
            onToggled: v => { page.sys.cfg.filesWindow = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Календарь")
            on: page.sys.cfg.featCalendar
            onToggled: v => { page.sys.cfg.featCalendar = v; page.sys.saveCfg(); }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Обои и темы")
            on: page.sys.cfg.featThemes
            onToggled: v => { page.sys.cfg.featThemes = v; page.sys.saveCfg(); }
        }
    }
}
