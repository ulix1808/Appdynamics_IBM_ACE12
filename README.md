# AppDynamics para IBM ACE 12

Documentación completa para la instrumentación del agente de AppDynamics en IBM ACE (Advanced Customer Experience) 12, también conocido como IBM Integration Bus (IIB).

## 📋 Contenido

- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Configuración](#configuración)
- [Instrumentación](#instrumentación)
- [Verificación](#verificación)
- [Solución de Problemas](#solución-de-problemas)
- [Referencias](#referencias)

## 📖 Documentación Completa

Para instrucciones detalladas paso a paso, consulta [INSTRUMENTACION.md](INSTRUMENTACION.md).

## 🚀 Inicio Rápido

1. Verificar [Requisitos](#requisitos)
2. Instalar el agente AppDynamics
3. Configurar las variables de entorno
4. Instrumentar el servidor ACE 12
5. Verificar la conexión con el Controller

---

## Requisitos

### Requisitos del Sistema

- **IBM ACE 12.0.x** (o superior)
- **Java**: JRE/JDK 1.8 o superior (compatible con ACE 12)
- **Sistema Operativo**: Linux x86_64, AIX, z/OS (según versión de ACE)
- **Permisos**: Usuario con permisos de administrador para ACE
- **Espacio en disco**: Mínimo 500 MB para el agente

### Requisitos de AppDynamics

- **Controller AppDynamics**: Acceso al Controller (hostname, puerto, cuenta)
- **Account Name**: Nombre de cuenta de AppDynamics
- **Access Key**: Access Key de AppDynamics
- **Application Name**: Nombre de la aplicación en AppDynamics
- **Tier Name**: Nombre del tier (ej: "ACE12-Production")
- **Node Name**: Nombre del nodo (único por instancia)

### Requisitos de Red

- **Conectividad**: Acceso de red al Controller de AppDynamics
- **Puertos**: 
  - Puerto del Controller (default: 8090 para HTTP, 443 para HTTPS)
  - Puerto para comunicación del agente

---

## Instalación

### Paso 1: Descargar el Agente Java

1. Acceder al portal de AppDynamics
2. Navegar a: **Settings > Downloads**
3. Descargar: **Java Agent** (versión compatible con tu Controller)
4. Extraer el archivo ZIP en un directorio accesible

### Paso 2: Ubicar el Directorio de Instalación

Recomendado: Crear un directorio dedicado para AppDynamics

```bash
# Ejemplo en Linux
mkdir -p /opt/appdynamics
cd /opt/appdynamics
# Extraer el agente aquí
unzip javaagent.zip
```

**Estructura esperada:**
```
/opt/appdynamics/
├── AppServerAgent/
│   ├── javaagent.jar
│   ├── conf/
│   ├── lib/
│   └── ...
└── README.txt
```

---

## Configuración

### Paso 1: Configurar el archivo `controller-info.xml`

Editar: `<AGENT_DIR>/AppServerAgent/conf/controller-info.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<controller-info>
    <!-- Información del Controller -->
    <controller-host>controller.appdynamics.com</controller-host>
    <controller-port>8090</controller-port>
    <controller-ssl-enabled>false</controller-ssl-enabled>
    
    <!-- Credenciales -->
    <account-name>customer1</account-name>
    <account-access-key>xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx</account-access-key>
    
    <!-- Información de la aplicación -->
    <application-name>IBM_ACE_Production</application-name>
    <tier-name>ACE12-Server</tier-name>
    <node-name>ACE12-Node-01</node-name>
    
    <!-- Configuración adicional -->
    <sim-enabled>false</sim-enabled>
    <enable-orchestration>false</enable-orchestration>
</controller-info>
```

**Parámetros importantes:**
- `controller-host`: Hostname o IP del Controller
- `controller-port`: Puerto del Controller (8090 HTTP, 443 HTTPS)
- `controller-ssl-enabled`: `true` si usa HTTPS, `false` para HTTP
- `account-name`: Nombre de la cuenta de AppDynamics
- `account-access-key`: Access Key (obtenido del portal)
- `application-name`: Nombre de la aplicación en AppDynamics
- `tier-name`: Identificador del tier/servidor
- `node-name`: Identificador único del nodo

### Paso 2: Configurar Logs (Opcional)

Editar: `<AGENT_DIR>/AppServerAgent/conf/logging/log4j.xml`

```xml
<log4j:configuration>
    <appender name="FileAppender" class="org.apache.log4j.RollingFileAppender">
        <param name="File" value="${appd.logs.dir}/appd.log"/>
        <param name="MaxFileSize" value="10MB"/>
        <param name="MaxBackupIndex" value="5"/>
    </appender>
    <root>
        <priority value="INFO"/>
        <appender-ref ref="FileAppender"/>
    </root>
</log4j:configuration>
```

---

## Instrumentación

### Opción 1: Instrumentación mediante Script mqsiprofile (Recomendado)

IBM ACE 12 utiliza el script `mqsiprofile` para configurar el entorno.

**Paso 1: Editar el archivo mqsiprofile**

Ubicación: `<ACE_INSTALL_DIR>/server/bin/mqsiprofile`

Agregar al final del archivo:

```bash
# AppDynamics Java Agent
export APP_AGENT_JAVA_OPTS="-javaagent:/opt/appdynamics/AppServerAgent/javaagent.jar"
export JAVA_OPTS="${JAVA_OPTS} ${APP_AGENT_JAVA_OPTS}"
```

**Paso 2: Reiniciar el servidor ACE**

```bash
# Detener el servidor
mqsistop <BROKER_NAME>

# Iniciar el servidor
mqsistart <BROKER_NAME>
```

### Opción 2: Instrumentación mediante Variables de Entorno del Sistema

Si prefieres no modificar el script `mqsiprofile`, puedes configurar variables de entorno del sistema:

```bash
# En /etc/profile o ~/.bashrc (Linux)
export APP_AGENT_JAVA_OPTS="-javaagent:/opt/appdynamics/AppServerAgent/javaagent.jar"
export JAVA_OPTS="${JAVA_OPTS} ${APP_AGENT_JAVA_OPTS}"
```

Luego reiniciar el servidor ACE.

### Opción 3: Instrumentación mediante archivo de inicio personalizado

Crear un script de inicialización personalizado:

**Crear: `/opt/appdynamics/ace_instrumentation.sh`**

```bash
#!/bin/bash
# Script de instrumentación AppDynamics para IBM ACE 12

APP_AGENT_DIR="/opt/appdynamics/AppServerAgent"
APP_AGENT_JAR="${APP_AGENT_DIR}/javaagent.jar"

if [ -f "${APP_AGENT_JAR}" ]; then
    export APP_AGENT_JAVA_OPTS="-javaagent:${APP_AGENT_JAR}"
    export JAVA_OPTS="${JAVA_OPTS} ${APP_AGENT_JAVA_OPTS}"
    echo "AppDynamics agent configurado: ${APP_AGENT_JAR}"
else
    echo "ERROR: AppDynamics agent no encontrado en ${APP_AGENT_JAR}"
fi
```

Agregar al inicio del script de ACE:

```bash
source /opt/appdynamics/ace_instrumentation.sh
```

---

## Verificación

### Paso 1: Verificar que el agente se carga

Revisar los logs del servidor ACE:

```bash
# Logs del servidor ACE
tail -f <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/*.log | grep -i appdynamics
```

**Mensajes esperados:**
- `AppDynamics Java Agent initialized successfully`
- `Connected to Controller`
- `Application successfully registered`

### Paso 2: Verificar en el Controller de AppDynamics

1. Acceder al portal de AppDynamics
2. Navegar a: **Applications > [Nombre de tu aplicación]**
3. Verificar que el **Tier** y **Node** aparecen como **Up** (verde)
4. Verificar métricas en tiempo real

### Paso 3: Verificar conectividad

```bash
# Verificar conectividad con el Controller
telnet <controller-host> <controller-port>

# O usando curl
curl -v http://<controller-host>:<controller-port>/controller/rest/applications
```

---

## Solución de Problemas

### Problema: El agente no se carga

**Síntomas:**
- No aparecen mensajes de AppDynamics en los logs
- El nodo no aparece en el Controller

**Soluciones:**
1. Verificar que `javaagent.jar` existe en la ruta especificada
2. Verificar permisos de lectura del archivo y directorio
3. Verificar que `JAVA_OPTS` se está configurando correctamente
4. Revisar logs del agente: `<AGENT_DIR>/AppServerAgent/logs/agent.log`

### Problema: No se conecta al Controller

**Síntomas:**
- Mensajes de error en los logs sobre conexión
- El nodo aparece como "Disconnected" en el Controller

**Soluciones:**
1. Verificar conectividad de red al Controller
2. Verificar que `controller-host` y `controller-port` son correctos
3. Verificar que `account-access-key` es válido
4. Verificar firewalls y reglas de seguridad
5. Verificar si el Controller usa SSL (ajustar `controller-ssl-enabled`)

### Problema: Errores de permisos

**Síntomas:**
- Errores al iniciar el servidor ACE
- Errores de acceso denegado en logs

**Soluciones:**
1. Verificar permisos de lectura en el directorio del agente
2. Verificar que el usuario que ejecuta ACE tiene acceso
3. Verificar permisos de escritura para logs: `<AGENT_DIR>/AppServerAgent/logs/`

### Problema: Conflictos con otras librerías

**Síntomas:**
- Errores de ClassNotFoundException
- Comportamiento inesperado de la aplicación

**Soluciones:**
1. Verificar versiones de Java compatibles
2. Verificar que no hay conflictos con otros agents (ej: New Relic)
3. Revisar logs completos del servidor ACE

---

## Permisos Requeridos

### Permisos del Sistema de Archivos

```bash
# Permisos recomendados
chown -R ace_user:ace_group /opt/appdynamics
chmod -R 755 /opt/appdynamics
chmod 644 /opt/appdynamics/AppServerAgent/conf/controller-info.xml
```

### Permisos en IBM ACE

El usuario que ejecuta ACE debe tener:
- Permisos para iniciar/detener el servidor
- Acceso de lectura al directorio del agente
- Acceso de escritura para logs del agente

### Permisos de Red

- Salida TCP al Controller de AppDynamics (puerto configurado)
- Acceso de salida HTTPS si usa SSL

---

## Variables de Entorno Importantes

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `JAVA_OPTS` | Opciones JVM que incluyen el javaagent | `-javaagent:/opt/appdynamics/AppServerAgent/javaagent.jar` |
| `APP_AGENT_DIR` | Directorio base del agente | `/opt/appdynamics/AppServerAgent` |
| `ACE_INSTALL_DIR` | Directorio de instalación de ACE | `/opt/ibm/ace-12.0` |
| `BROKER_NAME` | Nombre del broker ACE | `BRKR_PROD` |

---

## Referencias

- [Documentación Oficial AppDynamics](https://docs.appdynamics.com/)
- [IBM ACE Documentation](https://www.ibm.com/docs/en/app-connect/12.0)
- [AppDynamics Java Agent Installation Guide](https://docs.appdynamics.com/latest/en/application-monitoring/install-app-server-agents/java-agent)

---

## Soporte

Para consultas específicas sobre:
- **Configuración de AppDynamics**: Contactar al equipo de AppDynamics
- **IBM ACE 12**: Contactar al equipo de IBM o administradores de ACE
- **Permisos y acceso**: Contactar al área de Diego Romero

---

**Última actualización:** Enero 2025
