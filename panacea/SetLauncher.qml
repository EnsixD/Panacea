import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

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

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Launchpad")
            sub: page.sys.tr("Все приложения сеткой на весь экран, с папками. Приложение на приложение — новая папка.")
            on: page.sys.cfg.featLaunchpad
            onToggled: v => { page.sys.cfg.featLaunchpad = v; page.sys.saveCfg(); }
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
            label: page.sys.tr("Обои")
            on: page.sys.cfg.featThemes
            onToggled: v => { page.sys.cfg.featThemes = v; page.sys.saveCfg(); }
        }
    }

    // ------------------------------------------------ веб-поиск и ИИ
    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Поиск в интернете и ИИ") }
        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Любой запрос можно отправить в поисковик последней строкой списка. Если подключить ИИ, запрос с «?» в начале уйдёт ему, и короткий ответ появится прямо в лаунчере.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
        SetPick {
            sys: page.sys
            label: page.sys.tr("Поисковик")
            options: [
                { id: "duckduckgo", text: "DuckDuckGo" },
                { id: "google", text: "Google" },
                { id: "bing", text: "Bing" },
                { id: "brave", text: "Brave" },
                { id: "yandex", text: "Yandex" }
            ]
            value: page.sys.cfg.searchEngine
            onPicked: id => { page.sys.cfg.searchEngine = id; page.sys.saveCfg(); }
        }

        component Field: TextField {
            Layout.fillWidth: true
            color: page.sys.colFg
            placeholderTextColor: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
            leftPadding: 12; rightPadding: 12; topPadding: 9; bottomPadding: 9
            selectByMouse: true
            background: Rectangle {
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: parent.activeFocus ? page.sys.colOn : page.sys.colLine
            }
        }
        Text {
            Layout.fillWidth: true
            text: page.sys.tr("ИИ подключается по желанию: подойдёт любой OpenAI-совместимый сервис — OpenAI, OpenRouter, Groq или локальная Ollama (http://localhost:11434/v1). Пока адрес пуст, «?» в лаунчере ищет как обычно.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
        Field {
            placeholderText: page.sys.tr("Адрес API, например https://api.openai.com/v1")
            text: page.sys.cfg.aiUrl
            onEditingFinished: { page.sys.cfg.aiUrl = text.trim(); page.sys.saveCfg(); }
        }
        Field {
            placeholderText: page.sys.tr("Модель")
            text: page.sys.cfg.aiModel
            onEditingFinished: { page.sys.cfg.aiModel = text.trim(); page.sys.saveCfg(); }
        }
        Field {
            placeholderText: page.sys.tr("Ключ API (для локальных моделей не нужен)")
            echoMode: TextInput.Password
            text: page.sys.cfg.aiKey
            onEditingFinished: { page.sys.cfg.aiKey = text.trim(); page.sys.saveCfg(); }
        }
    }
}
