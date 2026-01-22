# Guía Detallada de Instrumentación: AppDynamics en IBM ACE 12

Esta guía proporciona instrucciones paso a paso para instrumentar IBM ACE 12 con AppDynamics.

## Índice

1. [Requisitos Previos](#requisitos-previos)
2. [Preparación del Entorno](#preparación-del-entorno)
3. [Instalación del Agente](#instalación-del-agente)
4. [Configuración del Agente](#configuración-del-agente)
5. [Instrumentación del Servidor](#instrumentación-del-servidor)
6. [Verificación](#verificación)
7. [Troubleshooting Detallado](#troubleshooting-detallado)
8. [Checklist Pre-Despliegue](#checklist-pre-despliegue)

---

## Requisitos Previos

### Información Requerida del Cliente

Antes de comenzar, necesitas obtener del equipo de AppDynamics:

- [ ] **Controller Host**: Hostname o IP del Controller
- [ ] **Controller Port**: Puerto (típicamente 8090 o 443)
- [ ] **Protocolo**: HTTP o HTTPS
- [ ] **Account Name**: Nombre de la cuenta de AppDynamics
- [ ] **Access Key**: Clave de acceso (Account Settings > Access Keys)
- [ ] **Application Name**: Nomque de la aplicación en AppDynamics
- [ ] **Tier Name**: Nombre del tier/servidor (ej: "ACE12-Production")
- [ ] **Node Name**: Nombre único del nodo (ej: "ACE12-Node-01")

### Información del Entorno ACE

Del administrador de IBM ACE necesitas:

- [ ] **Ruta de instalación de ACE**: `<ACE_INSTALL_DIR>`
- [ ] **Nombre del Broker**: `<BROKER_NAME>`
- [ ] **Usuario que ejecuta ACE**: `<ACE_USER>`
- [ ] **Versión de Java**: `java -version`
- [ ] **Sistema Operativo**: `uname -a`

### Verificaciones Iniciales

```bash
# 1. Verificar versión de ACE
mqsi version

# 2. Verificar versión de Java
java -version

# 3. Verificar que el servidor está funcionando
mqsi status <BROKER_NAME>

# 4. Verificar conectividad al Controller
ping <controller-host>
telnet <controller-host> <controller-port>
```

---

## Preparación del Entorno

### Paso 1: Crear Directorio para AppDynamics

```bash
# Crear directorio (ajustar según política de la organización)
sudo mkdir -p /opt/appdynamics
sudo chown <ACE_USER>:<ACE_GROUP> /opt/appdynamics
sudo chmod 755 /opt/appdynamics
```

### Paso 2: Descargar el Agente Java

1. Acceder al portal de AppDynamics
2. **Settings > Downloads > Java Agent**
3. Seleccionar la versión compatible con tu Controller
4. Descargar el archivo ZIP

### Paso 3: Extraer el Agente

```bash
cd /opt/appdynamics
unzip javaagent.zip

# Verificar estructura
ls -la AppServerAgent/
# Debe mostrar: javaagent.jar, conf/, lib/, logs/
```

---

## Instalación del Agente

### Estructura del Directorio

Después de extraer, deberías tener:

```
/opt/appdynamics/
└── AppServerAgent/
    ├── javaagent.jar          # Agente principal
    ├── conf/
    │   ├── controller-info.xml    # Configuración principal
    │   └── logging/
    │       └── log4j.xml          # Configuración de logs
    ├── lib/                    # Librerías del agente
    └── logs/                   # Logs del agente
```

### Verificar Permisos

```bash
cd /opt/appdynamics/AppServerAgent
ls -la javaagent.jar
# Debe ser legible por el usuario que ejecuta ACE

# Si es necesario, ajustar permisos:
sudo chown -R <ACE_USER>:<ACE_GROUP> /opt/appdynamics
sudo chmod -R 755 /opt/appdynamics

# ⚠️ IMPORTANTE: Si se usa script de instrumentación separado, verificar permisos de ejecución
# (Esto se hará más adelante cuando se cree el script)
```

---

## Configuración del Agente

### Paso 1: Configurar controller-info.xml

**Ubicación:** `/opt/appdynamics/AppServerAgent/conf/controller-info.xml`

**Archivo completo de ejemplo:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<controller-info>
    <!-- ========================================= -->
    <!-- Información del Controller AppDynamics   -->
    <!-- ========================================= -->
    
    <!-- Hostname o IP del Controller -->
    <controller-host>controller.banrural.com</controller-host>
    
    <!-- Puerto del Controller -->
    <!-- 8090 para HTTP, 443 para HTTPS -->
    <controller-port>8090</controller-port>
    
    <!-- Habilitar SSL -->
    <controller-ssl-enabled>false</controller-ssl-enabled>
    
    <!-- ========================================= -->
    <!-- Credenciales de Acceso                  -->
    <!-- ========================================= -->
    
    <!-- Nombre de la cuenta de AppDynamics -->
    <account-name>customer1</account-name>
    
    <!-- Access Key (obtener de Account Settings) -->
    <account-access-key>xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx</account-access-key>
    
    <!-- ========================================= -->
    <!-- Información de la Aplicación            -->
    <!-- ========================================= -->
    
    <!-- Nombre de la aplicación en AppDynamics -->
    <application-name>IBM_ACE_Production</application-name>
    
    <!-- Nombre del tier (servidor/grupo) -->
    <tier-name>ACE12-Production-Tier</tier-name>
    
    <!-- Nombre del nodo (único por instancia) -->
    <node-name>ACE12-Node-01</node-name>
    
    <!-- ========================================= -->
    <!-- Configuración Adicional                  -->
    <!-- ========================================= -->
    
    <!-- Deshabilitar Server Infrastructure Monitoring (típico para ACE) -->
    <sim-enabled>false</sim-enabled>
    
    <!-- Deshabilitar orquestación automática -->
    <enable-orchestration>false</enable-orchestration>
    
    <!-- Directorio de logs del agente -->
    <log-dir>/opt/appdynamics/AppServerAgent/logs</log-dir>
    
    <!-- Nivel de log (DEBUG, INFO, WARN, ERROR) -->
    <log-level>INFO</log-level>
    
</controller-info>
```

**⚠️ IMPORTANTE:** Reemplazar todos los valores de ejemplo con los valores reales proporcionados por el equipo de AppDynamics.

### Paso 2: Configurar Logs (Opcional)

**Ubicación:** `/opt/appdynamics/AppServerAgent/conf/logging/log4j.xml`

Si deseas configurar niveles de log específicos:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<log4j:configuration xmlns:log4j="http://jakarta.apache.org/log4j/">
    <appender name="FileAppender" class="org.apache.log4j.RollingFileAppender">
        <param name="File" value="${appd.logs.dir}/appd.log"/>
        <param name="MaxFileSize" value="10MB"/>
        <param name="MaxBackupIndex" value="5"/>
        <layout class="org.apache.log4j.PatternLayout">
            <param name="ConversionPattern" value="%d{yyyy-MM-dd HH:mm:ss} %-5p %c{1}:%L - %m%n"/>
        </layout>
    </appender>
    
    <logger name="com.appdynamics">
        <level value="INFO"/>
    </logger>
    
    <root>
        <priority value="INFO"/>
        <appender-ref ref="FileAppender"/>
    </root>
</log4j:configuration>
```

---

## Instrumentación del Servidor

### Método 1: Modificar mqsiprofile (Recomendado)

**Paso 1: Localizar el archivo mqsiprofile**

```bash
# Ubicación típica
/opt/ibm/ace-12.0/server/bin/mqsiprofile
```

**Paso 2: Hacer backup**

```bash
sudo cp /opt/ibm/ace-12.0/server/bin/mqsiprofile /opt/ibm/ace-12.0/server/bin/mqsiprofile.backup
```

**Paso 3: Editar el archivo**

Agregar al final del archivo `mqsiprofile`:

```bash
# =========================================
# AppDynamics Java Agent Configuration
# =========================================
APP_AGENT_DIR="/opt/appdynamics/AppServerAgent"
APP_AGENT_JAR="${APP_AGENT_DIR}/javaagent.jar"

if [ -f "${APP_AGENT_JAR}" ]; then
    export APP_AGENT_JAVA_OPTS="-javaagent:${APP_AGENT_JAR}"
    export JAVA_OPTS="${JAVA_OPTS} ${APP_AGENT_JAVA_OPTS}"
    echo "[AppDynamics] Agent configurado: ${APP_AGENT_JAR}"
else
    echo "[AppDynamics] WARNING: Agent no encontrado en ${APP_AGENT_JAR}"
fi
```

**Paso 4: Verificar cambios**

```bash
tail -20 /opt/ibm/ace-12.0/server/bin/mqsiprofile
```

### Método 2: Script de Instrumentación Separado (Alternativa)

Si prefieres no modificar `mqsiprofile`, crear un script separado:

**Crear:** `/opt/appdynamics/ace_instrumentation.sh`

```bash
#!/bin/bash
# Script de instrumentación AppDynamics para IBM ACE 12
# Autor: Equipo de Infraestructura
# Fecha: $(date +%Y-%m-%d)

APP_AGENT_DIR="/opt/appdynamics/AppServerAgent"
APP_AGENT_JAR="${APP_AGENT_DIR}/javaagent.jar"
LOG_FILE="/opt/appdynamics/logs/instrumentation.log"

# Crear directorio de logs si no existe
mkdir -p /opt/appdynamics/logs

# Verificar que el agente existe
if [ ! -f "${APP_AGENT_JAR}" ]; then
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] ERROR: AppDynamics agent no encontrado en ${APP_AGENT_JAR}" | tee -a "${LOG_FILE}"
    exit 1
fi

# Configurar opciones JVM
export APP_AGENT_JAVA_OPTS="-javaagent:${APP_AGENT_JAR}"
export JAVA_OPTS="${JAVA_OPTS} ${APP_AGENT_JAVA_OPTS}"

echo "[$(date +%Y-%m-%d\ %H:%M:%S)] AppDynamics agent configurado: ${APP_AGENT_JAR}" | tee -a "${LOG_FILE}"

# Exportar variables para uso en subprocesos
export APP_AGENT_DIR
export APP_AGENT_JAVA_OPTS
```

**⚠️ IMPORTANTE: Asignar permisos de ejecución al script:**

```bash
# Asignar permisos de ejecución
chmod +x /opt/appdynamics/ace_instrumentation.sh

# Verificar que los permisos se aplicaron correctamente
ls -l /opt/appdynamics/ace_instrumentation.sh
# Debe mostrar: -rwxr-xr-x (permisos de ejecución activos)

# Asegurar que el propietario es correcto
chown <ACE_USER>:<ACE_GROUP> /opt/appdynamics/ace_instrumentation.sh

# Verificar permisos finales
ls -l /opt/appdynamics/ace_instrumentation.sh
```

**Nota:** Sin permisos de ejecución, el script no podrá ser ejecutado por `source` o directamente, lo que causará errores al iniciar ACE. Si el script no tiene permisos de ejecución, no se podrá cargar y la instrumentación fallará.

**Modificar mqsiprofile para cargar el script:**

```bash
# Al inicio del mqsiprofile (después de definir variables base)
source /opt/appdynamics/ace_instrumentation.sh
```

### Paso 3: Reiniciar el Servidor ACE

```bash
# 1. Detener el broker
mqsi stop <BROKER_NAME>

# 2. Verificar que se detuvo correctamente
mqsi status <BROKER_NAME>

# 3. Iniciar el broker
mqsi start <BROKER_NAME>

# 4. Verificar que inició correctamente
mqsi status <BROKER_NAME>

# 5. Revisar logs inmediatamente
tail -f <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/*.log | grep -i appdynamics
```

---

## Verificación

### Paso 1: Verificar Logs del Agente

```bash
# Logs del agente AppDynamics
tail -f /opt/appdynamics/AppServerAgent/logs/agent.log

# Buscar mensajes de éxito
grep -i "initialized\|connected\|registered" /opt/appdynamics/AppServerAgent/logs/agent.log
```

**Mensajes esperados:**
```
INFO: AppDynamics Java Agent initialized successfully
INFO: Connected to Controller at <controller-host>:<controller-port>
INFO: Application 'IBM_ACE_Production' successfully registered
INFO: Tier 'ACE12-Production-Tier' registered
INFO: Node 'ACE12-Node-01' registered
```

### Paso 2: Verificar Logs del Servidor ACE

```bash
# Buscar referencias a AppDynamics en logs de ACE
grep -i "appdynamics\|javaagent" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/*.log
```

### Paso 3: Verificar Variables de Entorno

```bash
# Si tienes acceso a la sesión donde se ejecuta ACE
echo $JAVA_OPTS | grep -i appdynamics

# Debe mostrar algo como:
# -javaagent:/opt/appdynamics/AppServerAgent/javaagent.jar
```

### Paso 4: Verificar en el Controller de AppDynamics

1. **Acceder al portal:**
   - URL: `http://<controller-host>:<controller-port>`
   - Login con credenciales de AppDynamics

2. **Navegar a la aplicación:**
   - **Applications > [Nombre de tu aplicación]**

3. **Verificar estado:**
   - **Tier** debe aparecer como **Up** (indicador verde)
   - **Node** debe aparecer como **Up** (indicador verde)
   - Deben aparecer métricas en tiempo real

4. **Verificar métricas:**
   - CPU, Memory, Response Time
   - Transacciones, errores
   - JVM metrics

### Paso 5: Probar Conectividad

```bash
# Verificar conectividad de red
ping <controller-host>

# Verificar puerto
telnet <controller-host> <controller-port>

# O usando curl (si está disponible)
curl -v http://<controller-host>:<controller-port>/controller/rest/applications
```

---

## Troubleshooting Detallado

> **⚠️ PROBLEMA ESPECÍFICO: Agente no se carga (sin logs ni registro en Controller)**  
> Si el agente no genera logs y no aparece en el Controller después de reiniciar, consulta la guía detallada:  
> **[DIAGNOSTICO_AGENTE_NO_CARGA.md](DIAGNOSTICO_AGENTE_NO_CARGA.md)**

### Problema 1: El agente no se carga (NO HAY LOGS NI REGISTRO EN CONTROLLER)

**Síntomas:**
- No hay mensajes de AppDynamics en los logs
- El nodo no aparece en el Controller
- **No se crean archivos de log en `/opt/appdynamics/AppServerAgent/logs/`**
- El agente parece no estar ejecutándose

**🔍 Diagnóstico Paso a Paso:**

#### Paso 1: Verificar que el archivo javaagent.jar existe

```bash
# Verificar existencia y permisos del archivo
ls -la /opt/appdynamics/AppServerAgent/javaagent.jar

# Debe mostrar el archivo con permisos de lectura
# Si no existe, verificar la ruta de instalación
```

#### Paso 2: Verificar configuración en mqsiprofile

```bash
# Verificar que se agregó la configuración al mqsiprofile
grep -i "appdynamics\|javaagent" <ACE_INSTALL_DIR>/server/bin/mqsiprofile

# Debe mostrar las líneas de configuración que agregaste
# Si no aparece nada, la configuración no se guardó correctamente
```

**Si no aparece nada, verificar:**
- ¿Se editó el archivo correcto? (verificar ruta completa)
- ¿Se guardaron los cambios? (verificar con `tail -20` del archivo)
- ¿Hay múltiples archivos mqsiprofile? (verificar todas las ubicaciones)

#### Paso 3: Verificar que JAVA_OPTS se configura al cargar mqsiprofile

```bash
# Cargar el mqsiprofile manualmente
source <ACE_INSTALL_DIR>/server/bin/mqsiprofile

# Verificar que JAVA_OPTS contiene el javaagent
echo $JAVA_OPTS | grep -i "javaagent\|appdynamics"

# Debe mostrar algo como:
# -javaagent:/opt/appdynamics/AppServerAgent/javaagent.jar
```

**Si no aparece el javaagent en JAVA_OPTS:**
- La configuración en mqsiprofile no se está ejecutando
- Verificar sintaxis del script (puede haber errores de sintaxis)
- Verificar que no hay errores al cargar mqsiprofile

#### Paso 4: Verificar cómo se inicia el broker ACE

```bash
# Verificar el proceso de inicio del broker
ps aux | grep -i "mqsi\|ace\|broker" | grep -v grep

# Verificar las variables de entorno del proceso Java
# (Esto requiere acceso al proceso en ejecución)
```

**⚠️ PROBLEMA COMÚN:** IBM ACE puede iniciar el proceso Java de una manera que no carga el mqsiprofile automáticamente.

#### Paso 5: Verificar logs de inicio del broker

```bash
# Buscar en los logs de inicio del broker
grep -i "java\|jvm\|start" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/*.log | head -50

# Buscar errores relacionados con javaagent
grep -i "javaagent\|appdynamics\|agent" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/*.log
```

#### Paso 6: Verificar que el directorio de logs del agente existe y tiene permisos

```bash
# Verificar directorio de logs
ls -ld /opt/appdynamics/AppServerAgent/logs

# Si no existe, crearlo:
mkdir -p /opt/appdynamics/AppServerAgent/logs
chown <ACE_USER>:<ACE_GROUP> /opt/appdynamics/AppServerAgent/logs
chmod 775 /opt/appdynamics/AppServerAgent/logs
```

**Soluciones Detalladas:**

**Solución 1: Verificar y corregir mqsiprofile**

```bash
# 1. Hacer backup
cp <ACE_INSTALL_DIR>/server/bin/mqsiprofile <ACE_INSTALL_DIR>/server/bin/mqsiprofile.backup.$(date +%Y%m%d)

# 2. Verificar contenido actual
cat <ACE_INSTALL_DIR>/server/bin/mqsiprofile | tail -30

# 3. Agregar configuración al FINAL del archivo (no al inicio)
# Asegurar que está al final, después de todas las otras configuraciones
cat >> <ACE_INSTALL_DIR>/server/bin/mqsiprofile << 'EOF'

# =========================================
# AppDynamics Java Agent Configuration
# =========================================
APP_AGENT_DIR="/opt/appdynamics/AppServerAgent"
APP_AGENT_JAR="${APP_AGENT_DIR}/javaagent.jar"

if [ -f "${APP_AGENT_JAR}" ]; then
    export APP_AGENT_JAVA_OPTS="-javaagent:${APP_AGENT_JAR}"
    export JAVA_OPTS="${JAVA_OPTS} ${APP_AGENT_JAVA_OPTS}"
    echo "[AppDynamics] Agent configurado: ${APP_AGENT_JAR}"
else
    echo "[AppDynamics] WARNING: Agent no encontrado en ${APP_AGENT_JAR}"
fi
EOF

# 4. Verificar que se agregó correctamente
tail -15 <ACE_INSTALL_DIR>/server/bin/mqsiprofile

# 5. Probar cargar manualmente
source <ACE_INSTALL_DIR>/server/bin/mqsiprofile
echo $JAVA_OPTS | grep javaagent
```

**Solución 2: Verificar método de inicio del broker**

IBM ACE puede iniciar el broker de diferentes maneras. Verificar cómo se está iniciando:

```bash
# Verificar si hay un script de inicio personalizado
ls -la <ACE_INSTALL_DIR>/server/bin/mqsistart*

# Verificar si se usa systemd, init.d, o script manual
# Si se usa systemd, puede que necesites configurar las variables ahí
```

**Solución 3: Configurar variables en el script de inicio del broker**

Si el mqsiprofile no se carga automáticamente, agregar las variables directamente en el script de inicio:

```bash
# Localizar el script que inicia el broker
# Puede estar en: <ACE_INSTALL_DIR>/server/bin/mqsistart
# O en un script personalizado

# Agregar ANTES de iniciar el proceso Java:
export JAVA_OPTS="${JAVA_OPTS} -javaagent:/opt/appdynamics/AppServerAgent/javaagent.jar"
```

**Solución 4: Verificar permisos y rutas**

```bash
# Verificar permisos completos
sudo chown -R <ACE_USER>:<ACE_GROUP> /opt/appdynamics
sudo chmod -R 755 /opt/appdynamics
sudo chmod 644 /opt/appdynamics/AppServerAgent/javaagent.jar

# Verificar que la ruta es absoluta (no relativa)
# La ruta debe ser: /opt/appdynamics/AppServerAgent/javaagent.jar
# NO debe ser: ./AppServerAgent/javaagent.jar o ~/appdynamics/...
```

**Solución 5: Probar carga manual del agente**

Para verificar que el agente funciona, probar cargarlo manualmente:

```bash
# 1. Detener el broker
mqsi stop <BROKER_NAME>

# 2. Cargar mqsiprofile
source <ACE_INSTALL_DIR>/server/bin/mqsiprofile

# 3. Verificar JAVA_OPTS
echo $JAVA_OPTS

# 4. Iniciar el broker desde la misma sesión
mqsi start <BROKER_NAME>

# 5. Inmediatamente verificar logs
tail -f /opt/appdynamics/AppServerAgent/logs/agent.log
```

**Solución 6: Verificar sintaxis del script**

```bash
# Verificar que no hay errores de sintaxis en mqsiprofile
bash -n <ACE_INSTALL_DIR>/server/bin/mqsiprofile

# Si hay errores, corregirlos antes de reiniciar
```

**Checklist de Verificación:**

- [ ] El archivo `javaagent.jar` existe en la ruta especificada
- [ ] Los permisos del archivo y directorio son correctos
- [ ] La configuración está agregada al `mqsiprofile`
- [ ] Al cargar `mqsiprofile` manualmente, `JAVA_OPTS` contiene el javaagent
- [ ] El directorio de logs existe y tiene permisos de escritura
- [ ] No hay errores de sintaxis en el `mqsiprofile`
- [ ] El broker se reinició DESPUÉS de modificar el `mqsiprofile`
- [ ] Se está usando el método correcto para iniciar el broker

### Problema 2: No se conecta al Controller

**Síntomas:**
- Mensajes de error sobre conexión en logs
- Nodo aparece como "Disconnected" en Controller

**Diagnóstico:**

```bash
# 1. Verificar conectividad
ping <controller-host>
telnet <controller-host> <controller-port>

# 2. Verificar configuración
cat /opt/appdynamics/AppServerAgent/conf/controller-info.xml | grep -E "controller-host|controller-port|account-access-key"

# 3. Verificar logs de conexión
grep -i "connection\|controller\|error" /opt/appdynamics/AppServerAgent/logs/agent.log
```

**Soluciones:**
1. **Verificar host/port:** Revisar `controller-info.xml`
2. **Verificar Access Key:** Validar con el equipo de AppDynamics
3. **Verificar firewall:** Asegurar que el puerto está abierto
4. **Verificar SSL:** Si el Controller usa HTTPS, configurar `controller-ssl-enabled=true`
5. **Verificar DNS:** Resolver correctamente el hostname del Controller

**Mensajes de error comunes:**

```
ERROR: Failed to connect to Controller
→ Verificar host, port y conectividad de red

ERROR: Invalid account access key
→ Verificar el Access Key en controller-info.xml

ERROR: SSL handshake failed
→ Configurar controller-ssl-enabled=true o verificar certificados
```

### Problema 3: Errores de permisos

**Síntomas:**
- Errores "Permission denied" al iniciar ACE
- Errores al escribir logs
- Errores "cannot execute binary file" o "Permission denied" al ejecutar scripts
- Mensajes "Permission denied" al ejecutar scripts
- El script de instrumentación no se carga

**Soluciones:**

```bash
# Verificar y ajustar permisos de archivos y directorios
sudo chown -R <ACE_USER>:<ACE_GROUP> /opt/appdynamics
sudo chmod -R 755 /opt/appdynamics
sudo chmod 644 /opt/appdynamics/AppServerAgent/conf/controller-info.xml

# ⚠️ IMPORTANTE: Asegurar permisos de ejecución para scripts
sudo chmod +x /opt/appdynamics/ace_instrumentation.sh  # Si se usa script separado

# Verificar permisos de ejecución
ls -l /opt/appdynamics/ace_instrumentation.sh
# Debe mostrar permisos de ejecución (x): -rwxr-xr-x

# Asegurar permisos de escritura para logs
sudo chmod 775 /opt/appdynamics/AppServerAgent/logs
sudo chown <ACE_USER>:<ACE_GROUP> /opt/appdynamics/AppServerAgent/logs

<<<<<<< HEAD
# IMPORTANTE: Verificar permisos de ejecución en scripts
# Si usa script de instrumentación personalizado:
chmod +x /opt/appdynamics/ace_instrumentation.sh
chown <ACE_USER>:<ACE_GROUP> /opt/appdynamics/ace_instrumentation.sh

# Verificar permisos del mqsiprofile (si se modificó)
ls -l <ACE_INSTALL_DIR>/server/bin/mqsiprofile
# Si no tiene permisos de ejecución:
sudo chmod +x <ACE_INSTALL_DIR>/server/bin/mqsiprofile

# Verificar que el usuario puede ejecutar los scripts
sudo -u <ACE_USER> /opt/appdynamics/ace_instrumentation.sh
# No debe dar error de permisos
```

### Problema 4: Conflictos con otras librerías

**Síntomas:**
- Errores de ClassNotFoundException
- Comportamiento inesperado
- Errores de inicio

**Soluciones:**

1. **Verificar otros agents:**
   ```bash
   echo $JAVA_OPTS | grep -i "javaagent"
   # Solo debe haber un javaagent para AppDynamics
   ```

2. **Verificar versión de Java:**
   ```bash
   java -version
   # ACE 12 requiere Java 1.8 o superior
   ```

3. **Verificar conflictos de classpath:**
   - Revisar logs completos del servidor ACE
   - Verificar si hay otros agents (New Relic, etc.)

### Problema 5: Métricas no aparecen en el Controller

**Síntomas:**
- El nodo aparece como "Up" pero no hay métricas

**Soluciones:**

1. **Verificar que la aplicación está registrada:**
   - En Controller: Applications > [App Name]
   - Verificar que Tier y Node están visibles

2. **Generar tráfico:**
   - Ejecutar transacciones en ACE
   - Las métricas aparecen cuando hay actividad

3. **Verificar configuración del tier:**
   - Asegurar que `tier-name` coincide con la configuración en Controller

---

## Checklist Pre-Despliegue

Antes de instrumentar en producción, verificar:

### Información Requerida
- [ ] Controller host y port confirmados
- [ ] Account name y access key obtenidos
- [ ] Application name, tier name y node name definidos
- [ ] Permisos de red confirmados (firewall)

### Preparación del Entorno
- [ ] Directorio de instalación creado (`/opt/appdynamics`)
- [ ] Agente Java descargado y extraído
- [ ] Permisos de archivos configurados
- [ ] **Permisos de ejecución asignados a scripts** (`chmod +x`)
- [ ] Backup de configuración de ACE realizado

### Configuración
- [ ] `controller-info.xml` configurado con valores reales
- [ ] `logging/log4j.xml` configurado (opcional)
- [ ] Script de instrumentación preparado y probado
- [ ] `mqsiprofile` modificado o script alternativo creado

### Pruebas
- [ ] Conectividad al Controller verificada
- [ ] Agente probado en ambiente de desarrollo/pruebas
- [ ] Logs revisados y sin errores
- [ ] Verificación en Controller (ambiente de pruebas)

### Documentación
- [ ] Documentación del proceso actualizada
- [ ] Credenciales y configuración documentadas (seguro)
- [ ] Procedimiento de rollback documentado

---

## Procedimiento de Rollback

Si necesitas revertir la instrumentación:

```bash
# 1. Detener el broker
mqsi stop <BROKER_NAME>

# 2. Restaurar mqsiprofile desde backup
sudo cp /opt/ibm/ace-12.0/server/bin/mqsiprofile.backup /opt/ibm/ace-12.0/server/bin/mqsiprofile

# 3. Eliminar variables de entorno (si se configuraron a nivel sistema)
# Editar /etc/profile o ~/.bashrc y remover referencias a AppDynamics

# 4. Iniciar el broker
mqsi start <BROKER_NAME>

# 5. Verificar que inicia sin referencias a AppDynamics
tail -f <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/*.log
```

---

## Notas Adicionales

### Consideraciones de Performance

- El agente AppDynamics tiene un impacto mínimo en performance (< 5%)
- El overhead aumenta con el nivel de log (usar INFO en producción)
- Monitorear uso de memoria JVM después de la instrumentación

### Seguridad

- El `controller-info.xml` contiene credenciales sensibles (Access Key)
- Asegurar permisos restrictivos: `chmod 600 controller-info.xml`
- No compartir el Access Key públicamente
- Considerar rotación periódica de Access Keys

### Mantenimiento

- Revisar logs periódicamente: `/opt/appdynamics/AppServerAgent/logs/agent.log`
- Actualizar el agente cuando haya nuevas versiones (coordinado con AppDynamics)
- Verificar conectividad después de cambios de infraestructura

---

**Última actualización:** Enero 2025  
**Versión del documento:** 1.0
