// Nimbus Tabs (F6-T09): Cmd+2..4 = Meta+2..4 -> Spotlight en esa pestaña.
// Meta+1 sigue en nimbus-apps-toggle (Apps Tahoe); no se duplica aquí.
// Sin binds CTRL-* nuevos (R-CTRL): solo Meta, como Cmd.
function tabShortcut(tab) {
    return function () {
        try {
            callDBus("org.nimbus.Spotlight", "/Spotlight",
                     "org.nimbus.Spotlight", "toggleTab",
                     tab);
            print("SPOTLIGHT tab ok " + tab);
        } catch (e) {
            print("SPOTLIGHT tab-failed " + tab + " " + e
                  + " (¿nimbus-spotlight en ejecución?)");
        }
    };
}
registerShortcut("Nimbus Tab Files",
                 "Spotlight: Archivos (Cmd+2)",
                 "Meta+2", tabShortcut("files"));
registerShortcut("Nimbus Tab Actions",
                 "Spotlight: Acciones (Cmd+3)",
                 "Meta+3", tabShortcut("actions"));
registerShortcut("Nimbus Tab Clipboard",
                 "Spotlight: Portapapeles (Cmd+4)",
                 "Meta+4", tabShortcut("clipboard"));
