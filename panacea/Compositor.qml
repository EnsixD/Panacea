pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Одна точка, через которую вся оболочка разговаривает с компоновщиком.
//
// Panacea выросла на Hyprland, и до этого файла shell.qml звал `Hyprland.*`
// напрямую — а вместе с ним и OverviewView. Под niri ни один из этих
// вызовов не работает: у Quickshell модуля для niri нет вовсе (есть только
// Hyprland и I3), и весь IPC приходится вести самим.
//
// Поэтому: наружу торчит один набор свойств и функций, одинаковый для обоих
// компоновщиков, а внутри — две ветки. Точки сцепления собраны здесь, и
// добавить третий компоновщик значит дописать ветку сюда, а не искать
// `Hyprland.` по шести тысячам строк.
//
// С niri говорим через `niri msg --json`, а не через сырой сокет $NIRI_SOCKET.
// Кадрирование сокета — деталь реализации niri и менялось между версиями, а
// CLI — её публичный договор: та же JSON-структура, но разбирать поток
// вручную не нужно и обновление niri не ломает оболочку молча.
Singleton {
    id: comp

    // ------------------------------------------------------------ кто под нами
    // По переменным окружения сеанса, а не по наличию процесса: под niri
    // может быть запущен и hyprctl (например, вложенный Hyprland), и проверка
    // «есть ли бинарь» отвечала бы не на тот вопрос. Переменную выставляет
    // сам компоновщик своим потомкам, и врать ей незачем.
    readonly property bool isNiri:
        String(Quickshell.env("NIRI_SOCKET") || "").length > 0 ||
        /niri/i.test(String(Quickshell.env("XDG_CURRENT_DESKTOP") || ""))

    readonly property bool isHyprland:
        !comp.isNiri && (
            String(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "").length > 0 ||
            /hyprland/i.test(String(Quickshell.env("XDG_CURRENT_DESKTOP") || ""))
        )

    readonly property string kind:
        comp.isNiri ? "niri" : (comp.isHyprland ? "hyprland" : "unknown")

    // Lua-конфиг есть только у Hyprland, и только он меняет форму диспетчеров.
    readonly property bool usingLua: comp.isHyprland && Hyprland.usingLua

    // Чего у niri нет и не будет: блюра слоёв и своего шейдера насыщенности
    // (screen_shader — расширение Hyprland). Вкладки настроек прячут эти
    // ползунки по этим флагам, а не по имени компоновщика: так новая ветка
    // не потребует править ещё и UI.
    readonly property bool hasBlur: comp.isHyprland
    readonly property bool hasVibrance: comp.isHyprland
    // Прокручиваемая раскладка: у niri столы бесконечны вправо, и «обзор
    // столов» у него свой, встроенный.
    readonly property bool hasNativeOverview: comp.isNiri

    // --------------------------------------------------------------- столы
    // [{ id, idx, name, output, focused }]
    //
    // id — то, чем стол называют снаружи: у Hyprland это его номер, у niri —
    // idx, порядковый номер стола на своём мониторе. Именно idx, а не
    // niri'шный внутренний id: он растёт бесконечно и в точках свёрнутого
    // острова выглядел бы случайными числами, да и `focus-workspace` в CLI
    // ждёт как раз индекс.
    readonly property var workspaces:
        comp.isNiri ? comp._niriWorkspaces : comp._hyprWorkspaces

    readonly property int focusedWorkspace:
        comp.isNiri ? comp._niriFocusedWs
                    : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)

    // ------------------------------------------------------------- монитор
    // { name, x, y, width, height, screen } или null, пока компоновщик не
    // ответил. Null здесь осмыслен: Quickshell в этом случае выбирает экран
    // сам, и остров появляется хоть где-то, а не нигде.
    readonly property var focusedMonitor:
        comp.isNiri ? comp._niriMonitor : comp._hyprMonitor

    // ---------------------------------------------------------------- окна
    // [{ wayland, geo: { x, y, w, h, ws, cls } }] — ровно то, что нужно
    // обзору столов: wayland-хэндл для живого кадра и геометрия в координатах
    // монитора.
    readonly property var toplevels:
        comp.isNiri ? comp._niriToplevels : comp._hyprToplevels

    // Активное окно и полноэкранный режим
    readonly property bool isFullscreen:
        comp.isNiri ? comp._niriFullscreen : comp._hyprFullscreen
    readonly property string activeClass:
        comp.isNiri ? comp._niriActiveClass : comp._hyprActiveClass

    // ---------------------------------------------------- раскладка клавиатуры
    // "RU" / "US". Держим строкой, а не индексом: индекс без списка раскладок
    // ничего не значит, а показать нужно именно буквы.
    property string keyboardLayout: "US"

    // ==================================================================
    //                             действия
    // ==================================================================

    // Перейти на стол. Аргумент — тот же id, что лежит в workspaces.
    function focusWorkspace(id) {
        if (comp.isNiri) {
            comp._niri(["action", "focus-workspace", String(id)]);
            return;
        }
        // С Lua-конфигом Hyprland разбирает строку запроса как Lua-код, и
        // привычное "workspace 2" валится синтаксической ошибкой — нужен
        // настоящий диспетчер. На обычном конфиге работает старая форма.
        if (comp.usingLua) Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
        else               Hyprland.dispatch("workspace " + id);
    }

    // Запустить программу потомком компоновщика.
    //
    // Именно им, а не потомком оболочки: процессы, порождённые Quickshell,
    // умирают вместе с ним при перезапуске оболочки, и открытый редактор
    // закрывался бы на ровном месте. У обоих компоновщиков для этого есть
    // свой диспетчер.
    function exec(cmd) {
        var s = String(cmd);
        if (comp.isNiri) {
            // Через sh -c, а не голым spawn: в биндингах и лаунчере команды
            // приходят строкой с кавычками, пайпами и переменными, и spawn,
            // который ждёт argv, разобрал бы их как имя файла.
            comp._niri(["action", "spawn", "--", "sh", "-c", s]);
            return;
        }
        if (comp.usingLua) {
            var safe = s.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
            Hyprland.dispatch("hl.dsp.exec_cmd('" + safe + "')");
        } else {
            Hyprland.dispatch("exec " + s);
        }
    }

    // Закрыть активное окно.
    function closeActive() {
        if (comp.isNiri) { comp._niri(["action", "close-window"]); return; }
        pHyprClose.running = false;
        pHyprClose.running = true;
    }

    // Переключить раскладку клавиатуры на следующую.
    function switchLayout() {
        if (comp.isNiri) {
            comp._niri(["action", "switch-layout", "next"]);
            return;
        }
        pSwitchLayout.running = false;
        pSwitchLayout.running = true;
    }

    // Завершить сеанс графического интерфейса.
    function exit() {
        if (comp.isNiri) {
            comp._niri(["action", "quit", "--skip-confirmation"]);
            return;
        }
        pHyprExit.running = false;
        pHyprExit.running = true;
    }

    // Перечитать состояние. Под niri это ничего не стоит: поток событий и так
    // держит картину свежей, и функция оставлена только ради единого вызова.
    function refresh() {
        if (comp.isNiri) {
            pNiriOutputs.running = false;
            pNiriOutputs.running = true;
            return;
        }
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    // ==================================================================
    //                          ветка Hyprland
    // ==================================================================

    property int _hyprRevision: 0
    property bool _hyprFullscreen: false
    property string _hyprActiveClass: ""

    readonly property var _hyprWorkspaces: {
        comp._hyprRevision;
        var out = [];
        if (!comp.isHyprland) return out;
        var all = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (var i = 0; i < all.length; i++) {
            var w = all[i];
            if (!w) continue;
            out.push({
                id: w.id, idx: w.id,
                name: String(w.name || w.id || ""),
                output: w.monitor ? String(w.monitor.name || "") : "",
                focused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === w.id
            });
        }
        return out;
    }

    readonly property var _hyprMonitor: {
        comp._hyprRevision;
        if (!comp.isHyprland) return null;
        var m = Hyprland.focusedMonitor;
        if (!m) return null;
        return {
            name: String(m.name || ""),
            x: m.x, y: m.y, width: m.width, height: m.height,
            screen: m.screen || null
        };
    }

    readonly property var _hyprToplevels: {
        comp._hyprRevision;
        var out = [];
        if (!comp.isHyprland) return out;
        var all = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (var i = 0; i < all.length; i++) {
            var t = all[i];
            if (!t) continue;
            var o = t.lastIpcObject;
            if (!o || !o.at || !o.size) continue;
            if (o.hidden || o.workspace === undefined) continue;
            out.push({
                wayland: t.wayland,
                geo: {
                    x: o.at[0], y: o.at[1], w: o.size[0], h: o.size[1],
                    ws: o.workspace.id,
                    cls: String(o.initialClass || o.class || "")
                }
            });
        }
        return out;
    }

    Process {
        id: pHyprClose
        command: ["sh", "-c",
            "out=$(hyprctl dispatch 'hl.dsp.window.close()' 2>&1); " +
            "case \"$out\" in ok*) ;; *) hyprctl dispatch killactive ;; esac"]
    }

    Process {
        id: pSwitchLayout
        command: ["hyprctl", "switchxkblayout", "next"]
    }

    Process {
        id: pHyprExit
        command: ["sh", "-c",
            "out=$(hyprctl dispatch 'hl.dsp.exit()' 2>&1); " +
            "case \"$out\" in ok*) ;; *) hyprctl dispatch exit ;; esac"]
    }

    Process {
        id: pHyprLayout
        command: ["sh", "-c",
            "hyprctl devices -j 2>/dev/null | jq -r '.keyboards[]|select(.main==true)|.active_keymap' | head -1"]
        running: comp.isHyprland
        stdout: SplitParser {
            onRead: line => {
                var s = line.trim();
                if (s.length) comp.keyboardLayout = /rus/i.test(s) ? "RU" : "US";
            }
        }
    }

    Process {
        id: pHyprActive
        command: ["sh", "-c", "hyprctl activewindow -j 2>/dev/null"]
        running: comp.isHyprland
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var obj = JSON.parse(text);
                    if (obj) {
                        comp._hyprFullscreen = !!(obj.fullscreen);
                        comp._hyprActiveClass = String(obj.initialClass || obj.class || "");
                    } else {
                        comp._hyprFullscreen = false;
                        comp._hyprActiveClass = "";
                    }
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        enabled: comp.isHyprland
        function onRawEvent(ev) {
            comp._hyprRevision++;
            var n = String(ev.name);
            if (n === "activelayout") {
                pHyprLayout.running = false;
                pHyprLayout.running = true;
            } else if (n === "fullscreen" || n === "activewindow" || n === "activewindowv2"
                       || n === "closewindow" || n === "openwindow") {
                pHyprActive.running = false;
                pHyprActive.running = true;
            }
        }
    }

    // ==================================================================
    //                            ветка niri
    // ==================================================================

    // Сырые данные, как их отдаёт niri. Держим отдельно от общего вида,
    // чтобы разбор события не зависел от того, как оболочка это покажет.
    property var _niriWs: []          // список Workspace, как в IPC
    property var _niriWins: ({})      // id окна -> Window
    property var _niriOutputs: ({})   // имя выхода -> Output
    property string _niriFocusedOut: ""
    property var _niriKbNames: []
    property int _niriKbIdx: 0
    property bool _niriFullscreen: false
    property string _niriActiveClass: ""

    // Разовая команда к niri, ответ которой нам не нужен.
    function _niri(args) {
        niriAction.createObject(comp, { args: args });
    }

    Component {
        id: niriAction
        Process {
            property var args: []
            command: ["niri", "msg"].concat(args)
            running: true
            onExited: destroy()
        }
    }

    // ------------------------------------------------------- поток событий
    Process {
        id: pNiriEvents
        command: ["niri", "msg", "--json", "event-stream"]
        running: comp.isNiri
        stdout: SplitParser {
            onRead: line => comp._onNiriEvent(line)
        }
        onExited: if (comp.isNiri) niriRetry.restart()
    }

    Timer {
        id: niriRetry
        interval: 1000
        onTriggered: pNiriEvents.running = true
    }

    function _onNiriEvent(line) {
        var s = String(line).trim();
        if (!s.length) return;
        var ev;
        try { ev = JSON.parse(s); } catch (e) { return; }
        if (!ev || typeof ev !== "object") return;

        if (ev.WorkspacesChanged) {
            comp._niriWs = ev.WorkspacesChanged.workspaces || [];
            comp._syncNiriFocus();
        } else if (ev.WorkspaceActivated) {
            var a = ev.WorkspaceActivated;
            var ws = comp._niriWs.slice();
            var target = null;
            for (var i = 0; i < ws.length; i++) if (ws[i].id === a.id) target = ws[i];
            if (target) {
                for (var j = 0; j < ws.length; j++) {
                    if (ws[j].output === target.output) ws[j].is_active = (ws[j].id === a.id);
                    if (a.focused) ws[j].is_focused = (ws[j].id === a.id);
                }
            }
            comp._niriWs = ws;
            comp._syncNiriFocus();
        } else if (ev.WindowsChanged) {
            var map = {};
            var wins = ev.WindowsChanged.windows || [];
            for (var k = 0; k < wins.length; k++) {
                map[wins[k].id] = wins[k];
                if (wins[k].is_focused) {
                    comp._niriActiveClass = String(wins[k].app_id || "");
                    comp._niriFullscreen = !!wins[k].is_fullscreen;
                }
            }
            comp._niriWins = map;
        } else if (ev.WindowOpenedOrChanged) {
            var w = ev.WindowOpenedOrChanged.window;
            if (w) {
                var m2 = comp._niriWins;
                m2[w.id] = w;
                comp._niriWins = m2;
                comp._niriWinsRevision++;
                if (w.is_focused) {
                    comp._niriActiveClass = String(w.app_id || "");
                    comp._niriFullscreen = !!w.is_fullscreen;
                }
            }
        } else if (ev.WindowClosed) {
            var m3 = comp._niriWins;
            delete m3[ev.WindowClosed.id];
            comp._niriWins = m3;
            comp._niriWinsRevision++;
        } else if (ev.WindowFocusChanged) {
            var focId = ev.WindowFocusChanged.id;
            if (focId !== null && focId !== undefined && comp._niriWins[focId]) {
                comp._niriActiveClass = String(comp._niriWins[focId].app_id || "");
                comp._niriFullscreen = !!comp._niriWins[focId].is_fullscreen;
            } else {
                comp._niriActiveClass = "";
                comp._niriFullscreen = false;
            }
        } else if (ev.WindowLayoutsChanged) {
            var ch = ev.WindowLayoutsChanged.changes || [];
            var m4 = comp._niriWins;
            for (var n = 0; n < ch.length; n++) {
                var cid = ch[n][0], lay = ch[n][1];
                if (m4[cid]) m4[cid].layout = lay;
            }
            comp._niriWins = m4;
            comp._niriWinsRevision++;
        } else if (ev.KeyboardLayoutsChanged) {
            var kl = ev.KeyboardLayoutsChanged.keyboard_layouts || {};
            comp._niriKbNames = kl.names || [];
            comp._niriKbIdx = kl.current_idx || 0;
            comp._syncNiriLayout();
        } else if (ev.KeyboardLayoutSwitched) {
            comp._niriKbIdx = ev.KeyboardLayoutSwitched.idx || 0;
            comp._syncNiriLayout();
        } else if (ev.ConfigLoaded) {
            pNiriOutputs.running = false;
            pNiriOutputs.running = true;
        }
    }

    property int _niriWinsRevision: 0

    function _syncNiriLayout() {
        var n = comp._niriKbNames;
        var i = comp._niriKbIdx;
        if (!n || i < 0 || i >= n.length) return;
        comp.keyboardLayout = /ru/i.test(String(n[i])) ? "RU" : "US";
    }

    function _syncNiriFocus() {
        var ws = comp._niriWs;
        for (var i = 0; i < ws.length; i++) {
            if (!ws[i].is_focused) continue;
            var out = String(ws[i].output || "");
            if (out !== comp._niriFocusedOut) {
                comp._niriFocusedOut = out;
                pNiriOutputs.running = false;
                pNiriOutputs.running = true;
            }
            return;
        }
    }

    // ---------------------------------------------------------- запросы niri
    Process {
        id: pNiriOutputs
        command: ["niri", "msg", "--json", "outputs"]
        running: comp.isNiri
        stdout: StdioCollector {
            onStreamFinished: {
                try { comp._niriOutputs = JSON.parse(text) || ({}); }
                catch (e) {}
            }
        }
    }

    Process {
        id: pNiriKb
        command: ["niri", "msg", "--json", "keyboard-layouts"]
        running: comp.isNiri
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var kl = JSON.parse(text);
                    if (kl) {
                        comp._niriKbNames = kl.names || [];
                        comp._niriKbIdx = kl.current_idx || 0;
                        comp._syncNiriLayout();
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: pNiriFocusedWin
        command: ["niri", "msg", "--json", "focused-window"]
        running: comp.isNiri
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var win = JSON.parse(text);
                    if (win) {
                        comp._niriActiveClass = String(win.app_id || "");
                        comp._niriFullscreen = !!win.is_fullscreen;
                    }
                } catch (e) {}
            }
        }
    }

    readonly property var _niriMonitor: {
        if (!comp.isNiri) return null;
        var name = comp._niriFocusedOut;
        var o = name ? comp._niriOutputs[name] : null;
        if (!o || !o.logical) return null;
        var screen = null;
        var all = Quickshell.screens;
        for (var i = 0; i < all.length; i++)
            if (all[i].name === name) { screen = all[i]; break; }
        return {
            name: name,
            x: o.logical.x, y: o.logical.y,
            width: o.logical.width, height: o.logical.height,
            screen: screen
        };
    }

    // ------------------------------------------------------------- столы niri
    readonly property var _niriWorkspaces: {
        var out = [];
        if (!comp.isNiri) return out;
        var ws = comp._niriWs;
        var targetOut = comp._niriFocusedOut;
        if (!targetOut && ws.length > 0) {
            for (var f = 0; f < ws.length; f++) {
                if (ws[f] && ws[f].is_focused) { targetOut = String(ws[f].output || ""); break; }
            }
            if (!targetOut) targetOut = String(ws[0].output || "");
        }
        for (var i = 0; i < ws.length; i++) {
            var w = ws[i];
            if (!w) continue;
            if (targetOut && String(w.output || "") !== targetOut) continue;
            out.push({
                id: w.idx, idx: w.idx,
                name: String(w.name || w.idx || ""),
                output: String(w.output || ""),
                focused: !!w.is_focused,
                nid: w.id
            });
        }
        out.sort(function (a, b) { return a.idx - b.idx; });
        return out;
    }

    readonly property int _niriFocusedWs: {
        var ws = comp._niriWs;
        for (var i = 0; i < ws.length; i++)
            if (ws[i] && ws[i].is_focused) return ws[i].idx;
        return 1;
    }

    // -------------------------------------------------------------- окна niri
    readonly property var _niriToplevels: {
        var out = [];
        if (!comp.isNiri) return out;
        comp._niriWinsRevision;

        var handles = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : [];
        var byKey = {};
        for (var i = 0; i < handles.length; i++) {
            var h = handles[i];
            if (!h) continue;
            byKey[String(h.appId || "") + " " + String(h.title || "")] = h;
        }

        var mon = comp._niriMonitor;
        var ox = mon ? mon.x : 0, oy = mon ? mon.y : 0;

        for (var id in comp._niriWins) {
            var w = comp._niriWins[id];
            if (!w || !w.layout) continue;
            var lay = w.layout;
            if (!lay.tile_pos_in_workspace_view) continue;
            var off = lay.window_offset_in_tile || [0, 0];
            var size = lay.window_size || [0, 0];
            if (!size[0] || !size[1]) continue;

            var wsIdx = -1;
            for (var j = 0; j < comp._niriWs.length; j++)
                if (comp._niriWs[j].id === w.workspace_id) { wsIdx = comp._niriWs[j].idx; break; }
            if (wsIdx < 0) continue;

            out.push({
                wayland: byKey[String(w.app_id || "") + " " + String(w.title || "")] || null,
                geo: {
                    x: ox + lay.tile_pos_in_workspace_view[0] + off[0],
                    y: oy + lay.tile_pos_in_workspace_view[1] + off[1],
                    w: size[0], h: size[1],
                    ws: wsIdx,
                    cls: String(w.app_id || "")
                }
            });
        }
        return out;
    }
}
