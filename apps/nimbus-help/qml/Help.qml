// Help.qml — F11-T06. Visor offline: pestañas Guía/Atajos, selector
// ES/EN, búsqueda incremental (cuenta + filtrado por líneas), Markdown
// básico vía Text.Markdown (títulos, listas, tablas, enlaces;
// sin HTML/JS). Tokens Tahoe contrato §2.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    objectName: "helpWindow"
    width: 720
    height: 520
    minimumWidth: 600
    minimumHeight: 400
    visible: true
    title: "Ayuda de Nimbus"
    color: "transparent"

    property var c: ({
        "label": "#FFFFFF", "label2": "#EBEBF5", "bg": "#000000",
        "bgElevated": "#2C2C2E", "bg2": "#1C1C1E", "accent": "#0A84FF",
        "separator": "#38383A"
    })
    property int tab: (typeof initialTab !== "undefined" && initialTab === "shortcuts") ? 1 : 0
    property string query: ""
    function fullText() { return root.tab === 0 ? backend.guideText : backend.shortcutsText; }
    function shownText() {
        var t = fullText();
        if (root.query === "")
            return t;
        var q = root.query.toLowerCase();
        var lines = t.split("\n");
        var kept = [];
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].toLowerCase().indexOf(q) !== -1)
                kept.push(lines[i]);
        }
        return "Coincidencias de «" + root.query + "»: " + kept.length + "\n\n" + kept.join("\n");
    }
    function matchCount() {
        if (root.query === "")
            return 0;
        var q = root.query.toLowerCase();
        return fullText().toLowerCase().split(q).length - 1;
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: root.c.bgElevated
        border.color: root.c.separator
        border.width: 1
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                TabBar {
                    id: tabs
                    Layout.preferredWidth: 240
                    currentIndex: root.tab
                    onCurrentIndexChanged: root.tab = currentIndex
                    TabButton { text: "Guía"; width: 120 }
                    TabButton { text: "Atajos"; width: 120 }
                }
                Item { Layout.fillWidth: true }
                ComboBox {
                    objectName: "langCombo"
                    model: ["ES", "EN"]
                    currentIndex: backend.language === "en" ? 1 : 0
                    onActivated: backend.setLanguage(currentIndex === 1 ? "en" : "es")
                }
            }
            TextField {
                objectName: "searchField"
                Layout.fillWidth: true
                placeholderText: "Buscar…"
                onTextChanged: root.query = text
            }
            Text {
                text: root.query === "" ? backend.guidePath : (matchCount() + " coincidencias")
                font.pixelSize: 11
                color: root.c.label2
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                TextArea {
                    objectName: "docText"
                    text: root.shownText()
                    readOnly: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.MarkdownText
                    selectByMouse: true
                    color: root.c.label
                    background: Rectangle { color: root.c.bg }
                }
            }
        }
    }
}
