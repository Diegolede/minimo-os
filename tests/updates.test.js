// node tests/updates.test.js — notas de versión y reglas de comprobación.
const fs = require("fs"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../minimo-shell/Common/updates.js"), "utf8").replace(".pragma library", "")
const U = new Function(src + "; return { MIN_MANUAL, AUTO_EVERY, AUTO_FIRST, parseChangelog, canCheck, autoDelay, sane }")()

for (const [file, titles] of [["CHANGELOG.md", ["Nuevas funciones", "Correcciones", "Optimizaciones"]], ["CHANGELOG.en.md", ["New features", "Fixes", "Optimizations"]]]) {
    const v = U.parseChangelog(fs.readFileSync(path.join(__dirname, "../minimo-shell", file), "utf8"))
    assert.ok(v.length >= 3, file)
    assert.ok(v[0].next, file + ": primero la próxima versión")
    const r = v.find(x => x.version === "1.1.0")
    assert.ok(r && r.date === "2026-10-16", file + ": 1.1.0 con fecha")
    assert.deepStrictEqual(r.sections.map(s => s.title), titles, file)
    for (const x of v) for (const s of x.sections) assert.ok(titles.indexOf(s.title) >= 0, file + ": sección desconocida " + s.title)
    assert.ok(r.sections.every(s => s.items.length > 0))
}
// La versión de VERSION tiene su entrada en el CHANGELOG.
const ver = fs.readFileSync(path.join(__dirname, "../minimo-shell/VERSION"), "utf8").trim()
assert.ok(U.parseChangelog(fs.readFileSync(path.join(__dirname, "../minimo-shell/CHANGELOG.md"), "utf8")).some(v => v.version === ver), "VERSION en CHANGELOG")
assert.deepStrictEqual(U.parseChangelog("## 2.0.0\n### Correcciones\n"), [])   // sin puntos: se omite
assert.strictEqual(U.parseChangelog("## v2.0 — 2027-01-02\n### X\n- **a** `b`")[0].sections[0].items[0], "a b")

// Reglas.
const now = 1e12
assert.strictEqual(U.canCheck(now, 0, false, true), true)
assert.strictEqual(U.canCheck(now, now - 1000, true, true), false, "nunca dos a la vez")
assert.strictEqual(U.canCheck(now, now - 30e3, false, true), false, "mínimo entre manuales")
assert.strictEqual(U.canCheck(now, now - 61e3, false, true), true)
assert.strictEqual(U.canCheck(now, now - 3600e3, false, false), false, "automática: una por día")
assert.strictEqual(U.canCheck(now, now - U.AUTO_EVERY, false, false), true)
assert.strictEqual(U.autoDelay(now, 0), U.AUTO_FIRST, "sin comprobaciones previas: a los 2 min")
assert.strictEqual(U.autoDelay(now, now - 3600e3), U.AUTO_EVERY - 3600e3)
assert.strictEqual(U.autoDelay(now, now - 10 * U.AUTO_EVERY), U.AUTO_FIRST, "atrasada: pronto, pero no en el arranque")
assert.strictEqual(U.autoDelay(now, now + 1e9), U.AUTO_EVERY, "reloj hacia atrás: tope de 24 h")
assert.strictEqual(U.sane("uptodate"), "uptodate"); assert.strictEqual(U.sane("raro"), "unknown"); assert.strictEqual(U.sane(undefined), "unknown")
console.log("updates: changelog (es/en) y reglas OK")
