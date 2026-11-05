# Análisis: Regresión de scroll en isla dinámica

**Estado**: Causa raíz NO demostrada. Investigación en curso.

---

## Síntoma reportado

- **Antes (Hyprland < 0.57.1)**: Scroll del mouse sobre isla dinámica cambia de escritorio
- **Después (Hyprland 0.57.1)**: Scroll no hace nada

---

## Análisis del código

### Flujo completo del scroll

```
1. Mouse sobre isla → hoverZone (MouseArea en Island.qml)
2. Evento wheel → onWheel handler (línea 207)
3. Verificación: !win.open (isla no expandida)
4. Llamada: Workspaces.wheel(w.angleDelta.y)
5. Acumulación de deltaY hasta 120 unidades
6. Enfriamiento: mínimo 220ms entre cambios
7. Llamada: dispatchWs(deltaY > 0 ? "r-1" : "r+1")
8. Ejecución: sh -c "hyprctl dispatch 'hl.dsp.focus({workspace=\"TARGET\"})' >/dev/null 2>&1"
9. Hyprland procesa el comando
10. Workspace cambia (o debería cambiar)
```

### Código relevante

**Island.qml línea 207:**
```qml
onWheel: w => { if (!win.open) Workspaces.wheel(w.angleDelta.y) }
```

**Workspaces.qml línea 25-36:**
```qml
function wheel(deltaY) {
    const now = Date.now()
    if (deltaY === 0) return
    if (now - wheelT > 300 || (wheelAcc > 0) !== (deltaY > 0)) wheelAcc = 0
    wheelT = now
    wheelAcc += deltaY
    if (Math.abs(wheelAcc) < 120 || now - lastWheel < 220) return
    lastWheel = now; wheelAcc = 0
    dispatchWs(deltaY > 0 ? "r-1" : "r+1")
}
```

**Workspaces.qml línea 19-23:**
```qml
function dispatchWs(target) {
    Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({workspace=\"" + target + "\"})' >/dev/null 2>&1"])
    lastSwitch = Date.now()
}
```

---

## Hipótesis a investigar

### Hipótesis 1: Evento wheel no llega al handler QML

**Posibles causas:**
- Cambio en Qt6 o Quickshell 0.3.2 en cómo se manejan eventos wheel
- MouseArea no acepta wheel events sin configuración específica
- Otro componente intercepta el evento

**Cómo probar:**
```qml
onWheel: w => { 
    console.log("[DEBUG] wheel event received:", w.angleDelta.y)
    if (!win.open) Workspaces.wheel(w.angleDelta.y) 
}
```

**Test aislado:** `test-wheel-minimal.qml`

### Hipótesis 2: Acumulación de wheelAcc rompe la lógica

**Posibles causas:**
- deltaY tiene valores diferentes en nueva versión
- La condición `Math.abs(wheelAcc) < 120` nunca se cumple
- Enfriamiento de 220ms es demasiado agresivo

**Cómo probar:**
```qml
function wheel(deltaY) {
    console.log("[DEBUG] deltaY:", deltaY, "wheelAcc:", wheelAcc, "diff:", Date.now() - wheelT)
    // ... resto
}
```

### Hipótesis 3: dispatchWs ejecuta pero falla silenciosamente

**Posibles causas:**
- `Quickshell.execDetached()` no funciona en 0.3.2
- Redirección `>/dev/null 2>&1` oculta errores útiles
- Shell command no se ejecuta correctamente

**Cómo probar:**
- Quitar redirección: `hyprctl dispatch ...` sin `>/dev/null 2>&1`
- Usar Process en lugar de execDetached para capturar salida
- Ejecutar comando manualmente

### Hipótesis 4: hyprctl funciona pero Hyprland 0.57.1 cambió comportamiento

**Fix conocido en 0.57.1:**
```
state/workspace: fix underflow in r parsing resulting in a bad return (#16786)
```

Este fix hace que `r-1` desde el workspace más bajo NO salte a otro monitor. Pero esto no debería prevenir el cambio de workspace completamente.

**Cómo probar:**
```bash
# Manualmente
hyprctl dispatch 'hl.dsp.focus({workspace="r+1"})'
hyprctl dispatch 'hl.dsp.focus({ workspace = "r+1" })'
```

### Hipótesis 5: Sintaxis del comando es incorrecta

**Análisis:**
- Sintaxis actual: `hl.dsp.focus({workspace="r+1"})`
- Sintaxis con espacios: `hl.dsp.focus({ workspace = "r+1" })`

**En Lua, ambas son equivalentes:**
```lua
-- Estos son idénticos:
{workspace="value"}
{ workspace = "value" }
{workspace = "value"}
```

Los espacios alrededor de `=` y dentro de `{}` son opcionales y no afectan el parsing.

**Conclusión:** Este NO es el problema.

---

## Datos necesarios de Diego

### Test 1: ¿Funciona hyprctl manualmente?

```bash
# Cambiar al escritorio 2 directamente
hyprctl dispatch 'hl.dsp.focus({workspace="2"})'
echo "¿Cambió al escritorio 2? (sí/no)"

# Probar r+1
hyprctl dispatch 'hl.dsp.focus({workspace="r+1"})'
echo "¿Cambió al siguiente escritorio? (sí/no)"

# Ver escritorio actual
hyprctl activeworkspace -j | jq '.id'
```

### Test 2: ¿Llega el evento wheel a QML?

Editar temporalmente `minimo-shell/Common/Workspaces.qml`:

```diff
 function wheel(deltaY) {
     const now = Date.now()
+    console.log("[WHEEL] deltaY:", deltaY, "wheelAcc:", wheelAcc, "time_diff:", now - wheelT)
     if (deltaY === 0) return
```

Reiniciar shell y probar:

```bash
systemctl --user restart minimo-shell
# Esperar 2-3 segundos
# Mover mouse sobre isla y usar rueda
journalctl --user -u minimo-shell -f | grep WHEEL
```

### Test 3: ¿Se ejecuta dispatchWs?

Editar temporalmente `minimo-shell/Common/Workspaces.qml`:

```diff
 function dispatchWs(target) {
+    console.log("[DISPATCH] Executing for target:", target)
     Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({workspace=\"" + target + "\"})' >/dev/null 2>&1"])
     lastSwitch = Date.now()
 }
```

### Test 4: ¿Funciona sin redirección de errores?

Editar temporalmente `minimo-shell/Common/Workspaces.qml`:

```diff
 function dispatchWs(target) {
-    Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({workspace=\"" + target + "\"})' >/dev/null 2>&1"])
+    Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({workspace=\"" + target + "\"})'"])
     lastSwitch = Date.now()
 }
```

Ver si aparecen errores en logs.

### Test 5: ¿Funciona test aislado de wheel?

```bash
cd ~/Proyectos/minimo-os
quickshell -c test-wheel-minimal.qml
# Mover mouse sobre ventana roja y usar rueda
# Ver output en terminal
```

---

## Cambios NO demostr

ados como soluciones

### ❌ Agregar espacios alrededor de `=`

```diff
-Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({workspace=\"" + target + "\"})' >/dev/null 2>&1"])
+Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + target + "\" })"])
```

**Por qué no es demostrado:**
- Espacios son opcionales en Lua (ambas sintaxis válidas)
- No hay evidencia de que Hyprland rechace la sintaxis sin espacios
- No hay test que demuestre que esto arregla el problema

### ❌ Cambiar de sh -c a argumentos directos

```diff
-Quickshell.execDetached(["sh", "-c", "hyprctl dispatch '...'"])
+Quickshell.execDetached(["hyprctl", "dispatch", "..."])
```

**Por qué podría ayudar:**
- Elimina una capa de shell (menos lugares donde fallar)
- Más fácil de debuggear
- Errores no se pierden en redirección

**Pero:**
- Sin evidencia de que `sh -c` sea el problema
- Necesita testing para confirmar

---

## Próximos pasos

1. **Ejecutar tests de diagnóstico** con logging temporal
2. **Identificar en qué punto del flujo falla** (1-10 del diagrama arriba)
3. **Implementar fix específico** basado en causa real
4. **Crear test de regresión** que falle sin el fix y pase con él

---

## Archivos relevantes

- `minimo-shell/Island/Island.qml` - Handler onWheel (línea 207)
- `minimo-shell/Common/Workspaces.qml` - Lógica de scroll y dispatch
- `test-wheel-minimal.qml` - Test aislado de eventos wheel
- `COMANDOS_DIAGNOSTICO_READONLY.md` - Guía completa de diagnóstico

---

**No hacer cambios al código hasta demostrar causa raíz con datos reales.**
