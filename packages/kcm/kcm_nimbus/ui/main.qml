// F8-T01 — KCM Nimbus: raíz con sidebar, búsqueda y 6 páginas.
// Contrato Tahoe: colores semánticos Kirigami.Theme (nunca hex), iconos con
// Accessible.name, hit ≥24px. i18n(): cadenas extraíbles con xgettext (F11-T05).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: root

    implicitWidth: Kirigami.Units.gridUnit * 40
    implicitHeight: Kirigami.Units.gridUnit * 30

    // Tabla central de páginas: título + icono + id. Sin títulos dispersos.
    property var pageDefs: [
        { id: "appearance", title: i18n("Apariencia"), icon: "preferences-desktop-theme" },
        { id: "network", title: i18n("Red"), icon: "network-wireless" },
        { id: "shortcuts", title: i18n("Atajos"), icon: "preferences-desktop-keyboard" },
        { id: "accessibility", title: i18n("Accesibilidad"), icon: "preferences-desktop-accessibility" },
        { id: "system", title: i18n("Sistema"), icon: "preferences-system" },
        { id: "updates", title: i18n("Actualizaciones"), icon: "system-software-update" }
    ]
    property string currentPage: "appearance"

    function matchesFilter(title) {
        if (searchField.text.length === 0) {
            return true;
        }
        return title.toLowerCase().indexOf(searchField.text.toLowerCase()) !== -1;
    }
    function pageIndex(id) {
        for (let i = 0; i < pageDefs.length; i++) {
            if (pageDefs[i].id === id) {
                return i;
            }
        }
        return 0;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        // Cabecera Nimbus.
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon {
                source: "preferences-system"
                implicitWidth: Kirigami.Units.iconSizes.large
                implicitHeight: Kirigami.Units.iconSizes.large
                Accessible.name: i18n("Ajustes Nimbus")
            }
            ColumnLayout {
                spacing: 0
                Kirigami.Heading {
                    level: 2
                    text: i18n("Nimbus")
                }
                QQC2.Label {
                    text: i18n("Ajustes del sistema en lenguaje claro")
                    color: Kirigami.Theme.disabledTextColor
                }
            }
        }

        Kirigami.SearchField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: i18n("Buscar ajustes…")
            Accessible.name: i18n("Buscar ajustes")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.largeSpacing

            // Sidebar (240px, contrato §2.3 sidebar-w).
            QQC2.ScrollView {
                Layout.preferredWidth: 240
                Layout.fillHeight: true
                Layout.minimumWidth: 200
                ListView {
                    id: sidebar
                    model: root.pageDefs
                    keyNavigationWraps: true
                    Accessible.name: i18n("Secciones de ajustes")
                    delegate: QQC2.ItemDelegate {
                        required property var modelData
                        required property int index
                        width: sidebar.width
                        height: visible ? implicitHeight : 0
                        visible: root.matchesFilter(modelData.title)
                        // Hit ≥24px (contrato §2.3, floor Nimbus).
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon {
                                source: modelData.icon
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: modelData.title
                                elide: Text.ElideRight
                            }
                        }
                        highlighted: root.currentPage === modelData.id
                        Accessible.name: modelData.title
                        onClicked: root.currentPage = modelData.id
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillHeight: true
            }

            // Contenido: 6 páginas, solo la activa visible.
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.pageIndex(root.currentPage)
                AppearancePage {
                }
                NetworkPage {
                }
                ShortcutsPage {
                }
                AccessibilityPage {
                }
                SystemPage {
                }
                UpdatesPage {
                }
            }
        }
    }
}
