// tst_calendar.qml — test F3-T08 (qmltestrunner Qt6, offscreen).
// Instancia el Calendar.qml real y verifica: daysIn, leadBlanks (lunes
// primero), wrap prev/next, bisiesto, cabecera, y máquina open/close/toggle
// (el mismo close() que llaman Esc y el clic-fuera del scrim).
// Uso: QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/qml/tst_calendar.qml
import QtQuick
import QtTest
import "../../packages/shell/nimbus-bar/qml" as Bar

TestCase {
    name: "Calendar"
    property var cal: null
    Component { id: calFactory; Bar.Calendar {} }

    function init() {
        cal = createTemporaryObject(calFactory, null, {});
        verify(cal !== null, "Calendar creado");
    }

    function test_daysIn() {
        compare(cal.daysIn(9, 2026), 31); // octubre
        compare(cal.daysIn(3, 2026), 30); // abril
    }
    function test_leadBlanks() {
        compare(cal.leadBlanks(9, 2026), 3); // 1-oct-2026 = jueves
        compare(cal.leadBlanks(0, 2026), 3); // 1-ene-2026 = jueves
    }
    function test_wrap() {
        cal.shownMonth = 0; cal.shownYear = 2026;
        cal.prev();
        compare(cal.shownMonth, 11); compare(cal.shownYear, 2025);
        cal.next(); cal.next();
        compare(cal.shownMonth, 1); compare(cal.shownYear, 2026);
        cal.shownMonth = 11; cal.shownYear = 2026;
        cal.next();
        compare(cal.shownMonth, 0); compare(cal.shownYear, 2027);
    }
    function test_leap() {
        compare(cal.daysIn(1, 2024), 29);
        compare(cal.daysIn(1, 2025), 28);
    }
    function test_header() {
        compare(cal.monthName(9), "octubre");
    }
    function test_open_close() {
        // Esc (Shortcut) y clic-fuera (scrim) llaman a close(): mismo camino.
        compare(cal.opened, false);
        cal.open();
        compare(cal.opened, true);
        var d = new Date();
        compare(cal.shownMonth, d.getMonth());
        compare(cal.shownYear, d.getFullYear());
        verify(cal.isToday(d.getDate()));
        cal.toggle();
        compare(cal.opened, false);
        cal.toggle();
        compare(cal.opened, true);
        cal.close();
        compare(cal.opened, false);
    }
}
