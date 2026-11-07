// tst_controlcenter.qml — test unitario F3-T05 (qmltestrunner Qt6 offscreen).
// Verifica: apertura/cierre, toggles (wifi, bt, tema, dnd),
// parsing de estados (habilitado/deshabilitado, enabled/disabled, on/off),
// y geometrías Tahoe.
// Uso: QT_QPA_PLATFORM=offscreen qmltestrunner -import packages/shell/nimbus-bar/qml -input tests/qml/tst_controlcenter.qml
import QtQuick
import QtTest
import "../../packages/shell/nimbus-bar/qml" as Bar

TestCase {
    name: "ControlCenter"
    property var cc: null
    Component { id: ccFactory; Bar.ControlCenter { demo: true } }

    function init() {
        cc = createTemporaryObject(ccFactory, null, {});
        verify(cc !== null, "ControlCenter instanciado");
    }

    function test_open_close_toggle() {
        compare(cc.opened, false);
        cc.open();
        compare(cc.opened, true);
        cc.close();
        compare(cc.opened, false);
        cc.toggle();
        compare(cc.opened, true);
        cc.toggle();
        compare(cc.opened, false);
    }

    function test_geometries() {
        compare(cc.panelW, 304);
        compare(cc.contentW, 292);
        compare(cc.capsuleH, 64);
        compare(cc.capsuleR, 28);
        compare(cc.sliderR, 22);
    }

    function test_toggles_and_signals() {
        var lastKind = "";
        var lastState = false;
        cc.toggled.connect(function(k, s) {
            lastKind = k;
            lastState = s;
        });

        // Test flip("dnd")
        var prevDnd = cc.dndOn;
        cc.flip("dnd");
        compare(lastKind, "dnd");

        // Test flip("wifi")
        var prevWifi = cc.wifiOn;
        cc.flip("wifi");
        compare(lastKind, "wifi");
        compare(lastState, !prevWifi);

        // Test flip("bt")
        var prevBt = cc.btOn;
        cc.flip("bt");
        compare(lastKind, "bt");
        compare(lastState, !prevBt);

        // Test flip("theme")
        var prevDark = cc.darkOn;
        cc.flip("theme");
        compare(lastKind, "theme");
        compare(lastState, !prevDark);
    }

    function test_handle_output_wifi() {
        // Directamente prueba la función real cc.handleOutput en ControlCenter.qml
        cc.handleOutput("wifiOn", "enabled");
        compare(cc.wifiOn, true);
        cc.handleOutput("wifiOn", "habilitado\n");
        compare(cc.wifiOn, true);
        cc.handleOutput("wifiOn", "on");
        compare(cc.wifiOn, true);

        // Regresión bug "deshabilitado"
        cc.handleOutput("wifiOn", "deshabilitado\n");
        compare(cc.wifiOn, false);
        cc.handleOutput("wifiOn", "disabled");
        compare(cc.wifiOn, false);
        cc.handleOutput("wifiOn", "off");
        compare(cc.wifiOn, false);

        cc.handleOutput("wifi", "DIGIFIBRA-PLUS-fx5H\n");
        compare(cc.wifi, "DIGIFIBRA-PLUS-fx5H");
        cc.handleOutput("wifi", "");
        compare(cc.wifi, "—");
    }

    function test_handle_output_bt_and_theme() {
        cc.handleOutput("bt", "on\n");
        compare(cc.btOn, true);
        cc.handleOutput("bt", "off\n");
        compare(cc.btOn, false);

        cc.handleOutput("theme", "NimbusTahoeLight\n");
        compare(cc.darkOn, false);
        cc.handleOutput("theme", "NimbusTahoe\n");
        compare(cc.darkOn, true);
    }

    function test_handle_output_volume_brightness() {
        cc.handleOutput("vol", "Volume: 0.65 [MUTED]\n");
        compare(cc.vol, 0.65);
        cc.handleOutput("vol", "—");
        compare(cc.vol, -1);

        cc.handleOutput("bri", "75\n");
        compare(cc.bri, 0.75);
        cc.handleOutput("bri", "—\n");
        compare(cc.bri, -1);
    }

    function test_battery_level() {
        cc.handleOutput("batt", "80");
        compare(cc.batt, "80%");
        compare(cc.battLevel, 0.80);
        cc.handleOutput("batt", "100");
        compare(cc.battLevel, 1.0);
        cc.handleOutput("batt", "0");
        compare(cc.battLevel, 0.0);
        cc.handleOutput("batt", "—");
        compare(cc.batt, "—");
        compare(cc.battLevel, 0.75);
    }
}
