// focuslogic.js — F6-T07: lógica pura de navegación por teclado.
// Fuente única usada por Spotlight.qml/AppsWindow.qml (documentada en sus
// Keys.onPressed), por tst_focus.qml (qmltestrunner) y por test_focus.js
// (node). Sin dependencias Qt: funciona en QML y en node.
// Quick Keys A–L por posición VISIBLE; flechas con clamp; Home/End;
// RePág/AvPág ±10; ciclos Tab cerrados (último vuelve al primero).
function quickPos(keyText, n) {
    if (typeof keyText !== "string" || keyText.length !== 1)
        return -1;
    var pos = "ABCDEFGHIJKL".indexOf(keyText.toUpperCase());
    return (pos >= 0 && pos < n) ? pos : -1;
}
function stepDown(i, n) { return Math.min(i + 1, n - 1); }
function stepUp(i) { return Math.max(i - 1, 0); }
function goHome(n) { return 0; }
function goEnd(n) { return Math.max(n - 1, 0); }
function pageDown(i, n) { return Math.min(i + 10, n - 1); }
function pageUp(i) { return Math.max(i - 10, 0); }
function tabCycleSpotlight(clipboard) {
    var c = ["search"];
    if (clipboard)
        c.push("clipRow");
    return c.concat(["results", "actionRow", "footTabs"]);
}
function tabCycleApps(listMode) {
    return ["search", "viewBtn", "catList", listMode ? "list" : "grid"];
}
if (typeof module !== "undefined") {
    module.exports = { quickPos, stepDown, stepUp, goHome, goEnd,
                       pageDown, pageUp, tabCycleSpotlight, tabCycleApps };
}
