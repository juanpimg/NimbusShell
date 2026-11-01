function rep(s) { callDBus("org.nimbus.Probe", "/Probe", "org.nimbus.Probe", "report", s); }
function findKate() {
    var wl = workspace.windowList();
    for (var i = 0; i < wl.length; i++) {
        if (wl[i].caption.indexOf("Kate") >= 0 || wl[i].caption.indexOf("Bienvenido") >= 0) return wl[i];
    }
    return null;
}
var MODE = "restore";
try {
    if (MODE == "active") {
        var aw = workspace.activeWindow;
        rep("NIMBUS active=" + (aw ? aw.caption : "(none)"));
    } else if (MODE == "max") {
        var k = findKate();
        if (k) { k.setMaximize(true, true); rep("NIMBUS max-ok caption=" + k.caption); }
        else rep("NIMBUS max-FAIL kate-no-encontrado");
    } else if (MODE == "geom") {
        var k2 = findKate();
        if (k2) rep("NIMBUS geom x=" + k2.x + " y=" + k2.y + " w=" + k2.width + " h=" + k2.height + " caption=" + k2.caption);
        else rep("NIMBUS geom-FAIL kate-no-encontrado");
    } else if (MODE == "restore") {
        var k3 = findKate();
        if (k3) { k3.setMaximize(false, false); rep("NIMBUS restore-ok"); }
        else rep("NIMBUS restore-FAIL");
    }
} catch (err) { rep("NIMBUS " + MODE + "-ERR " + err); }
