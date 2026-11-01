// Spotlight.qml — overlay centrado ~680px (F6-T01, contrato §3).
// Glass oscuro, campo grande, resultados + preview, footer Cmd+1..4.
// Tokens dark §2.1 hardcodeados (light/dark completo vive en F8-T05).
//
// F6-T07 — TECLADO Y ACCESIBILIDAD (todos sin ratón, documentados aquí):
//   Tab / Shift+Tab .... recorre Campo → Resultados → Acciones →
//                        Pestañas footer → Campo (sin trampas; KeyNavigation)
//   ↑ / ↓ .............. mueve selección (en campo y en lista)
//   Home / End ......... primera / última selección (en lista)
//   RePág / AvPág ...... ±10 selecciones (en lista)
//   Enter .............. activa la selección (campo, lista, botón enfocado)
//   Espacio ............ activa el botón enfocado (acciones/pestañas)
//   Esc ................ cierra el overlay (foco en cualquier parte)
//   Cmd+1..4 ........... pestañas Apps/Archivos/Acciones/Portapapeles
//   A–L ................ selecciona el resultado N visible (foco en lista;
//                        en el campo A–L escribe texto, no salta)
//   Ctrl+Tab ........... fallback explícito a KRunner (F6-T02; en
//                        Portapapeles no hay fallback: datos locales).
//   NOTA Tab: antes Tab lanzaba KRunner (F6-T02); desde F6-T07 Tab navega
//   (a11y: Tab nunca debe quedar atrapado) y KRunner pasa a Ctrl+Tab +
//   botón "Buscar en KRunner". Ruling en docs/plans/evidence/F6-T07-nested.md.
// Foco visible: anillo blanco 2px + borde accent en el control enfocado
// (tokens focusCol/focusW). Contraste auditado en F6-T07-nested.md:
// texto normal ≥4.5:1 salvo selección transient (blanco sobre accent 3.65,
// paridad Tahoe + marcador ●/posición + announce, no solo color).
// Hit targets: filas 44px, botones ≥36px, pills ≥32px, pestañas 32px.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "PreviewGuard.js" as PreviewGuard

ApplicationWindow {
    id: root
    objectName: "spotlightWindow"
    width: 680
    height: 460
    visible: false // main.cpp la muestra en --demo/--query/--shot o al alternar
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    color: "transparent"
    title: "Spotlight"

    property int currentIndex: 0
    property string tab: "apps" // apps | files | actions | clipboard
    property string clipView: "history" // history | emoji (solo tab clipboard)
    property string emojiCategory: "" // "" = todas
    property var tabNames: ({
            "apps": "Apps",
            "files": "Archivos",
            "actions": "Acciones",
            "clipboard": "Portapapeles"
        })
    property var filtered: []
    property string lastQuery: ""
    property int clipLatency: -1 // F6-T06: latencia síncrona clips/emoji
    // F6-T09 (G1): item seleccionado a prueba de índices inválidos. El
    // ListView escribe un -1 transitorio al recambiar el modelo (pasa por
    // count=0); sin esta guarda, filtered[-1] lanzaba TypeError en el
    // preview. Sin cambio visible: null muestra los fallbacks de abajo.
    property var previewItem: PreviewGuard.safeAt(root.filtered, root.currentIndex)
    // F6-T02: locales primero; KRunner solo como fallback (Tab o botón).
    property bool krunnerMode: false
    // F6-T07: tokens de foco visible (anillo blanco 2px sobre accent).
    property color focusCol: "#FFFFFF"
    property color accentCol: "#0A84FF"
    property int focusW: 2

    // F6-T07: anuncia cambios a lectores (Orca/AT-SPI vía QAccessible).
    function announce(msg) {
        Accessible.announce(root, msg);
    }

    function announceSelection() {
        // F6-T09 (G1): accesor seguro (cubre lista vacía e índice -1).
        var it = PreviewGuard.safeAt(root.filtered, root.currentIndex);
        if (it === null) {
            root.announce(qsTr("Sin resultados"));
            return;
        }
        root.announce(it.text + ", " + it.subtext + ". " + (root.currentIndex + 1) + " de " + root.filtered.length);
    }

    function setTab(t) {
        // F6-T07: cambio de pestaña único (teclado, ratón y Cmd+1..4).
        if (root.tabNames[t] === undefined)
            return;
        root.tab = t;
        root.announce(root.tabNames[t]);
        root.doSearch();
    }

    // F6-T09: foco de teclado tras apertura vía DBus (showTab/toggleTab).
    function focusSearch() {
        searchField.forceActiveFocus();
    }

    function refreshFilter() {
        // F6-T06: clipboard/emoji son síncronos (sin señal): se recomputan.
        if (root.tab === "clipboard") {
            root.doSearch();
            return;
        }
        var all = root.krunnerMode ? backend.matches : nimbus.localMatches;
        var q = searchField.text;
        root.lastQuery = q;
        root.filtered = all.filter(function (m) {
            return m.category === root.tab;
        });
        // Si la pestaña queda vacía pero hay resultados, mostrar todos.
        if (root.filtered.length === 0 && all.length > 0 && q !== "")
            root.filtered = all;
        root.currentIndex = 0;
    }

    function doSearch() {
        // F6-T06: clipboard local (klipper→history2.lst→wl-paste) y emoji
        // propios; sin KRunner (R-KRUNNER: sin passwords/Universal Clipboard).
        if (root.tab === "clipboard" && !root.krunnerMode) {
            root.lastQuery = searchField.text;
            if (root.clipView === "emoji")
                root.filtered = nimbus.emojiList(searchField.text, root.emojiCategory);
            else
                root.filtered = nimbus.clipboardEntries(searchField.text);
            root.clipLatency = nimbus.lastClipLatency();
            root.currentIndex = 0;
            return;
        }
        if (root.krunnerMode)
            backend.search(searchField.text);
        else {
            // Fast-path local (<50ms); si no hay nada, cae a KRunner solo.
            nimbus.searchLocal(searchField.text, root.tab);
            if (nimbus.localMatches.length === 0 && searchField.text.trim() !== "")
                backend.search(searchField.text);
        }
    }

    function useKRunner() {
        root.krunnerMode = true;
        nimbus.requestKRunner();
        backend.search(searchField.text);
    }

    function activateCurrent(action) {
        if (root.filtered.length === 0)
            return;
        // F6-T06: Pegar/Copiar copia el texto completo y cierra el overlay.
        // (Autopegado en la app destino: no implementado, ver evidencia.)
        if (root.tab === "clipboard" && !root.krunnerMode) {
            var item = root.filtered[root.currentIndex];
            if (item.localKind === "emoji")
                nimbus.recordEmoji(item.localExec);
            else
                nimbus.recordUse(item.localId);
            if (nimbus.copyToClipboard(item.localExec)) {
                root.visible = false;
                if (action === "paste")
                    nimbus.pasteFromClipboard();
            }
            return;
        }
        if (root.krunnerMode)
            backend.activate(indexOf(root.filtered[root.currentIndex]));
        else
            nimbus.activateLocal(root.currentIndex, action === undefined ? "open" : action);
    }

    Connections {
        target: backend
        function onMatchesChanged() {
            if (root.krunnerMode)
                root.refreshFilter();
        }
    }

    Connections {
        target: nimbus
        function onLocalMatchesChanged() {
            if (!root.krunnerMode)
                root.refreshFilter();
        }
    }

    // F6-T07: atajos globales (funcionan con foco en cualquier parte;
    // sin trampas: Esc cierra, Cmd+1..4 cambia pestaña, Ctrl+Tab = KRunner).
    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }
    Shortcut {
        sequence: "Ctrl+Tab"
        onActivated: {
            if (root.tab !== "clipboard")
                root.useKRunner(); // F6-T06: en Portapapeles no hay fallback
        }
    }
    Shortcut {
        sequence: "Meta+1"
        onActivated: root.setTab("apps")
    }
    Shortcut {
        sequence: "Meta+2"
        onActivated: root.setTab("files")
    }
    Shortcut {
        sequence: "Meta+3"
        onActivated: root.setTab("actions")
    }
    Shortcut {
        sequence: "Meta+4"
        onActivated: root.setTab("clipboard")
    }

    Component.onCompleted: {
        // Test nested: pestaña/vista iniciales (--tab/--clipview).
        if (initialTab === "apps" || initialTab === "files" || initialTab === "actions" || initialTab === "clipboard")
            root.tab = initialTab;
        if (initialClipView === "emoji" || initialClipView === "history")
            root.clipView = initialClipView;
        if (initialQuery !== "")
            searchField.text = initialQuery;
        else
            // onTextChanged+debounce lanza
            root.doSearch(); // clipboard con consulta vacía no dispara debounce
        searchField.forceActiveFocus();
    }

    // Cierra al perder foco / Esc (sin robar teclado oculto: visible=false).
    onActiveChanged: {
        if (!root.active && root.visible)
            root.visible = false;
    }

    Rectangle {
        anchors.fill: parent
        radius: 20 // r-lg §2.3
        color: "#2C2C2E" // bgElevated dark [HIG]
        opacity: 0.94
        border.color: "#38383A" // separator opaco dark [HIG]
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // Campo de búsqueda grande.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 8
            Text {
                text: "🔍"
                font.pixelSize: 20
                Accessible.name: "Buscar"
            }
            TextField {
                id: searchField
                Layout.fillWidth: true
                font.pixelSize: 22 // t22 title1 [HIG]
                placeholderText: "Buscar en Spotlight"
                placeholderTextColor: "#EBEBF5"
                opacity: 1
                color: "#FFFFFF" // label dark [HIG]
                // F6-T07: anillo de foco visible (blanco 2px sobre accent).
                background: Rectangle {
                    color: "transparent"
                    radius: 8
                    border.color: searchField.activeFocus ? root.focusCol : "transparent"
                    border.width: root.focusW
                }
                Accessible.name: "Campo de búsqueda Spotlight"
                Accessible.description: "Escribe para buscar. Flechas arriba y abajo cambian la selección. Tab recorre los controles. Control Tab usa KRunner. Escape cierra."
                Accessible.role: Accessible.EditableText
                // F6-T07: Tab/Shift+Tab navegan (KeyNavigation, sin trampas).
                // En Portapapeles el ciclo pasa por las vistas Historial|Emoji.
                KeyNavigation.tab: root.tab === "clipboard" ? clipRow : results
                KeyNavigation.backtab: footTabs
                onTextChanged: {
                    root.krunnerMode = false; // cada tecla vuelve al fast-path
                    searchDebounce.restart();
                }
                onAccepted: root.activateCurrent("open")
                // Debounce 200ms: evita relanzar KRunner por cada tecla
                // (doble launchQuery deja a RunnerManager sin queryFinished).
                Timer {
                    id: searchDebounce
                    interval: 200
                    repeat: false
                    onTriggered: root.doSearch()
                }
                function indexOf(item) {
                    var all = root.krunnerMode ? backend.matches : nimbus.localMatches;
                    for (var i = 0; i < all.length; i++)
                        if (all[i].text === item.text && all[i].subtext === item.subtext)
                            return i;
                    return root.currentIndex;
                }
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Down) {
                        root.currentIndex = Math.min(root.currentIndex + 1, root.filtered.length - 1);
                        results.forceActiveFocus();
                        root.announceSelection();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.currentIndex = Math.max(root.currentIndex - 1, 0);
                        root.announceSelection();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.visible = false;
                        event.accepted = true;
                    }
                // F6-T07: Tab/Shift+Tab NO se aceptan aquí: los mueve
                // KeyNavigation (campo→resultados→acciones→pestañas).
                // Ctrl+Tab (fallback KRunner) vive en Shortcut global.
                }
            }
            Text {
                visible: backend.querying
                text: "…"
                color: "#0A84FF" // accent dark [HIG]
                font.pixelSize: 22
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#38383A"
        }

        // F6-T06: sub-vistas de Portapapeles (Cmd+4): Historial | Emoji.
        // F6-T07: tramo Tab del ciclo (campo→clipRow→resultados→…).
        // FocusScope: Tab avanza solo entre pills/combo; al salir usa
        // KeyNavigation (resultados). Solo es parada Tab en su pestaña.
        FocusScope {
            id: clipRow
            visible: root.tab === "clipboard"
            activeFocusOnTab: visible
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            KeyNavigation.tab: results
            KeyNavigation.backtab: searchField
            Accessible.role: Accessible.Grouping
            Accessible.name: qsTr("Vistas del portapapeles")
            RowLayout {
                anchors.fill: parent
                spacing: 8
                Repeater {
                    model: [["history", qsTr("Historial")], ["emoji", qsTr("Emoji")]]
                    delegate: Rectangle {
                        width: 96
                        height: 32 // F6-T07: hit target ≥32px (antes 90x22)
                        radius: 11
                        color: root.clipView === modelData[0] ? "#0A84FF" : "transparent"
                        border.color: clipPill.activeFocus ? root.focusCol : "#0A84FF"
                        border.width: clipPill.activeFocus ? root.focusW : 1
                        Text {
                            anchors.centerIn: parent
                            text: modelData[1]
                            color: root.clipView === modelData[0] ? "#FFFFFF" : "#0A84FF"
                            font.pixelSize: 12 // F6-T07: ≥12px (antes 11)
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData[0] === "history" ? qsTr("Vista Historial") : qsTr("Vista Emoji")
                        Accessible.description: qsTr("Pulsa Enter para mostrar esta vista del portapapeles")
                        FocusScope {
                            id: clipPill
                            anchors.fill: parent
                            activeFocusOnTab: true
                            Keys.onPressed: function (event) {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                    root.clipView = modelData[0];
                                    root.announce(modelData[1]);
                                    root.doSearch();
                                    event.accepted = true;
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.clipView = modelData[0];
                                root.announce(modelData[1]);
                                root.doSearch();
                            }
                        }
                    }
                }
                // Filtro por categoría emoji (i18n preparada: qsTr).
                ComboBox {
                    visible: root.clipView === "emoji"
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 28 // F6-T07: hit target (antes 24)
                    model: ["", "caras", "gestos", "animales", "comida", "naturaleza", "objetos", "simbolos", "viajes"]
                    displayText: root.emojiCategory === "" ? qsTr("Todas") : root.emojiCategory
                    Accessible.name: qsTr("Categoría de emoji")
                    Accessible.description: qsTr("Filtra los emoji por categoría")
                    Accessible.role: Accessible.ComboBox
                    onActivated: function (index) {
                        root.emojiCategory = index === 0 ? "" : model[index];
                        root.announce(displayText);
                        root.doSearch();
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    visible: root.clipView === "history"
                    text: qsTr("Enter: copiar y cerrar")
                    color: "#EBEBF5"
                    opacity: 0.4
                    font.pixelSize: 11
                }
            } // RowLayout interior de clipRow
        }

        // Resultados + preview lateral.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ListView {
                id: results
                Layout.preferredWidth: 400
                Layout.fillHeight: true
                Layout.margins: 8
                model: root.filtered
                currentIndex: root.currentIndex
                // F6-T09 (G1): ignora el -1 transitorio del ListView al
                // recambiar el modelo (pasa por count=0); antes llegaba a
                // root.currentIndex y rompía el preview con TypeError.
                onCurrentIndexChanged: {
                    if (PreviewGuard.isValidIndex(currentIndex, results.count))
                        root.currentIndex = currentIndex;
                }
                clip: true
                spacing: 2
                // F6-T07: parada Tab del ciclo + rol accesible.
                activeFocusOnTab: true
                KeyNavigation.tab: actionRow
                KeyNavigation.backtab: root.tab === "clipboard" ? clipRow : searchField
                Accessible.role: Accessible.List
                Accessible.name: "Resultados"
                Accessible.description: "Flechas arriba y abajo para elegir. Teclas A a L saltan al resultado. Enter abre. Tab sigue a las acciones."
                Keys.onPressed: function (event) {
                    var n = root.filtered.length;
                    if (event.key === Qt.Key_Down) {
                        root.currentIndex = Math.min(root.currentIndex + 1, n - 1);
                        root.announceSelection();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.currentIndex = Math.max(root.currentIndex - 1, 0);
                        root.announceSelection();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Home) {
                        root.currentIndex = 0;
                        root.announceSelection();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_End) {
                        root.currentIndex = Math.max(n - 1, 0);
                        root.announceSelection();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageDown) {
                        root.currentIndex = Math.min(root.currentIndex + 10, n - 1);
                        root.announceSelection();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_PageUp) {
                        root.currentIndex = Math.max(root.currentIndex - 10, 0);
                        root.announceSelection();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.activateCurrent("open");
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.visible = false;
                        event.accepted = true;
                    } else if (event.text.length === 1) {
                        // F6-T07: Quick Keys A–L (solo con foco en la
                        // lista: en el campo estas teclas escriben texto).
                        var k = event.text.toUpperCase();
                        var pos = "ABCDEFGHIJKL".indexOf(k);
                        if (pos >= 0 && pos < n) {
                            root.currentIndex = pos;
                            root.announceSelection();
                            event.accepted = true;
                        }
                    }
                // Tab/Shift+Tab: los mueve KeyNavigation (sin trampas).
                }
                delegate: Rectangle {
                    width: results.width
                    height: 44 // hit target 44px (ideal Apple/HIG)
                    radius: 8 // r-sm §2.3
                    color: index === root.currentIndex ? "#0A84FF" : "transparent" // accent dark
                    // F6-T07: anillo de foco visible sobre la selección.
                    border.color: (results.activeFocus && index === root.currentIndex) ? root.focusCol : "transparent"
                    border.width: (results.activeFocus && index === root.currentIndex) ? root.focusW : 0
                    Accessible.role: Accessible.ListItem
                    Accessible.name: modelData.text + ", " + modelData.subtext
                    Accessible.description: "Motor " + modelData.runner + ". Tecla " + (index < 12 ? "ABCDEFGHIJKL".charAt(index) : "")
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 6
                            color: "#1C1C1E" // bg2 dark
                            Text {
                                anchors.centerIn: parent
                                // Quick Key por posición VISIBLE (A–L); el backend
                                // numera sobre todos los matches sin filtrar.
                                text: index < 12 ? "ABCDEFGHIJKL".charAt(index) : "▤"
                                color: "#FFFFFF"
                                font.pixelSize: 13
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: modelData.text
                                color: "#FFFFFF"
                                font.pixelSize: 13 // t13 body [HIG]
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.subtext
                                color: "#EBEBF5" // label2 dark [HIG]
                                opacity: 0.6
                                font.pixelSize: 12 // t12 [HIG]
                                elide: Text.ElideRight
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.currentIndex = index;
                            root.activateCurrent("open");
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: "#38383A"
            }

            // Preview lateral (contrato §3: preview derecha).
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: root.previewItem !== null ? root.previewItem.text : "Sin resultados"
                    color: "#FFFFFF"
                    font.pixelSize: 17 // t17 title2 [HIG]
                    font.bold: true
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    text: root.previewItem !== null ? root.previewItem.subtext : "Escribe para buscar con KRunner"
                    color: "#EBEBF5"
                    opacity: 0.6
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                }
                Text {
                    visible: root.filtered.length > 0
                    text: root.previewItem !== null ? ("Motor: " + root.previewItem.runner) : ""
                    color: "#EBEBF5"
                    opacity: 0.3
                    font.pixelSize: 11 // t11 [HIG]
                }
                Item {
                    Layout.fillHeight: true
                }
                // Acciones locales (F6-T02): Abrir / Copiar / Revelar.
                // F6-T06: en Portapapeles solo Copiar/Pegar (copia y cierra).
                // F6-T07: tramo Tab (resultados→actionRow→pestañas).
                FocusScope {
                    id: actionRow
                    visible: root.filtered.length > 0 && !root.krunnerMode
                    activeFocusOnTab: visible
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    KeyNavigation.tab: footTabs
                    KeyNavigation.backtab: results
                    Accessible.role: Accessible.Grouping
                    Accessible.name: "Acciones"
                    RowLayout {
                        anchors.fill: parent
                        spacing: 8
                        Repeater {
                            model: (root.tab === "clipboard") ? [["copy", qsTr("Copiar")], ["paste", qsTr("Pegar")]] : [["open", "Abrir"], ["copy", "Copiar"], ["reveal", "Revelar"]]
                            delegate: Rectangle {
                                width: 76
                                height: 36 // F6-T07: hit target ≥36px (antes 72x28)
                                radius: 6
                                color: "#0A84FF"
                                border.color: actFocus.active ? root.focusCol : "transparent"
                                border.width: actFocus.active ? root.focusW : 0
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData[1]
                                    color: "#FFFFFF"
                                    font.pixelSize: 13 // F6-T07: ≥13px (antes 12)
                                    font.bold: true // F6-T07: bold sobre accent (3.65:1, ver Ruling)
                                }
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData[0] === "copy" && root.tab === "clipboard" ? modelData[1] + " y cerrar" : modelData[1]
                                Accessible.description: "Pulsa Enter para " + modelData[1].toLowerCase() + " la selección"
                                FocusScope {
                                    id: actFocus
                                    anchors.fill: parent
                                    activeFocusOnTab: true
                                    Keys.onPressed: function (event) {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                            root.activateCurrent(modelData[0]);
                                            event.accepted = true;
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.activateCurrent(modelData[0])
                                }
                            }
                        }
                    } // RowLayout interior de actionRow
                }
                // Fallback KRunner explícito (Ctrl+Tab o clic; no en Portapapeles).
                // F6-T07: Tab ya no lanza KRunner (navega); ver Ruling.
                FocusScope {
                    visible: !root.krunnerMode && root.lastQuery !== "" && root.tab !== "clipboard"
                    activeFocusOnTab: visible
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    KeyNavigation.tab: footTabs
                    KeyNavigation.backtab: actionRow
                    Accessible.role: Accessible.Button
                    Accessible.name: "Buscar en KRunner"
                    Accessible.description: "Pulsa Enter para repetir la búsqueda con el motor KRunner. Atajo Control Tab."
                    Rectangle {
                        anchors.fill: parent
                        height: 36
                        radius: 6
                        color: "transparent"
                        border.color: krFocus.active ? root.focusCol : "#0A84FF"
                        border.width: krFocus.active ? root.focusW : 1
                        Text {
                            anchors.centerIn: parent
                            text: "Buscar en KRunner (Ctrl+Tab)"
                            color: "#0A84FF"
                            font.pixelSize: 13 // F6-T07: ≥13px (antes 12)
                        }
                    }
                    FocusScope {
                        id: krFocus
                        anchors.fill: parent
                        activeFocusOnTab: true
                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                root.useKRunner();
                                event.accepted = true;
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.useKRunner()
                    }
                }
                Text {
                    visible: root.krunnerMode
                    text: "Motor: KRunner (fallback)"
                    color: "#0A84FF"
                    font.pixelSize: 11
                }
                Text {
                    text: root.lastQuery !== "" ? ("Latencia: " + (root.tab === "clipboard" ? root.clipLatency : (root.krunnerMode ? backend.lastLatencyMs : nimbus.localLatencyMs)) + " ms · " + root.filtered.length + " resultados" + (root.krunnerMode ? " · KRunner" : " · Nimbus")) : ""
                    color: "#0A84FF"
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#38383A"
        }

        // Footer Cmd+1..4 + Quick Keys.
        // F6-T07: última parada Tab (pestañas→campo, cierra el ciclo).
        FocusScope {
            id: footTabs
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            activeFocusOnTab: true
            KeyNavigation.tab: searchField
            KeyNavigation.backtab: actionRow
            Accessible.role: Accessible.Grouping
            Accessible.name: "Pestañas de búsqueda"
            RowLayout {
                anchors.fill: parent
                spacing: 8
                Repeater {
                    model: [["apps", "⌘1"], ["files", "⌘2"], ["actions", "⌘3"], ["clipboard", "⌘4"]]
                    delegate: Rectangle {
                        // F6-T07: hit target 32px + foco visible + Enter/Espacio.
                        width: tabLabel.implicitWidth + 16
                        height: 32
                        radius: 6
                        color: "transparent"
                        border.color: tabFocus.active ? root.focusCol : "transparent"
                        border.width: tabFocus.active ? root.focusW : 0
                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: (root.tab === modelData[0] ? "● " : "○ ") + root.tabNames[modelData[0]] + " " + modelData[1]
                            // F6-T07: seleccionada en blanco (13.94:1; antes
                            // accent 3.82:1 bajo 4.5) + marcador ● (no solo color).
                            color: root.tab === modelData[0] ? "#FFFFFF" : "#EBEBF5"
                            opacity: root.tab === modelData[0] ? 1.0 : 0.6
                            font.pixelSize: 12 // F6-T07: ≥12px (antes 11)
                            font.bold: root.tab === modelData[0]
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: root.tabNames[modelData[0]] + ", " + modelData[1]
                        Accessible.description: "Pulsa Enter para mostrar esta pestaña"
                        FocusScope {
                            id: tabFocus
                            anchors.fill: parent
                            activeFocusOnTab: true
                            Keys.onPressed: function (event) {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                    root.setTab(modelData[0]);
                                    event.accepted = true;
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.setTab(modelData[0])
                        }
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: "A–L elige · Tab navega · Ctrl+Tab=KRunner · Esc cierra"
                    color: "#EBEBF5"
                    opacity: 0.3
                    font.pixelSize: 11
                }
            } // RowLayout interior de footTabs
        }
    }
}
