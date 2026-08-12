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
    implicitHeight: Math.max(col.implicitHeight,
                             keysTab.implicitHeight + 52,
                             monTab.implicitHeight + 52)

    // 0 — пилюля, 1 — система, 2 — экран, 3 — клавиши, 4 — о системе
    property int tab: 0
    // Клавиши живут отдельным окном (Super + /), а не разделом настроек: их
    // правят редко и подолгу, а список длинный. В этом режиме полоса разделов
    // не рисуется, и виден только он.
    property bool keysOnly: false
    // обе вкладки раскладываются в две колонки, поэтому окно всегда широкое:
    // «Пилюля» вертикально уже не помещалась и уезжала за нижнюю кромку
    // view.sys может быть ещё не присвоен: обработчик срабатывает и на
    // начальном значении tab, до того как вид получил ссылку на оболочку
    onTabChanged: if (!view.keysOnly && view.sys) view.sys.wideSettings = true

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

    // ---------------------------------------------------------- экраны
    // Железо читаем у Hyprland, правки копятся в monDraft и уезжают в
    // monitors.conf по «Применить» — как оформление и клавиши. Сразу не
    // применяем нарочно: неверный режим или масштаб гасит экран, и
    // отменять было бы уже нечем.
    property var mons: []            // [{name, desc, res[], rrByRes, …}]
    property int monSel: 0           // какой экран настраиваем
    property var monDraft: ({})      // name -> {res, rr, scale, transform, vrr, on}
    property int monRev: 0           // счётчик, чтобы черновик перечитался
    property bool monDirty: false

    // Раскладка нескольких экранов. mirror — дублировать, only — показывать
    // на одном, extend — общий рабочий стол.
    property string monLayout: "extend"
    property string monOnly: ""      // имя единственного включённого
    property string monDir: "right"  // куда пристраивать соседей

    readonly property var monCur:
        mons.length ? mons[Math.max(0, Math.min(monSel, mons.length - 1))] : null

    readonly property var monScales: [1.0, 1.25, 1.5, 1.75, 2.0]
    // transform у Hyprland: 0 — как есть, 1 — 90° по часовой, 2 — 180°, 3 — 270°
    readonly property var monTransforms: [
        { v: 0, t: "Обычная" }, { v: 1, t: "Повёрнут вправо" },
        { v: 3, t: "Повёрнут влево" }, { v: 2, t: "Вверх ногами" }
    ]

    // Привычные имена режимов: «FHD» говорит больше, чем 1920x1080, а сами
    // пиксели всё равно стоят рядом.
    readonly property var monResNames: ({
        "3840x2160": "4K",   "3440x1440": "UWQHD", "2560x1600": "WQXGA",
        "2560x1440": "QHD",  "2560x1080": "UWFHD", "1920x1200": "WUXGA",
        "1920x1080": "FHD",  "1680x1050": "WSXGA+", "1600x900": "HD+",
        "1440x900":  "WXGA+", "1366x768": "WXGA",  "1280x1024": "SXGA",
        "1280x800":  "WXGA",  "1280x720": "HD",    "1024x768": "XGA",
        "800x600":   "SVGA",  "640x480":  "VGA"
    })
    function monResName(res) {
        var n = monResNames[res];
        if (n !== undefined) return n;
        // неизвестный режим показываем высотой: 1440p понятнее пустого места
        var p = String(res).split("x");
        return p.length === 2 ? p[1] + "p" : String(res);
    }

    function monTouch() { monDirty = true; dirty = true; }

    Process {
        id: pMons
        command: ["bash", view.sys.scriptDir + "/monitors.sh", "list"]
        stdout: StdioCollector { onStreamFinished: view.readMons(text) }
    }
    function reloadMons() { pMons.running = false; pMons.running = true; }

    // Список режимов приходит строками «1920x1080@60.00Hz» — разбираем их
    // в разрешения и частоты к каждому, чтобы кнопки не показывали
    // невозможных сочетаний.
    function readMons(text) {
        var arr = [];
        try { arr = JSON.parse(text); } catch (e) { arr = []; }
        var out = [];
        for (var i = 0; i < arr.length; i++) {
            var m = arr[i];
            var modes = m.availableModes || [];
            var res = [], rrByRes = ({});
            for (var j = 0; j < modes.length; j++) {
                var mm = String(modes[j]).match(/^(\d+)x(\d+)@([\d.]+)/);
                if (!mm) continue;
                var r = mm[1] + "x" + mm[2];
                if (res.indexOf(r) < 0) { res.push(r); rrByRes[r] = []; }
                var hz = Math.round(parseFloat(mm[3]) * 100) / 100;
                if (rrByRes[r].indexOf(hz) < 0) rrByRes[r].push(hz);
            }
            res.sort(function (a, b) {
                var pa = a.split("x"), pb = b.split("x");
                return (pb[0] * pb[1]) - (pa[0] * pa[1]);
            });
            for (var k in rrByRes) rrByRes[k].sort(function (a, b) { return b - a; });

            // выключенный монитор отдаёт нули — берём его первый режим
            var curRes = (m.width && m.height) ? (m.width + "x" + m.height)
                                               : (res.length ? res[0] : "");
            if (res.indexOf(curRes) < 0 && res.length) curRes = res[0];
            var rrs = rrByRes[curRes] || [];
            var curRr = m.refreshRate ? Math.round(m.refreshRate * 100) / 100
                                      : (rrs.length ? rrs[0] : 60);
            if (rrs.length && rrs.indexOf(curRr) < 0) curRr = rrs[0];

            out.push({
                name: String(m.name || ""),
                desc: String(m.description || m.make || ""),
                res: res, rrByRes: rrByRes,
                curRes: curRes, curRr: curRr,
                scale: m.scale || 1, transform: m.transform || 0,
                vrr: m.vrr === true, disabled: m.disabled === true,
                mirror: String(m.mirrorOf || "none"),
                x: m.x || 0, y: m.y || 0
            });
        }
        view.mons = out;
        view.initMonDraft();
    }

    // Черновик «как сейчас»: раскладку и сторону выводим из живых координат,
    // иначе вкладка при открытии показывала бы не то, что на экранах.
    function initMonDraft() {
        var d = ({});
        for (var i = 0; i < mons.length; i++) {
            var m = mons[i];
            d[m.name] = { res: m.curRes, rr: m.curRr, scale: m.scale,
                          transform: m.transform, vrr: m.vrr, on: !m.disabled };
        }
        monDraft = d;

        var live = mons.filter(function (m) { return !m.disabled; });
        var mirrored = mons.filter(function (m) { return m.mirror !== "none"; });
        if (mons.length > 1 && live.length === 1) {
            monLayout = "only";
            monOnly = live[0].name;
        } else if (mirrored.length) {
            monLayout = "mirror";
        } else {
            monLayout = "extend";
            if (mons.length > 1) {
                var a = mons[0], b = mons[1];
                monDir = b.x > a.x ? "right" : b.x < a.x ? "left"
                       : b.y < a.y ? "up" : "down";
            }
        }
        if (monOnly.length === 0 && mons.length) monOnly = mons[0].name;
        if (monSel >= mons.length) monSel = 0;
        monRev++;
        monDirty = false;
    }

    function monGet(name, key) {
        monRev;
        var d = monDraft[name];
        return d ? d[key] : undefined;
    }
    function monSet(name, key, val) {
        var d = monDraft[name];
        if (d === undefined || d[key] === val) return;
        d[key] = val;
        // сменилось разрешение — прежней частоты у него может и не быть
        if (key === "res") {
            var m = null;
            for (var i = 0; i < mons.length; i++) if (mons[i].name === name) m = mons[i];
            var rrs = (m && m.rrByRes[val]) || [];
            if (rrs.length && rrs.indexOf(d.rr) < 0) d.rr = rrs[0];
        }
        monRev++;
        monTouch();
    }

    // Размер рабочего стола: пиксели, поделённые на масштаб, а поворот на
    // 90° меняет стороны местами.
    function monLogical(name) {
        monRev;
        var d = monDraft[name];
        if (d === undefined) return { w: 0, h: 0 };
        var p = String(d.res).split("x");
        var w = Math.round((parseInt(p[0]) || 0) / d.scale);
        var h = Math.round((parseInt(p[1]) || 0) / d.scale);
        if (d.transform === 1 || d.transform === 3) { var t = w; w = h; h = t; }
        return { w: w, h: h };
    }

    // Hyprland отказывается от масштаба, при котором рабочий стол выходит
    // нецелым по пикселям, — предупреждаем до «Применить».
    function monScaleOk(name) {
        monRev;
        var d = monDraft[name];
        if (d === undefined) return true;
        var p = String(d.res).split("x");
        var w = parseInt(p[0]) || 0, h = parseInt(p[1]) || 0;
        var lw = w / d.scale, lh = h / d.scale;
        return Math.abs(lw - Math.round(lw)) < 0.001
            && Math.abs(lh - Math.round(lh)) < 0.001;
    }

    // Куда встанут экраны при текущем черновике. Одна функция и на карту
    // сверху, и на строки monitor=… — иначе предпросмотр и результат
    // разъезжались бы.
    function monPlaces() {
        monRev;
        var out = [];
        if (mons.length === 0) return out;
        var primary = mons[0].name;
        var fwd = 0, back = 0;      // сколько уже занято по направлению
        for (var i = 0; i < mons.length; i++) {
            var m = mons[i];
            var d = monDraft[m.name];
            if (d === undefined) continue;
            var on = (monLayout === "only") ? (m.name === monOnly) : d.on;
            var L = view.monLogical(m.name);
            var mirror = (monLayout === "mirror" && m.name !== primary && on);
            var x = 0, y = 0;
            if (on && !mirror && m.name !== primary) {
                if      (monDir === "right") x = fwd;
                else if (monDir === "left")  { back += L.w; x = -back; }
                else if (monDir === "down")  y = fwd;
                else                         { back += L.h; y = -back; }
            }
            if (on && !mirror) {
                if      (monDir === "right") fwd += L.w;
                else if (monDir === "down")  fwd += L.h;
            }
            out.push({ name: m.name, desc: m.desc, x: x, y: y, w: L.w, h: L.h,
                       on: on, mirror: mirror, primary: m.name === primary });
        }
        return out;
    }
    function monPlaceOf(name) {
        var pl = view.monPlaces();
        for (var i = 0; i < pl.length; i++) if (pl[i].name === name) return pl[i];
        return { x: 0, y: 0, w: 0, h: 0, on: false, mirror: false, primary: false };
    }

    function monLines() {
        var pl = view.monPlaces();
        var lines = [];
        for (var i = 0; i < pl.length; i++) {
            var p = pl[i];
            var d = monDraft[p.name];
            if (d === undefined) continue;
            if (!p.on) { lines.push("monitor=" + p.name + ",disable"); continue; }
            var s = "monitor=" + p.name + "," + d.res + "@" + d.rr + ","
                  + (p.mirror ? "auto" : (p.x + "x" + p.y)) + ","
                  + Number(d.scale).toFixed(2);
            if (d.transform) s += ",transform," + d.transform;
            if (d.vrr)       s += ",vrr,1";
            if (p.mirror)    s += ",mirror," + mons[0].name;
            lines.push(s);
        }
        return lines.join("\n");
    }

    Process { id: pMonApply }
    function monApply() {
        pMonApply.running = false;
        pMonApply.command = ["bash", view.sys.scriptDir + "/monitors.sh",
                             "apply", view.monLines()];
        pMonApply.running = true;
        monDirty = false;
        monSettle.restart();
    }
    // Hyprland переключает режим не мгновенно: перечитываем чуть позже,
    // чтобы карта показала то, что вышло на самом деле.
    Timer {
        id: monSettle
        interval: 1500
        onTriggered: view.reloadMons()
    }

    function loadDraft() {
        for (var i = 0; i < appearanceKeys.length; i++) {
            var k = appearanceKeys[i];
            draft[k] = view.sys.cfg[k];
        }
        discardBinds();
        reloadMons();
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
        // экраны живут не в settings.json, а в monitors.conf — своей записью
        if (monDirty) view.monApply();
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
        // экранам «заводское» — то, что сейчас на железе: гасить их сбросом
        // оформления было бы неожиданно
        initMonDraft();
        dirty = true;
    }

    Component.onCompleted: {
        loadDraft();
        if (!view.keysOnly) view.sys.wideSettings = true;
        forceActiveFocus();
    }
    Component.onDestruction: {
        view.sys.tipText = "";
        // не оставляем систему без горячих клавиш и не запоминаем широкий режим
        if (capturingKey.length) grabKeys(false);
        if (!view.keysOnly) view.sys.wideSettings = false;
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
        running: view.tab === 4
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
            if (event.key === Qt.Key_Escape) {
                if (view.keysOnly) view.sys.keysWindowOpen = false;
                else               view.sys.collapse();
                event.accepted = true;
            }
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

    // Кнопка-выбор одного из нескольких. Ширина по тексту: у режимов экрана
    // подписи разной длины, фиксированная колонка выглядела бы рвано.
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property string sub: ""
        property bool picked: false
        signal chosen()

        implicitWidth: Math.max(72, Math.max(chipTop.implicitWidth,
                                             chipSub.implicitWidth) + 26)
        implicitHeight: chip.sub.length ? 44 : 32
        radius: 10
        color: chip.picked
               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)
               : (chipMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
        border.color: chip.picked
                      ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                      : view.sys.colLine
        border.width: 1
        scale: chipMa.pressed ? 0.96 : 1.0
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 1
            Text {
                id: chipTop
                Layout.alignment: Qt.AlignHCenter
                text: chip.label
                color: chip.picked ? view.sys.colFg : view.sys.colMuted
                font {
                    family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3
                    bold: chip.picked
                }
                Behavior on color { ColorAnimation { duration: 160 } }
            }
            Text {
                id: chipSub
                Layout.alignment: Qt.AlignHCenter
                visible: chip.sub.length > 0
                text: chip.sub
                color: Qt.rgba(1, 1, 1, 0.35)
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
            }
        }
        MouseArea {
            id: chipMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.chosen()
        }
    }

    // Группа настроек в карточке: ряды сливались в одну простыню, и вкладка
    // читалась как список полей, а не как несколько понятных блоков.
    component CardBox: Rectangle {
        radius: 18
        color: Qt.rgba(1, 1, 1, 0.035)
        border.color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
        Layout.fillWidth: true
    }

    // Подпись слева от ряда кнопок. Сам ряд — Flow: кнопок бывает много
    // (режимы экрана), и они переносятся на следующую строку, а не ужимаются.
    component ChipLabel: Text {
        Layout.preferredWidth: 120
        Layout.alignment: Qt.AlignTop
        topPadding: 7
        color: view.sys.colFg
        wrapMode: Text.WordWrap
        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
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
            visible: !view.keysOnly

            Repeater {
                // Индексы заданы явно: клавиши (3) в полосе не показываются,
                // но сама страница осталась — её открывает отдельное окно.
                model: [
                    { i: 0, t: view.sys.tr("Пилюля"),    g: 0xF12E1 },
                    { i: 1, t: view.sys.tr("Система"),   g: 0xF0493 },
                    { i: 2, t: view.sys.tr("Экран"),     g: 0xF0379 },
                    { i: 4, t: view.sys.tr("О системе"), g: 0xF02FD }
                ]
                Rectangle {
                    id: navBtn
                    required property int index
                    required property var modelData
                    readonly property bool active: view.tab === navBtn.modelData.i

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
                        onClicked: view.tab = navBtn.modelData.i
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
            visible: !view.keysOnly
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
                                          view.sys.tr("Экран"), view.sys.tr("Клавиши"),
                                          view.sys.tr("О системе")][view.tab]
                    color: Qt.rgba(1, 1, 1, 0.30)
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            // «Применить» подсвечивается, только когда есть что применять
            Rectangle {
                id: applyBtn
                // на вкладке «Экран» применяет своя кнопка рядом с настройками:
                // две одинаковые кнопки в одном окне только путали
                visible: view.tab !== 2
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
                visible: view.tab !== 2
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
        // Только то, что действительно правят: цвета и способ переставить
        // остров. Макет рабочего стола и четыре кнопки кромок убраны —
        // остров теперь переносится прямо на экране, руками.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14
            visible: view.tab === 0

            Section { Layout.topMargin: 0; text: view.sys.tr("Положение") }

            Toggle {
                label: view.sys.tr("Переносить остров мышью")
                on: view.sys.cfg.pillDrag
                // Тумблер про поведение, а не про оформление: действует сразу,
                // ждать «Применить» ему не за чем.
                onToggled: {
                    view.sys.cfg.pillDrag = !view.sys.cfg.pillDrag;
                    view.sys.saveCfg();
                }
            }

            Text {
                Layout.fillWidth: true
                text: view.sys.tr("Раскройте быстрые настройки и потяните за "
                                  + "полосу над часами. У кромки остров "
                                  + "прицепится к её центру, в пустоте — "
                                  + "вернётся на место.")
                color: Qt.rgba(1, 1, 1, 0.32)
                wrapMode: Text.WordWrap
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
            }

            Text {
                Layout.fillWidth: true
                text: view.sys.tr("Сейчас: ") + view.sys.tr(
                          view.sys.pillPos === "bottom" ? "Снизу"
                        : view.sys.pillPos === "left"   ? "Слева"
                        : view.sys.pillPos === "right"  ? "Справа" : "Сверху")
                color: view.sys.colMuted
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
            }

            CardBox {
                Layout.topMargin: 6
                Layout.preferredHeight: colorsCol.implicitHeight + 34
                ColumnLayout {
                    id: colorsCol
                    anchors.fill: parent
                    anchors.margins: 17
                    spacing: 12

                    Section { Layout.topMargin: 0; text: view.sys.tr("Цвета") }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        Text {
                            Layout.preferredWidth: 90
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
                            Layout.preferredWidth: 90
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
                }
            }

            Text {
                Layout.fillWidth: true
                text: view.dirty ? view.sys.tr("Есть несохранённые изменения")
                                 : view.sys.tr("Изменения применены")
                color: view.dirty ? view.sys.colOk : Qt.rgba(1, 1, 1, 0.30)
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Item { Layout.fillHeight: true }
        }

        // ==================================================== ВКЛАДКА «СИСТЕМА»
        // Всё, что не про внешний вид пилюли: язык, формат часов и поведение
        // хранилища паролей. В одну колонку — раздел короткий.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: view.tab === 1

            ColumnLayout {
                // без ограничения по ширине: макеты проводника занимают всю
                // ширину окна, а языку и часам лишнее место не мешает
                Layout.fillWidth: true
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

            // Слайдер вместо двух карточек: макет один, зато во всю ширину
            // окна — на нём видно и раскладку проводника, и то, как он стоит
            // на столе. Стрелка всегда показывает в сторону другого варианта.
            Item {
                id: fmSlider
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.preferredHeight: Math.round(width * 0.62)

                readonly property int mode: view.sys.cfg.filesWindow ? 1 : 0
                property real slide: fmSlider.mode
                Behavior on slide {
                    NumberAnimation { duration: 420; easing.type: Easing.OutQuint }
                }
                onModeChanged: fmSlider.slide = fmSlider.mode

                function setMode(m) {
                    if (view.sys.cfg.filesWindow === (m === 1)) return;
                    view.sys.cfg.filesWindow = (m === 1);
                    view.sys.saveCfg();
                }

                Item {
                    id: fmReel
                    anchors.fill: parent
                    clip: true

                    Repeater {
                        model: [
                            { win: false, t: view.sys.tr("По центру экрана"),
                              s: view.sys.tr("раскрывается из острова") },
                            { win: true,  t: view.sys.tr("Отдельным окном"),
                              s: view.sys.tr("тайлится в Hyprland") }
                        ]

                        // ------------------------------------- один макет
                        Item {
                            id: fmPane
                            required property int index
                            required property var modelData
                            readonly property bool picked: fmSlider.mode === fmPane.index

                            width: fmReel.width
                            height: fmReel.height
                            x: (fmPane.index - fmSlider.slide) * fmReel.width
                            opacity: 1 - Math.min(1, Math.abs(fmPane.index - fmSlider.slide))

                            // экран целиком: остров у своей кромки + проводник
                            Rectangle {
                                id: fmScreen
                                anchors.fill: parent
                                anchors.bottomMargin: 44
                                radius: 14
                                color: "#0b0f12"
                                border.color: fmPane.picked ? view.sys.colOn
                                                            : Qt.rgba(1, 1, 1, 0.10)
                                border.width: fmPane.picked ? 2 : 1
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                Item {
                                    id: fmShot
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    visible: false
                                    layer.enabled: true

                                    Image {
                                        anchors.fill: parent
                                        source: view.sys.currentWallThumb.length
                                                ? "file://" + view.sys.currentWallThumb : ""
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: Math.max(1100, Math.round(fmShot.width * 1.4))
                                        asynchronous: true
                                        cache: true
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#000000"
                                        opacity: 0.35
                                    }

                                    // Остров — тот же компонент, что и в макете
                                    // стола: те же сегменты и уголки, на любой
                                    // кромке.
                                    PillMock {
                                        anchors.fill: parent
                                        sys: view.sys
                                        pos: view.sys.pillPos
                                        fgCol: draft.colFg
                                        onCol: draft.colOn
                                        k: fmShot.height / (view.sys.screen
                                                            ? view.sys.screen.height : 1080)
                                    }

                                    // ------------- вариант 1: панель по центру
                                    Item {
                                        visible: !fmPane.modelData.win
                                        anchors.centerIn: parent
                                        width: parent.width * 0.74
                                        height: parent.height * 0.76

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 14
                                            color: Qt.rgba(0.04, 0.04, 0.05, 0.97)
                                            border.color: Qt.rgba(1, 1, 1, 0.14)
                                            border.width: 1
                                        }
                                        FilesMock {
                                            width: 1180
                                            height: 740
                                            sys: view.sys
                                            accent: draft.colOn
                                            fg: draft.colFg
                                            transformOrigin: Item.TopLeft
                                            scale: parent.width / width
                                        }
                                    }

                                    // ------------- вариант 2: два окна рядом
                                    Row {
                                        visible: fmPane.modelData.win
                                        anchors.fill: parent
                                        anchors.margins: Math.max(6, fmShot.height * 0.03)
                                        anchors.topMargin: view.sys.pillPos === "top"
                                                ? fmShot.height * 0.09 : Math.max(6, fmShot.height * 0.03)
                                        anchors.bottomMargin: view.sys.pillPos === "bottom"
                                                ? fmShot.height * 0.09 : Math.max(6, fmShot.height * 0.03)
                                        anchors.leftMargin: view.sys.pillPos === "left"
                                                ? fmShot.width * 0.05 : Math.max(6, fmShot.height * 0.03)
                                        anchors.rightMargin: view.sys.pillPos === "right"
                                                ? fmShot.width * 0.05 : Math.max(6, fmShot.height * 0.03)
                                        spacing: 8

                                        Repeater {
                                            model: 2
                                            Item {
                                                required property int index
                                                width: (parent.width - 8) / 2
                                                height: parent.height

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 12
                                                    color: Qt.rgba(0.04, 0.04, 0.05, 0.95)
                                                    border.width: 1
                                                    border.color: index === 0
                                                                  ? Qt.rgba(view.sys.colOn.r,
                                                                            view.sys.colOn.g,
                                                                            view.sys.colOn.b, 0.7)
                                                                  : Qt.rgba(1, 1, 1, 0.14)
                                                }
                                                FilesMock {
                                                    width: 1180
                                                    height: 900
                                                    sys: view.sys
                                                    accent: draft.colOn
                                                    fg: draft.colFg
                                                    dirName: view.sys.tr(index === 0 ? "Домашняя"
                                                                                     : "Загрузки")
                                                    dirPath: index === 0 ? "/home/ensi"
                                                                         : "/home/ensi/Downloads"
                                                    transformOrigin: Item.TopLeft
                                                    scale: parent.width / width
                                                }
                                            }
                                        }
                                    }
                                }

                                Item {
                                    id: fmMask
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    visible: false
                                    layer.enabled: true
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 12
                                        color: "#ffffff"
                                    }
                                }

                                MaskedShot {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    src: fmShot
                                    mask: fmMask
                                }
                            }

                            // подпись под макетом
                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                spacing: 9

                                Text {
                                    text: fmPane.modelData.t
                                    color: view.sys.colFg
                                    font {
                                        family: view.sys.fontFam
                                        pixelSize: view.sys.fontSize; bold: true
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "· " + fmPane.modelData.s
                                    color: Qt.rgba(1, 1, 1, 0.32)
                                    elide: Text.ElideRight
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    radius: 11
                                    visible: fmPane.picked
                                    color: view.sys.colOn
                                    Text {
                                        anchors.centerIn: parent
                                        text: String.fromCodePoint(0xF012C)
                                        color: "#ffffff"
                                        font { family: view.sys.fontFam; pixelSize: 12 }
                                    }
                                }
                            }
                        }
                    }
                }

                // Стрелка показывает в сторону другого варианта: выбран первый
                // — она справа, выбран второй — слева.
                Rectangle {
                    id: fmArrow
                    width: 46
                    height: 46
                    radius: 23
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -20
                    x: fmSlider.mode === 0 ? fmSlider.width - width - 16 : 16
                    Behavior on x {
                        NumberAnimation { duration: 420; easing.type: Easing.OutQuint }
                    }
                    color: arrowMa.containsMouse
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4)
                           : Qt.rgba(0, 0, 0, 0.55)
                    border.color: Qt.rgba(1, 1, 1, 0.22)
                    border.width: 1
                    scale: arrowMa.pressed ? 0.94 : 1.0
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                    Text {
                        anchors.centerIn: parent
                        text: fmSlider.mode === 0 ? String.fromCodePoint(0xF0142)
                                                  : String.fromCodePoint(0xF0141)
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: 20 }
                    }

                    MouseArea {
                        id: arrowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fmSlider.setMode(fmSlider.mode === 0 ? 1 : 0)
                    }
                }
            }

            }

            Item { Layout.fillHeight: true }
        }

        // ====================================================== ВКЛАДКА «ЭКРАН»
        // Режим, масштаб, поворот и взаимное расположение экранов. Карта
        // сверху показывает будущую раскладку до нажатия «Применить»:
        // проверить настройку на самом экране — значит рискнуть им.
        ColumnLayout {
            id: monTab
            Layout.fillWidth: true
            spacing: 12
            visible: view.tab === 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Text {
                    Layout.fillWidth: true
                    text: view.mons.length
                          ? view.sys.tr("Изменения применятся по кнопке «Применить».")
                          : view.sys.tr("Экраны не найдены")
                    color: Qt.rgba(1, 1, 1, 0.32)
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                }

                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 30
                    radius: 10
                    color: rescanMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14)
                                                  : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: view.sys.tr("Определить экраны")
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                    }
                    MouseArea {
                        id: rescanMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.reloadMons()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 26

                // ----------------------------------------------- слева: экран
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 14

                    // Картинка выбранного экрана. Пропорции живые: повёрнутый
                    // монитор и на картинке стоит вертикально, так что режим
                    // и поворот видно до нажатия «Применить».
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 0
                        visible: view.monCur !== null

                        Rectangle {
                            id: monShot
                            readonly property real ratio: {
                                if (!view.monCur) return 16 / 9;
                                var L = view.monLogical(view.monCur.name);
                                return L.h > 0 ? L.w / L.h : 16 / 9;
                            }
                            // Layout.* не принимает Behavior, поэтому размер
                            // считаем в своих свойствах и анимируем их
                            property real shotW: Math.min(320, 210 * ratio)
                            property real shotH: Math.min(210, 320 / ratio)
                            Behavior on shotW { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutCubic } }
                            Behavior on shotH { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutCubic } }

                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Math.round(shotW)
                            Layout.preferredHeight: Math.round(shotH)
                            radius: 12
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                                  view.sys.colOn.b, 0.55)
                            border.width: 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - 24
                                spacing: 4

                                Glyph {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    glyph: String.fromCodePoint(0xF0379)
                                    color: view.sys.colOn
                                    fontFam: view.sys.fontFam
                                    size: view.sys.iconSize + 12
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: view.monCur ? view.monCur.name : ""
                                    color: view.sys.colFg
                                    font {
                                        family: view.sys.fontFam
                                        pixelSize: view.sys.fontSize; bold: true
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: view.monCur
                                          ? view.monGet(view.monCur.name, "res") + " @ "
                                            + view.monGet(view.monCur.name, "rr") + "Hz"
                                          : ""
                                    color: view.sys.colMuted
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                                }
                            }
                        }

                        // ножка и подставка — чтобы картинка читалась монитором,
                        // а не просто прямоугольником
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 18
                            color: Qt.rgba(1, 1, 1, 0.10)
                        }
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 116
                            Layout.preferredHeight: 7
                            radius: 4
                            color: Qt.rgba(1, 1, 1, 0.10)
                        }
                    }

                    Section {
                        text: view.sys.tr("Экраны")
                        visible: view.mons.length > 1
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        visible: view.mons.length > 1
                        ChipLabel { text: view.sys.tr("Настроить") }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: view.mons
                                Chip {
                                    required property int index
                                    required property var modelData
                                    label: modelData.name
                                    sub: modelData.desc
                                    picked: view.monSel === index
                                    onChosen: view.monSel = index
                                }
                            }
                        }
                    }

                    Section {
                        text: view.sys.tr("Раскладка")
                        visible: view.mons.length > 1
                    }

                    // Карта будущей раскладки: проверять её на самих экранах —
                    // значит рискнуть остаться без картинки.
                    Rectangle {
                        id: monMap
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        visible: view.mons.length > 1
                        radius: 14
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.color: view.sys.colLine
                        border.width: 1

                        // Общий охват включённых экранов в точках рабочего стола.
                        readonly property var bounds: {
                            var p = view.monPlaces().filter(function (q) { return q.on; });
                            if (!p.length) return { x0: 0, y0: 0, w: 1, h: 1 };
                            var x0 = p[0].x, y0 = p[0].y;
                            var x1 = p[0].x + p[0].w, y1 = p[0].y + p[0].h;
                            for (var i = 1; i < p.length; i++) {
                                x0 = Math.min(x0, p[i].x);
                                y0 = Math.min(y0, p[i].y);
                                x1 = Math.max(x1, p[i].x + p[i].w);
                                y1 = Math.max(y1, p[i].y + p[i].h);
                            }
                            return { x0: x0, y0: y0,
                                     w: Math.max(1, x1 - x0), h: Math.max(1, y1 - y0) };
                        }
                        // не readonly: к таким свойствам нельзя прицепить Behavior,
                        // а без него карта дёргалась бы при смене раскладки
                        property real k:
                            Math.min((width - 40) / bounds.w, (height - 40) / bounds.h)
                        property real offX: (width  - bounds.w * k) / 2
                        property real offY: (height - bounds.h * k) / 2

                        Behavior on k    { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutCubic } }
                        Behavior on offX { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutCubic } }
                        Behavior on offY { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutCubic } }

                        // Модель — само железо, а не раскладка: список не
                        // пересобирается при каждой правке, и прямоугольники
                        // переезжают плавно, а не появляются заново.
                        Repeater {
                            model: view.mons
                            Rectangle {
                                id: monRect
                                required property int index
                                required property var modelData
                                readonly property var place: view.monPlaceOf(monRect.modelData.name)
                                readonly property bool active: view.monSel === monRect.index

                                x: monMap.offX + (place.x - monMap.bounds.x0) * monMap.k
                                y: monMap.offY + (place.y - monMap.bounds.y0) * monMap.k
                                width:  Math.max(2, place.w * monMap.k)
                                height: Math.max(2, place.h * monMap.k)
                                radius: 8
                                opacity: place.on ? 1 : 0
                                visible: opacity > 0.01
                                // дубли лежат друг на друге — активный сверху
                                z: monRect.active ? 2 : 1

                                color: monRect.active
                                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                                 view.sys.colOn.b, 0.22)
                                       : Qt.rgba(1, 1, 1, 0.07)
                                border.color: monRect.active
                                              ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.22)
                                border.width: monRect.active ? 2 : 1

                                Behavior on x       { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutCubic } }
                                Behavior on y       { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutCubic } }
                                Behavior on width   { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutCubic } }
                                Behavior on height  { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: view.sys.animMs } }
                                Behavior on color        { ColorAnimation { duration: 160 } }
                                Behavior on border.color { ColorAnimation { duration: 160 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    width: parent.width - 12
                                    spacing: 1
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: monRect.modelData.name
                                        color: view.sys.colFg
                                        elide: Text.ElideRight
                                        font {
                                            family: view.sys.fontFam
                                            pixelSize: view.sys.fontSize - 3; bold: true
                                        }
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        visible: monRect.height > 46
                                        text: monRect.place.mirror ? view.sys.tr("Дубль")
                                            : monRect.place.primary ? view.sys.tr("Основной") : ""
                                        color: Qt.rgba(1, 1, 1, 0.32)
                                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 6 }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: view.monSel = monRect.index
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        visible: view.mons.length > 1
                        ChipLabel { text: view.sys.tr("Режим") }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: [
                                    { m: "extend", t: view.sys.tr("Расширить"),
                                      s: view.sys.tr("общий стол") },
                                    { m: "mirror", t: view.sys.tr("Дублировать"),
                                      s: view.sys.tr("одна картинка") },
                                    { m: "only",   t: view.sys.tr("Только один"),
                                      s: view.sys.tr("остальные погасить") }
                                ]
                                Chip {
                                    required property var modelData
                                    label: modelData.t
                                    sub: modelData.s
                                    picked: view.monLayout === modelData.m
                                    onChosen: {
                                        if (view.monLayout === modelData.m) return;
                                        view.monLayout = modelData.m;
                                        view.monRev++;
                                        view.monTouch();
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        visible: view.mons.length > 1 && view.monLayout === "only"
                        ChipLabel { text: view.sys.tr("Показывать на") }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: view.mons
                                Chip {
                                    required property var modelData
                                    label: modelData.name
                                    picked: view.monOnly === modelData.name
                                    onChosen: {
                                        if (view.monOnly === modelData.name) return;
                                        view.monOnly = modelData.name;
                                        view.monRev++;
                                        view.monTouch();
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        visible: view.mons.length > 1 && view.monLayout === "extend"
                        ChipLabel { text: view.sys.tr("Второй экран") }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: [
                                    { d: "right", t: view.sys.tr("Справа") },
                                    { d: "left",  t: view.sys.tr("Слева") },
                                    { d: "up",    t: view.sys.tr("Сверху") },
                                    { d: "down",  t: view.sys.tr("Снизу") }
                                ]
                                Chip {
                                    required property var modelData
                                    label: modelData.t
                                    picked: view.monDir === modelData.d
                                    onChosen: {
                                        if (view.monDir === modelData.d) return;
                                        view.monDir = modelData.d;
                                        view.monRev++;
                                        view.monTouch();
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: view.mons.length > 1 && view.monLayout === "mirror"
                        text: view.sys.tr("Дубли повторяют картинку основного экрана: "
                                          + "у них своё разрешение, но общая раскладка.")
                        color: Qt.rgba(1, 1, 1, 0.32)
                        wrapMode: Text.WordWrap
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                    }
                }

                // ------------------------------------ справа: режим и масштаб
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 12
                    visible: view.monCur !== null

                    // Разрешения плиткой по два: у режимов привычные имена
                    // (FHD, QHD), а пиксели — рядом мелким.
                    Grid {
                        id: resGrid
                        Layout.fillWidth: true
                        columns: 2
                        spacing: 10

                        Repeater {
                            model: view.monCur ? view.monCur.res : []
                            Rectangle {
                                id: resCell
                                required property int index
                                required property string modelData
                                readonly property bool picked:
                                    view.monCur !== null
                                    && view.monGet(view.monCur.name, "res") === resCell.modelData

                                width: Math.floor((resGrid.width - resGrid.spacing) / 2)
                                height: 46
                                radius: 12
                                color: resCell.picked
                                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g,
                                                 view.sys.colOn.b, 0.16)
                                       : (resMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                                                              : Qt.rgba(1, 1, 1, 0.05))
                                border.color: resCell.picked
                                              ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.08)
                                border.width: resCell.picked ? 2 : 1
                                scale: resMa.pressed ? 0.97 : 1.0
                                Behavior on color { ColorAnimation { duration: 160 } }
                                Behavior on border.color { ColorAnimation { duration: 160 } }
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Text {
                                        text: view.monResName(resCell.modelData)
                                        color: resCell.picked ? view.sys.colFg : view.sys.colMuted
                                        font {
                                            family: view.sys.fontFam
                                            pixelSize: view.sys.fontSize - 1; bold: true
                                        }
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: resCell.modelData
                                        color: Qt.rgba(1, 1, 1, 0.35)
                                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                                    }
                                }

                                MouseArea {
                                    id: resMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: view.monSet(view.monCur.name, "res", resCell.modelData)
                                }
                            }
                        }
                    }

                    // ------------------------------------------------ частота
                    // Циферблат: стрелка ходит по доступным частотам, а не по
                    // произвольным герцам — монитор всё равно примет только их.
                    Item {
                        id: rateDial
                        readonly property var rates: view.monCur
                            ? (view.monCur.rrByRes[view.monGet(view.monCur.name, "res")] || [])
                            : []
                        // мелкие частоты слева, крупные справа — как на шкале ниже
                        readonly property var asc: rateDial.rates.slice().reverse()
                        readonly property int idx: view.monCur
                            ? Math.max(0, rateDial.asc.indexOf(view.monGet(view.monCur.name, "rr")))
                            : 0
                        property real ang: rateDial.asc.length > 1
                            ? -120 + 240 * rateDial.idx / (rateDial.asc.length - 1) : 0
                        Behavior on ang { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutBack } }

                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        implicitWidth: 124
                        implicitHeight: 124
                        visible: rateDial.rates.length > 0

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1
                        }

                        // четыре засечки по сторонам
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                width: 2
                                height: 8
                                radius: 1
                                color: Qt.rgba(1, 1, 1, 0.22)
                                x: rateDial.width / 2 - 1
                                y: 5
                                transformOrigin: Item.Center
                                transform: Rotation {
                                    origin.x: 1
                                    origin.y: rateDial.height / 2 - 5
                                    angle: index * 90
                                }
                            }
                        }

                        // стрелка
                        Rectangle {
                            width: 2
                            height: rateDial.height / 2 - 16
                            radius: 1
                            color: view.sys.colOn
                            x: rateDial.width / 2 - 1
                            y: 16
                            transformOrigin: Item.Bottom
                            rotation: rateDial.ang
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 14; height: 14; radius: 7
                            color: Qt.rgba(0, 0, 0, 0.5)
                            border.color: view.sys.colOn
                            border.width: 2
                        }
                    }

                    // Шкала частот: ручка встаёт только на доступные значения,
                    // подписи под ней тоже кликаются.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: rateDial.rates.length > 0

                        Item {
                            id: rateBar
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26

                            readonly property int last: Math.max(1, rateDial.asc.length - 1)
                            readonly property real usable: width - rateKnob.width
                            property real pos: rateDial.asc.length > 1
                                               ? rateDial.idx / rateBar.last : 1
                            Behavior on pos { NumberAnimation { duration: view.sys.animMs; easing.type: Easing.OutCubic } }

                            function setFromX(x) {
                                if (!view.monCur || rateDial.asc.length === 0) return;
                                var r = Math.max(0, Math.min(1,
                                        (x - rateKnob.width / 2) / Math.max(1, usable)));
                                var i = Math.round(r * rateBar.last);
                                view.monSet(view.monCur.name, "rr", rateDial.asc[i]);
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: rateKnob.width / 2
                                width: rateBar.usable
                                height: 6
                                radius: 3
                                color: Qt.rgba(1, 1, 1, 0.12)

                                Rectangle {
                                    width: parent.width * rateBar.pos
                                    height: parent.height
                                    radius: 3
                                    color: view.sys.colOn
                                }
                            }

                            Rectangle {
                                id: rateKnob
                                width: 20; height: 20; radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                x: rateBar.pos * rateBar.usable
                                color: "#ffffff"
                                scale: rateMa.pressed ? 1.22 : (rateMa.containsMouse ? 1.1 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                            }

                            MouseArea {
                                id: rateMa
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => rateBar.setFromX(mouse.x)
                                onPositionChanged: mouse => { if (pressed) rateBar.setFromX(mouse.x); }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Repeater {
                                model: rateDial.asc
                                Text {
                                    id: rateLbl
                                    required property var modelData
                                    readonly property bool picked:
                                        view.monCur !== null
                                        && view.monGet(view.monCur.name, "rr") === rateLbl.modelData

                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    color: rateLbl.picked ? view.sys.colOn : view.sys.colMuted
                                    font {
                                        family: view.sys.fontFam
                                        pixelSize: view.sys.fontSize - 4
                                        bold: rateLbl.picked
                                    }
                                    Behavior on color { ColorAnimation { duration: 160 } }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: view.monSet(view.monCur.name, "rr", rateLbl.modelData)
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 14
                        ChipLabel { text: view.sys.tr("Масштаб") }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: view.monScales
                                Chip {
                                    required property var modelData
                                    label: Math.round(modelData * 100) + "%"
                                    picked: view.monCur !== null
                                            && view.monGet(view.monCur.name, "scale") === modelData
                                    onChosen: view.monSet(view.monCur.name, "scale", modelData)
                                }
                            }
                        }
                    }

                    // размер рабочего стола после масштаба и поворота
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!view.monCur) return "";
                            var L = view.monLogical(view.monCur.name);
                            return view.sys.tr("Рабочий стол") + ": " + L.w + "×" + L.h;
                        }
                        color: Qt.rgba(1, 1, 1, 0.32)
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: view.monCur !== null && !view.monScaleOk(view.monCur.name)
                        text: view.sys.tr("Такой масштаб даёт нецелый размер стола — "
                                          + "Hyprland его не примет.")
                        color: view.sys.colCrit
                        wrapMode: Text.WordWrap
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        ChipLabel { text: view.sys.tr("Ориентация") }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: view.monTransforms
                                Chip {
                                    required property var modelData
                                    label: view.sys.tr(modelData.t)
                                    picked: view.monCur !== null
                                            && view.monGet(view.monCur.name, "transform") === modelData.v
                                    onChosen: view.monSet(view.monCur.name, "transform", modelData.v)
                                }
                            }
                        }
                    }

                    Toggle {
                        label: view.sys.tr("Экран включён")
                        // единственный экран выключать нельзя, а в режиме
                        // «только один» этим занимается сам режим
                        visible: view.mons.length > 1 && view.monLayout !== "only"
                        on: view.monCur ? view.monGet(view.monCur.name, "on") === true : false
                        onToggled: view.monSet(view.monCur.name, "on",
                                               !(view.monGet(view.monCur.name, "on") === true))
                    }

                    Toggle {
                        label: view.sys.tr("Переменная частота (VRR)")
                        on: view.monCur ? view.monGet(view.monCur.name, "vrr") === true : false
                        onToggled: view.monSet(view.monCur.name, "vrr",
                                               !(view.monGet(view.monCur.name, "vrr") === true))
                    }

                    // Своя кнопка: настройки экрана рискованные, и применять их
                    // хочется отсюда же, не уводя взгляд к шапке окна.
                    Rectangle {
                        id: monApplyBtn
                        Layout.alignment: Qt.AlignRight
                        Layout.topMargin: 6
                        Layout.preferredWidth: 150
                        Layout.preferredHeight: 42
                        radius: 14
                        opacity: view.monDirty ? 1 : 0.45
                        color: view.monDirty
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b,
                                         monApplyMa.containsMouse ? 0.36 : 0.24)
                               : Qt.rgba(1, 1, 1, 0.05)
                        border.color: view.monDirty ? view.sys.colOn : view.sys.colLine
                        border.width: 1
                        scale: monApplyMa.pressed ? 0.97 : 1.0
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 9
                            Glyph {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                glyph: String.fromCodePoint(0xF0379)
                                color: view.sys.colFg
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize - 2
                            }
                            Text {
                                text: view.sys.tr("Применить")
                                color: view.sys.colFg
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: view.sys.fontSize - 1; bold: true
                                }
                            }
                        }

                        MouseArea {
                            id: monApplyMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: view.monDirty
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.monApply()
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
            visible: view.tab === 3

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
            visible: view.tab === 4

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
