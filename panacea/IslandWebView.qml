import QtQuick
import QtWebEngine
WebEngineView {
    profile: WebEngineProfile { storageName: "panacea-chat"; persistentCookiesPolicy: WebEngineProfile.AllowPersistentCookies }
}
