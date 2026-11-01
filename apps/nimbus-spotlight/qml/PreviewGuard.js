// PreviewGuard.js — F6-T09: acceso seguro al resultado seleccionado.
// Fuente única usada por qml/Spotlight.qml (import local) y por
// tests/spotlight/test_previewguard.js (node). Sin dependencias Qt:
// no usa .import para que node pueda cargarlo con require.
function isValidIndex(idx, count) {
    return typeof idx === "number" && typeof count === "number"
        && idx >= 0 && idx < count;
}
function safeAt(list, idx) {
    if (!list || typeof list.length !== "number")
        return null;
    return isValidIndex(idx, list.length) ? list[idx] : null;
}
if (typeof module !== "undefined") {
    module.exports = { isValidIndex, safeAt };
}
