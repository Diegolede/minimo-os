// Pruebas de los avisos de la mascota (node tests/petalerts.test.js).
const fs = require("fs"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../minimo-shell/Common/petalerts.js"), "utf8").replace(/^\.pragma library$/m, "")
const P = new Function(src + "; return { initial, sane, step, suppress, nextCrossing }")()
const below = { food: 0.25, fun: 0.2, energy: 0.25 }
const H = 3600000, MIN = 60000, PER = 3 * H, GLOB = 10 * MIN
const ok = { food: 1, fun: 1, energy: 1 }
let a = P.initial(), r
// 1. Sin necesidad: nada.
r = P.step(a, ok, below, 1000, PER, GLOB); assert.equal(r.post, "")
// 2. Entra en hambre: un aviso; siguiente paso con la misma hambre: ninguno (mismo episodio).
r = P.step(a, { ...ok, food: 0.2 }, below, 10 * H, PER, GLOB); assert.equal(r.post, "food"); a = r.alerts
r = P.step(a, { ...ok, food: 0.1 }, below, 11 * H, PER, GLOB); assert.equal(r.post, "")
// 3. Atendida (comió): termina el episodio (para retirar el aviso viejo).
r = P.step(a, ok, below, 11.5 * H, PER, GLOB); assert.deepEqual(r.ended, ["food"]); a = r.alerts
// 4. Vuelve a tener hambre antes del intervalo mínimo por necesidad: espera (retryAt).
r = P.step(a, { ...ok, food: 0.2 }, below, 12 * H, PER, GLOB); assert.equal(r.post, ""); assert.equal(r.retryAt, 13 * H)
r = P.step(a, { ...ok, food: 0.2 }, below, 13 * H, PER, GLOB); assert.equal(r.post, "food"); a = r.alerts
// 5. Tres necesidades a la vez: una sola por paso, el resto espera el intervalo global.
a = P.initial()
const all = { food: 0.1, fun: 0.1, energy: 0.1 }
r = P.step(a, all, below, 100 * H, PER, GLOB); assert.equal(r.post, "food"); assert.equal(r.retryAt, 100 * H + GLOB); a = r.alerts
r = P.step(a, all, below, 100 * H + 1000, PER, GLOB); assert.equal(r.post, "")
r = P.step(a, all, below, 100 * H + GLOB, PER, GLOB); assert.equal(r.post, "fun"); a = r.alerts
r = P.step(a, all, below, 100 * H + 2 * GLOB, PER, GLOB); assert.equal(r.post, "energy"); a = r.alerts
r = P.step(a, all, below, 100 * H + 3 * GLOB, PER, GLOB); assert.equal(r.post, "")
// 6. Reactivar: lo que ya está en necesidad no avisa (sin ráfaga), lo demás sí cuando cruce.
a = P.suppress(P.initial(), { food: 0.1, fun: 0.5, energy: 0.1 }, below, 200 * H)
r = P.step(a, { food: 0.1, fun: 0.5, energy: 0.1 }, below, 200 * H + 1, PER, GLOB); assert.equal(r.post, "")
// 7. nextCrossing: momento exacto del cruce, sin energía si está en pausa.
const m = { lastFed: 0, lastPlayed: 0, activeSince: 0, idle: false, foodSpan: 8 * H, funSpan: 5 * H, energySpan: 2 * H }
assert.equal(P.nextCrossing(m, below, 0), 1.5 * H)                  // energía: 2 h × 0,75
assert.equal(P.nextCrossing({ ...m, idle: true }, below, 0), 4 * H)  // ánimo: 5 h × 0,8
assert.equal(P.nextCrossing(m, below, 7 * H), Infinity)              // todo ya cruzado
// 8. sane: basura del disco → estado inicial seguro.
assert.deepEqual(P.sane(null), P.initial()); assert.deepEqual(P.sane({ food: { alerted: "x", last: -5 } }).food, { alerted: false, last: 0 })
console.log("petalerts: 8 casos OK")
