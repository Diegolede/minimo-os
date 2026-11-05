# Aplicar patch de diagnóstico (sin reinicio de sesión)

## Qué hace este patch

**Captura errores de dispatch** en `/tmp/minimo-dispatch-debug.log` sin suprimir stderr.

### Cambios exactos

1. **Elimina supresión de stderr**: `>/dev/null 2>&1` → `2>&1 | tee -a /tmp/...`
2. **Agrega logging**: `console.log` muestra cuando se ejecuta dispatch
3. **Captura output**: Todo stdout/stderr va a archivo temporal

### Efectos

- ✅ **NO reinicia sesión**
- ✅ **NO cambia comportamiento** (sólo agrega logging)
- ✅ **Reversible** fácilmente
- ⚠️ **Crea archivo** `/tmp/minimo-dispatch-debug.log`

---

## Aplicación

```bash
cd ~/Proyectos/minimo-os

# Backup del original
cp minimo-shell/Common/Workspaces.qml minimo-shell/Common/Workspaces.qml.backup

# Aplicar patch
patch -p1 < patch-capture-dispatch-errors.diff

# Forzar recarga del singleton (sin reiniciar shell completa)
# Quickshell recarga singletons modificados automáticamente en algunos casos
# Si no recarga solo, necesitarás reiniciar minimo-shell
```

---

## Uso

1. **Aplicar patch** (arriba)
2. **Probar scroll** sobre isla dinámica
3. **Ver errores capturados**:
   ```bash
   cat /tmp/minimo-dispatch-debug.log
   ```
4. **Ver logs de consola**:
   ```bash
   journalctl --user -u minimo-shell -n 50 --no-pager | grep DISPATCH
   ```

---

## Reversión

```bash
cd ~/Proyectos/minimo-os

# Restaurar original
mv minimo-shell/Common/Workspaces.qml.backup minimo-shell/Common/Workspaces.qml

# Limpiar
rm /tmp/minimo-dispatch-debug.log

# Reiniciar shell
systemctl --user restart minimo-shell
```

---

## Qué buscar en logs

### Si dispatch funciona correctamente

```
[DISPATCH] Executing for target: r+1 at 2026-11-05T21:44:00.000Z
ok
```

### Si hay error de sintaxis

```
[DISPATCH] Executing for target: r+1 at 2026-11-05T21:44:00.000Z
error: [string "..."]:1: syntax error near ...
```

### Si selector no funciona

```
[DISPATCH] Executing for target: r+1 at 2026-11-05T21:44:00.000Z
error: invalid workspace selector
```

### Si no se ejecuta nada

- No hay líneas `[DISPATCH]` en logs → función wheel() no se llama
- Problema está antes del dispatch (evento wheel no llega)
