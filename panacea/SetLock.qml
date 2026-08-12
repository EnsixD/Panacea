import QtQuick
import QtQuick.Layouts

// Lock Screen. Экран блокировки видит любой, кто подойдёт к машине, поэтому
// показ медиа и уведомлений на нём — отдельные переключатели, а не часть
// общих настроек этих разделов.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Экран блокировки")
            sub: page.sys.tr("Выключить, если блокировкой занимается другая программа.")
            on: page.sys.cfg.featLock
            onToggled: v => { page.sys.cfg.featLock = v; page.sys.saveCfg(); }
        }

        SetSlider {
            sys: page.sys
            label: page.sys.tr("Размытие обоев")
            from: 0; to: 96; step: 2
            value: page.sys.cfg.lockBlur
            suffix: "px"
            onMoved: v => { page.sys.cfg.lockBlur = v; page.sys.saveCfg(); }
        }

    }


    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Подпись") }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 10
            color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.07)

            TextInput {
                id: hintInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                color: page.sys.colFg
                clip: true
                selectByMouse: true
                text: page.sys.cfg.lockHint
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                onEditingFinished: { page.sys.cfg.lockHint = text; page.sys.saveCfg(); }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: hintInput.text.length === 0
                    text: page.sys.tr("Строка под полем пароля — например, чей это компьютер")
                    color: page.sys.colMuted
                    elide: Text.ElideRight
                    font: hintInput.font
                }
            }
        }
    }
}
