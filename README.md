# AppDynamics para IBM ACE 12

Documentación completa para la instrumentación del agente de AppDynamics en IBM ACE (Advanced Customer Experience) 12, también conocido como IBM Integration Bus (IIB).

> **⚠️ IMPORTANTE:** El agente de AppDynamics para IBM ACE/IIB es un **User Exit nativo (C/C++)**, NO un agente Java. Este agente se instala usando el comando `mqsichangebroker` y NO requiere configuración de `JAVA_OPTS` ni `-javaagent`.

## 📋 Contenido

- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Configuración](#configuración)
- [Instrumentación](#instrumentación)
- [Verificación](#verificación)
- [Solución de Problemas](#solución-de-problemas)
- [Referencias](#referencias)

## 📖 Documentación Completa

- [INSTRUMENTACION.md](INSTRUMENTACION.md) - Guía detallada paso a paso
- [DIAGNOSTICO_AGENTE_NO_CARGA.md](DIAGNOSTICO_AGENTE_NO_CARGA.md) - **Diagnóstico si el agente no se carga** (no hay logs ni registro en Controller)

## 🔴 PoC: Redis + IBM ACE 13

Repositorio ampliado con una Proof of Concept para integrar **Redis** con **IBM ACE 13** (Redis Global Cache y Redis Request node).

- **[poc-redis-ace13/README.md](poc-redis-ace13/README.md)** — Visión general de la PoC
- **[poc-redis-ace13/QUICK_START.md](poc-redis-ace13/QUICK_START.md)** — Levantar Redis y conectar ACE
- **[poc-redis-ace13/docs/BENEFICIOS_INTEGRACION.md](poc-redis-ace13/docs/BENEFICIOS_INTEGRACION.md)** — Beneficios para equipos de integración

## 🚀 Inicio Rápido

1. Verificar [Requisitos](#requisitos)
2. Descargar e instalar el agente IIB de AppDynamics
3. Configurar `controller-info.xml`
4. Instalar el User Exit (en **ACE 12.0.12.x** usar `mqsichangeproperties`; en versiones anteriores puede usarse `mqsichangebroker`)
5. Reiniciar el broker y verificar la conexión con el Controller

---

## Requisitos

### Requisitos del Sistema

- **IBM ACE 12.0.x** (o superior) o **IBM IIB 10.x**
- **Sistema Operativo**: Linux x86_64, AIX, Windows (según versión de ACE)
- **Permisos**: Usuario con permisos de administrador para ACE (para ejecutar `mqsichangebroker`)
- **Espacio en disco**: Mínimo 500 MB para el agente

### Requisitos de AppDynamics

- **Controller AppDynamics**: Acceso al Controller (hostname, puerto, cuenta)
- **Account Name**: Nombre de cuenta de AppDynamics
- **Access Key**: Access Key de AppDynamics (obtenido de Account Settings > Access Keys)
- **Application Name**: Nombre de la aplicación en AppDynamics
- **Tier Name**: Nombre del tier (ej: "ACE12-Production")
- **User Exit Name**: Debe ser **`wmqi`** (requerido por el Controller; otros valores como "AppDynamics" o "AppDynamicsExit" no funcionan)

### Requisitos de Red

- **Conectividad**: Acceso de red al Controller de AppDynamics
- **Puertos**: 
  - Puerto del Controller (default: 8090 para HTTP, 443 para HTTPS)
  - Puerto para comunicación del agente

---

## Instalación

### Paso 1: Descargar el Agente IIB

1. Acceder al portal de AppDynamics
2. Navegar a: **Settings > Downloads**
3. Descargar: **IBM Integration Bus Agent** (NO el Java Agent)
4. Extraer el archivo ZIP en un directorio accesible

### Paso 2: Ubicar el Directorio de Instalación

Recomendado: Crear un directorio dedicado para AppDynamics

```bash
# Ejemplo en Linux
mkdir -p /opt/appdynamics
cd /opt/appdynamics
# Extraer el agente IIB aquí
unzip iib-agent.zip
```

**Estructura esperada:**
```
/opt/appdynamics/
└── iib-agent/
    ├── conf/
    │   └── controller-info.xml
    ├── lib/
    └── ...
```

---

## Configuración

### Paso 1: Configurar el archivo `controller-info.xml`

**Ubicación:** `<AGENT_INSTALL_DIR>/conf/controller-info.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<controller-info>
    <!-- Información del Controller -->
    <controller-host>controller.appdynamics.com</controller-host>
    <controller-port>443</controller-port>
    <controller-ssl-enabled>1</controller-ssl-enabled>
    
    <!-- Credenciales -->
    <account-name>customer1</account-name>
    <account-access-key>xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx</account-access-key>
    
    <!-- Información de la aplicación -->
    <application-name>IBM_ACE_Production</application-name>
    <tier-name>ACE12-Production-Tier</tier-name>
    
    <!-- User Exit Name: debe ser "wmqi" (requerido por el Controller) -->
    <user-exit>wmqi</user-exit>
    
    <!-- Configuración de logs -->
    <log-dir>/opt/appdynamics/iib-agent/logs</log-dir>
    <log-level>info</log-level>
    
    <!-- Configuración adicional -->
    <flow-level-visibility-enabled>0</flow-level-visibility-enabled>
    <disable-mq-correlation>0</disable-mq-correlation>
    <disable-http-correlation>0</disable-http-correlation>
    <disable-jms-correlation>0</disable-jms-correlation>
</controller-info>
```

**Parámetros importantes:**
- `controller-host`: Hostname o IP del Controller
- `controller-port`: Puerto del Controller (8090 HTTP, 443 HTTPS)
- `controller-ssl-enabled`: `1` para HTTPS, `0` para HTTP
- `account-name`: Nombre de la cuenta de AppDynamics
- `account-access-key`: Access Key (obtenido del portal)
- `application-name`: Nombre de la aplicación en AppDynamics
- `tier-name`: Identificador del tier/servidor
- `user-exit`: **Debe ser `wmqi`**. El Controller de AppDynamics exige este valor; con otros (p. ej. "AppDynamics", "AppDynamicsExit") el agente no funciona.
- `log-dir`: Directorio para logs del agente (default: `/tmp/appd`)
- `log-level`: Nivel de log (`trace|debug|info|warning|error`)

**⚠️ IMPORTANTE:** Usar **`wmqi`** tanto en `controller-info.xml` como en `node.conf.yaml` (activeUserExitList). Con otro valor el agente no se carga correctamente.

---

## Instrumentación

### Paso 1: Detener el Broker

El broker debe estar detenido para instalar el user exit:

```bash
mqsi stop <BROKER_NAME>

# Verificar que se detuvo correctamente
mqsi status <BROKER_NAME>
```

### Paso 2: Instalar el User Exit

Hay dos métodos para instalar el user exit:

#### Método 1: Usando mqsichangebroker o mqsichangeproperties

**⚠️ Comandos en versiones recientes de ACE 12:** En **ACE 12.0.12.x** (y otras versiones recientes) el comando `mqsichangebroker` está **deprecado**. Si al ejecutarlo recibes:
- `BIP8161E` o `BIP8101E`: *"The functionality provided by the mqsichangebroker command is now available using the mqsichangeproperties command"*

debes usar **`mqsichangeproperties`** (Opción B). El método por **`node.conf.yaml`** (Método 2) también es válido y evita depender del comando deprecado.

**Opción A: mqsichangebroker (si está disponible)**
```bash
mqsichangebroker <BROKER_NAME> -x <INSTALL_DIRECTORY> -e <USER_EXIT_NAME>
```

**Opción B: mqsichangeproperties (cuando mqsichangebroker está deprecado)**
```bash
mqsichangeproperties <BROKER_NAME> -n userExitPath -v <INSTALL_DIRECTORY>
mqsichangeproperties <BROKER_NAME> -n activeUserExitList -v <USER_EXIT_NAME>
```

**Ejemplo:**
```bash
# Si mqsichangebroker funciona:
mqsichangebroker BRKR_PROD -x /opt/appdynamics/iib-agent -e wmqi

# Si mqsichangebroker está deprecado:
mqsichangeproperties BRURALBRKQA -n userExitPath -v /opt/appdynamics/iib-agent
mqsichangeproperties BRURALBRKQA -n activeUserExitList -v wmqi
```

#### Método 2: Usando node.conf.yaml (ACE 11, ACE 12)

Para ACE 11 y ACE 12, también puedes configurar editando el archivo `node.conf.yaml`:

**Ubicación:** `<ACE_INSTALL_DIR>/server/<BROKER_NAME>/node.conf.yaml`

**Agregar o modificar:**
```yaml
UserExits:
  activeUserExitList: 'wmqi'  # Debe ser "wmqi" (requerido por el Controller)
  userExitPath: '/opt/appdynamics/iib-agent'  # Ruta del agente
```

**Parámetros:**
- `<BROKER_NAME>`: Nombre del broker (ej: `BRKR_PROD`)
- `<INSTALL_DIRECTORY>`: Directorio donde se extrajo el agente IIB (ej: `/opt/appdynamics/iib-agent`)
- `<USER_EXIT_NAME>`: **Debe ser `wmqi`** (mismo valor en `controller-info.xml` y en este YAML)

**⚠️ IMPORTANTE:** 
- El Controller exige el valor **`wmqi`** en `controller-info.xml` y en `node.conf.yaml` (activeUserExitList). Con "AppDynamics", "AppDynamicsExit" u otros valores no funciona.
- El directorio de instalación debe ser la ruta completa donde se extrajo el agente
- Si usas `node.conf.yaml`, no necesitas ejecutar `mqsichangebroker`

### Paso 3: Iniciar el Broker

```bash
mqsi start <BROKER_NAME>

# Verificar que inició correctamente
mqsi status <BROKER_NAME>
```

El agente se carga automáticamente cuando el broker inicia, si está instalado correctamente.

---

## Verificación

### Paso 1: Verificar Logs del Agente

Los logs del agente se encuentran en el directorio configurado en `log-dir` (default: `/tmp/appd`):

```bash
# Verificar que el directorio de logs existe
ls -la /opt/appdynamics/iib-agent/logs/

# Ver logs del agente
tail -f /opt/appdynamics/iib-agent/logs/*.log

# O si usa el directorio por defecto:
tail -f /tmp/appd/*.log
```

**Mensajes esperados:**
- Información sobre la conexión al Controller
- Registro de la aplicación y tier
- Mensajes de inicialización del agente

### Paso 2: Verificar Logs del Broker

Buscar referencias al user exit en los logs del broker:

```bash
# Buscar referencias al user exit
grep -i "<USER_EXIT_NAME>" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/*.log

# Ver logs del sistema del broker
tail -100 <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/system.log | grep -i "user.exit\|appdynamics"
```

**Mensajes esperados:**
- Información sobre la carga del user exit
- Confirmación de que el user exit está activo

### Paso 3: Verificar en el Controller de AppDynamics

1. Acceder al portal de AppDynamics
2. Navegar a: **Applications > [Nombre de tu aplicación]**
3. Verificar que el **Tier** aparece como **Up** (verde)
4. Verificar que aparecen **Nodes** (uno por cada execution group instrumentado)
5. Verificar métricas en tiempo real

### Paso 4: Verificar Conectividad

```bash
# Verificar conectividad con el Controller
ping <controller-host>

# Verificar puerto
telnet <controller-host> <controller-port>

# O usando curl (si está disponible)
curl -v https://<controller-host>:<controller-port>/controller/rest/applications
```

---

## Solución de Problemas

### Problema: El agente no se carga

**Síntomas:**
- No aparecen mensajes del agente en los logs
- El tier no aparece en el Controller
- El broker inicia pero no hay actividad del agente

**Soluciones:**
1. **Verificar que el user exit está instalado:**
   ```bash
   # Verificar configuración del broker
   mqsireportbroker <BROKER_NAME>
   # Debe mostrar información sobre el user exit
   ```

2. **Verificar que el nombre del user exit es `wmqi`:**
   - En `controller-info.xml` (`<user-exit>`) debe ser **wmqi**
   - En `node.conf.yaml` (activeUserExitList) y en `mqsichangebroker` (`-e`) debe ser **wmqi**. Otros valores como "AppDynamics" o "AppDynamicsExit" no funcionan

3. **Verificar la ruta de instalación:**
   ```bash
   # Verificar que el directorio existe
   ls -la <INSTALL_DIRECTORY>
   # Debe contener los archivos del agente
   ```

4. **Revisar logs del broker:**
   ```bash
   # Buscar errores relacionados con user exits
   grep -i "user.exit\|error" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/system.log
   ```

### Problema: No se conecta al Controller

**Síntomas:**
- Mensajes de error en los logs sobre conexión
- El tier aparece como "Disconnected" en el Controller

**Soluciones:**
1. Verificar conectividad de red al Controller
2. Verificar que `controller-host` y `controller-port` son correctos
3. Verificar que `account-access-key` es válido
4. Verificar firewalls y reglas de seguridad
5. Verificar si el Controller usa SSL (ajustar `controller-ssl-enabled`)

### Problema: Errores de permisos

**Síntomas:**
- Errores al iniciar el broker
- Errores de acceso denegado en logs

**Soluciones:**
1. Verificar permisos de lectura en el directorio del agente
2. Verificar que el usuario que ejecuta ACE tiene acceso
3. Verificar permisos de escritura para logs: `<log-dir>`

### Problema: El broker no inicia después de instalar el agente

**Síntomas:**
- El broker falla al iniciar
- Errores en los logs sobre el user exit

**Soluciones:**
1. **Verificar que el nombre del user exit es `wmqi`:**
   - El Controller exige **wmqi** en `controller-info.xml` y en el YAML
   - Si usas "AppDynamics", "AppDynamicsExit" u otro valor, cambiarlo a **wmqi**

2. **Verificar la ruta de instalación:**
   - La ruta debe ser absoluta y accesible
   - Verificar permisos del directorio

3. **Desinstalar temporalmente el agente:**
   ```bash
   mqsistop <BROKER_NAME>
   # Si mqsichangebroker está disponible:
   mqsichangebroker <BROKER_NAME> -x "" -e ""
   # O si está deprecado:
   # mqsichangeproperties <BROKER_NAME> -n userExitPath -v ""
   # mqsichangeproperties <BROKER_NAME> -n activeUserExitList -v ""
   mqsistart <BROKER_NAME>
   ```
   Si el broker inicia sin el agente, el problema está en la configuración del agente.

---

## Desinstalar el Agente

Si necesitas desinstalar el agente:

```bash
# 1. Detener el broker
mqsi stop <BROKER_NAME>

# 2. Remover el user exit
# Si mqsichangebroker está disponible:
mqsichangebroker <BROKER_NAME> -x "" -e ""
# O si está deprecado:
# mqsichangeproperties <BROKER_NAME> -n userExitPath -v ""
# mqsichangeproperties <BROKER_NAME> -n activeUserExitList -v ""

# 3. Iniciar el broker
mqsi start <BROKER_NAME>
```

---

## Referencias

- [Documentación Oficial AppDynamics - IIB Agent](https://docs.appdynamics.com/appd/24.x/latest/en/application-monitoring/install-app-server-agents/ibm-integration-bus-agent/install-the-iib-agent)
- [IBM ACE Documentation](https://www.ibm.com/docs/en/app-connect/12.0)
- [AppDynamics Downloads Portal](https://download.appdynamics.com/)

---

## Soporte

Para consultas específicas sobre:
- **Configuración de AppDynamics**: Contactar al equipo de AppDynamics
- **IBM ACE 12**: Contactar al equipo de IBM o administradores de ACE
- **Permisos y acceso**: Contactar al área correspondiente

---

**Última actualización:** Enero 2025  
**Referencia:** [AppDynamics IIB Agent Documentation](https://docs.appdynamics.com/appd/24.x/latest/en/application-monitoring/install-app-server-agents/ibm-integration-bus-agent/install-the-iib-agent)
