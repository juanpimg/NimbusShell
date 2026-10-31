// Nimbus Spotlight: Cmd+Espacio (Meta+Space) alterna el overlay vía DBus.
// Sin binds CTRL-* nuevos (instalador): Meta como Cmd (contrato §3).
function toggleSpotlight() {
    try {
        callDBus("org.nimbus.Spotlight", "/Spotlight",
                 "org.nimbus.Spotlight", "toggle");
        print("SPOTLIGHT toggle ok");
    } catch (e) {
        print("SPOTLIGHT toggle-failed " + e
              + " (¿nimbus-spotlight en ejecución?)");
    }
}
registerShortcut("Nimbus Spotlight",
                 "Nimbus Spotlight toggle (Cmd+Espacio)",
                 "Meta+Space", toggleSpotlight);
