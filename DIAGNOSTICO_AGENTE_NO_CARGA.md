# Diagnóstico: Agente AppDynamics No Se Carga

**Problema:** Después de reiniciar el BUS, no hay logs en la carpeta del agente y no aparece registrado en el Controller.

> **⚠️ IMPORTANTE:** El agente de AppDynamics para IBM ACE/IIB es un **User Exit nativo**, NO un agente Java. Se instala usando `mqsichangebroker` y NO requiere `JAVA_OPTS` ni `-javaagent`.

## ⚠️ Síntoma Crítico: Comando de Verificación No Devuelve Nada

Si ejecutaste este comando y **NO devuelve nada**:

```bash
grep -i "<USER_EXIT_NAME>\|appdynamics\|user.exit" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/*.log
```

**Esto significa:**
- ✅ El agente **NO se está cargando** en absoluto
- ✅ El user exit **NO está instalado** o **NO se está cargando** correctamente
- ✅ El broker **NO está reconociendo** el user exit

**Acción inmediata:** Verificar que el user exit está instalado con `mqsireportbroker` y seguir el diagnóstico paso a paso.

---

## 🔍 Diagnóstico Rápido (Ejecutar en Orden)

### Paso 1: Verificar que el user exit está instalado

```bash
# Verificar configuración del broker
mqsireportbroker <BROKER_NAME>

# Debe mostrar información sobre el user exit instalado
# Buscar referencias a AppDynamics o el nombre del user exit
```

**Resultado esperado:** Debe mostrar información sobre el user exit instalado.

**Si NO aparece nada:**
- El user exit no está instalado
- Necesitas instalarlo con `mqsichangebroker`

---

### Paso 2: Verificar que el directorio del agente existe

```bash
# Verificar existencia del directorio de instalación
ls -la /opt/appdynamics/iib-agent/

# Si no existe, verificar otras ubicaciones posibles
find /opt -name "controller-info.xml" 2>/dev/null | grep -i appdynamics
find /usr/local -name "controller-info.xml" 2>/dev/null | grep -i appdynamics
```

**Resultado esperado:** Debe mostrar el directorio con los archivos del agente.

---

### Paso 3: Verificar configuración en controller-info.xml

```bash
# Verificar que el archivo existe
ls -la /opt/appdynamics/iib-agent/conf/controller-info.xml

# Verificar configuración básica
grep -E "controller-host|controller-port|account-name|account-access-key|application-name|user-exit" /opt/appdynamics/iib-agent/conf/controller-info.xml

# ⚠️ CRÍTICO: Verificar que user-exit es wmqi
grep "user-exit" /opt/appdynamics/iib-agent/conf/controller-info.xml
```

**Resultado esperado:** 
- Debe mostrar todas las configuraciones
- El `user-exit` debe ser **wmqi** (requerido por el Controller)

**Si el `user-exit` no es wmqi (p. ej. "AppDynamics", "AppDynamicsExit"):**
- El agente NO funciona con otros valores
- Cambiar a **wmqi** en controller-info.xml y en node.conf.yaml (activeUserExitList)

---

### Paso 4: Verificar que el nombre del user exit coincide

```bash
# Verificar nombre en controller-info.xml
USER_EXIT_XML=$(grep "user-exit" /opt/appdynamics/iib-agent/conf/controller-info.xml | sed 's/.*<user-exit>\(.*\)<\/user-exit>.*/\1/')
echo "User exit en XML: $USER_EXIT_XML"

# Verificar nombre usado en mqsichangebroker
# (Revisar historial de comandos o documentación)
# Deben coincidir EXACTAMENTE
```

**Resultado esperado:** Los nombres deben coincidir exactamente.

**Si NO coinciden:**
- El broker no puede cargar el user exit
- Reinstalar con el nombre correcto

---

### Paso 5: Verificar permisos y directorio de logs

```bash
# Verificar permisos del directorio del agente
ls -ld /opt/appdynamics/iib-agent

# Verificar que el directorio de logs existe
LOG_DIR=$(grep "log-dir" /opt/appdynamics/iib-agent/conf/controller-info.xml | sed 's/.*<log-dir>\(.*\)<\/log-dir>.*/\1/')
echo "Directorio de logs: $LOG_DIR"
ls -ld "$LOG_DIR" 2>/dev/null || echo "⚠️ Directorio de logs no existe"

# Si no existe, crearlo
mkdir -p "$LOG_DIR"
chown <ACE_USER>:<ACE_GROUP> "$LOG_DIR"
chmod 775 "$LOG_DIR"
```

**Reemplazar `<ACE_USER>` y `<ACE_GROUP>` con el usuario y grupo que ejecuta ACE.**

---

### Paso 6: Verificar cómo se instaló el user exit

```bash
# Verificar la instalación del user exit
mqsireportbroker <BROKER_NAME> | grep -i "user.exit\|appdynamics"

# Verificar logs del broker al iniciar
grep -i "user.exit\|appdynamics" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/system.log | tail -50
```

**Si no hay referencias:** El user exit no se está cargando.

---

### Paso 7: Verificar logs del agente

```bash
# Verificar directorio de logs configurado
LOG_DIR=$(grep "log-dir" /opt/appdynamics/iib-agent/conf/controller-info.xml | sed 's/.*<log-dir>\(.*\)<\/log-dir>.*/\1/')
echo "Buscando logs en: $LOG_DIR"

# Si está vacío, usar default
if [ -z "$LOG_DIR" ]; then
    LOG_DIR="/tmp/appd"
fi

# Verificar logs
ls -la "$LOG_DIR"/*.log 2>/dev/null || echo "⚠️ No hay archivos de log aún"

# Ver contenido de logs
tail -50 "$LOG_DIR"/*.log 2>/dev/null || echo "⚠️ No hay logs para mostrar"
```

**Si no hay logs:** El agente no se está ejecutando.

---

## 🔧 Soluciones Comunes

### ⚠️ Solución 0: Si el user exit NO está instalado

**Síntoma:** `mqsireportbroker` no muestra información del user exit.

**Solución:** Instalar el user exit. En **ACE 12.0.12.x** suele estar deprecado `mqsichangebroker` (error BIP8161E/BIP8101E); en ese caso usar `mqsichangeproperties` o editar `node.conf.yaml` (ver README/INSTRUMENTACION).

```bash
# 1. Detener el broker
mqsi stop <BROKER_NAME>

# 2. Instalar el user exit (si sale BIP8161E/BIP8101E, usar los dos comandos siguientes en su lugar)
mqsichangebroker <BROKER_NAME> -x /opt/appdynamics/iib-agent -e wmqi
# Alternativa si mqsichangebroker está deprecado:
# mqsichangeproperties <BROKER_NAME> -n userExitPath -v /opt/appdynamics/iib-agent
# mqsichangeproperties <BROKER_NAME> -n activeUserExitList -v wmqi

# 3. Verificar instalación
mqsireportbroker <BROKER_NAME>

# 4. Iniciar el broker
mqsi start <BROKER_NAME>
```

---

### Solución 1: Verificar y corregir nombre del user exit

**Problema:** El nombre del user exit contiene caracteres especiales o no coincide.

```bash
# 1. Verificar nombre en controller-info.xml
grep "user-exit" /opt/appdynamics/iib-agent/conf/controller-info.xml

# 2. Si no es wmqi, cambiarlo a wmqi
# Editar controller-info.xml y poner: <user-exit>wmqi</user-exit>

# 3. Detener el broker
mqsi stop <BROKER_NAME>

# 4. Reinstalar con el nombre correcto
mqsichangebroker <BROKER_NAME> -x /opt/appdynamics/iib-agent -e wmqi

# 5. Verificar que coinciden
USER_EXIT_XML=$(grep "user-exit" /opt/appdynamics/iib-agent/conf/controller-info.xml | sed 's/.*<user-exit>\(.*\)<\/user-exit>.*/\1/')
echo "User exit configurado: $USER_EXIT_XML"
echo "Asegurar que coincide con el usado en mqsichangebroker"

# 6. Iniciar el broker
mqsi start <BROKER_NAME>
```

---

### Solución 2: Verificar ruta de instalación

**Problema:** La ruta de instalación es incorrecta o inaccesible.

```bash
# 1. Verificar que el directorio existe
INSTALL_DIR="/opt/appdynamics/iib-agent"
ls -la "$INSTALL_DIR"

# 2. Verificar que contiene los archivos del agente
ls -la "$INSTALL_DIR/conf/controller-info.xml"
ls -la "$INSTALL_DIR/lib/"

# 3. Verificar permisos
ls -ld "$INSTALL_DIR"
# Debe ser legible por el usuario que ejecuta ACE

# 4. Si la ruta es incorrecta, reinstalar con la ruta correcta
mqsi stop <BROKER_NAME>
mqsichangebroker <BROKER_NAME> -x "$INSTALL_DIR" -e wmqi
mqsi start <BROKER_NAME>
```

---

### Solución 3: Verificar configuración de controller-info.xml

**Problema:** La configuración es incorrecta o incompleta.

```bash
# 1. Verificar que el archivo existe
ls -la /opt/appdynamics/iib-agent/conf/controller-info.xml

# 2. Verificar configuración básica
cat /opt/appdynamics/iib-agent/conf/controller-info.xml | grep -E "controller-host|controller-port|account-name|account-access-key|application-name|tier-name|user-exit"

# 3. Verificar que todos los valores están configurados
# No debe haber valores vacíos o de ejemplo

# 4. Si hay problemas, corregir el archivo y reiniciar el broker
mqsi stop <BROKER_NAME>
mqsi start <BROKER_NAME>
```

---

### Solución 4: Verificar logs del broker

**Problema:** El broker tiene errores al cargar el user exit.

```bash
# 1. Ver logs del sistema del broker
tail -100 <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/system.log

# 2. Buscar errores relacionados con user exits
grep -i "user.exit\|error\|fail" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/system.log | tail -50

# 3. Buscar referencias específicas al user exit
grep -i "wmqi\|appdynamics" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/system.log
```

**Errores comunes:**
- "User exit name must be alphanumeric" → El nombre contiene caracteres especiales
- "Cannot load user exit" → La ruta es incorrecta o el archivo no existe
- "Permission denied" → Problemas de permisos

---

### Solución 5: Reinstalar el user exit completamente

Si nada funciona, reinstalar desde cero:

```bash
# 1. Detener el broker
mqsi stop <BROKER_NAME>

# 2. Remover el user exit actual
mqsichangebroker <BROKER_NAME> -x "" -e ""

# 3. Verificar que se removió
mqsireportbroker <BROKER_NAME>

# 4. Verificar configuración
cat /opt/appdynamics/iib-agent/conf/controller-info.xml | grep "user-exit"
# Asegurar que es wmqi

# 5. Instalar nuevamente
mqsichangebroker <BROKER_NAME> -x /opt/appdynamics/iib-agent -e wmqi

# 6. Verificar instalación
mqsireportbroker <BROKER_NAME>

# 7. Iniciar el broker
mqsi start <BROKER_NAME>

# 8. Verificar logs inmediatamente
tail -f <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/system.log | grep -i "user.exit\|appdynamics"
```

---

## ✅ Checklist de Verificación Final

Antes de reportar el problema, verificar:

- [ ] El directorio del agente existe: `/opt/appdynamics/iib-agent/`
- [ ] El archivo `controller-info.xml` existe y es legible
- [ ] El `user-exit` en `controller-info.xml` es **wmqi**
- [ ] El user exit está instalado (verificado con `mqsireportbroker`)
- [ ] El nombre del user exit coincide entre `controller-info.xml` y `mqsichangebroker`
- [ ] El directorio de logs existe y tiene permisos de escritura
- [ ] El broker se reinició DESPUÉS de instalar el user exit
- [ ] Se verificaron los logs del broker para errores
- [ ] Se verificaron los logs del agente (en el directorio configurado)

---

## 🆘 Si Nada Funciona

Si después de seguir todos los pasos el agente aún no se carga:

1. **Verificar versión de ACE:**
   ```bash
   mqsi version
   # ACE 12 debe ser compatible
   ```

2. **Verificar compatibilidad del agente:**
   - Verificar que la versión del agente IIB es compatible con tu Controller
   - Verificar que es compatible con la versión de ACE

3. **Contactar soporte:**
   - Documentar todos los resultados de los pasos anteriores
   - Incluir salida de `mqsireportbroker`
   - Incluir logs del broker (system.log)
   - Incluir logs del agente (si existen)
   - Incluir contenido de `controller-info.xml` (sin el Access Key)

---

## 📝 Comandos de Verificación Rápida (Copy-Paste)

```bash
# 1. Verificar que el user exit está instalado
mqsireportbroker <BROKER_NAME> | grep -i "user.exit\|appdynamics"

# 2. Verificar directorio del agente
ls -la /opt/appdynamics/iib-agent/

# 3. Verificar configuración
grep -E "controller-host|controller-port|user-exit" /opt/appdynamics/iib-agent/conf/controller-info.xml

# 4. Verificar que user-exit es wmqi
grep "user-exit" /opt/appdynamics/iib-agent/conf/controller-info.xml

# 5. Verificar logs del broker
grep -i "user.exit\|appdynamics" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/system.log | tail -20

# 6. Verificar logs del agente
LOG_DIR=$(grep "log-dir" /opt/appdynamics/iib-agent/conf/controller-info.xml | sed 's/.*<log-dir>\(.*\)<\/log-dir>.*/\1/' 2>/dev/null)
LOG_DIR=${LOG_DIR:-/tmp/appd}
ls -la "$LOG_DIR"/*.log 2>/dev/null || echo "No hay logs aún"
```

---

**Última actualización:** Enero 2025  
**Referencia:** [AppDynamics IIB Agent Documentation](https://docs.appdynamics.com/appd/24.x/latest/en/application-monitoring/install-app-server-agents/ibm-integration-bus-agent/install-the-iib-agent)
