// test_previewguard.js — F6-T09: regresión del preview ante índices
// inválidos (TypeError en Spotlight.qml al colapsar a ≤2 resultados:
// el ListView escribe un -1 transitorio al recambiar el modelo).
// Uso: node tests/spotlight/test_previewguard.js
"use strict";
const assert = require("assert");
const G = require("../../apps/nimbus-spotlight/qml/PreviewGuard.js");

// isValidIndex: idx >= 0 && idx < count.
assert.strictEqual(G.isValidIndex(0, 2), true);
assert.strictEqual(G.isValidIndex(1, 2), true);
assert.strictEqual(G.isValidIndex(-1, 2), false); // el -1 transitorio
assert.strictEqual(G.isValidIndex(2, 2), false);
assert.strictEqual(G.isValidIndex(0, 0), false); // modelo vacío
assert.strictEqual(G.isValidIndex(0, 1), true);

// safeAt: elemento o null (nunca lanza).
const two = [{ text: "= 8" }, { text: "web" }];
assert.strictEqual(G.safeAt(two, 0).text, "= 8");
assert.strictEqual(G.safeAt(two, 1).text, "web");
assert.strictEqual(G.safeAt(two, -1), null); // caso G1: 2 resultados
assert.strictEqual(G.safeAt(two, 2), null);
assert.strictEqual(G.safeAt([{ text: "solo" }], -1), null); // 1 resultado
assert.strictEqual(G.safeAt([], 0), null); // 0 resultados
assert.strictEqual(G.safeAt([], -1), null);
assert.strictEqual(G.safeAt(null, 0), null);
assert.strictEqual(G.safeAt(undefined, 0), null);

console.log("OK: previewguard 15 aserciones (índices -1/fuera de rango → null)");
