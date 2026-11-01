// nimbus-mc — Meta+W alterna el overlay propio (R-MC-CUSTOM).
// El Overview stock se desactiva en kglobalshortcutsrc (Overview=none).
registerShortcut("Nimbus Mission Control", "Alternar Mission Control Nimbus",
                 "Meta+W", function () {
    callDBus("org.nimbus.MissionControl", "/MC",
             "org.nimbus.MissionControl", "toggle");
});
