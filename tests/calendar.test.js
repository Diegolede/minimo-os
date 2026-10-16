// Pruebas de la cuadrícula del calendario (node tests/calendar.test.js).
const fs = require("fs"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../minimo-shell/Common/calendar.js"), "utf8").replace(/^\.pragma library$/m, "")
const C = new Function(src + "; return { isLeap, daysIn, weekday, addMonths, monthGrid }")()
// 1. Bisiestos.
assert.ok(C.isLeap(2024) && C.isLeap(2000) && !C.isLeap(1900) && !C.isLeap(2026) && !C.isLeap(2100))
assert.equal(C.daysIn(2024, 1), 29); assert.equal(C.daysIn(2026, 1), 28); assert.equal(C.daysIn(2000, 1), 29); assert.equal(C.daysIn(1900, 1), 28)
// 2. Día de la semana igual al de Date en 1900..2100 (todos los días).
let n = 0
for (let y = 1900; y <= 2100; y++) for (let m = 0; m < 12; m++) for (let d = 1; d <= C.daysIn(y, m); d++) {
    assert.equal(C.weekday(y, m, d), new Date(Date.UTC(y, m, d)).getUTCDay(), `${y}-${m + 1}-${d}`); n++ }
// 3. Cambio de año.
assert.deepEqual(C.addMonths(2026, 11, 1), { y: 2027, m: 0 }); assert.deepEqual(C.addMonths(2026, 0, -1), { y: 2025, m: 11 })
assert.deepEqual(C.addMonths(2026, 5, -30), { y: 2023, m: 11 })
// 4. Cuadrículas concretas.
let g = C.monthGrid(2026, 9, 0)              // octubre 2026, semana desde domingo: 1/10 es jueves
assert.equal(g.length, 42); assert.deepEqual(g[4], { y: 2026, m: 9, d: 1, inMonth: true }); assert.deepEqual(g[3], { y: 2026, m: 8, d: 30, inMonth: false })
g = C.monthGrid(2026, 9, 1)                  // desde lunes
assert.deepEqual(g[3], { y: 2026, m: 9, d: 1, inMonth: true })
g = C.monthGrid(2024, 1, 1)                  // febrero bisiesto: 29 días en el mes
assert.equal(g.filter(c => c.inMonth).length, 29); assert.ok(g.some(c => c.inMonth && c.d === 29))
g = C.monthGrid(2026, 11, 1)                 // diciembre → las celdas finales son de enero del año siguiente
assert.deepEqual(g[41].y, 2027); assert.equal(g[41].m, 0)
g = C.monthGrid(2027, 0, 1)                  // enero → celdas iniciales de diciembre anterior
assert.equal(g[0].y, 2026); assert.equal(g[0].m, 11)
// 5. Para todo mes 1900..2100 y todo primer día: 42 celdas consecutivas, el 1 cae en la columna correcta.
for (let y = 1900; y <= 2100; y++) for (let m = 0; m < 12; m++) for (let f = 0; f < 7; f++) {
    g = C.monthGrid(y, m, f)
    const first = g.findIndex(c => c.inMonth)
    assert.ok(first >= 0 && first < 7); assert.equal((f + first) % 7, C.weekday(y, m, 1))
    assert.equal(g.filter(c => c.inMonth).length, C.daysIn(y, m))
    for (let i = 1; i < 42; i++) {
        const a = Date.UTC(g[i - 1].y, g[i - 1].m, g[i - 1].d), b = Date.UTC(g[i].y, g[i].m, g[i].d)
        assert.equal(b - a, 86400000)
    }
}
console.log("calendar: " + n + " días comparados con Date; 5 grupos de pruebas OK")
