// NotificationCenter.qml — banners glass arriba-derecha bajo la barra
// (F3-T12, R-NOTIF-SERVER, contrato §3: notif Banner ~5s [INFERIDO]).
// Una sola superficie layer-shell (LayerTop, sin exclusión) con columna:
// ancho ~360, stack vertical máximo 4 + contador "+N más". Sin activos
// Apple: badge con inicial si no hay iconSource, tokens NimbusTokens.
// El auto-hide lo gobierna el servidor C++ (expire_timeout; 0 =
// persistente, default 5000). Clic en banner = acción default si la hay,
// si no descarta; × / Esc descartan (reason 2); Enter activa la default.
import QtQuick
import org.kde.layershell as LayerShellQt

Item {
    id: root
    property int maxVisible: 4
    property int bannerWidth: 360
    property int topOffset: 28 // barra 24 + 4
    property int marginRight: 12
    // notifServer llega por contexto (main.cpp); sin servidor la lista
    // está vacía y la ventana no se muestra (modo sin servidor intacto).
    property var server: typeof notifServer !== "undefined" ? notifServer : null
    property var allBanners: server ? server.banners : []
    property var shown: allBanners.slice(0, maxVisible)
    property int extra: Math.max(0, allBanners.length - maxVisible)

    function defaultKey(b) {
        if (!b || !b.actions)
            return "";
        for (var i = 0; i < b.actions.length; ++i) {
            if (b.actions[i].key === "default")
                return "default";
        }
        return "";
    }
    function activate(b) {
        if (!server || !b)
            return;
        var k = defaultKey(b);
        if (k !== "")
            server.invokeAction(b.nid, k);
        else
            server.dismiss(b.nid);
    }

    Window {
        id: popup
        visible: root.shown.length > 0
        width: root.bannerWidth + 4
        height: col.height + 4
        x: Screen.width - width - root.marginRight
        y: root.topOffset
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "transparent"
        title: "nimbus-notifications"
        LayerShellQt.Window.layer: LayerShellQt.Window.LayerTop
        // Anclas Top|Right (patrón Calendar.qml): sin ancla horizontal
        // layer-shell centra la superficie; x actúa de margen derecho.
        LayerShellQt.Window.anchors: LayerShellQt.Window.AnchorTop | LayerShellQt.Window.AnchorRight
        LayerShellQt.Window.exclusionZone: 0
        LayerShellQt.Window.keyboardInteractivity: LayerShellQt.Window.KeyboardInteractivityOnDemand
        LayerShellQt.Window.scope: "nimbus-notifications"
        LayerShellQt.Window.activateOnShow: false
        Column {
            id: col
            x: 2
            y: 2
            width: root.bannerWidth
            spacing: 8
            Repeater {
                model: root.shown
                delegate: Rectangle {
                    id: banner
                    required property var modelData
                    width: root.bannerWidth
                    // Altura implícita por contenido (sin valores mágicos
                    // fuera de tokens/spacing).
                    height: inner.height + 20
                    radius: 12
                    color: NimbusTokens.popupBg(NimbusTokens.dark)
                    border.color: NimbusTokens.popupBorder(NimbusTokens.dark)
                    border.width: 1
                    objectName: "notifBanner"
                    Accessible.name: (modelData.app || "") + ": " + (modelData.summary || "")
                    Accessible.role: Accessible.AlertMessage
                    focus: index === 0
                    activeFocusOnTab: true
                    // Anillo de foco 2px [HIG §2.5].
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2
                        radius: 14
                        color: "transparent"
                        border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                        border.width: banner.activeFocus ? NimbusTokens.states.focusRingPx : 0
                    }
                    Column {
                        id: inner
                        x: 10
                        y: 10
                        width: parent.width - 20
                        spacing: 6
                        Row {
                            width: parent.width
                            spacing: 8
                            // Icono: imagen si hay file://, si no badge
                            // propio con la inicial de la app.
                            Item {
                                width: 28
                                height: 28
                                anchors.verticalCenter: parent.verticalCenter
                                Image {
                                    anchors.fill: parent
                                    source: modelData.iconSource || ""
                                    visible: (modelData.iconSource || "") !== ""
                                    fillMode: Image.PreserveAspectFit
                                    Accessible.ignored: true
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 7
                                    color: NimbusTokens.accentColor(NimbusTokens.dark)
                                    visible: (modelData.iconSource || "") === ""
                                    Text {
                                        anchors.centerIn: parent
                                        text: (modelData.app || "?").charAt(0).toUpperCase()
                                        font.family: NimbusTokens.fontFamily
                                        font.pixelSize: 14
                                        font.weight: 700
                                        color: "white"
                                    }
                                }
                            }
                            Column {
                                width: parent.width - 28 - 8 - 24
                                spacing: 1
                                Text {
                                    width: parent.width
                                    text: (modelData.app || "") + " · " + (modelData.timeStr || "")
                                    font.family: NimbusTokens.fontFamily
                                    font.pixelSize: NimbusTokens.type.t11.size
                                    color: NimbusTokens.faintText(NimbusTokens.dark)
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.summary || ""
                                    font.family: NimbusTokens.fontFamily
                                    font.pixelSize: NimbusTokens.type.t13b.size
                                    font.weight: NimbusTokens.type.t13b.weight
                                    color: NimbusTokens.colors(NimbusTokens.dark).label
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                }
                            }
                            Text {
                                width: 24
                                height: 24
                                text: "×"
                                font.pixelSize: 16
                                color: NimbusTokens.faintText(NimbusTokens.dark)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.server.dismiss(banner.modelData.nid)
                                    Accessible.name: "Descartar notificación"
                                    Accessible.role: Accessible.Button
                                }
                            }
                        }
                        Text {
                            width: parent.width
                            visible: (modelData.body || "") !== ""
                            text: modelData.body || ""
                            textFormat: Text.RichText
                            font.family: NimbusTokens.fontFamily
                            font.pixelSize: NimbusTokens.type.t12.size
                            color: NimbusTokens.subText(NimbusTokens.dark)
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                        Row {
                            spacing: 8
                            visible: modelData.actions && modelData.actions.length > 0
                            Repeater {
                                model: banner.modelData.actions || []
                                delegate: Rectangle {
                                    required property var modelData
                                    width: actLabel.width + 20
                                    height: 26
                                    radius: 8
                                    color: NimbusTokens.hoverFill(NimbusTokens.dark)
                                    border.color: NimbusTokens.accentColor(NimbusTokens.dark)
                                    border.width: actArea.activeFocus ? NimbusTokens.states.focusRingPx : 1
                                    Text {
                                        id: actLabel
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: NimbusTokens.fontFamily
                                        font.pixelSize: NimbusTokens.type.t12.size
                                        color: NimbusTokens.accentColor(NimbusTokens.dark)
                                    }
                                    MouseArea {
                                        id: actArea
                                        anchors.fill: parent
                                        activeFocusOnTab: true
                                        onClicked: root.server.invokeAction(banner.modelData.nid, modelData.key)
                                        Accessible.name: modelData.label
                                        Accessible.role: Accessible.Button
                                    }
                                }
                            }
                        }
                    }
                    MouseArea {
                        // Clic en el cuerpo: default o descartar. Debajo de
                        // los MouseArea hijos (×, botones) en z.
                        anchors.fill: parent
                        z: -1
                        onClicked: root.activate(banner.modelData)
                    }
                    Keys.onEscapePressed: root.server.dismiss(banner.modelData.nid)
                    Keys.onReturnPressed: root.activate(banner.modelData)
                    Keys.onEnterPressed: root.activate(banner.modelData)
                }
            }
            Text {
                visible: root.extra > 0
                text: "+" + root.extra + " más"
                font.family: NimbusTokens.fontFamily
                font.pixelSize: NimbusTokens.type.t12.size
                color: NimbusTokens.subText(NimbusTokens.dark)
                horizontalAlignment: Text.AlignRight
                width: parent.width
                objectName: "notifMore"
            }
        }
    }
}
