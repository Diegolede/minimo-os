Iconos de Minimo OS: **Fluent UI System Icons** (estilo Filled) de Microsoft.

- Fuente oficial: https://github.com/microsoft/fluentui-system-icons (commit `a347af95478f989038cccbf085978865264c048a`).
- Licencia: MIT, © 2020 Microsoft Corporation — ver `fluent/LICENSE`.
- Solo se vendorizan los SVG que usa la interfaz (`fluent/`, originales sin modificar).
- `map.json` es el mapa central: nombre en Minimo OS → carpeta de Fluent. `Common/Icon.qml`
  (shell) y `greeter/Common/Icon.qml` cargan `<tono>/<nombre>.svg`.
- `dark/`, `gray/`, `graydark/` y `white/` se generan con `python3 build.py` (solo cambia el color
  de relleno). Para un icono nuevo: añadirlo a `map.json`, `python3 build.py fetch`, `python3 build.py`.
- Nada se descarga en tiempo de ejecución.
