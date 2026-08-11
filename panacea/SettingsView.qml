import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

// Настройки (Super+I). Две вкладки:
//   «Пилюля» — внешний вид. Правится в черновике и сразу видно в предпросмотре;
//              к настоящей пилюле применяется только по кнопке «Применить».
//   «Клавиши» — все именованные сочетания системы, меняются захватом нажатия.
Item {
    id: view
    property var sys

    // Окно не должно скакать при переключении разделов, поэтому высоту
    // держим по самому длинному — «Клавиши». Остальные просто не добирают
    // до неё, и низ остаётся пустым.
    implicitHeight: Math.max(col.implicitHeight, keysTab.implicitHeight + 52)

    property int tab: 0                 // 0 — пилюля, 1 — клавиши
    // обе вкладки раскладываются в две колонки, поэтому окно всегда широкое:
    // «Пилюля» вертикально уже не помещалась и уезжала за нижнюю кромку
    onTabChanged: view.sys.wideSettings = true

    // ------------------------------------------------------------- черновик
    // Копия оформления. Ползунки крутят её, настоящие настройки не трогаются,
    // пока не нажата «Применить» — поэтому ничего не меняется вслепую.
    QtObject {
        id: draft
        property string fontFam: "JetBrainsMono Nerd Font"
        property int    fontSize: 15
        property int    iconSize: 17
        property string colFg: "#ffffff"
        property real   mutedAlpha: 0.45
        property string colOn: "#3b82f6"
        property int    pillH: 38
        property int    panelW: 540
        property int    cornerR: 14
        property int    animMs: 230
        property string lang: "en"
        property bool   clock12: false
    }

    readonly property var appearanceKeys: [
        "fontFam", "fontSize", "iconSize", "colFg", "mutedAlpha",
        "colOn", "pillH", "panelW", "cornerR", "animMs", "lang", "clock12"
    ]

    property bool dirty: false
    function touch() { dirty = true; }

    // ------------------------------------------------- черновик сочетаний
    // Как и оформление, клавиши не применяются сразу: правки копятся здесь
    // и уезжают в Hyprland только по кнопке «Применить».
    property var bindDraft: ({})
    property int bindRev: 0          // счётчик, чтобы привязки перечитались

    function bindCombo(id) {
        bindRev;                     // зависимость для пересчёта
        var raw = bindDraft[id] !== undefined
                  ? String(bindDraft[id]) : String(view.sys.cfg["bind_" + id] || "");
        return view.prettyCombo(raw);
    }
    // Hyprland знает клавиши по именам (slash, comma, period…), а человеку
    // привычнее сам знак. Показываем знак, в настройках лежит имя.
    readonly property var keySigns: ({
        slash: "/", backslash: "\\", comma: ",", period: ".",
        semicolon: ";", apostrophe: "'", grave: "`", minus: "-", equal: "=",
        bracketleft: "[", bracketright: "]", space: "Space", delete: "Del"
    })
    function prettyCombo(raw) {
        var parts = String(raw).split("+");
        for (var i = 0; i < parts.length; i++) {
            var k = parts[i].trim();
            var sign = view.keySigns[k.toLowerCase()];
            if (sign !== undefined) parts[i] = sign;
            else parts[i] = k;
        }
        return parts.join(" + ");
    }
    function bindChanged(id) {
        bindRev;
        return bindDraft[id] !== undefined;
    }
    function setBind(id, combo) {
        bindDraft[id] = combo;
        bindRev++;
        dirty = true;
    }
    function clearBind(id) { setBind(id, ""); }
    function discardBinds() { bindDraft = ({}); bindRev++; }

    function loadDraft() {
        for (var i = 0; i < appearanceKeys.length; i++) {
            var k = appearanceKeys[i];
            draft[k] = view.sys.cfg[k];
        }
        discardBinds();
        dirty = false;
    }
    function applyDraft() {
        for (var i = 0; i < appearanceKeys.length; i++) {
            var k = appearanceKeys[i];
            view.sys.cfg[k] = draft[k];
        }
        var touched = false;
        for (var id in bindDraft) {
            view.sys.cfg["bind_" + id] = bindDraft[id];
            touched = true;
        }
        discardBinds();
        // applyBinds сам сохраняет настройки и пересобирает binds_data.lua
        if (touched) view.sys.applyBinds();
        else         view.sys.saveCfg();
        dirty = false;
    }
    function resetDraft() {
        draft.fontFam = "JetBrainsMono Nerd Font";
        draft.fontSize = 15; draft.iconSize = 17;
        draft.colFg = "#ffffff"; draft.mutedAlpha = 0.45; draft.colOn = "#3b82f6";
        draft.pillH = 38; draft.panelW = 540; draft.cornerR = 14; draft.animMs = 230;
        draft.lang = "en"; draft.clock12 = false;
        // клавиши тоже возвращаем к заводским, а не просто отменяем правки
        var o = {};
        var def = view.sys.defaultBinds;
        for (var id in def) {
            if (String(view.sys.cfg["bind_" + id] || "") !== def[id]) o[id] = def[id];
        }
        bindDraft = o;
        bindRev++;
        dirty = true;
    }

    Component.onCompleted: { loadDraft(); view.sys.wideSettings = true; forceActiveFocus(); }
    Component.onDestruction: {
        view.sys.tipText = "";
        // не оставляем систему без горячих клавиш и не запоминаем широкий режим
        if (capturingKey.length) grabKeys(false);
        view.sys.wideSettings = false;
    }

    // ----------------------------------------------------------- о системе
    // Одним вызовом sh: десять отдельных процессов ради восьми строчек — это
    // десять fork'ов на каждое открытие настроек.
    property string osName: ""
    property string kernel: ""
    property string wm: ""
    property string shellVer: ""
    property string cpu: ""
    property string ram: ""
    property string uptime: ""
    property string screenInfo: view.sys.screen
        ? view.sys.screen.width + "×" + view.sys.screen.height
          + " · " + Math.round(view.sys.screen.refreshRate) + " Hz"
        : ""

    Process {
        id: pInfo
        command: ["sh", "-c",
            ". /etc/os-release 2>/dev/null; echo \"${PRETTY_NAME:-Linux}\"; " +
            "uname -r; " +
            "(hyprctl version 2>/dev/null | head -1 | awk '{print $1, $2}') || echo Hyprland; " +
            "(qs --version 2>/dev/null | head -1) || echo quickshell; " +
            "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//' " +
            "  || grep -m1 'Model' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//'; " +
            "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} " +
            "  END{printf \"%.1f / %.1f GiB\", (t-a)/1048576, t/1048576}' /proc/meminfo; " +
            "awk '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60); " +
            "  if (d>0) printf \"%dd %dh %dm\", d, h, m; " +
            "  else if (h>0) printf \"%dh %dm\", h, m; else printf \"%dm\", m}' /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n");
                view.osName   = (l[0] || "").trim();
                view.kernel   = (l[1] || "").trim();
                view.wm       = (l[2] || "").trim();
                view.shellVer = (l[3] || "").trim();
                view.cpu      = (l[4] || "").trim();
                view.ram      = (l[5] || "").trim();
                view.uptime   = (l[6] || "").trim();
            }
        }
    }
    // аптайм и занятая память живут своей жизнью — обновляем, пока открыто
    Timer {
        interval: 20000
        running: view.tab === 3
        repeat: true
        triggeredOnStart: true
        onTriggered: { pInfo.running = false; pInfo.running = true; }
    }

    Process { id: pLink }
    function openLink(url) {
        pLink.command = ["sh", "-c", "xdg-open \"$1\" >/dev/null 2>&1 &", "_", url];
        pLink.running = true;
    }

    // ------------------------------------------------------ захват сочетания
    property string capturingKey: ""

    // Что уже нажато прямо сейчас — показывается в строке по мере набора.
    property bool  mMeta:  false
    property bool  mCtrl:  false
    property bool  mAlt:   false
    property bool  mShift: false
    property string pendingName: ""

    readonly property string capturePreview: {
        var m = [];
        if (mMeta)  m.push("SUPER");
        if (mCtrl)  m.push("CTRL");
        if (mAlt)   m.push("ALT");
        if (mShift) m.push("SHIFT");
        if (pendingName.length) m.push(pendingName);
        return m.join(" + ");
    }

    // Пока идёт захват, Hyprland уводится в пустой submap: иначе нажатие
    // срабатывало как уже существующее сочетание и до панели не доходило.
    Process { id: pCapture }
    function grabKeys(on) {
        // Перезапускаем явно: присвоение command работающему Process
        // не вступает в силу, и следующий вход в submap молча пропадал.
        pCapture.running = false;
        pCapture.command = ["sh", "-c",
            view.sys.scriptDir + "/capture.sh " + (on ? "on" : "off")];
        pCapture.running = true;
    }

    function clearHeld() {
        mMeta = false; mCtrl = false; mAlt = false; mShift = false;
        pendingName = "";
    }

    function startCapture(key) {
        capturingKey = key;
        clearHeld();
        forceActiveFocus();
        grabKeys(true);
        captureTimeout.restart();
    }
    function stopCapture() {
        if (capturingKey.length === 0) return;   // уже остановлен
        capturingKey = "";
        clearHeld();
        captureTimeout.stop();
        grabKeys(false);
    }

    // страховка: не оставлять систему без горячих клавиш
    Timer {
        id: captureTimeout
        interval: 8000
        onTriggered: view.stopCapture()
    }

    Connections {
        target: view.sys
        // приходит из capture.sh off; если захват уже снят — ничего не делаем
        function onCancelCaptureRequested() {
            if (view.capturingKey.length) view.stopCapture();
        }
    }

    readonly property var modKeys: [
        Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr,
        Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_CapsLock
    ]

    function isMeta(k)  { return k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R; }
    function isCtrl(k)  { return k === Qt.Key_Control; }
    function isAlt(k)   { return k === Qt.Key_Alt || k === Qt.Key_AltGr; }
    function isShift(k) { return k === Qt.Key_Shift; }

    // Имя обычной клавиши в терминах Hyprland
    function keyName(k) {
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k);
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F12) return "F" + (k - Qt.Key_F1 + 1);
        switch (k) {
            case Qt.Key_Space:  return "Space";
            case Qt.Key_Return:
            case Qt.Key_Enter:  return "Return";
            case Qt.Key_Tab:    return "Tab";
            case Qt.Key_Left:   return "left";
            case Qt.Key_Right:  return "right";
            case Qt.Key_Up:     return "up";
            case Qt.Key_Down:   return "down";
            case Qt.Key_Comma:  return "comma";
            case Qt.Key_Period: return "period";
            case Qt.Key_Slash:  return "slash";
            case Qt.Key_Minus:  return "minus";
            case Qt.Key_Equal:  return "equal";
            case Qt.Key_BracketLeft:  return "bracketleft";
            case Qt.Key_BracketRight: return "bracketright";
            case Qt.Key_Semicolon:    return "semicolon";
            case Qt.Key_Apostrophe:   return "apostrophe";
            case Qt.Key_Backslash:    return "backslash";
            case Qt.Key_Delete:       return "delete";
            case Qt.Key_Insert:       return "insert";
            case Qt.Key_Home:         return "home";
            case Qt.Key_End:          return "end";
            case Qt.Key_PageUp:       return "Page_Up";
            case Qt.Key_PageDown:     return "Page_Down";
            case Qt.Key_Backspace:    return "BackSpace";
            case Qt.Key_Print:        return "Print";
            case Qt.Key_Pause:        return "Pause";
            case Qt.Key_Menu:         return "Menu";
        }
        return "";
    }

    focus: true

    Keys.onPressed: event => {
        if (capturingKey.length === 0) {
            if (event.key === Qt.Key_Escape) { view.sys.collapse(); event.accepted = true; }
            return;
        }
        event.accepted = true;
        captureTimeout.restart();

        if (event.key === Qt.Key_Escape) { stopCapture(); return; }

        // Модификаторы отмечаем сразу — они появляются в строке по мере нажатия.
        // Qt в событии самого модификатора его ещё не показывает, поэтому
        // смотрим и на код клавиши, и на маску.
        mMeta  = mMeta  || isMeta(event.key)  || (event.modifiers & Qt.MetaModifier)    !== 0;
        mCtrl  = mCtrl  || isCtrl(event.key)  || (event.modifiers & Qt.ControlModifier) !== 0;
        mAlt   = mAlt   || isAlt(event.key)   || (event.modifiers & Qt.AltModifier)     !== 0;
        mShift = mShift || isShift(event.key) || (event.modifiers & Qt.ShiftModifier)   !== 0;

        if (modKeys.indexOf(event.key) >= 0) return;   // ждём настоящую клавишу

        var n = keyName(event.key);
        if (n.length === 0) return;
        pendingName = n;

        // сочетание собрано — запоминаем в черновик, применится по «Применить»
        var target = capturingKey;
        var combo = capturePreview;
        stopCapture();
        view.setBind(target, combo);
    }

    Keys.onReleased: event => {
        if (capturingKey.length === 0) return;
        event.accepted = true;
        if (isMeta(event.key))  mMeta = false;
        if (isCtrl(event.key))  mCtrl = false;
        if (isAlt(event.key))   mAlt = false;
        if (isShift(event.key)) mShift = false;
    }

    // ------------------------------------------------------ общие компоненты

    component Section: Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        color: view.sys.colMuted
        font {
            family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
            bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
        }
    }

    component SliderRow: RowLayout {
        id: srow
        property string label: ""
        property int from: 0
        property int to: 100
        property int value: 0
        property string suffix: ""
        signal moved(int v)

        Layout.fillWidth: true
        spacing: 14

        Text {
            Layout.preferredWidth: 150
            text: srow.label
            color: view.sys.colFg
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
        }

        // Свой ползунок вместо QtQuick.Controls.Slider.
        // У штатного при быстром движении терялось событие отпускания, и
        // ручка продолжала ехать за курсором с уже отпущенной кнопкой.
        // Здесь positionChanged у MouseArea без hoverEnabled приходит ТОЛЬКО
        // пока кнопка зажата, поэтому такое невозможно в принципе.
        Item {
            id: sl
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            implicitHeight: 26

            readonly property real span: Math.max(1, srow.to - srow.from)
            readonly property real pos:
                Math.max(0, Math.min(1, (srow.value - srow.from) / span))
            readonly property real usable: width - knob.width

            function setFromX(x) {
                var r = Math.max(0, Math.min(1, (x - knob.width / 2) / Math.max(1, usable)));
                srow.moved(Math.round(srow.from + r * span));
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: knob.width / 2
                width: parent.usable
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.12)

                Rectangle {
                    width: parent.width * sl.pos
                    height: parent.height
                    radius: 3
                    color: view.sys.colOn
                }
            }

            Rectangle {
                id: knob
                width: 18; height: 18; radius: 9
                anchors.verticalCenter: parent.verticalCenter
                x: sl.pos * sl.usable
                color: "#ffffff"
                scale: drag.pressed ? 1.25 : (drag.containsMouse ? 1.1 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
            }

            MouseArea {
                id: drag
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => sl.setFromX(mouse.x)
                onPositionChanged: mouse => { if (pressed) sl.setFromX(mouse.x); }
            }
        }

        Text {
            Layout.preferredWidth: 50
            horizontalAlignment: Text.AlignRight
            text: srow.value + srow.suffix
            color: view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }
    }

    component Swatch: Rectangle {
        id: sw
        property string hex: "#ffffff"
        property bool picked: false
        signal chosen()

        width: 30; height: 30; radius: 15
        color: sw.hex
        border.color: sw.picked ? "#ffffff" : Qt.rgba(1, 1, 1, 0.25)
        border.width: sw.picked ? 3 : 1
        scale: swMa.pressed ? 0.88 : (swMa.containsMouse ? 1.12 : 1.0)
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        MouseArea {
            id: swMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.chosen()
        }
    }

    // Строка сочетания: клик — захват, × — убрать
    component BindRow: RowLayout {
        id: brow
        property string bindId: ""
        property string label: ""
        readonly property bool capturing: view.capturingKey === brow.bindId
        readonly property string combo: view.bindCombo(brow.bindId)
        readonly property bool edited: view.bindChanged(brow.bindId)

        Layout.fillWidth: true
        spacing: 14

        Rectangle {
            id: box
            Layout.preferredWidth: 176
            Layout.preferredHeight: 32
            radius: 9
            color: brow.capturing
                   ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                   : (bMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07))
            border.color: brow.capturing ? view.sys.colOn : view.sys.colLine
            border.width: 1
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

            SequentialAnimation {
                running: brow.capturing
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { target: box; property: "opacity"; to: 0.45; duration: 520 }
                NumberAnimation { target: box; property: "opacity"; to: 1.0;  duration: 520 }
            }

            Text {
                anchors.centerIn: parent
                // во время захвата показываем то, что уже нажато
                text: brow.capturing
                      ? (view.capturePreview.length ? view.capturePreview
                                                    : view.sys.tr("Нажмите сочетание…"))
                      : (brow.combo.length ? brow.combo : "—")
                color: brow.combo.length || brow.capturing ? view.sys.colFg : view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true }
            }

            // точка-отметка: сочетание изменено, но ещё не применено
            Rectangle {
                width: 6; height: 6; radius: 3
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 5
                visible: brow.edited
                color: view.sys.colOk
            }

            MouseArea {
                id: bMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.startCapture(brow.bindId)
            }
        }

        Text {
            Layout.fillWidth: true
            text: brow.label
            color: view.sys.colMuted
            elide: Text.ElideRight
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }

        Text {
            text: "×"
            visible: brow.combo.length > 0
            color: cMa.containsMouse ? view.sys.colCrit : view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 2 }
            Behavior on color { ColorAnimation { duration: 150 } }
            MouseArea {
                id: cMa
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.clearBind(brow.bindId)
            }
        }
    }

    // Справочная строка для несменяемых сочетаний
    component InfoRow: RowLayout {
        id: irow
        property string keys: ""
        property string label: ""
        Layout.fillWidth: true
        spacing: 14
        Text {
            Layout.preferredWidth: 176
            text: irow.keys
            color: view.sys.colMuted
            horizontalAlignment: Text.AlignHCenter
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
        }
        Text {
            Layout.fillWidth: true
            text: irow.label
            color: Qt.rgba(1, 1, 1, 0.32)
            elide: Text.ElideRight
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
        }
    }

    // Строка-переключатель: подпись слева, тумблер справа. Действует сразу —
    // такие настройки не про оформление, ждать «Применить» им незачем.
    component Toggle: RowLayout {
        property string label: ""
        property bool on: false
        signal toggled()

        Layout.fillWidth: true
        spacing: 14

        Text {
            Layout.fillWidth: true
            text: parent.label
            color: view.sys.colFg
            wrapMode: Text.WordWrap
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
        }
        Rectangle {
            Layout.preferredWidth: 46
            Layout.preferredHeight: 26
            radius: 13
            color: parent.on
                   ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.55)
                   : Qt.rgba(1, 1, 1, 0.10)
            Behavior on color { ColorAnimation { duration: 160 } }
            Rectangle {
                width: 20; height: 20; radius: 10
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
                x: parent.parent.on ? parent.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.toggled()
            }
        }
    }

    // Строка «ключ — значение» для раздела «О системе»
    component AboutRow: RowLayout {
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        spacing: 12
        visible: value.length > 0

        Text {
            Layout.preferredWidth: 120
            text: parent.label
            color: view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
        }
        Text {
            Layout.fillWidth: true
            text: parent.value
            color: view.sys.colFg
            elide: Text.ElideRight
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
        }
    }

    // ------------------------------------------------------------ содержимое
    // Слева — разделы, справа — сам раздел. Вкладок стало четыре, полосой
    // сверху они уже не помещались, а список слева читается сразу целиком.
    RowLayout {
        id: col
        width: parent.width
        // высоту задаём явно: иначе строка сжимается по содержимому и
        // разделительная черта не доходит до нижнего края окна
        height: view.implicitHeight
        spacing: 18

        // Полоса ровно по иконкам. Подпись при наведении рисует корень
        // (sys.showTip): собственный тултип обрезался краем капсулы, а
        // выехавший вправо тонул под колонкой с содержимым.
        ColumnLayout {
            // все три размера жёстко: иначе на широкой вкладке «Клавиши»
            // раскладке не хватало места и она ужимала полосу до минимума,
            // а на узких — отпускала обратно
            Layout.preferredWidth: 40
            Layout.minimumWidth: 40
            Layout.maximumWidth: 40
            Layout.alignment: Qt.AlignTop
            spacing: 4

            Repeater {
                model: [
                    { t: view.sys.tr("Пилюля"),   g: 0xF12E1 },
                    { t: view.sys.tr("Система"),  g: 0xF0493 },
                    { t: view.sys.tr("Клавиши"),  g: 0xF030C },
                    { t: view.sys.tr("О системе"), g: 0xF02FD }
                ]
                Rectangle {
                    id: navBtn
                    required property int index
                    required property var modelData
                    readonly property bool active: view.tab === navBtn.index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 12
                    color: navBtn.active
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                           : (navMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : "transparent")
                    border.color: navBtn.active
                                  ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45)
                                  : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    Glyph {
                        anchors.fill: parent
                        glyph: String.fromCodePoint(navBtn.modelData.g)
                        color: navBtn.active ? view.sys.colFg
                             : navMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize
                    }

                    MouseArea {
                        id: navMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.tab = navBtn.index
                        onEntered: {
                            // точка в координатах окна: тултип раскроется от неё влево
                            var p = navBtn.mapToItem(null, 0, navBtn.height / 2);
                            view.sys.showTip(navBtn.modelData.t, p.x, p.y);
                        }
                        onExited: view.sys.hideTip(navBtn.modelData.t)
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // фон у полосы и у содержимого один, без черты граница не читалась
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            // заметнее colLine и на всю высоту окна: фон у полосы и у
            // содержимого одинаковый, слабая черта на нём терялась
            color: Qt.rgba(1, 1, 1, 0.18)
        }

        // ------------------------------------------------- сам раздел
        ColumnLayout {
            id: pages
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 12

            // «Применить» и «Сбросить» стоят над разделом справа: в узкой
            // полосе слева им уже негде было поместиться.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Panacea · " + [view.sys.tr("Пилюля"), view.sys.tr("Система"),
                                          view.sys.tr("Клавиши"), view.sys.tr("О системе")][view.tab]
                    color: Qt.rgba(1, 1, 1, 0.30)
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            // «Применить» подсвечивается, только когда есть что применять
            Rectangle {
                id: applyBtn
                Layout.preferredWidth: 112
                Layout.preferredHeight: 32
                radius: 11
                opacity: view.dirty ? 1 : 0.4
                color: view.dirty
                       ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b,
                                 applyMa.containsMouse ? 0.34 : 0.22)
                       : Qt.rgba(1, 1, 1, 0.05)
                border.color: view.dirty ? view.sys.colOk : view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on opacity { NumberAnimation { duration: 160 } }

                Text {
                    anchors.centerIn: parent
                    text: view.sys.tr("Применить")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                }
                MouseArea {
                    id: applyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: view.dirty
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.applyDraft()
                }
            }

            Rectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 32
                radius: 11
                color: resetMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: view.sys.tr("Сбросить")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
                MouseArea {
                    id: resetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.resetDraft()
                }
            }
            }

        // ===================================================== ВКЛАДКА «ПИЛЮЛЯ»
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: view.tab === 0

            Section { text: view.sys.tr("Предпросмотр") }

            PillPreview {
                Layout.fillWidth: true
                sys: view.sys
                d: draft
            }

            Text {
                Layout.fillWidth: true
                text: view.dirty ? view.sys.tr("Есть несохранённые изменения")
                                 : view.sys.tr("Изменения применены")
                color: view.dirty ? view.sys.colOk : Qt.rgba(1, 1, 1, 0.30)
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            // ---------------------------------------------------- обход страниц
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 210
                    Layout.preferredHeight: 34
                    radius: 11
                    color: view.sys.tourRunning
                           ? Qt.rgba(view.sys.colCrit.r, view.sys.colCrit.g, view.sys.colCrit.b, 0.22)
                           : (tourMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06))
                    border.color: view.sys.tourRunning ? view.sys.colCrit : view.sys.colLine
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    Text {
                        anchors.centerIn: parent
                        text: view.sys.tourRunning
                              ? view.sys.tr("Остановить показ")
                              : view.sys.tr("Показать все страницы")
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true }
                    }
                    MouseArea {
                        id: tourMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.startTour()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: view.sys.tr("Пролистает все страницы по очереди")
                    color: Qt.rgba(1, 1, 1, 0.32)
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }

            SliderRow {
                label: view.sys.tr("Пауза показа"); from: 1; to: 8; suffix: view.sys.tr("с")
                value: Math.round(view.sys.tourStepMs / 1000)
                onMoved: v => view.sys.tourStepMs = v * 1000
            }

            // Дальше — в две колонки: одним столбцом «Пилюля» не помещалась
            // по высоте и уезжала за нижнюю кромку экрана.
            RowLayout {
                Layout.fillWidth: true
                spacing: 26

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

            Section { text: view.sys.tr("Размеры") }

            SliderRow {
                label: view.sys.tr("Высота пилюли"); from: 28; to: 60; suffix: "px"
                value: draft.pillH
                onMoved: v => { draft.pillH = v; view.touch(); }
            }
            SliderRow {
                label: view.sys.tr("Ширина панели"); from: 380; to: 900; suffix: "px"
                value: draft.panelW
                onMoved: v => { draft.panelW = v; view.touch(); }
            }
            SliderRow {
                label: view.sys.tr("Радиус углов"); from: 0; to: 30; suffix: "px"
                value: draft.cornerR
                onMoved: v => { draft.cornerR = v; view.touch(); }
            }
            SliderRow {
                label: view.sys.tr("Скорость"); from: 80; to: 500; suffix: view.sys.tr("мс")
                value: draft.animMs
                onMoved: v => { draft.animMs = v; view.touch(); }
            }

                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

            Section { text: view.sys.tr("Шрифт") }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Text {
                    Layout.preferredWidth: 150
                    text: view.sys.tr("Семейство")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                }
                ComboBox {
                    id: fontBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    model: view.sys.fontList
                    currentIndex: Math.max(0, view.sys.fontList.indexOf(draft.fontFam))
                    onActivated: { draft.fontFam = view.sys.fontList[currentIndex]; view.touch(); }

                    background: Rectangle {
                        radius: 10
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: view.sys.colLine
                        border.width: 1
                    }
                    contentItem: Text {
                        leftPadding: 12; rightPadding: 26
                        text: fontBox.displayText
                        color: view.sys.colFg
                        font { family: draft.fontFam; pixelSize: view.sys.fontSize - 2 }
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    delegate: ItemDelegate {
                        id: fontItem
                        required property string modelData
                        width: fontBox.width
                        height: 30
                        contentItem: Text {
                            text: fontItem.modelData
                            color: view.sys.colFg
                            font { family: fontItem.modelData; pixelSize: view.sys.fontSize - 3 }
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        background: Rectangle {
                            color: fontItem.highlighted ? Qt.rgba(1, 1, 1, 0.12) : "#111111"
                        }
                    }
                    popup: Popup {
                        y: fontBox.height + 2
                        width: fontBox.width
                        implicitHeight: Math.min(contentItem.implicitHeight + 8, 260)
                        padding: 4
                        background: Rectangle {
                            radius: 10
                            color: "#111111"
                            border.color: view.sys.colLine
                            border.width: 1
                        }
                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: fontBox.popup.visible ? fontBox.delegateModel : null
                            ScrollIndicator.vertical: ScrollIndicator {}
                        }
                    }
                }
            }

            SliderRow {
                label: view.sys.tr("Размер текста"); from: 10; to: 24
                value: draft.fontSize
                onMoved: v => { draft.fontSize = v; view.touch(); }
            }
            SliderRow {
                label: view.sys.tr("Размер иконок"); from: 10; to: 28
                value: draft.iconSize
                onMoved: v => { draft.iconSize = v; view.touch(); }
            }

            Section { text: view.sys.tr("Цвета") }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Text {
                    Layout.preferredWidth: 150
                    text: view.sys.tr("Текст")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                }
                Repeater {
                    model: ["#ffffff", "#e5e7eb", "#fbbf24", "#86efac", "#93c5fd", "#f9a8d4"]
                    Swatch {
                        required property string modelData
                        hex: modelData
                        picked: draft.colFg === modelData
                        onChosen: { draft.colFg = modelData; view.touch(); }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Text {
                    Layout.preferredWidth: 150
                    text: view.sys.tr("Акцент")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                }
                Repeater {
                    model: ["#3b82f6", "#22c55e", "#f59e0b", "#ef4444", "#a855f7", "#06b6d4"]
                    Swatch {
                        required property string modelData
                        hex: modelData
                        picked: draft.colOn === modelData
                        onChosen: { draft.colOn = modelData; view.touch(); }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            SliderRow {
                label: view.sys.tr("Блёклость"); from: 20; to: 80; suffix: "%"
                value: Math.round(draft.mutedAlpha * 100)
                onMoved: v => { draft.mutedAlpha = v / 100; view.touch(); }
            }

                }
            }
        }

        // ==================================================== ВКЛАДКА «СИСТЕМА»
        // Всё, что не про внешний вид пилюли: язык, формат часов и поведение
        // хранилища паролей. В одну колонку — раздел короткий.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: view.tab === 1

            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 520
                Layout.alignment: Qt.AlignTop
                spacing: 12

            Section { text: view.sys.tr("Язык") }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Text {
                    Layout.preferredWidth: 150
                    text: view.sys.tr("Язык")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                }
                Repeater {
                    model: [{ code: "en", name: "English" },
                            { code: "ru", name: view.sys.tr("Русский") }]
                    Rectangle {
                        id: langBtn
                        required property var modelData
                        readonly property bool picked: draft.lang === langBtn.modelData.code

                        Layout.preferredWidth: 110
                        Layout.preferredHeight: 32
                        radius: 10
                        color: langBtn.picked
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                               : (langMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                        border.color: langBtn.picked
                                      ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                      : view.sys.colLine
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Text {
                            anchors.centerIn: parent
                            text: langBtn.modelData.name
                            color: langBtn.picked ? view.sys.colFg : view.sys.colMuted
                            font {
                                family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3
                                bold: langBtn.picked
                            }
                        }
                        MouseArea {
                            id: langMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { draft.lang = langBtn.modelData.code; view.touch(); }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            Section { text: view.sys.tr("Формат часов") }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Text {
                    Layout.preferredWidth: 150
                    text: view.sys.tr("Формат часов")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                }
                Repeater {
                    model: [
                        { on: false, name: view.sys.tr("24 часа"),  sample: "14:05" },
                        { on: true,  name: view.sys.tr("12 часов"), sample: "2:05 PM" }
                    ]
                    Rectangle {
                        id: clkBtn
                        required property var modelData
                        readonly property bool picked: draft.clock12 === clkBtn.modelData.on

                        Layout.preferredWidth: 132
                        Layout.preferredHeight: 42
                        radius: 10
                        color: clkBtn.picked
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                               : (clkMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                        border.color: clkBtn.picked
                                      ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                                      : view.sys.colLine
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 160 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: clkBtn.modelData.name
                                color: clkBtn.picked ? view.sys.colFg : view.sys.colMuted
                                font {
                                    family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3
                                    bold: clkBtn.picked
                                }
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: clkBtn.modelData.sample
                                color: Qt.rgba(1, 1, 1, 0.35)
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                            }
                        }
                        MouseArea {
                            id: clkMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { draft.clock12 = clkBtn.modelData.on; view.touch(); }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            Section { text: view.sys.tr("Проводник") }

            Toggle {
                label: view.sys.tr("Проводник отдельным окном")
                on: view.sys.cfg.filesWindow
                onToggled: {
                    view.sys.cfg.filesWindow = !view.sys.cfg.filesWindow;
                    view.sys.saveCfg();
                }
            }
            Text {
                Layout.fillWidth: true
                text: view.sys.tr("Тайлится в Hyprland, живёт на своём рабочем столе и не трогает пилюлю.")
                color: Qt.rgba(1, 1, 1, 0.32)
                wrapMode: Text.WordWrap
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
            }

            Section { text: view.sys.tr("Пароли") }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Text {
                    Layout.fillWidth: true
                    text: view.sys.tr("Предлагать сохранять пароли")
                    color: view.sys.colFg
                    wrapMode: Text.WordWrap
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                }
                Item { Layout.preferredWidth: 12 }
                Rectangle {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 26
                    radius: 13
                    color: view.sys.cfg.vaultCapture
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.55)
                           : Qt.rgba(1, 1, 1, 0.10)
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Rectangle {
                        width: 20; height: 20; radius: 10
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        x: view.sys.cfg.vaultCapture ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        // тумблер действует сразу: он не про оформление
                        onClicked: {
                            view.sys.cfg.vaultCapture = !view.sys.cfg.vaultCapture;
                            view.sys.saveCfg();
                        }
                    }
                }
            }

            }

            Item { Layout.fillHeight: true }
        }

        // ==================================================== ВКЛАДКА «КЛАВИШИ»
        ColumnLayout {
            id: keysTab
            Layout.fillWidth: true
            spacing: 9
            visible: view.tab === 2

            Text {
                Layout.fillWidth: true
                text: view.sys.tr("Нажмите на сочетание, чтобы изменить. × убирает клавишу.")
                color: Qt.rgba(1, 1, 1, 0.32)
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
            }

            // Две колонки: одним столбцом список не влезал и уезжал
            // за нижнюю кромку экрана.
            RowLayout {
                Layout.fillWidth: true
                spacing: 26

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1     // делим поровну, а не по содержимому
                    Layout.alignment: Qt.AlignTop
                    spacing: 9

                    Section { text: view.sys.tr("Пилюля") }
                    BindRow { bindId: "pillLauncher"; label: view.sys.tr("Лаунчер приложений") }
                    BindRow { bindId: "overview";     label: view.sys.tr("Обзор столов") }
                    BindRow { bindId: "pillControls"; label: view.sys.tr("Wi-Fi, Bluetooth, питание") }
                    BindRow { bindId: "pillSettings"; label: view.sys.tr("Эти настройки") }
                    BindRow { bindId: "pillShortcuts"; label: view.sys.tr("Быстрые клавиши") }
                    BindRow { bindId: "pillWifi";     label: view.sys.tr("Список сетей") }
                    BindRow { bindId: "pillBt";       label: view.sys.tr("Устройства Bluetooth") }
                    BindRow { bindId: "pillClip";     label: view.sys.tr("Буфер обмена") }
                    BindRow { bindId: "pillPower";    label: view.sys.tr("Меню питания") }
                    BindRow { bindId: "pillRecord";   label: view.sys.tr("Запись экрана") }
                    BindRow { bindId: "pillNotif";    label: view.sys.tr("Уведомления") }
                    BindRow { bindId: "fileManager";  label: view.sys.tr("Проводник") }
                    BindRow { bindId: "pillVault";    label: view.sys.tr("Менеджер паролей") }

                    Section { text: view.sys.tr("Приложения") }
                    BindRow { bindId: "terminal";       label: view.sys.tr("Терминал") }
                    BindRow { bindId: "terminalAlt";    label: view.sys.tr("Терминал (запасная)") }
                    BindRow { bindId: "browser";        label: view.sys.tr("Браузер") }
                    BindRow { bindId: "fileManagerTui"; label: view.sys.tr("Файлы в терминале") }
                    BindRow { bindId: "notes";          label: view.sys.tr("Заметки") }
                    BindRow { bindId: "screenshot";     label: view.sys.tr("Скриншот области") }
                    BindRow { bindId: "themeSwitch";    label: view.sys.tr("Смена темы") }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1     // делим поровну, а не по содержимому
                    Layout.alignment: Qt.AlignTop
                    spacing: 9

                    Section { text: view.sys.tr("Окна") }
                    BindRow { bindId: "closeWindow"; label: view.sys.tr("Закрыть окно") }
                    BindRow { bindId: "fullscreen";  label: view.sys.tr("Во весь экран") }
                    BindRow { bindId: "floatToggle"; label: view.sys.tr("Плавающее окно") }
                    BindRow { bindId: "floatCenter"; label: view.sys.tr("Плавающее по центру") }
                    BindRow { bindId: "toggleSplit"; label: view.sys.tr("Сменить направление сплита") }

                    Section { text: view.sys.tr("Рабочие столы") }
                    BindRow { bindId: "emptyWorkspace";   label: view.sys.tr("На пустой стол") }
                    BindRow { bindId: "specialWorkspace"; label: view.sys.tr("Спецстол") }
                    BindRow { bindId: "packWorkspaces";   label: view.sys.tr("Собрать столы подряд") }

                    Section { text: view.sys.tr("Система") }
                    BindRow { bindId: "screenOff"; label: view.sys.tr("Погасить экран") }
                    BindRow { bindId: "exitHypr";  label: view.sys.tr("Выйти из Hyprland") }

                    Section { text: view.sys.tr("Несменяемые") }
                    InfoRow { keys: "Super + 1…0";           label: view.sys.tr("Перейти на рабочий стол") }
                    InfoRow { keys: "Super + Shift + 1…0";   label: view.sys.tr("Перенести окно на стол") }
                    InfoRow { keys: "Super + ←↑↓→";          label: view.sys.tr("Фокус по направлению") }
                    InfoRow { keys: "Super + Shift + ←↑↓→";  label: view.sys.tr("Двигать окно") }
                    InfoRow { keys: "Alt + ←↑↓→";            label: view.sys.tr("Менять размер окна") }
                    InfoRow { keys: "Super + " + view.sys.tr("колесо");  label: view.sys.tr("Листать рабочие столы") }
                    InfoRow { keys: "Super + " + view.sys.tr("ЛКМ");     label: view.sys.tr("Перетащить окно") }
                    InfoRow { keys: "Super + " + view.sys.tr("ПКМ");     label: view.sys.tr("Менять размер окна") }
                    InfoRow { keys: view.sys.tr("Средняя кнопка мыши");  label: view.sys.tr("Закрыть окно") }
                    InfoRow { keys: view.sys.tr("Мультимедиа-клавиши"); label: view.sys.tr("Громкость, яркость, плеер") }
                    InfoRow { keys: view.sys.tr("Крышка ноутбука");     label: view.sys.tr("Блокировка экрана") }
                }
            }
        }
        // ================================================== ВКЛАДКА «О СИСТЕМЕ»
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: view.tab === 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    radius: 18
                    color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
                    border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.45)
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "E"
                        color: view.sys.colOn
                        font { family: view.sys.fontFam; pixelSize: 26; bold: true }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "EnsiZeroGravity"
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 4; bold: true }
                    }
                    Text {
                        text: view.sys.tr("автор Panacea")
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                    }
                }
            }

            // ссылка открывается в браузере по умолчанию
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 13
                color: ghMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                border.color: view.sys.colLine
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 11

                    Glyph {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        glyph: String.fromCodePoint(0xF02A4)
                        color: ghMa.containsMouse ? view.sys.colFg : view.sys.colMuted
                        fontFam: view.sys.fontFam
                        size: view.sys.iconSize
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "github.com/EnsixD"
                        color: view.sys.colFg
                        elide: Text.ElideRight
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    }
                    Text {
                        text: String.fromCodePoint(0xF03CC)
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                    }
                }
                MouseArea {
                    id: ghMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.openLink("https://github.com/EnsixD")
                }
            }

            Section { text: view.sys.tr("Система") }

            AboutRow { label: view.sys.tr("Система");    value: view.osName }
            AboutRow { label: view.sys.tr("Ядро");       value: view.kernel }
            AboutRow { label: view.sys.tr("Композитор"); value: view.wm }
            AboutRow { label: view.sys.tr("Оболочка");   value: view.shellVer }
            AboutRow { label: view.sys.tr("Процессор");  value: view.cpu }
            AboutRow { label: view.sys.tr("Память");     value: view.ram }
            AboutRow { label: view.sys.tr("Экран");      value: view.screenInfo }
            AboutRow { label: view.sys.tr("Аптайм");     value: view.uptime }
        }
        }
    }
}
