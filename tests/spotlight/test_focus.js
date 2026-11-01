// test_focus.js — F6-T07: ejecuta focuslogic.js (la misma que importa
// tst_focus.qml) en node. Uso: node tests/spotlight/test_focus.js
"use strict";
const assert = require("assert");
const F = require("./focuslogic.js");

assert.strictEqual(F.quickPos("a", 5), 0);
assert.strictEqual(F.quickPos("C", 5), 2);
assert.strictEqual(F.quickPos("l", 12), 11);
assert.strictEqual(F.quickPos("L", 5), -1);
assert.strictEqual(F.quickPos("m", 12), -1);
assert.strictEqual(F.quickPos("", 5), -1);

assert.strictEqual(F.stepDown(0, 5), 1);
assert.strictEqual(F.stepDown(4, 5), 4);
assert.strictEqual(F.stepUp(4), 3);
assert.strictEqual(F.stepUp(0), 0);

assert.strictEqual(F.goHome(7), 0);
assert.strictEqual(F.goEnd(7), 6);
assert.strictEqual(F.goEnd(0), 0);

assert.strictEqual(F.pageDown(0, 30), 10);
assert.strictEqual(F.pageDown(25, 30), 29);
assert.strictEqual(F.pageUp(25), 15);
assert.strictEqual(F.pageUp(3), 0);

assert.deepStrictEqual(F.tabCycleSpotlight(false),
    ["search", "results", "actionRow", "footTabs"]);
assert.deepStrictEqual(F.tabCycleSpotlight(true),
    ["search", "clipRow", "results", "actionRow", "footTabs"]);
assert.deepStrictEqual(F.tabCycleApps(false),
    ["search", "viewBtn", "catList", "grid"]);
assert.strictEqual(F.tabCycleApps(true)[3], "list");

console.log("OK: focuslogic 17 aserciones (quick A-L, flechas, Home/End, paginas, ciclos Tab)");
