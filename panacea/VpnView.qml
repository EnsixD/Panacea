import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: view
    required property var sys
    property bool settingsMode: false
    implicitHeight: settingsMode ? Math.min(720, content.implicitHeight + 12) : 470
    property var profiles: []
    property var apps: []
    property string error: ""
    readonly property string selectedClient: sys.cfg.vpnPreferredClient || ""
    readonly property bool directControl: !selectedClient || selectedClient.toLowerCase().endsWith("/happ.desktop")
    function refresh() { if (!listProc.running) listProc.running = true; }
    function chooseClient(path) { sys.cfg.vpnPreferredClient = path; sys.cfg.vpnPreferred = ""; sys.saveCfg(); sys.refreshVpnStatus(); }
    function chooseProfile(id) { sys.cfg.vpnPreferredClient = ""; sys.cfg.vpnPreferred = id; sys.saveCfg(); sys.refreshVpnStatus(); }
    Process {
        id: listProc
        command: ["python3", view.sys.scriptDir + "/vpn.py", "list"]
        stdout: StdioCollector { onStreamFinished: {
            try { var d = JSON.parse(text); view.profiles = d.profiles || []; view.apps = d.apps || []; view.error = d.error || ""; }
            catch(e) { view.error = String(e); }
        } }
    }
    Process { id: launch }
    Component.onCompleted: refresh()

    component Choice: Rectangle {
        id: card
        required property var sys
        property string title: ""
        property string subtitle: ""
        property string mark: ""
        property bool chosen: false
        signal picked()
        Layout.fillWidth: true
        implicitHeight: 72
        radius: 18
        color: chosen ? "#202123" : (mouse.containsMouse ? "#191a1c" : "#101113")
        border.width: 1
        border.color: chosen ? "#66686d" : "#252629"
        Behavior on color { ColorAnimation { duration: 140 } }
        RowLayout {
            anchors.fill: parent; anchors.margins: 14; spacing: 12
            Rectangle {
                Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 21
                color: card.chosen ? card.sys.colFg : "#292a2d"
                Text { anchors.centerIn: parent; text: card.mark; color: card.chosen ? card.sys.colBg : card.sys.colFg; font { family: card.sys.fontDisplay; pixelSize: 15; bold: true } }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text { Layout.fillWidth: true; text: card.title; color: card.sys.colFg; elide: Text.ElideRight; font { family: card.sys.fontBody; pixelSize: 14; bold: true } }
                Text { Layout.fillWidth: true; text: card.subtitle; color: card.sys.colMuted; elide: Text.ElideRight; font { family: card.sys.fontBody; pixelSize: 10 } }
            }
            Rectangle {
                Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 11
                color: card.chosen ? card.sys.colFg : "transparent"; border.width: 1; border.color: card.chosen ? card.sys.colFg : "#55575c"
                Text { anchors.centerIn: parent; text: card.chosen ? "✓" : ""; color: card.sys.colBg; font { pixelSize: 12; bold: true } }
            }
        }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !card.sys.vpnBusy; onClicked: card.picked() }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            id: content
            width: parent.width
            spacing: 12
            Rectangle {
                Layout.fillWidth: true; implicitHeight: view.settingsMode ? 92 : 148
                radius: 24; color: "#111214"; border.width: 1; border.color: "#28292c"
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Text { text: view.sys.tr("VPN и регион").toUpperCase(); color: view.sys.colMuted; font { family: view.sys.fontBody; pixelSize: 10; letterSpacing: 2 } }
                    Row {
                        spacing: 12
                        Rectangle {
                            width: 42; height: 42; radius: 21; color: view.sys.vpnConnected ? view.sys.colFg : "#303135"
                            Text { anchors.centerIn: parent; text: view.sys.vpnCountry; color: view.sys.vpnConnected ? view.sys.colBg : view.sys.colFg; font { family: view.sys.fontDisplay; pixelSize: 15; bold: true } }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: view.sys.vpnBusy ? view.sys.tr("Ожидание ответа клиента…") : (view.sys.vpnConnected ? view.sys.tr("Подключено") : view.sys.tr("Отключено")); color: view.sys.colFg; font { family: view.sys.fontBody; pixelSize: 11 } }
                    }
                }
                Rectangle {
                    visible: !view.settingsMode
                    anchors.right: parent.right; anchors.rightMargin: 18; anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                    width: 48; height: 48; radius: 24
                    color: view.sys.vpnConnected ? view.sys.colFg : "#303135"
                    opacity: view.sys.vpnBusy ? 0.45 : 1
                    Text { anchors.centerIn: parent; text: "⏻"; color: view.sys.vpnConnected ? view.sys.colBg : view.sys.colFg; font.pixelSize: 23 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !view.sys.vpnBusy; onClicked: {
                        if (view.directControl) view.sys.togglePreferredVpn();
                        else { launch.command = ["gio", "launch", view.selectedClient]; launch.running = true; }
                    } }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: view.sys.tr("VPN-клиент"); color: view.sys.colFg; font { family: view.sys.fontDisplay; pixelSize: 15; bold: true } }
                Text { text: "↻"; color: view.sys.colMuted; font.pixelSize: 21; MouseArea { anchors.fill: parent; anchors.margins: -7; cursorShape: Qt.PointingHandCursor; onClicked: view.refresh() } }
            }
            Text { Layout.fillWidth: true; text: view.error; visible: view.error.length > 0; wrapMode: Text.WordWrap; color: view.sys.colCrit }
            Repeater {
                model: view.apps
                delegate: Choice {
                    required property var modelData
                    sys: view.sys
                    title: modelData.name
                    mark: modelData.name.substring(0, 2).toUpperCase()
                    chosen: view.selectedClient === modelData.desktop
                    subtitle: modelData.desktop.toLowerCase().endsWith("/happ.desktop") ? view.sys.tr("Управление подключением через Happ") : view.sys.tr("Управление в приложении клиента")
                    onPicked: view.chooseClient(modelData.desktop)
                }
            }
            Text { visible: view.apps.length === 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: view.sys.tr("VPN-приложения не найдены"); color: view.sys.colMuted }
            Text { visible: view.profiles.length > 0; text: "NETWORKMANAGER"; color: view.sys.colMuted; font { family: view.sys.fontBody; pixelSize: 10; letterSpacing: 2 } }
            Repeater {
                model: view.profiles
                delegate: Choice {
                    required property var modelData
                    sys: view.sys; title: modelData.name; mark: "NM"
                    chosen: !view.selectedClient && view.sys.cfg.vpnPreferred === modelData.id
                    subtitle: modelData.active ? view.sys.tr("Подключено") : view.sys.tr("VPN-профиль")
                    onPicked: view.chooseProfile(modelData.id)
                }
            }
            Text { Layout.fillWidth: true; Layout.topMargin: 4; wrapMode: Text.WordWrap; text: view.sys.tr("Выбор сохраняется. Нажмите на страну в острове, чтобы управлять подключением."); color: view.sys.colMuted; font { family: view.sys.fontBody; pixelSize: 10 } }
        }
    }
}
