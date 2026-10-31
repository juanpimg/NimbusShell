// Nimbus Zoom (F4-T03): boton verde macOS en KWin 6.8.
// Llena el area de trabajo bajo la barra de 24px (fs=0), toggle, restaura.
var saved = {};
function key(w) { try { return "w" + (w.windowId !== undefined ? w.windowId : w.internalId); } catch (e) { return "p" + w; } }
function area(w) {
    var names = ["MaximizeArea", "WorkArea", "PlacementArea", "FullArea"], outs = [];
    try { outs.push(w); if (w.output !== undefined) outs.push(w.output); } catch (e) {}
    try { outs.push(workspace.activeScreen); } catch (e) {}
    outs.push(0);
    for (var i = 0; i < names.length; i++) {
        if (KWin[names[i]] === undefined) continue;
        for (var s = 0; s < outs.length; s++) try {
            var a = workspace.clientArea(KWin[names[i]], outs[s], workspace.currentDesktop);
            if (a && a.width > 0 && a.height > 0) { print("ZOOM area via " + names[i]); return a; }
        } catch (e) {}
    }
    return { x: 0, y: 0, width: 1024, height: 768 };
}
function toggleZoom() {
    var w = workspace.activeWindow;
    if (!w || !w.normalWindow) { print("ZOOM none"); return; }
    var k = key(w);
    if (saved[k]) { var g = saved[k]; delete saved[k];
        try { if (w.setMaximize !== undefined) w.setMaximize(false, false); w.frameGeometry = g; } catch (e) { print("ZOOM restore-failed " + e); }
        print("ZOOM restored x=" + g.x + " y=" + g.y + " w=" + g.width + " h=" + g.height); return; }
    try { if (w.fullScreen) w.fullScreen = false; if (w.setMaximize !== undefined) w.setMaximize(false, false); } catch (e) {}
    var c; try { c = w.frameGeometry; } catch (e) { c = w.geometry; }
    saved[k] = { x: c.x, y: c.y, width: c.width, height: c.height };
    var a = area(w), n = { x: a.x, y: a.y + 24, width: a.width, height: a.height - 24 };
    try { w.frameGeometry = n; } catch (e) { print("ZOOM apply-failed " + e); return; }
    print("ZOOM zoomed x=" + n.x + " y=" + n.y + " w=" + n.width + " h=" + n.height);
}
registerShortcut("Nimbus Zoom", "Nimbus Zoom (macOS fill below bar)", "Meta+Z", toggleZoom);
print("ZOOM loaded");
