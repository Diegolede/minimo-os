<p align="center">
  <img src="assets/minimo-icon.png" width="128" alt="Minimo OS">
</p>

<h1 align="center">Minimo OS</h1>

<p align="center">Hyprland minimalista: una isla flotante y un personaje feliz. Nada más de lo necesario.</p>

<p align="center"><a href="https://diegolede.github.io/minimo-os-web/">Web oficial</a></p>

---

## Qué es

Minimo OS es una configuración completa de escritorio para Arch Linux sobre Hyprland, con una
shell propia escrita en Quickshell (QML). Toda la interfaz vive en una sola isla flotante en la
parte superior de la pantalla, acompañada por un pequeño personaje que reacciona a lo que hacés.

## Características

- **Isla dinámica.** Hora, escritorios y estado en una píldora compacta que se oculta sola y aparece al acercar el mouse. Al hacer clic se expande: buscador, música, volumen, brillo, saturación y accesos rápidos.
- **Personaje.** Una esfera negra con ojos que siguen al mouse con proyección esférica. Parpadea, respira, salta hacia atrás, se ríe, guiña, se marea, bosteza, saluda al abrir la isla y baila con la música.
- **Paneles deslizables.** Arrastrá la isla de izquierda a derecha para ver los recursos del sistema, o de derecha a izquierda para ver las apps en segundo plano de la bandeja del sistema (Steam, Discord…), como los iconos ocultos de Windows 11; un clic las vuelve a abrir.
- **Notificaciones.** La isla muestra las notificaciones entrantes; se pausan al pasar el mouse y se respeta el modo No molestar.
- **Sueño.** Cuando la PC queda inactiva (1, 2 o 5 minutos) el personaje se duerme y aparecen las "z". Despierta al volver a usar el equipo.
- **Lanzador.** `Super + B` abre un buscador de aplicaciones centrado, navegable con el teclado.
- **Grabación de pantalla.** Botón "Grabar" en la isla (wf-recorder, con audio del sistema). Los videos se guardan en `~/Vídeos/Grabaciones`.
- **Reproductor.** Carátula circular que gira como un vinilo mientras suena la música.
- **Wi-Fi.** En equipos sin cable, la isla muestra la red actual, la señal y las redes cercanas para conectarse.
- **Ajustes.** Ventana propia con fondo de pantalla, opciones de la isla y del personaje, monitores (resolución, frecuencia y escala con confirmación) y brillo/saturación.

## Capturas

| Personalización | Pantalla | Acerca de |
|---|---|---|
| ![Personalización](docs/ajustes-personalizacion.png) | ![Pantalla](docs/ajustes-pantalla.png) | ![Acerca de](docs/ajustes-acerca.png) |

## Requisitos

- Arch Linux (usuario normal con `sudo`).
- Hyprland 0.56 o superior (configuración en Lua).
- Paquetes (el instalador los instala): `hyprland xdg-desktop-portal-hyprland hyprpolkitagent quickshell qt6-declarative qt6-svg qt6-wayland pipewire pipewire-pulse wireplumber cava playerctl ghostty grim slurp wf-recorder zenity adwaita-fonts networkmanager wl-clipboard cliphist gnome-keyring python lua git`.
- Opcionales: `fuzzel github-cli`; `mpvpaper` (AUR) para el fondo animado.
- Contraseñas de administrador (pkexec, gestores de particiones…): el agente polkit `hyprpolkitagent` se habilita como servicio de usuario.

## Instalación

En una sola línea:

```bash
curl -fsSL https://raw.githubusercontent.com/Diegolede/minimo-os/main/install.sh | bash
```

Con opciones: `curl -fsSL …/install.sh | bash -s -- --dry-run`. Clona el proyecto en
`~/Proyectos/minimo-os` y continúa desde ahí; las preguntas se responden en la terminal.

> La instalación en una línea requiere que el repositorio sea público. Mientras sea privado,
> usá el método manual después de `gh auth login`.

Manual:

```bash
git clone https://github.com/Diegolede/minimo-os.git ~/Proyectos/minimo-os
~/Proyectos/minimo-os/install.sh
```

- `--dry-run` muestra cada paso sin cambiar nada.
- `--yes` no hace preguntas.
- `--no-greeter` conserva tu gestor de sesión actual (GDM, SDDM…) en vez de la pantalla de inicio de Minimo.

Incluye todo Minimo OS: Hyprland + minimo-shell, el navegador Helium (`helium-browser-bin`, AUR),
Ghostty con su configuración y el saludo de Minimo en la terminal, y la **pantalla de inicio**
(greetd + cage + Quickshell) con el llavero de GNOME desbloqueado al entrar. La pantalla de inicio
respalda `/etc/greetd/config.toml`, desactiva el gestor actual **sin detenerlo** y se ve al reiniciar.
Si no arranca: `Ctrl+Alt+F3`, entrá con tu usuario y
`sudo systemctl disable greetd && sudo systemctl enable gdm && sudo reboot`.

El instalador es idempotente. Instala los paquetes, respalda `~/.config/hypr` en
`~/.config/hypr.bak-<fecha>`, enlaza la configuración del repositorio (un `git pull` la
actualiza), copia `minimo/monitores.lua` una sola vez (es propio de cada PC), copia los fondos a
`~/Imágenes/Fondos` y habilita el servicio `minimo-shell.service`.


## Desinstalación

```bash
~/Proyectos/minimo-os/uninstall.sh
```

Desactiva la shell y restaura el último respaldo de `~/.config/hypr`. No borra paquetes ni fondos.

## Configuración

Todo lo habitual se cambia desde **Ajustes** (botón en la isla o `Super + ,`):

- **Personalización:** fondo de pantalla, ocultar la isla automáticamente, personaje animado y tiempo para dormir.
- **Pantalla:** resolución, frecuencia y escala por monitor (se revierte en 15 s si no confirmás), brillo y saturación.
- **Minimo OS:** versión e información del sistema.

El estado se guarda en `~/.config/minimo-os/state.json`. La configuración de Hyprland está en
`hypr/` y se puede editar directamente.

Desde la terminal o atajos propios:

```bash
qs -p ~/Proyectos/minimo-os/minimo-shell ipc call launcher toggle
qs -p ~/Proyectos/minimo-os/minimo-shell ipc call settings toggle
qs -p ~/Proyectos/minimo-os/minimo-shell ipc call recorder toggle
qs -p ~/Proyectos/minimo-os/minimo-shell ipc call character list
```

## Estructura del proyecto

```
minimo-os/
├── install.sh / uninstall.sh   instalación y desinstalación
├── hypr/
│   ├── hyprland.lua            punto de entrada de Hyprland
│   ├── minimo.lua              atajos de la shell
│   └── minimo/                 apariencia, entrada, monitores, reglas y atajos
├── minimo-shell/               shell en Quickshell (QML)
│   ├── Island/                 isla dinámica y sus secciones
│   ├── Character/              personaje y reacciones
│   ├── Launcher/               lanzador (Super + B)
│   ├── Settings/               ventana de Ajustes
│   ├── Wallpaper/              fondo de pantalla
│   ├── Common/                 estado compartido, tema y servicios
│   └── assets/                 iconos de línea
├── systemd/                    servicio de usuario de la shell
├── assets/                     icono y fondos por defecto
└── docs/                       capturas
```

## Apoyar Minimo OS

Si te gusta Minimo OS y querés que siga mejorando, podés apoyar el proyecto:
<!-- TODO: reemplazar por el link de donaciones (y completar .github/FUNDING.yml) -->
**[Apoyar Minimo OS](#)** _(link pendiente)_

## Autor

Creado por **TRN1 (Diego Ledesma)**.

## Licencia

[MIT](LICENSE) — © 2026 Diego Ledesma (TRN1).
