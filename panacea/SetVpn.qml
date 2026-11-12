import QtQuick
import QtQuick.Layouts
ColumnLayout {
    id: page
    property var sys
    Layout.fillWidth: true
    Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: page.sys.colMuted; text: page.sys.tr("Выберите клиент или профиль. Выбор сохраняется без подключения.") }
    Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: page.sys.colMuted; text: page.sys.tr("Сторонний клиент открывается для управления VPN. Профили NetworkManager переключаются прямо в острове.") }
    VpnView { sys: page.sys; settingsMode: true; Layout.fillWidth: true; Layout.preferredHeight: implicitHeight }
}
