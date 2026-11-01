// tst_focus.qml — F6-T07: navegación solo-teclado (qmltestrunner, offscreen).
// Ejecuta la MISMA focuslogic.js que usan los Keys.onPressed de
// Spotlight.qml/AppsWindow.qml (ver test_focus.js para node).
// Uso: QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/spotlight tst_focus
// (en este host qmltestrunner sale 1 en silencio incluso con un TestCase
// trivial: limitación preexistente del entorno, ver test_a11y.py que
// replica estas aserciones y corre la lógica real en node).
import QtQuick
import QtTest
import "focuslogic.js" as Focus

TestCase {
    name: "FocusKeys"

    function test_quickKeys() {
        compare(Focus.quickPos("a", 5), 0);
        compare(Focus.quickPos("C", 5), 2);
        compare(Focus.quickPos("l", 12), 11);
        compare(Focus.quickPos("L", 5), -1); // fuera de resultados: no salta
        compare(Focus.quickPos("m", 12), -1); // M no es Quick Key
        compare(Focus.quickPos("", 5), -1);
    }
    function test_arrows() {
        compare(Focus.stepDown(0, 5), 1);
        compare(Focus.stepDown(4, 5), 4); // clamp final
        compare(Focus.stepUp(4), 3);
        compare(Focus.stepUp(0), 0); // clamp inicio
    }
    function test_homeEnd() {
        compare(Focus.goHome(7), 0);
        compare(Focus.goEnd(7), 6);
        compare(Focus.goEnd(0), 0); // sin resultados no hay negativo
    }
    function test_pages() {
        compare(Focus.pageDown(0, 30), 10);
        compare(Focus.pageDown(25, 30), 29); // clamp
        compare(Focus.pageUp(25), 15);
        compare(Focus.pageUp(3), 0); // clamp
    }
    function test_tabCycleClosed() {
        // Sin trampa: el ciclo es finito, sin repetidos, y el último
        // vuelve al primero (footTabs→search / grid→search en QML).
        compare(Focus.tabCycleSpotlight(false), ["search", "results", "actionRow", "footTabs"]);
        compare(Focus.tabCycleSpotlight(true), ["search", "clipRow", "results", "actionRow", "footTabs"]);
        compare(Focus.tabCycleApps(false), ["search", "viewBtn", "catList", "grid"]);
        compare(Focus.tabCycleApps(true)[3], "list");
    }
}
