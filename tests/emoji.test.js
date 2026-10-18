// node tests/emoji.test.js — selector de emojis: datos y secuencias exactas.
const fs = require("fs"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../minimo-shell/Common/emoji.js"), "utf8").replace(".pragma library", "")
const E = new Function(src + "; return { TONES, norm, parse, search, withTone, textFor, glyph }")()
const raw = fs.readFileSync(path.join(__dirname, "../minimo-shell/assets/emoji/emoji.json"), "utf8")

const es = E.parse(raw, "es"), en = E.parse(raw, "en")
assert.ok(es.length >= 8, "categorías")
const all = es.flatMap(c => c.items)
assert.ok(all.length > 200)
// Sin duplicados y cada uno con nombre en ambos idiomas.
const json = JSON.parse(raw)
const seen = new Set()
for (const c of json.categories) {
    assert.ok(c.es && c.en && c.icon, "categoría " + c.id)
    for (const it of c.items) {
        assert.ok(it[1] && it[2], "nombres de " + it[0])
        assert.ok(!seen.has(it[0]), "duplicado " + it[0]); seen.add(it[0])
        // El tono solo se aplica a emojis de un único código (+ FE0F opcional).
        if (it[3] === 1) assert.ok(Array.from(it[0].replace("\uFE0F", "")).length === 1, "tono en secuencia " + it[0])
    }
}
assert.strictEqual(en[0].label, "Smileys"); assert.strictEqual(es[0].label, "Caras")

// Búsqueda en ambos idiomas y sin tildes.
assert.strictEqual(E.search(es, "cafe")[0].e, "☕")
assert.strictEqual(E.search(es, "coffee")[0].e, "☕")
assert.ok(E.search(es, "bandera arcoiris").some(i => i.e === "🏳️‍🌈"))
assert.strictEqual(E.search(es, "   ").length, 0)
assert.strictEqual(E.search(es, "zzzqqq").length, 0)
assert.ok(E.search(es, "a", 10).length === 10)

// Secuencias exactas (puntos de código).
const cp = s => Array.from(s).map(c => c.codePointAt(0).toString(16).toUpperCase())
const find = e => all.find(i => i.e === e)
assert.deepStrictEqual(cp(E.textFor(find("👍"), 0)), ["1F44D"])
assert.deepStrictEqual(cp(E.textFor(find("👍"), 3)), ["1F44D", "1F3FD"])
assert.deepStrictEqual(cp(E.textFor(find("✌️"), 5)), ["270C", "1F3FF"])          // sin FE0F
assert.deepStrictEqual(cp(E.textFor(find("👩‍💻"), 3)), ["1F469", "200D", "1F4BB"]) // ZWJ: no se toca
assert.deepStrictEqual(cp(E.textFor(find("🏳️‍🌈"), 2)), ["1F3F3", "FE0F", "200D", "1F308"])
assert.deepStrictEqual(cp(E.textFor(find("🇦🇷"), 1)), ["1F1E6", "1F1F7"])
assert.deepStrictEqual(cp(E.textFor(find("🏴󠁧󠁢󠁳󠁣󠁴󠁿"), 0)), ["1F3F4", "E0067", "E0062", "E0073", "E0063", "E0074", "E007F"])
assert.deepStrictEqual(cp(E.textFor(find("❤️‍🔥"), 4)), ["2764", "FE0F", "200D", "1F525"])
assert.deepStrictEqual(E.parse("{malo", "es"), [])
// glyph(): solo para dibujar; quita FE0F antes de ZWJ y nada más.
assert.deepStrictEqual(cp(E.glyph("🏳️‍🌈")), ["1F3F3", "200D", "1F308"])
assert.strictEqual(E.glyph("✌️"), "✌️"); assert.strictEqual(E.glyph("👩‍💻"), "👩‍💻")
console.log("emoji: " + all.length + " emojis en " + es.length + " categorías; búsqueda y secuencias OK")
