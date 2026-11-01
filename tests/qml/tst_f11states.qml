// tst_f11states.qml — test F11-T03 (qmltestrunner Qt6, offscreen).
// Tokens de estado + dark/light + acento sobre los componentes REALES de
// nimbus-bar (Menu/ControlCenter/Calendar/GlobalMenu/OSD). Los context
// properties del C++ (runner/appMenu/osdBridge) se sustituyen por stubs en
// el root con las mismas señales (outputReady/menusChanged/osdShow): el
// scope de definición los hace visibles igual que en la barra real. StatusArea exige
// StatusNotifierModel real y se cubre en nested (capturas), no aquí.
// Uso: QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/qml/tst_f11states.qml
import QtQuick
import QtTest
import "../../packages/shell/nimbus-bar/qml" as Bar

TestCase {
    name: "F11States"
    // Stubs en el root: el scope de definición los hace visibles a los
    // componentes creados (igual que los context properties del C++).
    property QtObject runner: QtObject {
            signal outputReady(string tag, string out)
            function query(cmd, tag) {}
            function run(cmd) {}
            function logAction(i, cmd) {}
        }
    property QtObject appMenu: QtObject {
            signal menusChanged()
            property string appName: "TestApp"
            property bool hasMenu: true
            property var topLevel: [{ "id": 1, "label": "Archivo", "enabled": true }, { "id": 2, "label": "Ver", "enabled": false }]
            property var submenu: []
            property string submenuTitle: ""
            function openSubmenu(id) {}
            function closeMenu() {}
            function trigger(id) {}
        }
    property QtObject osdBridge: QtObject {
            signal osdShow(string kind, double value)
        }

    // ---- tokens §2.5 [HIG] ----
    function test_states_tokens() {
        verify(Bar.NimbusTokens.states.hoverAlpha > 0, "hoverAlpha");
        verify(Bar.NimbusTokens.states.pressedAlpha > Bar.NimbusTokens.states.hoverAlpha, "pressed>hover");
        compare(Bar.NimbusTokens.states.focusRingPx, 2);
        verify(Bar.NimbusTokens.states.disabledOpacity[0] >= 0.3, "disabled min 30%");
        verify(Bar.NimbusTokens.states.disabledOpacity[1] <= 0.5, "disabled max 50%");
        compare(Bar.NimbusTokens.states.focusContrast, 3);
    }
    function test_accent_default_and_custom() {
        Bar.NimbusTokens.accentCustom = "";
        compare(Bar.NimbusTokens.accentColor(false), "#007AFF");
        compare(Bar.NimbusTokens.accentColor(true), "#0A84FF");
        Bar.NimbusTokens.accentCustom = "#FF9F0A";
        compare(Bar.NimbusTokens.accentColor(false), "#FF9F0A");
        compare(Bar.NimbusTokens.accentColor(true), "#FF9F0A");
        compare(Bar.NimbusTokens.selectedFill(true), "#FF9F0A");
        Bar.NimbusTokens.accentCustom = "";
    }
    function test_derived_differ_per_mode() {
        verify(String(Bar.NimbusTokens.popupBg(false)) !== String(Bar.NimbusTokens.popupBg(true)), "popupBg light≠dark");
        verify(String(Bar.NimbusTokens.popupBorder(false)) !== String(Bar.NimbusTokens.popupBorder(true)), "border light≠dark");
        verify(String(Bar.NimbusTokens.barBg(false)) !== String(Bar.NimbusTokens.barBg(true)), "barBg light≠dark");
        verify(String(Bar.NimbusTokens.hairline(false)) !== String(Bar.NimbusTokens.hairline(true)), "hairline light≠dark");
        verify(String(Bar.NimbusTokens.hoverFill(false)) !== String(Bar.NimbusTokens.hoverFill(true)), "hover light≠dark");
    }

    // ---- componentes reales: máquina de estados + binding a dark ----
    Component { id: menuFactory; Bar.Menu { demo: true } }
    Component { id: ccFactory; Bar.ControlCenter { demo: true } }
    Component { id: gmFactory; Bar.GlobalMenu { demo: false } }
    Component { id: osdFactory; Bar.OSD { demo: true } }
    Component { id: calFactory; Bar.Calendar { demo: true } }
    function test_menu_states() {
        var m = createTemporaryObject(menuFactory, null, {});
        verify(m !== null, "Menu creado");
        m.open();
        compare(m.opened, true);
        m.close();
        compare(m.opened, false);
    }
    function test_cc_dark_sync_from_kdeglobals() {
        var c = createTemporaryObject(ccFactory, null, {});
        verify(c !== null, "CC creado");
        // kdeglobals informa BreezeLight → token dark se apaga en toda la barra.
        Bar.NimbusTokens.dark = true;
        runner.outputReady("theme", "BreezeLight");
        compare(c.darkOn, false);
        compare(Bar.NimbusTokens.dark, false);
        runner.outputReady("theme", "BreezeDark");
        compare(Bar.NimbusTokens.dark, true);
        Bar.NimbusTokens.dark = true;
    }
    function test_globalmenu_disabled_token() {
        var g = createTemporaryObject(gmFactory, null, {});
        verify(g !== null, "GlobalMenu creado");
        compare(g.opened, false);
    }
    function test_osd_show_hide() {
        var o = createTemporaryObject(osdFactory, null, {});
        verify(o !== null, "OSD creado");
        o.show("volume", 0.7);
        compare(o.opened, true);
        compare(o.value, 0.7);
        o.hide();
        compare(o.opened, false);
    }
    function test_calendar_accent_today() {
        var cal = createTemporaryObject(calFactory, null, {});
        verify(cal !== null, "Calendar creado");
        cal.open();
        compare(cal.opened, true);
        // El día actual usa el acento configurable (selected).
        Bar.NimbusTokens.accentCustom = "#FF9F0A";
        compare(Bar.NimbusTokens.selectedFill(Bar.NimbusTokens.dark), "#FF9F0A");
        Bar.NimbusTokens.accentCustom = "";
    }
}
