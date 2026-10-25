# Novedades de Minimo OS

Cada versión se divide en **Nuevas funciones**, **Correcciones** y **Optimizaciones**.
Ajustes › Actualizaciones muestra este archivo (y CHANGELOG.en.md en inglés). Al publicar una versión: renombrar
«Próxima versión» con el número y la fecha, subir `minimo-shell/VERSION` y crear la etiqueta `vX.Y.Z`.

## 1.2.3 beta — 2026-10-25

### Nuevas funciones
- Actualizar desde Ajustes › Actualizaciones: muestra la versión nueva y sus novedades antes de actualizar, con barra de progreso, registro y «Reiniciar interfaz» sin cerrar sesión.
- Instalador robusto: chequeos previos, reintentos, servidor oficial de respaldo, instalación paquete por paquete, AUR con yay, resumen claro de lo que faltó y registro en ~/.cache/minimo-install.log.
- Convive con KDE Plasma: conserva SDDM, agrega la sesión Minimo OS y la isla solo arranca dentro de Hyprland.
- Accesibilidad: «Reducir animaciones» y «Más contraste».
- No molestar con Super+N, borrar avisos con Super+Shift+N y atajos visibles con Super+/.
- Bienvenida en el primer inicio.
- Barra de nivel para volumen y brillo, estados de silencio y micrófono.

### Correcciones
- Inicio de sesión: el error de contraseña ya no se borra con la sacudida.
- Actualizaciones: se lee bien la versión beta y el estado viejo se limpia al actualizar.
- Buscador: Enter sin resultados ya no falla.

### Optimizaciones
- Instalador más claro: plan previo, porcentaje, tiempos y «Primeros pasos» al final.
- Gestos de touchpad más cómodos: deslizar más corto, cancelar con un gesto corto, toque con dos dedos para clic derecho.
- Notificaciones largas duran más y se indica cuántas hay en cola.

## 1.2.1 beta — 2026-10-25

### Nuevas funciones
- Minimo: ojos que siguen la forma esférica del personaje en todas las animaciones, un poco más grandes, con guiño de un ojo abierto y el otro cerrado.
- Panel de recursos rediseñado y minimalista: anillos de CPU y memoria, detalles al pasar el mouse (temperatura y apps que más consumen), fila de Wi-Fi solo con placa inalámbrica y Deshacer al cambiar el modo de energía.
- Liberar memoria muestra qué ventanas va a cerrar antes de confirmar.

### Correcciones
- Isla: los botones se activan también tocando su texto, se cancelan arrastrando afuera, y Escape vuelve al menú desde una subpágina.
- Un roce del touchpad ya no cambia de escritorio ni hace saltar los sliders.

### Optimizaciones
- Animaciones de Minimo más suaves: anticipación, interrupciones sin saltos y bucles continuos.
- Transiciones, foco de teclado y estados de hover más suaves en la isla.

## 1.2.0 beta — 2026-10-24

### Nuevas funciones
- Laptop: indicador de batería en la isla, avisos de batería baja (20 %) y crítica (5 %), aviso y pulso al enchufar o desenchufar el cargador.
- Laptop: teclas de brillo, manejo de la tapa (apaga la pantalla interna con monitor externo) y selector de energía Ahorro / Equilibrado / Rendimiento.
- Panel de recursos: barra «Liberar memoria», que cierra las ventanas que no usás y muestra cuánta memoria se liberó.
- Escritorios: se reacomodan solos cuando uno queda vacío.
- Atajo de rescate Super+Shift+Escape: reinicia la interfaz si se tilda, sin cerrar apps.
- Simulador de laptop para desarrollo (`scripts/fake-laptop.sh`).

### Optimizaciones
- Sin batería no corre ningún proceso nuevo; con batería se usan eventos de UPower.

## 1.1.1 beta — 2026-10-18

### Nuevas funciones
- Isla: la captura de pantalla se muestra en grande, con su proporción real.
- Mascota: avisos de hambre, aburrimiento y sueño en la isla (uno por necesidad, sin ráfagas) e interruptor para apagarla en Ajustes.
- Ajustes: sección «Gestos de la isla dinámica» con ilustraciones de cada gesto.
- Isla: selector de emojis con categorías, búsqueda y tono de piel (se copia con un clic).
- Ajustes: sección «Actualizaciones» con la versión instalada, comprobación de versiones nuevas y estas notas.
- Iconos Fluent UI System Icons (Filled) en la shell y en la pantalla de inicio.
- Isla › Escritorios: arrastrar una app a otro escritorio, cerrarla con × y enfocarla con un clic.
- Diálogo de contraseña (polkit) con los colores, la fuente y el redondeo de Minimo, claro u oscuro.

### Correcciones
- Pantalla de inicio: el cursor de la contraseña se ve siempre, también con el campo vacío.
- Isla: un poco más separada del borde superior.

### Optimizaciones
- Mascota: los avisos usan un solo temporizador hasta el próximo cambio (sin sondeos) y se detienen con la mascota apagada.
- Conectividad por eventos de NetworkManager en vez de una comprobación cada 10 s.
- El seguimiento del mouse consulta menos cuando el mouse lleva un rato quieto.

## 1.1.0 — 2026-10-16

### Nuevas funciones
- Idioma: interfaz en español o inglés, con selector en Ajustes.
- Pantalla de inicio de Minimo (greetd): transiciones, Bloq Mayús, ver contraseña, botones de apagado con confirmación, selector de sesión y desbloqueo del llavero de GNOME.
- Isla: elementos fijables en el menú (deslizadores, accesos y accesos propios), reordenables desde Ajustes.
- Isla: portapapeles con historial (Super+V), imágenes y elementos fijados.
- Isla: notas, calendario del mes (clic en la fecha) y botones de navegador y archivos.
- Isla: deslizar hacia abajo abre a Minimo como mascota (comida, ánimo y energía).
- Isla: deslizar para ver los recursos del sistema (batería, Wi-Fi con lista de redes) y las apps en segundo plano (bandeja del sistema con su menú).
- Isla: notificaciones con servidor propio, cola y acciones; aviso con miniatura al hacer una captura.
- Vista de ventanas estilo Exposé con Super+Tab.
- Ajustes: fondo animado (video o GIF) que se pausa con ventanas encima o en inactividad; borrar fondos propios.
- Ajustes: sección Atajos generada desde la configuración real, con buscador.
- Modo oscuro y ocultamiento inteligente de la isla.
- Terminal: Minimo saluda en Ghostty; instalador con nuevo diseño e instalación de Helium.
- Instalador de una línea con curl.

### Correcciones
- Energía: una sola confirmación armada a la vez y el negro de confirmación vuelve a verse.
- Polkit: hyprpolkitagent como servicio de usuario (vuelven los diálogos de contraseña).
- Fondo animado: cambiar de A a Quitar a B ya no deja procesos sobrantes.
- Ajustes: los textos largos de las filas con interruptor ya no quedan tapados.
- Notificaciones: se quita la correcta de la cola y se ignoran reemplazos duplicados.
- Bandeja: relanzar apps con una cadena de respaldo segura y menús con mnemónicos correctos.
- Textos en español e inglés revisados.

### Optimizaciones
- Animaciones en pausa durante la inactividad; el fondo anterior se libera.
- Seguimiento del mouse del personaje más eficiente.
- Refresco de ventanas diferido y por eventos (sin sondeos).
- Acerca de consulta las versiones una sola vez.
- Superficies sin filetes finos ni transparencias.

## 1.0.0 — 2026-10-11

### Nuevas funciones
- Primera versión: Hyprland con la isla flotante de Quickshell y Minimo, el personaje.
