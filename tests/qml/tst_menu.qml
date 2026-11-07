// tst_menu.qml — test unitario F3-T04 (qmltestrunner Qt6 offscreen).
// Verifica: modelo de 9 acciones, confirmación de acciones destructivas,
// comandos DBus/systemd, y máquina de estados open/close.
// Uso: QT_QPA_PLATFORM=offscreen qmltestrunner -import packages/shell/nimbus-bar/qml -input tests/qml/tst_menu.qml
import QtQuick
import QtTest
import "../../packages/shell/nimbus-bar/qml" as Bar

TestCase {
    name: "Menu"
    property var menu: null
    Component { id: menuFactory; Bar.Menu { demo: true } }

    function init() {
        menu = createTemporaryObject(menuFactory, null, {});
        verify(menu !== null, "Menu instanciado");
    }

    function test_open_close() {
        compare(menu.opened, false);
        menu.open();
        compare(menu.opened, true);
        menu.close();
        compare(menu.opened, false);
        menu.toggle();
        compare(menu.opened, true);
        menu.toggle();
        compare(menu.opened, false);
    }

    function test_action_items() {
        verify(menu.actionModel !== null, "actionModel disponible");
        compare(menu.actionModel.count, 9);

        // Recorre y verifica los 9 items exactos
        var expected = [
            { label: "Acerca de Nimbus", icon: "logo", cmd: "nimbus-about" },
            { label: "Ayuda de Nimbus", icon: "help", cmd: "nimbus-help" },
            { label: "Reloj", icon: "clock", cmd: "nimbus-clock" },
            { label: "Ajustes del sistema…", icon: "gear", cmd: "systemsettings kcm_nimbus" },
            { label: "Dormir", icon: "moon", mustContain: "suspend" },
            { label: "Bloquear", icon: "lock", mustContain: "lock" },
            { label: "Cerrar sesión", icon: "logout", mustContain: "Shutdown.logout" },
            { label: "Reiniciar…", icon: "restart", mustContain: "logoutAndReboot" },
            { label: "Apagar…", icon: "power", mustContain: "logoutAndShutdown" }
        ];

        for (var i = 0; i < expected.length; i++) {
            var item = menu.actionModel.get(i);
            compare(item.label, expected[i].label);
            compare(item.icon, expected[i].icon);
            if (expected[i].cmd) {
                compare(item.cmd, expected[i].cmd);
            }
            if (expected[i].mustContain) {
                verify(item.cmd.indexOf(expected[i].mustContain) >= 0,
                       "Comando de " + item.label + " contiene " + expected[i].mustContain);
            }
            if (i >= 6) {
                compare(item.destructive, true);
            }
        }

        // Verificar logAllActions() sin crash
        menu.logAllActions();
    }

    function test_direct_action() {
        var triggeredCmd = "";
        var triggeredLabel = "";
        menu.actionTriggered.connect(function(cmd, lbl) {
            triggeredCmd = cmd;
            triggeredLabel = lbl;
        });

        menu.open();
        compare(menu.opened, true);
        menu.doRun("nimbus-about", "Acerca de Nimbus");
        compare(triggeredCmd, "nimbus-about");
        compare(triggeredLabel, "Acerca de Nimbus");
        compare(menu.opened, false);
    }

    function test_ask_confirm() {
        compare(menu.pendingAction, "");
        compare(menu.pendingLabel, "");
        menu.askConfirm("systemctl reboot", "Reiniciar…");
        compare(menu.pendingAction, "systemctl reboot");
        compare(menu.pendingLabel, "Reiniciar…");

        var triggeredCmd = "";
        var triggeredLabel = "";
        menu.actionTriggered.connect(function(cmd, lbl) {
            triggeredCmd = cmd;
            triggeredLabel = lbl;
        });

        menu.doRun(menu.pendingAction, menu.pendingLabel);
        compare(triggeredCmd, "systemctl reboot");
        compare(triggeredLabel, "Reiniciar…");
        compare(menu.opened, false);
        compare(menu.pendingAction, "");
        compare(menu.pendingLabel, "");
    }
}
