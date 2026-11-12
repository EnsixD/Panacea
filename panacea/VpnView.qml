import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: view
    required property var sys
    property bool settingsMode: false
    implicitHeight: settingsMode ? Math.max(300, vpnContent.implicitHeight) : 430
    property var profiles: []
    property var apps: []
    property string error: ""
    property string pending: ""
    function refresh() { if (!listProc.running) listProc.running = true; }
    function toggle(profile) {
        if (action.running) return;
        sys.cfg.vpnPreferred = profile.id; sys.saveCfg();
        pending = profile.active ? "down" : "up";
        action.command = ["python3", sys.scriptDir + "/vpn.py", pending, profile.id];
        action.running = true;
    }
    Process {
        id: listProc
        command: ["python3", view.sys.scriptDir + "/vpn.py", "list"]
        stdout: StdioCollector { onStreamFinished: { try { var d = JSON.parse(text); view.profiles = d.profiles || []; view.apps = d.apps || []; view.error = d.error || ""; view.sys.vpnActiveIds = view.profiles.filter(p => p.active).map(p => p.id); view.sys.vpnConnected = view.sys.vpnActiveIds.length > 0 || !!d.tunnelActive; } catch(e) { view.error = String(e); } } }
    }
    Process {
        id: action
        stdout: StdioCollector { onStreamFinished: {
            try {
                var d = JSON.parse(text);
                view.error = d.error || "";
                if (d.ok) {
                    view.profiles = d.profiles || [];
                    view.sys.vpnActiveIds = view.profiles.filter(p => p.active).map(p => p.id); view.sys.vpnConnected = view.sys.vpnActiveIds.length > 0 || !!d.tunnelActive;
                    view.sys.announceVpnChange(view.pending);
                } else { notify.command = ["notify-send", "--app-name", "Panacea VPN", view.sys.tr("Ошибка VPN"), view.error]; notify.running = true; }
            } catch(e) { view.error = String(e); }
        } }
    }
    Process { id: notify }
    Process { id: launch }
    Component.onCompleted: refresh()
    ColumnLayout {
        id: vpnContent
        anchors.fill: parent; spacing: 10
        Text { Layout.fillWidth: true; text: view.sys.tr("VPN и регион"); color: view.sys.colFg; font { family: view.sys.fontDisplay; pixelSize: 19; bold: true } }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: view.sys.colMuted; text: view.sys.tr("Выберите профиль: он запомнится для быстрого подключения.") }
        Text { visible: view.error.length > 0; Layout.fillWidth: true; color: view.sys.colCrit; wrapMode: Text.WordWrap; text: view.error }
        Text { visible: view.profiles.length === 0; Layout.fillWidth: true; color: view.sys.colMuted; wrapMode: Text.WordWrap; text: view.sys.tr("VPN-профили NetworkManager не найдены.") }
        Repeater {
            model: view.profiles
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true; Layout.preferredHeight: 50; radius: 12
                color: Qt.rgba(1,1,1,0.07)
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: modelData.name; color: view.sys.colFg; font { family: view.sys.fontBody; pixelSize: 13; bold: true } }
                        Text { text: modelData.active ? view.sys.tr("Подключено") : (view.sys.cfg.vpnPreferred === modelData.id ? view.sys.tr("Выбрано") : view.sys.tr("Отключено")); color: modelData.active ? "#8fd5a6" : view.sys.colMuted; font.pixelSize: 10 }
                    }
                    Text { text: modelData.active ? "●" : "○"; color: modelData.active ? "#8fd5a6" : view.sys.colMuted; font.pixelSize: 18 }
                }
                MouseArea { anchors.fill: parent; enabled: !action.running; cursorShape: Qt.PointingHandCursor; onClicked: { if (view.settingsMode) { view.sys.cfg.vpnPreferredClient = ""; view.sys.cfg.vpnPreferred = modelData.id; view.sys.saveCfg(); } else view.toggle(modelData); } }
            }
        }
        Text { visible: view.apps.length > 0; text: view.sys.tr("Другие VPN-приложения"); color: view.sys.colMuted; font.pixelSize: 11 }
        Repeater {
            model: view.apps
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true; Layout.preferredHeight: 35; radius: 10; color: Qt.rgba(1,1,1,0.05)
                Text { anchors.centerIn: parent; text: modelData.name + (view.sys.cfg.vpnPreferredClient === modelData.desktop ? " ✓" : ""); color: view.sys.colFg }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { view.sys.cfg.vpnPreferredClient = modelData.desktop; view.sys.cfg.vpnPreferred = ""; view.sys.saveCfg(); if (!view.settingsMode) { launch.command = ["gio", "launch", modelData.desktop]; launch.running = true; } } }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
