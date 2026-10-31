// nimbus-mc.js — atajo Meta+W → Mission Control (F7-T02).
// Instalación manual: este one-shot NO es un plasmoide; se invoca desde
// un atajo personalizado que ejecute:
//   qdbus6 org.nimbus.MissionControl /MC org.nimbus.MissionControl.toggle
// Para bindearlo vía KWin scripting (una vez):
//   qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
//     "$HOME/.local/share/kwin/scripts/nimbus-mc/contents/code/main.js" nimbus-mc
// El script registra Meta+W y desaconseja el Overview stock duplicado
// (Ruling R-MC-STOCK: Nimbus MC reemplaza a Overview; desactivar
// Meta+W/F3 de kwin en kglobalshortcutsrc).
try {
    callDBus("org.nimbus.MissionControl", "/MC",
             "org.nimbus.MissionControl", "toggle");
} catch (e) { print("nimbus-mc: " + e); }
