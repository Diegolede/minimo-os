# Pantalla de inicio de Minimo OS

greetd + `cage` (compositor kiosco, mínimo) + Quickshell (`Quickshell.Services.Greetd`).
Usa el personaje real de `minimo-shell/Character` (enlace simbólico); `Common/` trae
versiones livianas de los singletons que el personaje necesita (sin Hyprland ni música).

- `Login.qml`: interfaz (hora, Minimo, usuario, píldora de contraseña). Los ojos siguen al
  mouse y entrecierra los ojos mientras escribís, como en la isla.
- `shell.qml`: conexión con greetd; al autenticar lanza `Hyprland`.
- `preview.qml`: vista previa sin greetd ni Quickshell (`qml6 greeter/preview.qml`, clave: `minimo`).
- Ajustes en `/etc/minimo-os/greeter.env`: `MINIMO_USER`, `MINIMO_SESSION`, `MINIMO_DARK=1`.

Instalar: `./install.sh --greeter` (opcional; respalda y desactiva el gestor de sesión actual).

Si algo falla: en otra consola (Ctrl+Alt+F2) editá `/etc/greetd/config.toml` y usá la
línea de `tuigreet`/`agreety`, o volvé al gestor anterior:
`sudo systemctl disable greetd && sudo systemctl enable <gdm|sddm|lightdm>`.
Probar sin cerrar sesión: `MINIMO_GREETER_TEST=1 qs -p greeter` (clave: `minimo`).
