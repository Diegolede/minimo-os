// Pruebas del orden del menú de la isla (node tests/pinorder.test.js).
const fs = require("fs"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../minimo-shell/Common/pinorder.js"), "utf8").replace(/^\.pragma library$/m, "")
const P = new Function(src + "; return { full, move, sortPins }")()
const all = ["volume", "brightness", "terminal", "record", "capture", "c1"]
// 1. Sin orden guardado: primero los fijados en su orden histórico, luego el resto.
let o = P.full([], ["capture", "volume"], all)
assert.deepEqual(o, ["capture", "volume", "brightness", "terminal", "record", "c1"])
// 2. Duplicados y borrados en lo guardado se descartan; los nuevos se agregan al final.
assert.deepEqual(P.full(["c9", "record", "record", "volume"], [], all), ["record", "volume", "brightness", "terminal", "capture", "c1"])
// 3. Mover y límites.
o = all.slice()
assert.deepEqual(P.move(o, "terminal", -1), ["volume", "terminal", "brightness", "record", "capture", "c1"])
assert.deepEqual(P.move(o, "volume", -1), o, "primero no sube")
assert.deepEqual(P.move(o, "c1", 1), o, "último no baja")
assert.deepEqual(P.move(o, "nada", 1), o)
// 4. El orden se refleja en los fijados.
o = P.move(P.move(o, "capture", -1), "capture", -1)   // capture antes que terminal
assert.deepEqual(P.sortPins(["terminal", "capture"], o), ["capture", "terminal"])
// 5. Desactivar y reactivar conserva la posición (el orden no depende de pins).
let pins = ["terminal", "capture"]; pins = pins.filter(p => p !== "capture"); pins = pins.concat(["capture"])
assert.deepEqual(P.sortPins(pins, o), ["capture", "terminal"])
// 6. Mover muchas veces nunca duplica ni pierde elementos.
let r = all.slice(); for (let k = 0; k < 500; k++) r = P.move(r, all[k % all.length], k % 3 ? 1 : -1)
assert.equal(new Set(r).size, all.length); assert.equal(r.length, all.length)
console.log("pinorder: 6 grupos de pruebas OK")
