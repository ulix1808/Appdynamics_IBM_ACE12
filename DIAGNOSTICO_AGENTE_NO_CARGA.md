# Diagnóstico: Agente AppDynamics No Se Carga

**Problema:** Después de reiniciar el BUS, no hay logs en la carpeta del agente y no aparece registrado en el Controller.

## 🔍 Diagnóstico Rápido (Ejecutar en Orden)

### Paso 1: Verificar que el archivo javaagent.jar existe

```bash
# Verificar existencia
ls -la /opt/appdynamics/AppServerAgent/javaagent.jar

# Si no existe, verificar otras ubicaciones posibles
find /opt -name "javaagent.jar" 2>/dev/null
find /usr/local -name "javaagent.jar" 2>/dev/null
```

**Resultado esperado:** Debe mostrar el archivo con permisos de lectura.

---

### Paso 2: Verificar configuración en mqsiprofile

```bash
# Reemplazar <ACE_INSTALL_DIR> con tu ruta real (ej: /opt/ibm/ace-12.0)
# Reemplazar <BROKER_NAME> con el nombre de tu broker

# Verificar que la configuración está en el archivo
grep -i "appdynamics\|javaagent" <ACE_INSTALL_DIR>/server/bin/mqsiprofile

# Ver las últimas 20 líneas del archivo
tail -20 <ACE_INSTALL_DIR>/server/bin/mqsiprofile
```

**Resultado esperado:** Debe mostrar las líneas de configuración de AppDynamics.

**Si NO aparece nada:**
- La configuración no se guardó correctamente
- Verificar que se editó el archivo correcto
- Verificar permisos de escritura en el archivo

---

### Paso 3: Verificar que JAVA_OPTS se configura correctamente

```bash
# Cargar el mqsiprofile manualmente
source <ACE_INSTALL_DIR>/server/bin/mqsiprofile

# Verificar JAVA_OPTS
echo $JAVA_OPTS | grep -i "javaagent\|appdynamics"

# Ver el contenido completo de JAVA_OPTS
echo $JAVA_OPTS
```

**Resultado esperado:** Debe mostrar `-javaagent:/opt/appdynamics/AppServerAgent/javaagent.jar`

**Si NO aparece:**
- El mqsiprofile no está configurando JAVA_OPTS correctamente
- Puede haber un error de sintaxis en el script
- Verificar que la ruta del javaagent.jar es correcta

---

### Paso 4: Verificar sintaxis del mqsiprofile

```bash
# Verificar que no hay errores de sintaxis
bash -n <ACE_INSTALL_DIR>/server/bin/mqsiprofile
```

**Resultado esperado:** No debe mostrar ningún error.

**Si hay errores:** Corregir la sintaxis antes de continuar.

---

### Paso 5: Verificar permisos y directorio de logs

```bash
# Verificar permisos del javaagent.jar
ls -l /opt/appdynamics/AppServerAgent/javaagent.jar

# Verificar que el directorio de logs existe
ls -ld /opt/appdynamics/AppServerAgent/logs

# Si no existe, crearlo
mkdir -p /opt/appdynamics/AppServerAgent/logs
chown <ACE_USER>:<ACE_GROUP> /opt/appdynamics/AppServerAgent/logs
chmod 775 /opt/appdynamics/AppServerAgent/logs
```

**Reemplazar `<ACE_USER>` y `<ACE_GROUP>` con el usuario y grupo que ejecuta ACE.**

---

### Paso 6: Verificar cómo se inicia el broker

```bash
# Verificar procesos en ejecución
ps aux | grep -i "mqsi\|ace\|broker" | grep -v grep

# Verificar si hay un script de inicio personalizado
ls -la <ACE_INSTALL_DIR>/server/bin/mqsistart*
ls -la /etc/init.d/*mqsi* 2>/dev/null
ls -la /etc/systemd/system/*mqsi* 2>/dev/null
ls -la /etc/systemd/system/*ace* 2>/dev/null
```

**Importante:** Si el broker se inicia mediante systemd o un script personalizado, puede que el mqsiprofile no se cargue automáticamente.

---

### Paso 7: Verificar logs de inicio del broker

```bash
# Buscar en logs de inicio
grep -i "java\|jvm\|start" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/*.log | tail -50

# Buscar cualquier referencia a javaagent o appdynamics
grep -i "javaagent\|appdynamics\|agent" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/*.log
```

**Si no hay referencias:** El agente definitivamente no se está cargando.

---

## 🔧 Soluciones Comunes

### Solución 1: Corregir configuración en mqsiprofile

```bash
# 1. Hacer backup
cp <ACE_INSTALL_DIR>/server/bin/mqsiprofile <ACE_INSTALL_DIR>/server/bin/mqsiprofile.backup.$(date +%Y%m%d_%H%M%S)

# 2. Verificar ruta correcta del javaagent.jar
JAVAAGENT_PATH="/opt/appdynamics/AppServerAgent/javaagent.jar"
ls -la "$JAVAAGENT_PATH"

# 3. Agregar al FINAL del mqsiprofile (usar >> para agregar, no sobrescribir)
cat >> <ACE_INSTALL_DIR>/server/bin/mqsiprofile << 'EOF'

# =========================================
# AppDynamics Java Agent Configuration
# Agregado: $(date)
# =========================================
APP_AGENT_DIR="/opt/appdynamics/AppServerAgent"
APP_AGENT_JAR="${APP_AGENT_DIR}/javaagent.jar"

if [ -f "${APP_AGENT_JAR}" ]; then
    export APP_AGENT_JAVA_OPTS="-javaagent:${APP_AGENT_JAR}"
    export JAVA_OPTS="${JAVA_OPTS} ${APP_AGENT_JAVA_OPTS}"
    echo "[AppDynamics] Agent configurado: ${APP_AGENT_JAR}"
else
    echo "[AppDynamics] ERROR: Agent no encontrado en ${APP_AGENT_JAR}"
fi
EOF

# 4. Verificar que se agregó
tail -15 <ACE_INSTALL_DIR>/server/bin/mqsiprofile

# 5. Probar carga manual
source <ACE_INSTALL_DIR>/server/bin/mqsiprofile
echo $JAVA_OPTS | grep javaagent
```

---

### Solución 2: Verificar que el broker carga el mqsiprofile

IBM ACE debe cargar el mqsiprofile al iniciar. Verificar:

```bash
# Verificar si hay referencias a mqsiprofile en los scripts de inicio
grep -r "mqsiprofile" <ACE_INSTALL_DIR>/server/bin/ 2>/dev/null

# Verificar el script mqsistart (si existe)
cat <ACE_INSTALL_DIR>/server/bin/mqsistart | grep -i "mqsiprofile\|source"
```

**Si el mqsiprofile no se carga automáticamente**, puede ser necesario:

1. **Agregar source mqsiprofile en el script de inicio:**
   ```bash
   # Editar el script que inicia el broker
   # Agregar ANTES de iniciar el proceso:
   source <ACE_INSTALL_DIR>/server/bin/mqsiprofile
   ```

2. **O configurar JAVA_OPTS directamente en el script de inicio:**
   ```bash
   # En el script de inicio, antes de ejecutar el proceso Java:
   export JAVA_OPTS="${JAVA_OPTS} -javaagent:/opt/appdynamics/AppServerAgent/javaagent.jar"
   ```

---

### Solución 3: Reiniciar correctamente

```bash
# 1. Detener el broker completamente
mqsi stop <BROKER_NAME>

# 2. Verificar que se detuvo
mqsi status <BROKER_NAME>
# Debe mostrar que está detenido

# 3. Esperar unos segundos
sleep 5

# 4. Cargar mqsiprofile en la sesión actual
source <ACE_INSTALL_DIR>/server/bin/mqsiprofile

# 5. Verificar JAVA_OPTS
echo $JAVA_OPTS | grep javaagent

# 6. Iniciar el broker desde la MISMA sesión
mqsi start <BROKER_NAME>

# 7. Inmediatamente verificar logs (esperar 10-15 segundos)
sleep 15
ls -la /opt/appdynamics/AppServerAgent/logs/
tail -50 /opt/appdynamics/AppServerAgent/logs/agent.log
```

---

### Solución 4: Verificar variables de entorno del proceso Java

Si el broker ya está corriendo, verificar si el proceso Java tiene JAVA_OPTS configurado:

```bash
# Encontrar el PID del proceso Java del broker
JAVA_PID=$(ps aux | grep "[j]ava.*broker\|[j]ava.*ace" | awk '{print $2}' | head -1)

# Ver variables de entorno del proceso (requiere permisos)
if [ ! -z "$JAVA_PID" ]; then
    echo "PID del proceso Java: $JAVA_PID"
    # En Linux, ver variables de entorno:
    cat /proc/$JAVA_PID/environ | tr '\0' '\n' | grep -i "java_opts\|javaagent"
else
    echo "No se encontró proceso Java del broker"
fi
```

**Nota:** Esto requiere permisos adecuados. Si no funciona, puede ser necesario ejecutarlo como el usuario que ejecuta ACE.

---

### Solución 5: Verificar configuración de controller-info.xml

Aunque el agente no se esté cargando, verificar que la configuración es correcta:

```bash
# Verificar que el archivo existe
ls -la /opt/appdynamics/AppServerAgent/conf/controller-info.xml

# Verificar configuración básica
grep -E "controller-host|controller-port|account-name|account-access-key|application-name" /opt/appdynamics/AppServerAgent/conf/controller-info.xml
```

---

## ✅ Checklist de Verificación Final

Antes de reportar el problema, verificar:

- [ ] El archivo `javaagent.jar` existe en `/opt/appdynamics/AppServerAgent/javaagent.jar`
- [ ] Los permisos del archivo son correctos (lectura para el usuario de ACE)
- [ ] La configuración está en el `mqsiprofile` (verificado con `grep`)
- [ ] Al cargar `mqsiprofile` manualmente, `JAVA_OPTS` contiene el javaagent
- [ ] No hay errores de sintaxis en el `mqsiprofile` (`bash -n` no muestra errores)
- [ ] El directorio de logs existe: `/opt/appdynamics/AppServerAgent/logs/`
- [ ] El directorio de logs tiene permisos de escritura
- [ ] El broker se reinició DESPUÉS de modificar el `mqsiprofile`
- [ ] Se verificaron los logs del broker para errores
- [ ] Se verificó cómo se inicia el broker (script, systemd, etc.)

---

## 🆘 Si Nada Funciona

Si después de seguir todos los pasos el agente aún no se carga:

1. **Verificar versión de Java:**
   ```bash
   java -version
   # ACE 12 requiere Java 1.8 o superior
   ```

2. **Verificar compatibilidad del agente:**
   - Verificar que la versión del agente AppDynamics es compatible con tu Controller
   - Verificar que es compatible con la versión de Java

3. **Contactar soporte:**
   - Documentar todos los resultados de los pasos anteriores
   - Incluir salida de comandos de verificación
   - Incluir logs del broker
   - Incluir contenido del mqsiprofile (últimas 30 líneas)

---

## 📝 Comandos de Verificación Rápida (Copy-Paste)

```bash
# Verificar archivo
ls -la /opt/appdynamics/AppServerAgent/javaagent.jar

# Verificar configuración
grep -i "appdynamics\|javaagent" <ACE_INSTALL_DIR>/server/bin/mqsiprofile

# Verificar JAVA_OPTS
source <ACE_INSTALL_DIR>/server/bin/mqsiprofile && echo $JAVA_OPTS | grep javaagent

# Verificar logs
ls -la /opt/appdynamics/AppServerAgent/logs/
tail -50 /opt/appdynamics/AppServerAgent/logs/agent.log 2>/dev/null || echo "No hay logs aún"
```

---

**Última actualización:** Enero 2025