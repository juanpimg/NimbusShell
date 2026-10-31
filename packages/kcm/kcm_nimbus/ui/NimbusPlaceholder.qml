// F8-T01 — Placeholder común de las 5 páginas pendientes (F8-T03…T07).
// Lenguaje llano + salto al KCM existente (embeber por salto, F8-kcm.md §2).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

KCMUtils.SimpleKCM {
    id: placeholder

    property string heading: ""
    property string explanation: ""
    // [{ "label": "...", "target": "kcm_id" | "app:binario" }]
    property var jumpButtons: []
    property var kcmRef: (typeof kcm !== "undefined") ? kcm : null
    property string statusMessage: ""

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        Kirigami.Heading {
            level: 2
            text: placeholder.heading
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: placeholder.explanation
        }
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: placeholder.jumpButtons
                delegate: QQC2.Button {
                    required property var modelData
                    text: modelData.label
                    Accessible.name: modelData.label
                    onClicked: {
                        let ok = false;
                        if (placeholder.kcmRef) {
                            if (modelData.target.startsWith("app:")) {
                                ok = placeholder.kcmRef.openApp(modelData.target.slice(4));
                            } else {
                                ok = placeholder.kcmRef.openKcm(modelData.target);
                            }
                        }
                        if (!ok) {
                            placeholder.statusMessage = i18n("No disponible en este sistema.");
                        }
                    }
                }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: placeholder.statusMessage.length > 0
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.neutralTextColor
            text: placeholder.statusMessage
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Vista provisional: la página completa con lenguaje llano llega en su tarea F8.")
        }
    }
}
