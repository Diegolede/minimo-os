// Pruebas del selector de sesión del greeter (node tests/sessions.test.js).
const fs = require("fs"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../greeter/Common/sessions.js"), "utf8").replace(/^\.pragma library$/m, "")
const S = new Function(src + "; return { splitExec, parseDesktop, parseAll, envFor, pick }")()
// 1. Exec: comillas, escapes y códigos de campo.
assert.deepEqual(S.splitExec("Hyprland"), ["Hyprland"])
assert.deepEqual(S.splitExec('env FOO=1 "/opt/my app/run" --x %U'), ["env", "FOO=1", "/opt/my app/run", "--x"])
assert.deepEqual(S.splitExec('sh -c "echo \\"hola\\" \\$HOME"'), ["sh", "-c", 'echo "hola" $HOME'])
assert.deepEqual(S.splitExec("run --pct=50%% %f"), ["run", "--pct=50%"])
assert.deepEqual(S.splitExec('roto "sin cerrar'), [])
assert.deepEqual(S.splitExec(""), [])
// 2. .desktop: ocultos, NoDisplay, sin Exec, otras secciones.
const hypr = "[Desktop Entry]\nName=Hyprland\nComment=x\nExec=start-hyprland\nType=Application\nDesktopNames=Hyprland\n"
assert.deepEqual(S.parseDesktop(hypr, "/usr/share/wayland-sessions/hyprland.desktop"), { id: "hyprland", name: "Hyprland", exec: ["start-hyprland"], desktopNames: "Hyprland" })
assert.equal(S.parseDesktop(hypr + "Hidden=true\n", "/a/h.desktop"), null)
assert.equal(S.parseDesktop(hypr.replace("Type=Application", "NoDisplay=true"), "/a/h.desktop"), null)
assert.equal(S.parseDesktop("[Desktop Entry]\nName=Nada\n", "/a/n.desktop"), null)
assert.equal(S.parseDesktop("[Desktop Entry]\nName=A\nExec=a\n[Desktop Action x]\nExec=b\nName=B\n", "/a/a.desktop").exec[0], "a")
assert.equal(S.parseDesktop("[Desktop Entry]\nName[es]=Gnomo\nName=GNOME\nExec=gnome-session\n", "/x/gnome.desktop").name, "GNOME")
// 3. Lista completa: Minimo primero, orden por nombre, sin duplicados, inválidas fuera.
const dump = "@@FILE /usr/share/wayland-sessions/sway.desktop\n[Desktop Entry]\nName=Sway\nExec=sway\nDesktopNames=sway\n" +
             "@@FILE /usr/share/wayland-sessions/hyprland.desktop\n" + hypr +
             "@@FILE /usr/share/wayland-sessions/oculta.desktop\n[Desktop Entry]\nName=Oculta\nExec=x\nHidden=true\n" +
             "@@FILE /usr/share/wayland-sessions/gnome.desktop\n[Desktop Entry]\nName=GNOME\nExec=gnome-session\nDesktopNames=GNOME\n"
const list = S.parseAll(dump, ["minimo-session"])
assert.deepEqual(list.map(s => s.id), ["minimo", "gnome", "hyprland", "sway"])
assert.deepEqual(list[0].exec, ["minimo-session"])
assert.deepEqual(S.parseAll("", ["minimo-session"]).map(s => s.id), ["minimo"], "sin archivos: solo Minimo")
// 4. Recordada / por defecto.
assert.equal(S.pick(list, "sway\n"), "sway"); assert.equal(S.pick(list, "borrada"), "minimo"); assert.equal(S.pick(list, ""), "minimo")
// 5. Entorno.
assert.deepEqual(S.envFor(list[0]), ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=Hyprland", "XDG_CURRENT_DESKTOP=Hyprland"])
assert.deepEqual(S.envFor({ desktopNames: "GNOME;Unity;" }), ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=GNOME", "XDG_CURRENT_DESKTOP=GNOME:Unity"])
assert.deepEqual(S.envFor({ desktopNames: "" }), ["XDG_SESSION_TYPE=wayland"])
console.log("sessions: 5 grupos de pruebas OK")
