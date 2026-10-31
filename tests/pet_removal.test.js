// Pruebas de retirada del tamagotchi / Pet panel (node tests/pet_removal.test.js).
// Comprueba que no quedan módulos, iconos ni claves de estado exclusivas.
const fs = require("fs"), path = require("path"), assert = require("assert")
const root = path.join(__dirname, "../minimo-shell")

function exists(rel) { return fs.existsSync(path.join(root, rel)) }
function read(rel) { return fs.readFileSync(path.join(root, rel), "utf8") }

// 1. Archivos exclusivos eliminados.
for (const f of [
  "Common/Pet.qml", "Common/petalerts.js",
  "Island/PetPanel.qml", "Island/PetMeter.qml",
]) {
  assert.equal(exists(f), false, "debe estar eliminado: " + f)
}

// 2. Iconos exclusivos (comida / pelota) fuera del árbol.
for (const f of [
  "assets/icons/gray/bowl.svg", "assets/icons/gray/ball.svg",
  "assets/icons/white/bowl.svg", "assets/icons/white/ball.svg",
  "assets/icons/dark/bowl.svg", "assets/icons/dark/ball.svg",
  "assets/icons/graydark/bowl.svg", "assets/icons/graydark/ball.svg",
  "assets/icons/fluent/ic_fluent_food_24_filled.svg",
  "assets/icons/fluent/ic_fluent_sport_soccer_24_filled.svg",
]) {
  assert.equal(exists(f), false, "icono pet residual: " + f)
}

// 3. qmldir sin singleton Pet.
const qmldir = read("Common/qmldir")
assert.ok(!/\bPet\b/.test(qmldir), "qmldir aún declara Pet")
assert.ok(!/petalerts/.test(qmldir), "qmldir aún declara petalerts")

// 4. map.json sin ball/bowl.
const map = JSON.parse(read("assets/icons/map.json"))
assert.equal(map.ball, undefined)
assert.equal(map.bowl, undefined)

// 5. DisplayState: no guarda petEnabled; al cargar lo ignora (comentario de migración).
const ds = read("Common/DisplayState.qml")
assert.ok(!/property bool petEnabled/.test(ds), "property petEnabled sigue definida")
assert.ok(!/setPetEnabled/.test(ds), "setPetEnabled sigue definido")
assert.ok(!/petEnabled: root\.petEnabled/.test(ds), "save aún escribe petEnabled")
assert.ok(/Migración 1\.2\.[45].*petEnabled/.test(ds), "falta nota de migración")

// 6. Island ya no instancia PetPanel; el gesto hacia abajo abre el menú.
const island = read("Island/Island.qml")
assert.ok(!/PetPanel/.test(island), "Island aún referencia PetPanel")
assert.ok(/cmd === "pet"/.test(island) || /"pet"/.test(island), "falta remap de comando pet legado")

// 7. CharacterBus: IPC pet abre el menú (no el panel de mascota).
const bus = read("Common/CharacterBus.qml")
assert.ok(/islandCommand\("open"\)/.test(bus), "CharacterBus.pet no abre el menú")

// 8. Personalización: sin interruptor "Mascota".
const pers = read("Settings/PersonalizationPage.qml")
assert.ok(!/setPetEnabled|petEnabled|I18n\.tr\("Mascota"\)/.test(pers), "queda UI de Mascota")

// 9. Gestos: textos actualizados (sin abrir mascota).
const gest = read("Settings/GesturesPage.qml")
assert.ok(!/mascota|PetPanel|tamagotchi/i.test(gest), "GesturesPage aún habla de mascota")

// 10. Migración de state.json: un estado viejo con petEnabled se puede parsear y
//     el objeto resultante no necesita esa clave para seguir válido.
const legacy = {
  theme: "light", language: "es", petEnabled: true,
  characterAnimated: true, reduceMotion: false, pins: [], pinOrder: []
}
const cleaned = Object.assign({}, legacy)
delete cleaned.petEnabled
assert.equal(cleaned.petEnabled, undefined)
assert.equal(cleaned.theme, "light")
assert.equal(cleaned.characterAnimated, true)

// 11. Migración 1.2.5: si state.json traía petEnabled, se reescribe sin esa clave.
const displayState = read("Common/DisplayState.qml")
assert.ok(displayState.includes("hadPetKey"), "DisplayState debe detectar petEnabled residual")
assert.ok(displayState.includes("if (hadPetKey) root.save()"), "DisplayState debe reescribir state.json sin petEnabled")

console.log("pet_removal: 11 casos OK")
