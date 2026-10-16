// Pruebas de la máquina de confirmación de energía (node tests/confirm.test.js).
// Usa un comando simulado (contador), nunca apaga nada.
const fs = require("fs"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../minimo-shell/Common/confirm.js"), "utf8").replace(/^\.pragma library$/m, "")
const C = new Function(src + "; return { initial, press, disarm }")()

function machine() {
    let st = C.initial(); const ran = []
    return { press(id, t) { const r = C.press(st, id, t, 3000, 2000); st = r.state; if (r.run) ran.push(r.run); return st }, ran, get st() { return st } }
}
let m
// 1. Un clic arma, el segundo ejecuta una sola vez.
m = machine(); m.press("poweroff", 0); assert.equal(m.st.armed, "poweroff"); m.press("poweroff", 500)
assert.deepEqual(m.ran, ["poweroff"]); assert.equal(m.st.armed, "")
// 2. Exclusión: armar otra desarma la anterior; nunca dos armadas.
m = machine(); m.press("logout", 0); m.press("reboot", 100); assert.equal(m.st.armed, "reboot")
m.press("logout", 200); assert.equal(m.st.armed, "logout"); assert.deepEqual(m.ran, [])
// 3. Confirmar la que está armada tras cambiar: ejecuta esa, no la otra.
m.press("logout", 300); assert.deepEqual(m.ran, ["logout"])
// 4. Clics rápidos (10 en 50 ms) tras confirmar: ejecuta exactamente una vez.
m = machine(); for (let i = 0; i < 10; i++) m.press("poweroff", i * 5); assert.deepEqual(m.ran, ["poweroff"])
// 5. Armado vencido (> 3 s): el clic vuelve a armar en vez de ejecutar.
m = machine(); m.press("reboot", 0); m.press("reboot", 3500); assert.deepEqual(m.ran, []); assert.equal(m.st.armed, "reboot")
// 6. Después de la guarda (2 s) se puede volver a usar.
m = machine(); m.press("logout", 0); m.press("logout", 10); m.press("logout", 2100); m.press("logout", 2200)
assert.deepEqual(m.ran, ["logout", "logout"])
// 7. disarm limpia el armado sin ejecutar.
m = machine(); m.press("poweroff", 0); const d = C.disarm(m.st); assert.equal(d.armed, "")
console.log("confirm: 7 casos OK")
