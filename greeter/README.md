# Pantalla de inicio de Minimo OS

greetd + `cage` (compositor kiosco, mínimo) + Quickshell (`Quickshell.Services.Greetd`).
Usa el personaje real de `minimo-shell/Character` (enlace simbólico); `Common/` trae
versiones livianas de los singletons que el personaje necesita (sin Hyprland ni música).

- `Login.qml`: interfaz (hora, Minimo, usuario, píldora de contraseña). Los ojos siguen al
  mouse y entrecierra los ojos mientras escribís, como en la isla.
- `shell.qml`: conexión con greetd (Quickshell ≥ 0.3); al autenticar lanza `start-hyprland`
  (lanzador recomendado desde Hyprland 0.53). Soporta pedidos extra de PAM y reintentos.
- `preview.qml`: vista previa sin greetd ni Quickshell (`qml6 greeter/preview.qml`, clave: `minimo`).
- `minimo-session`: sesión que abre greetd (`start-hyprland` sin texto de arranque en la consola;
  si no existe, `Hyprland`). Para ver el texto de arranque al depurar: `MINIMO_SESSION=start-hyprland`.
- Llavero: si está `gnome-keyring`, el instalador añade `pam_gnome_keyring.so` (auth y session
  auto_start) a `/etc/pam.d/greetd` para desbloquearlo con la clave del inicio. Quitar esas dos
  líneas lo desactiva.
- Ajustes en `/etc/minimo-os/greeter.env`: `MINIMO_USER`, `MINIMO_SESSION`, `MINIMO_DARK=1`.

Instalar: `greeter/install-greeter.sh` (o `./install.sh --greeter`). Idempotente; respalda
`/etc/greetd/config.toml`, desactiva el gestor actual (p. ej. GDM) sin detenerlo y activa greetd:
se ve al reiniciar. `--dry-run` muestra lo que haría.

Si algo falla: en otra consola (Ctrl+Alt+F3) editá `/etc/greetd/config.toml` y usá la
línea de `tuigreet`/`agreety`, o volvé al gestor anterior:
`sudo systemctl disable greetd && sudo systemctl enable gdm && sudo reboot`.
Registro: `/run/user/$(id -u greeter)/minimo-greeter/greeter.log`.
Probar sin cerrar sesión: `MINIMO_GREETER_TEST=1 qs -p greeter` (clave: `minimo`).

## Detalles de la experiencia
- Entrada con fundido suave; al entrar, Minimo guiña y todo se desvanece antes de abrir Hyprland.
- Píldora: puntos que respiran mientras verifica, ojo dibujado para mostrar/ocultar, aviso de
  Bloq Mayús, Escape borra (y cancela un pedido extra de PAM).
- Minimo se duerme (Z z z de la isla) tras 1 min sin actividad y despierta con mouse o teclado.
- Apagar / reiniciar abajo a la derecha: primer clic muestra la etiqueta, el segundo (≤ 3 s)
  ejecuta `systemctl poweroff|reboot` (logind lo permite a la sesión activa del asiento).
- Vista previa de estados: `qml6 greeter/preview.qml -- --typing|--loading|--success|--caps|--sleep|--power|--dark`.
