// Pruebas de idioma (node tests/i18n.test.js): toda clave I18n.tr("…") del código tiene
// traducción al inglés, los %n coinciden y no quedan textos visibles sin envolver.
const fs = require("fs"), path = require("path"), assert = require("assert")
const root = path.join(__dirname, "../minimo-shell")
const src = fs.readFileSync(path.join(root, "Common/i18n.js"), "utf8").replace(/^\.pragma library$/m, "")
const D = new Function(src + "; return { en, translate, languages, localeName }")()
function walk(d) { return fs.readdirSync(d, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(path.join(d, e.name)) : e.name.endsWith(".qml") ? [path.join(d, e.name)] : []) }
const files = walk(root), used = new Set()
for (const f of files) for (const m of fs.readFileSync(f, "utf8").split("\n").filter(l => !/^\s*\/\//.test(l)).join("\n").matchAll(/I18n\.tr\("((?:[^"\\]|\\.)*)"/g)) used.add(m[1])
// 1. Cada clave usada existe en `en`, con los mismos %n.
const missing = [...used].filter(k => !(k in D.en))
assert.deepEqual(missing, [], "sin traducción: " + missing.join(" | "))
for (const k of used) {
    const ph = s => (s.match(/%\d/g) || []).sort().join()
    assert.equal(ph(D.en[k]), ph(k), "marcadores distintos en: " + k)
}
// 2. Claves sobrantes (avisa, no falla).
const extra = Object.keys(D.en).filter(k => !used.has(k))
// 3. Sustitución de argumentos y español como identidad.
assert.equal(D.translate("en", "Conectando a %1…", ["Casa"]), "Connecting to Casa…")
assert.equal(D.translate("es", "Conectando a %1…", ["Casa"]), "Conectando a Casa…")
assert.equal(D.translate("en", "Imagen %1 · %2 × %3", ["PNG", 1920, 1080]), "PNG image · 1920 × 1080")
assert.equal(D.translate("en", "texto del usuario", []), "texto del usuario", "lo que no es clave no se toca")
assert.equal(D.localeName("en"), "en_US"); assert.equal(D.localeName("es"), "es_AR"); assert.equal(D.localeName("xx"), "es_AR")
// 4. Textos visibles sin envolver: literales en text:/label:/detail:/value: con letras en español.
const leftovers = []
const allow = /^(Minimo OS|Minimo|Wi-Fi|Internet|Ethernet|CPU|GPU|USB|Bluetooth|Audio|Hyprland|Quickshell|MIT|Terminal|TRN1 \(Diego Ledesma\)|…|—|z)$/
for (const f of files) fs.readFileSync(f, "utf8").split("\n").forEach((l, i) => {
    if (/^\s*\/\//.test(l)) return
    for (const m of l.matchAll(/\b(text|label|detail|value|title|placeholder|k|badge):\s*(?:[^"\n]*\?\s*)?"([^"]*[A-Za-zÁÉÍÓÚáéíóúñ][^"]*)"/g))
        if (!allow.test(m[2]) && !/I18n\.tr\($/.test(l.slice(0, m.index + m[0].length - m[2].length - 1))) leftovers.push(path.relative(root, f) + ":" + (i + 1) + ": " + m[2])
})
assert.deepEqual(leftovers, [], "textos sin traducir:\n" + leftovers.join("\n"))
console.log("i18n: " + used.size + " claves usadas, todas traducidas; " + extra.length + " sin uso (" + extra.join(", ") + "); sin textos visibles sueltos")
