// Ciclos reales de procesos con un mpvpaper falso (node tests/livewall.test.js).
// Reproduce el flujo de LiveWallpaper.qml: want() decide, se lanza/termina el proceso y
// exited() + want() al terminar (como onExited + Qt.callLater(sync)).
const fs = require("fs"), path = require("path"), cp = require("child_process"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../minimo-shell/Common/livewall.js"), "utf8").replace(/^\.pragma library$/m, "")
const LW = new Function(src + "; return { initial, want, exited }")()
const FAKE = path.join(__dirname, "fake/mpvpaper"), SOCK = "/tmp/minimo-wallpaper-test.sock"
const sleep = ms => new Promise(r => setTimeout(r, ms))

let st = LW.initial(), wanted = "", proc = null, starts = 0, maxAlive = 0, alive = 0
function sync() {
    const r = LW.want(st, wanted, Date.now()); st = r.state
    if (r.act === "start") {
        starts++; alive++; maxAlive = Math.max(maxAlive, alive)
        // Mismo envoltorio que LiveWallpaper.qml: borra el socket viejo y hace exec.
        proc = cp.spawn("sh", ["-c", 'rm -f "$1"; shift; exec "$0" "$@"', FAKE, SOCK, "-o", "no-audio input-ipc-server=" + SOCK, "*", st.current], { stdio: "ignore" })
        proc.on("exit", () => { alive--; proc = null; st = LW.exited(st, Date.now()); setImmediate(sync) })
    } else if (r.act === "stop") proc.kill("SIGTERM")
}
function set(p) { wanted = p; sync() }
function pgrep() { try { return cp.execFileSync("pgrep", ["-f", FAKE]).toString().trim().split("\n").filter(Boolean) } catch (e) { return [] } }

;(async () => {
    for (let i = 1; i <= 5; i++) {
        set("/videos/A" + i + ".mp4"); await sleep(150)
        assert.equal(st.current, "/videos/A" + i + ".mp4"); assert.equal(pgrep().length, 1, "ciclo " + i + ": un proceso con A")
        set(""); await sleep(150)
        assert.equal(pgrep().length, 0, "ciclo " + i + ": ninguno tras Quitar")
        set("/videos/B" + i + ".mp4"); await sleep(150)
        assert.equal(st.current, "/videos/B" + i + ".mp4", "ciclo " + i + ": B arranca tras Quitar")
        assert.equal(pgrep().length, 1)
        set("/videos/C" + i + ".mp4"); await sleep(150)          // cambio directo B→C
        assert.equal(st.current, "/videos/C" + i + ".mp4"); assert.equal(pgrep().length, 1)
        set(""); await sleep(150)
        assert.equal(pgrep().length, 0)
    }
    // Cambios rápidos (sin esperar): termina con el último, un solo proceso.
    set("/videos/X.mp4"); set(""); set("/videos/Y.mp4"); set("/videos/Z.mp4"); await sleep(300)
    assert.equal(st.current, "/videos/Z.mp4"); assert.equal(pgrep().length, 1)
    // Archivo que falla al instante: no hay bucle de reinicios.
    const before = starts; set("/videos/roto.mp4"); await sleep(600)
    assert.ok(starts - before <= 2, "sin bucle: " + (starts - before) + " arranques"); assert.equal(pgrep().length, 0)
    // El socket que dejó el proceso roto se reemplaza al arrancar el siguiente y se borra al detenerlo.
    assert.ok(fs.existsSync(SOCK)); set("/videos/D.mp4"); await sleep(150); assert.equal(pgrep().length, 1)
    set(""); await sleep(150)
    assert.equal(maxAlive, 1, "nunca dos procesos a la vez")
    assert.equal(pgrep().length, 0, "sin procesos sobrantes")
    assert.ok(!fs.existsSync(SOCK), "sin socket sobrante")
    console.log("livewall: 5 ciclos A→Quitar→B→C→Quitar + cambios rápidos + archivo roto OK; arranques=" + starts + ", máx. simultáneos=" + maxAlive + ", sobrantes=" + pgrep().length)
})().catch(e => { console.error("FALLA:", e.message); process.exit(1) })
