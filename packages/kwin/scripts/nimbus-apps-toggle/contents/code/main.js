// Nimbus Apps Toggle (F6-T04): Cmd+1 = Meta+1 -> DBus org.nimbus.Apps /Apps toggle().
// Vía elegida: KWin Script registerShortcut (más fiable que KGlobalAccel
// editando ficheros: KWin aplica el atajo en vivo, sin re-login, y no
// colisiona con atajos de apps porque Ctrl queda intacto — R-CTRL).
// Si nimbus-apps no corre, lo arranca (oculto; el propio bin se registra).
function toggleApps() {
    callDBus("org.nimbus.Apps", "/Apps", "org.nimbus.Apps", "toggle");
}
registerShortcut("Nimbus Apps", "Abrir Apps (Tahoe)", "Meta+1", toggleApps);
