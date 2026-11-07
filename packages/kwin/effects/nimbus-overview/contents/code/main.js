// nimbus-overview — KWin scripted effect (F7-T03 / R-MC-CUSTOM).
// Proporciona el gancho del efecto Overview para Mission Control en KWin.
// Reemplaza el Overview stock canalizando la activación hacia org.nimbus.MissionControl.

function toggleNimbusOverview() {
    callDBus("org.nimbus.MissionControl", "/MC",
             "org.nimbus.MissionControl", "toggle");
}

effects.registerShortcut("Nimbus Overview", "Alternar Nimbus Overview / Mission Control",
                         "Meta+W", toggleNimbusOverview);
