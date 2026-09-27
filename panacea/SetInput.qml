import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Мышь. Скоростью указателя и разгоном распоряжается libinput через
// компоновщик, а не оболочка, — поэтому здесь только две ручки, зато те
// самые, за которыми обычно лезут в конфиг руками.
//
// Keyboard layouts are stored in settings.json and generated into Hyprland's
// configuration so they survive shell updates.
ColumnLayout {
    id: page

    property var sys

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys
        visible: Compositor.isHyprland

        SetLabel { sys: page.sys; text: page.sys.tr("Раскладки клавиатуры") }
        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Коды XKB через запятую, например us,tr. Сочетания клавиш меняются отдельно по Super+/.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
        TextField {
            id: layoutsField
            Layout.fillWidth: true
            placeholderText: "us,tr"
            text: page.sys.cfg.keyboardLayouts
            color: page.sys.colFg
            placeholderTextColor: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
        }
        TextField {
            id: variantsField
            Layout.fillWidth: true
            placeholderText: page.sys.tr("Варианты (пустые — по умолчанию)")
            text: page.sys.cfg.keyboardVariants
            color: page.sys.colFg
            placeholderTextColor: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
        }
        TextField {
            id: optionsField
            Layout.fillWidth: true
            placeholderText: "grp:alt_shift_toggle"
            text: page.sys.cfg.keyboardOptions
            color: page.sys.colFg
            placeholderTextColor: page.sys.colMuted
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
        }
        Text {
            Layout.fillWidth: true
            visible: page.sys.keyboardInputError.length > 0
            text: page.sys.keyboardInputError
            color: page.sys.colCrit
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
        SetButton {
            sys: page.sys
            text: page.sys.tr("Применить раскладки")
            onClicked: page.sys.applyKeyboardLayouts(layoutsField.text, variantsField.text, optionsField.text)
        }
    }

    Text {
        Layout.fillWidth: true
        visible: Compositor.isNiri
        text: page.sys.tr("В Niri раскладки задаются в ~/.config/niri/config.kdl; этот файл сохраняется при обновлении.")
        color: page.sys.colMuted
        wrapMode: Text.WordWrap
        font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Указатель") }

        // Шкала libinput: -1 — самая медленная, 0 — как есть, 1 — самая
        // быстрая. Это сдвиг кривой, а не умножение, поэтому шаг мелкий и
        // ноль подписан отдельно — на него возвращаются чаще всего.
        SetSlider {
            sys: page.sys
            label: page.sys.tr("Скорость указателя")
            from: -1; to: 1; step: 0.05
            decimals: 2
            value: page.sys.cfg.mouseSens
            onMoved: v => { page.sys.cfg.mouseSens = v; page.sys.applyInput(); }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("0 — скорость как её отдаёт мышь. Влево медленнее, вправо быстрее.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Прямой ввод")
            sub: page.sys.tr("Без разгона: одно и то же движение по столу всегда даёт одно и то же расстояние по экрану. То, ради чего в играх выключают повышенную точность указателя.")
            on: page.sys.cfg.mouseRaw
            onToggled: v => { page.sys.cfg.mouseRaw = v; page.sys.applyInput(); }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Сброс") }

        SetButton {
            sys: page.sys
            text: page.sys.tr("Вернуть заводские")
            onClicked: {
                page.sys.cfg.mouseSens = 0;
                page.sys.cfg.mouseRaw = false;
                page.sys.applyInput();
            }
        }
    }
}
