// Nimbus Zoom+FS: verde = clientArea tal cual (KWin ya excluye la barra; +24 duplicaba).
var saved = {}; function key(w) { try { return "w" + (w.windowId !== undefined ? w.windowId : w.internalId); } catch (e) { return "p" + w; } }
function area(w) { var N = ["MaximizeArea","WorkArea","PlacementArea","FullArea"], O = [0];
    try { O.unshift(workspace.activeScreen); if (w.output !== undefined) O.unshift(w.output); O.unshift(w); } catch (e) {}
    for (var i = 0; i < N.length; i++) { if (KWin[N[i]] === undefined) continue;
        for (var s = 0; s < O.length; s++) try { var a = workspace.clientArea(KWin[N[i]], O[s], workspace.currentDesktop);
            if (a && a.width > 0 && a.height > 0) return a; } catch (e) {} }
    return { x: 0, y: 0, width: 1024, height: 768 }; }
function act() { var w = workspace.activeWindow; if (!w || !w.normalWindow) { print("ZOOM/FS none"); return null; } return w; }
function toggleZoom() { var w = act(); if (!w) return; var k = key(w), g = saved[k];
    if (g) { delete saved[k]; try { if (w.setMaximize !== undefined) w.setMaximize(false, false); w.frameGeometry = g; } catch (e) {}
        print("ZOOM restored x=" + g.x + " y=" + g.y + " w=" + g.width + " h=" + g.height); return; }
    try { if (w.fullScreen) w.fullScreen = false; if (w.setMaximize !== undefined) w.setMaximize(false, false); } catch (e) {}
    try { g = w.frameGeometry; } catch (e) { g = w.geometry; } saved[k] = { x: g.x, y: g.y, width: g.width, height: g.height };
    var a = area(w); try { w.frameGeometry = a; } catch (e) { print("ZOOM apply-failed " + e); return; }
    print("ZOOM zoomed x=" + a.x + " y=" + a.y + " w=" + a.width + " h=" + a.height); }
function toggleFS() { var w = act(); if (!w) return;
    try { var on = !w.fullScreen; w.fullScreen = on; print("FS " + (on ? "on" : "off")); } catch (e) { print("FS failed " + e); } }
registerShortcut("Nimbus Zoom", "Nimbus Zoom (macOS fill below bar)", "Meta+Z", toggleZoom); registerShortcut("Nimbus Fullscreen", "Nimbus Fullscreen toggle", "Meta+F", toggleFS);
