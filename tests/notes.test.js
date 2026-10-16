// Pruebas de las notas (node tests/notes.test.js); incluye escritura atómica simulada.
const fs = require("fs"), path = require("path"), assert = require("assert"), os = require("os")
const src = fs.readFileSync(path.join(__dirname, "../minimo-shell/Common/notes.js"), "utf8").replace(/^\.pragma library$/m, "")
const N = new Function(src + "; return { parse, serialize, add, update, remove, title, preview, prune, newId }")()
// 1. Crear.
let r = N.add([], 1000), notes = r.notes
assert.equal(notes.length, 1); assert.equal(notes[0].text, "")
r = N.add(notes, 1000); notes = r.notes; assert.notEqual(notes[0].id, notes[1].id, "ids únicos aun con el mismo instante")
// 2. Editar y leer.
notes = N.update(notes, notes[1].id, "Compras\nleche\npan", 2000)
assert.equal(notes[0].text, "Compras\nleche\npan"); assert.equal(N.title(notes[0].text), "Compras"); assert.equal(N.preview(notes[0].text), "leche pan")
assert.strictEqual(N.update(notes, notes[0].id, notes[0].text, 3000), notes, "sin cambios no reordena")
assert.strictEqual(N.update(notes, "nada", "x", 3000), notes)
// 3. Borrar.
const vacia = notes[1].id
notes = N.remove(notes, vacia); assert.equal(notes.length, 1)
// 4. Ida y vuelta por JSON; texto del usuario intacto (unicode, comillas, saltos).
const raro = "Línea \"uno\"\n\tñandú — 😀 <b>no html</b>\n\n"
notes = N.update(notes, notes[0].id, raro, 4000)
assert.deepEqual(N.parse(N.serialize(notes)), notes)
// 5. Archivos corruptos o de otra forma no rompen.
assert.deepEqual(N.parse("{roto"), []); assert.deepEqual(N.parse("null"), [])
assert.deepEqual(N.parse('[{"id":"a","text":"x","updated":1},{"id":2},{"text":"sin id"}]'), [{ id: "a", text: "x", updated: 1 }])
// 6. prune descarta vacías al guardar.
assert.equal(N.prune([{ id: "a", text: "  \n" }, { id: "b", text: "x" }]).length, 1)
// 7. Escritura atómica (misma estrategia que FileView.atomicWrites: archivo temporal + rename).
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "notes-")), file = path.join(dir, "notes.json")
function atomicWrite(p, text) { const t = p + ".tmp"; fs.writeFileSync(t, text); fs.renameSync(t, p) }
atomicWrite(file, N.serialize(notes)); assert.deepEqual(N.parse(fs.readFileSync(file, "utf8")), notes)
assert.ok(!fs.existsSync(file + ".tmp")); fs.rmSync(dir, { recursive: true })
console.log("notes: 7 grupos de pruebas OK")
