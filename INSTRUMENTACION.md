# Guía Detallada de Instrumentación: AppDynamics en IBM ACE 12

Esta guía proporciona instrucciones paso a paso para instrumentar IBM ACE 12 con AppDynamics usando el **IIB Agent (User Exit nativo)**.

> **⚠️ IMPORTANTE:** El agente de AppDynamics para IBM ACE/IIB es un **User Exit nativo (C/C++)**, NO un agente Java. Este agente se instala usando el comando `mqsichangebroker` y NO requiere configuración de `JAVA_OPTS` ni `-javaagent`.

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
- [ ] **Controller Port**: Puerto (típicamente 8090 para HTTP o 443 para HTTPS)
- [ ] **Protocolo**: HTTP o HTTPS
- [ ] **Account Name**: Nombre de la cuenta de AppDynamics
- [ ] **Access Key**: Clave de acceso (Account Settings > Access Keys)
- [ ] **Application Name**: Nombre de la aplicación en AppDynamics
- [ ] **Tier Name**: Nombre del tier/servidor (ej: "ACE12-Production")
- [ ] **User Exit Name**: Debe ser **`wmqi`** (requerido por el Controller; con "AppDynamics" o "AppDynamicsExit" no funciona)

### Información del Entorno ACE

Del administrador de IBM ACE necesitas:

- [ ] **Ruta de instalación de ACE**: `<ACE_INSTALL_DIR>`
- [ ] **Nombre del Broker**: `<BROKER_NAME>`
- [ ] **Usuario que ejecuta ACE**: `<ACE_USER>`
- [ ] **Sistema Operativo**: `uname -a`

### Verificaciones Iniciales

```bash
# 1. Verificar versión de ACE
mqsi version

# 2. Verificar que el servidor está funcionando
mqsi status <BROKER_NAME>

# 3. Verificar conectividad al Controller
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

### Paso 2: Descargar el Agente IIB

1. Acceder al portal de AppDynamics
2. **Settings > Downloads > IBM Integration Bus Agent** (NO el Java Agent)
3. Seleccionar la versión compatible con tu Controller
4. Descargar el archivo ZIP

### Paso 3: Extraer el Agente

```bash
cd /opt/appdynamics
unzip iib-agent.zip

# Verificar estructura
ls -la iib-agent/
# Debe mostrar: conf/, lib/, y otros archivos del agente
```

---

## Instalación del Agente

### Estructura del Directorio

Después de extraer, deberías tener:

```
/opt/appdynamics/
└── iib-agent/
    ├── conf/
    │   └── controller-info.xml    # Archivo de configuración principal
    ├── lib/                       # Librerías del agente
    └── ...
```

### Verificar Permisos

```bash
cd /opt/appdynamics/iib-agent
ls -la
# Debe ser legible por el usuario que ejecuta ACE

# Si es necesario, ajustar permisos:
sudo chown -R <ACE_USER>:<ACE_GROUP> /opt/appdynamics
sudo chmod -R 755 /opt/appdynamics
```

---

## Configuración del Agente

### Paso 1: Configurar controller-info.xml

**Ubicación:** `/opt/appdynamics/iib-agent/conf/controller-info.xml`

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
    <controller-port>443</controller-port>
    
    <!-- Habilitar SSL -->
    <!-- 1 para HTTPS, 0 para HTTP -->
    <controller-ssl-enabled>1</controller-ssl-enabled>
    
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
    
    <!-- ========================================= -->
    <!-- Configuración del User Exit             -->
    <!-- ========================================= -->
    
    <!-- ⚠️ IMPORTANTE: Debe ser "wmqi" (requerido por el Controller) -->
    <user-exit>wmqi</user-exit>
    
    <!-- ========================================= -->
    <!-- Configuración de Logs                   -->
    <!-- ========================================= -->
    
    <!-- Directorio de logs del agente -->
    <log-dir>/opt/appdynamics/iib-agent/logs</log-dir>
    
    <!-- Nivel de log (trace|debug|info|warning|error) -->
    <log-level>info</log-level>
    
    <!-- ========================================= -->
    <!-- Configuración Adicional                  -->
    <!-- ========================================= -->
    
    <!-- Habilitar visibilidad a nivel de flow -->
    <flow-level-visibility-enabled>0</flow-level-visibility-enabled>
    
    <!-- Deshabilitar correlación (0=habilitado, 1=deshabilitado) -->
    <disable-mq-correlation>0</disable-mq-correlation>
    <disable-http-correlation>0</disable-http-correlation>
    <disable-jms-correlation>0</disable-jms-correlation>
    
    <!-- Configuración de reutilización de nombres de nodos -->
    <node-reuse>true</node-reuse>
    <node-reuse-prefix>ACE12-Node</node-reuse-prefix>
    
</controller-info>
```

**⚠️ IMPORTANTE:** 
- Reemplazar todos los valores de ejemplo con los valores reales proporcionados por el equipo de AppDynamics.
- El `<user-exit>` **DEBE ser `wmqi`**. El Controller exige este valor; con "AppDynamics", "AppDynamicsExit" u otros no funciona.

### Paso 2: Verificar Configuración

```bash
# Verificar que el archivo existe y es legible
ls -la /opt/appdynamics/iib-agent/conf/controller-info.xml

# Verificar configuración básica
grep -E "controller-host|controller-port|account-name|account-access-key|application-name|user-exit" /opt/appdynamics/iib-agent/conf/controller-info.xml

# Verificar que user-exit es wmqi
grep "user-exit" /opt/appdynamics/iib-agent/conf/controller-info.xml
# Debe mostrar: <user-exit>wmqi</user-exit>
```

---

## Instrumentación del Servidor

### Paso 1: Detener el Broker

**⚠️ IMPORTANTE:** El broker debe estar detenido para instalar el user exit.

```bash
# 1. Detener el broker
mqsi stop <BROKER_NAME>

# 2. Verificar que se detuvo correctamente
mqsi status <BROKER_NAME>
# Debe mostrar que el broker está detenido
```

### Paso 2: Instalar el User Exit

Hay dos métodos para instalar el user exit, dependiendo de la versión de ACE:

> **📌 Comandos en versiones recientes (ACE 12.0.12.x):** En versiones nuevas de ACE 12, **`mqsichangebroker` está deprecado**. Si al ejecutarlo aparece **BIP8161E** o **BIP8101E** con el mensaje *"The functionality provided by the mqsichangebroker command is now available using the mqsichangeproperties command"*, usar **Opción B** (`mqsichangeproperties`) o el **Método 2** (`node.conf.yaml`).

#### Método 1: Usando mqsichangebroker o mqsichangeproperties

**⚠️ NOTA IMPORTANTE:** En ACE 12.0.12.x y otras versiones recientes, el comando `mqsichangebroker` está deprecado. Si recibes uno de estos errores:
- **BIP8161E** (común en 12.0.12.x)
- **BIP8101E**

con el mensaje indicando que la funcionalidad está disponible con `mqsichangeproperties`, debes usar **Opción B** (`mqsichangeproperties`) en su lugar.

##### Opción A: Usando mqsichangebroker (si está disponible)

```bash
mqsichangebroker <BROKER_NAME> -x <INSTALL_DIRECTORY> -e <USER_EXIT_NAME>
```

**Ejemplo:**
```bash
mqsichangebroker BRKR_PROD -x /opt/appdynamics/iib-agent -e wmqi
```

##### Opción B: Usando mqsichangeproperties (cuando mqsichangebroker está deprecado)

Si `mqsichangebroker` muestra el error de deprecación, usar:

```bash
mqsichangeproperties <BROKER_NAME> -n userExitPath -v <INSTALL_DIRECTORY>
mqsichangeproperties <BROKER_NAME> -n activeUserExitList -v <USER_EXIT_NAME>
```

**Ejemplo:**
```bash
mqsichangeproperties BRURALBRKQA -n userExitPath -v /opt/appdynamics/iib-agent
mqsichangeproperties BRURALBRKQA -n activeUserExitList -v wmqi
```

**Parámetros:**
- `<BROKER_NAME>`: Nombre del broker (ej: `BRKR_PROD` o `BRURALBRKQA`)
- `<INSTALL_DIRECTORY>`: Directorio donde se extrajo el agente IIB (ej: `/opt/appdynamics/iib-agent`)
- `<USER_EXIT_NAME>`: **Debe ser `wmqi`** (requerido por el Controller; mismo valor en controller-info.xml y en el YAML)

**⚠️ IMPORTANTE:**
- El Controller exige **`wmqi`** en `controller-info.xml` y en `node.conf.yaml` (activeUserExitList). Con "AppDynamics", "AppDynamicsExit" u otros no funciona.
- El directorio de instalación debe ser la ruta completa donde se extrajo el agente
- Si `mqsichangebroker` muestra error de deprecación, usar `mqsichangeproperties` con los dos comandos mostrados arriba

#### Método 2: Usando node.conf.yaml (ACE 11, ACE 12)

Para ACE 11 y ACE 12, también puedes configurar el user exit editando directamente el archivo `node.conf.yaml`:

**Ubicación del archivo:**
```
<path-to-installation-directory>/<broker-name>/node.conf.yaml
```

**Ejemplo de ruta:**
```
/opt/ibm/ace-12.0/server/<BROKER_NAME>/node.conf.yaml
```

**Configuración en node.conf.yaml:**

Agregar o modificar la sección `UserExits`:

```yaml
UserExits:
  activeUserExitList: 'wmqi'  # Debe ser "wmqi" (requerido por el Controller)
  userExitPath: '/opt/appdynamics/iib-agent'  # Especificar la ruta del agente
```

**Ejemplo completo de node.conf.yaml:**

```yaml
# Otras configuraciones del broker...
# ...

UserExits:
  activeUserExitList: 'wmqi'
  userExitPath: '/opt/appdynamics/iib-agent'
```

**⚠️ IMPORTANTE:**
- El Controller exige **`wmqi`** tanto en `controller-info.xml` como en `activeUserExitList`. Con "AppDynamics" o "AppDynamicsExit" no funciona.
- El `userExitPath` debe ser la ruta completa donde se extrajo el agente
- Después de editar `node.conf.yaml`, es necesario reiniciar el broker

**Verificar la configuración:**

```bash
# Verificar que el archivo existe
ls -la <ACE_INSTALL_DIR>/server/<BROKER_NAME>/node.conf.yaml

# Verificar la configuración del user exit
grep -A 2 "UserExits" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/node.conf.yaml
```

**Nota:** Si usas el método de `node.conf.yaml`, no necesitas ejecutar `mqsichangebroker` ni `mqsichangeproperties`. El broker cargará el user exit automáticamente al iniciar basándose en la configuración del archivo.

### Paso 3: Verificar Instalación

```bash
# Verificar que el user exit está configurado
mqsireportbroker <BROKER_NAME>
# Debe mostrar información sobre el user exit instalado
```

### Paso 4: Iniciar el Broker

```bash
# 1. Iniciar el broker
mqsi start <BROKER_NAME>

# 2. Verificar que inició correctamente
mqsi status <BROKER_NAME>
# Debe mostrar que el broker está corriendo

# 3. Revisar logs inmediatamente
tail -f <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/system.log | grep -i "user.exit\|appdynamics"
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

# Buscar mensajes de éxito
grep -i "initialized\|connected\|registered" /opt/appdynamics/iib-agent/logs/*.log
```

**Mensajes esperados:**
```
INFO: AppDynamics IIB Agent initialized successfully
INFO: Connected to Controller at <controller-host>:<controller-port>
INFO: Application 'IBM_ACE_Production' successfully registered
INFO: Tier 'ACE12-Production-Tier' registered
```

### Paso 2: Verificar Logs del Servidor ACE

```bash
# Buscar referencias al user exit en logs de ACE
grep -i "<USER_EXIT_NAME>\|appdynamics\|user.exit" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/*.log

# Ver logs del sistema del broker
tail -100 <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/system.log | grep -i "user.exit\|appdynamics"
```

**Mensajes esperados:**
- Información sobre la carga del user exit
- Confirmación de que el user exit está activo

### Paso 3: Verificar en el Controller de AppDynamics

1. **Acceder al portal:**
   - URL: `http://<controller-host>:<controller-port>` o `https://<controller-host>:<controller-port>`
   - Login con credenciales de AppDynamics

2. **Navegar a la aplicación:**
   - **Applications > [Nombre de tu aplicación]**

3. **Verificar estado:**
   - **Tier** debe aparecer como **Up** (indicador verde)
   - **Nodes** deben aparecer (uno por cada execution group instrumentado)
   - Deben aparecer métricas en tiempo real

4. **Verificar métricas:**
   - CPU, Memory, Response Time
   - Transacciones, errores
   - Business transactions

### Paso 4: Probar Conectividad

```bash
# Verificar conectividad de red
ping <controller-host>

# Verificar puerto
telnet <controller-host> <controller-port>

# O usando curl (si está disponible)
curl -v https://<controller-host>:<controller-port>/controller/rest/applications
```

---

## Troubleshooting Detallado

### Problema 1: El agente no se carga

**Síntomas:**
- No hay mensajes del agente en los logs
- El tier no aparece en el Controller
- El broker inicia pero no hay actividad del agente

**Diagnóstico:**

```bash
# 1. Verificar que el user exit está instalado
mqsireportbroker <BROKER_NAME>
# Debe mostrar información sobre el user exit

# 2. Verificar que el directorio de instalación existe
ls -la <INSTALL_DIRECTORY>
# Debe contener los archivos del agente

# 3. Verificar que el nombre del user exit es wmqi
grep "user-exit" /opt/appdynamics/iib-agent/conf/controller-info.xml
# NO debe contener caracteres especiales

# 4. Verificar logs del broker
grep -i "user.exit\|error" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/system.log
```

**Soluciones:**
1. **Verificar que el user exit está instalado:**
   ```bash
   mqsireportbroker <BROKER_NAME>
   ```
   Si no aparece información del user exit, reinstalarlo.

2. **Verificar nombre del user exit:**
   - El nombre debe ser wmqi (requerido por el Controller)
   - Debe coincidir exactamente entre `controller-info.xml` y el comando `mqsichangebroker`

3. **Reinstalar el user exit:**
   ```bash
   mqsi stop <BROKER_NAME>
   # Si mqsichangebroker está disponible:
   mqsichangebroker <BROKER_NAME> -x <INSTALL_DIRECTORY> -e <USER_EXIT_NAME>
   # O si está deprecado, usar:
   # mqsichangeproperties <BROKER_NAME> -n userExitPath -v <INSTALL_DIRECTORY>
   # mqsichangeproperties <BROKER_NAME> -n activeUserExitList -v <USER_EXIT_NAME>
   mqsi start <BROKER_NAME>
   ```

### Problema 2: No se conecta al Controller

**Síntomas:**
- Mensajes de error sobre conexión en logs
- Tier aparece como "Disconnected" en Controller

**Diagnóstico:**

```bash
# 1. Verificar conectividad
ping <controller-host>
telnet <controller-host> <controller-port>

# 2. Verificar configuración
grep -E "controller-host|controller-port|account-access-key" /opt/appdynamics/iib-agent/conf/controller-info.xml

# 3. Verificar logs de conexión
grep -i "connection\|controller\|error" /opt/appdynamics/iib-agent/logs/*.log
```

**Soluciones:**
1. **Verificar host/port:** Revisar `controller-info.xml`
2. **Verificar Access Key:** Validar con el equipo de AppDynamics
3. **Verificar firewall:** Asegurar que el puerto está abierto
4. **Verificar SSL:** Si el Controller usa HTTPS, configurar `controller-ssl-enabled=1`
5. **Verificar DNS:** Resolver correctamente el hostname del Controller

**Mensajes de error comunes:**

```
ERROR: Failed to connect to Controller
→ Verificar host, port y conectividad de red

ERROR: Invalid account access key
→ Verificar el Access Key en controller-info.xml

ERROR: SSL handshake failed
→ Configurar controller-ssl-enabled=1 o verificar certificados
```

### Problema 3: El broker no inicia después de instalar el agente

**Síntomas:**
- El broker falla al iniciar
- Errores en los logs sobre el user exit

**Soluciones:**

```bash
# 1. Verificar que el nombre del user exit es wmqi
grep "user-exit" /opt/appdynamics/iib-agent/conf/controller-info.xml
# Si tiene otro valor (AppDynamics, AppDynamicsExit), cambiarlo a wmqi

# 2. Verificar la ruta de instalación
ls -la <INSTALL_DIRECTORY>
# La ruta debe ser absoluta y accesible

# 3. Desinstalar temporalmente el agente
mqsi stop <BROKER_NAME>
mqsichangebroker <BROKER_NAME> -x "" -e ""
mqsi start <BROKER_NAME>
# Si el broker inicia sin el agente, el problema está en la configuración del agente
```

### Problema 4: Errores de permisos

**Síntomas:**
- Errores "Permission denied" al iniciar ACE
- Errores al escribir logs

**Soluciones:**

```bash
# Verificar y ajustar permisos de archivos y directorios
sudo chown -R <ACE_USER>:<ACE_GROUP> /opt/appdynamics
sudo chmod -R 755 /opt/appdynamics
sudo chmod 644 /opt/appdynamics/iib-agent/conf/controller-info.xml

# Asegurar permisos de escritura para logs
sudo chmod 775 /opt/appdynamics/iib-agent/logs
sudo chown <ACE_USER>:<ACE_GROUP> /opt/appdynamics/iib-agent/logs
```

### Problema 5: No aparecen métricas en el Controller

**Síntomas:**
- El tier aparece como "Up" pero no hay métricas

**Soluciones:**

1. **Verificar que la aplicación está registrada:**
   - En Controller: Applications > [App Name]
   - Verificar que Tier y Nodes están visibles

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
- [ ] Application name y tier name definidos
- [ ] User exit name definido como **wmqi**
- [ ] Permisos de red confirmados (firewall)

### Preparación del Entorno
- [ ] Directorio de instalación creado (`/opt/appdynamics`)
- [ ] Agente IIB descargado y extraído
- [ ] Permisos de archivos configurados
- [ ] Backup de configuración de ACE realizado

### Configuración
- [ ] `controller-info.xml` configurado con valores reales
- [ ] `user-exit` es **wmqi** en controller-info.xml y en node.conf.yaml (activeUserExitList)
- [ ] Directorio de logs configurado y con permisos de escritura

### Instalación
- [ ] Broker detenido antes de instalar el user exit
- [ ] User exit instalado con `mqsichangebroker`
- [ ] Instalación verificada con `mqsireportbroker`

### Pruebas
- [ ] Conectividad al Controller verificada
- [ ] Agente probado en ambiente de desarrollo/pruebas
- [ ] Logs revisados y sin errores
- [ ] Verificación en Controller (ambiente de pruebas)
- [ ] Tier y Nodes aparecen en el Controller

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

# 2. Remover el user exit
# Si mqsichangebroker está disponible:
mqsichangebroker <BROKER_NAME> -x "" -e ""
# O si está deprecado, usar:
# mqsichangeproperties <BROKER_NAME> -n userExitPath -v ""
# mqsichangeproperties <BROKER_NAME> -n activeUserExitList -v ""

# 3. Iniciar el broker
mqsi start <BROKER_NAME>

# 4. Verificar que inicia sin referencias a AppDynamics
tail -f <ACE_INSTALL_DIR>/server/<BROKER_NAME>/workspace/.esb/logs/system.log
```

---

## Notas Adicionales

### Consideraciones de Performance

- El agente AppDynamics tiene un impacto mínimo en performance (< 5%)
- El overhead aumenta con el nivel de log (usar `info` en producción)
- Monitorear uso de recursos después de la instrumentación

### Seguridad

- El `controller-info.xml` contiene credenciales sensibles (Access Key)
- Asegurar permisos restrictivos: `chmod 600 controller-info.xml`
- No compartir el Access Key públicamente
- Considerar rotación periódica de Access Keys

### Mantenimiento

- Revisar logs periódicamente: `/opt/appdynamics/iib-agent/logs/` o `/tmp/appd/`
- Actualizar el agente cuando haya nuevas versiones (coordinado con AppDynamics)
- Verificar conectividad después de cambios de infraestructura

### Instrumentación Parcial

Si tienes un alto volumen de actividad, puedes instrumentar solo componentes críticos en lugar de todo el broker.

#### Opción 1: Instrumentar solo Flows Críticos (IIB 10)

Para IIB 10, puedes instrumentar solo flows específicos:

1. Instalar el agente sin habilitarlo para todos los flows:
   ```bash
   mqsichangebroker <BROKER_NAME> -x <INSTALL_DIRECTORY>
   ```

2. Agregar el agente a flows individuales:
   ```bash
   mqsichangeflowuserexits <BROKER_NAME> -a <USER_EXIT_NAME> -e <integrationServerName> -f <MessageFlow> -k <application_name>
   ```

#### Opción 2: Instrumentar solo Integration Servers Críticos (ACE 11, ACE 12)

Para ACE 11 y ACE 12, puedes instrumentar solo integration servers específicos en lugar de todo el broker. Esto es útil cuando tienes un alto volumen de actividad y solo quieres monitorear servers críticos.

**Pasos:**

1. **Configurar el user exit en cada integration server que quieras instrumentar:**

   Editar el archivo `server.conf.yaml` de cada integration server:
   
   **Ubicación:** `<path-to-installation-directory>/<broker-name>/servers/<server-name>/server.conf.yaml`
   
   **Ejemplo de ruta:**
   ```
   /opt/ibm/ace-12.0/server/<BROKER_NAME>/servers/<SERVER_NAME>/server.conf.yaml
   ```

   **Agregar o modificar la sección `UserExits`:**
   ```yaml
   UserExits:
     activeUserExitList: 'wmqi'  # Debe ser wmqi (requerido por el Controller)
     userExitPath: '/opt/appdynamics/iib-agent'  # Ruta del agente
   ```

2. **Dejar vacío el `node.conf.yaml` (si estaba configurado):**

   Editar: `<path-to-installation-directory>/<broker-name>/node.conf.yaml`
   
   **Configurar como vacío:**
   ```yaml
   UserExits:
     activeUserExitList: ''  # Dejar como cadena vacía
     userExitPath: ''  # Dejar como cadena vacía
   ```

   **⚠️ IMPORTANTE:** Si el `node.conf.yaml` tiene el user exit configurado, se aplicará a TODOS los integration servers. Para instrumentación selectiva, debe estar vacío.

3. **Reiniciar el broker:**
   ```bash
   mqsi stop <BROKER_NAME>
   mqsi start <BROKER_NAME>
   ```

**Resultado:**
- El agente solo se habilitará para los integration servers que tengan el user exit configurado en su `server.conf.yaml`
- Los business transactions solo se crearán (o continuarán) para integration servers donde el user exit esté activo
- Un nodo de aplicación se registrará por cada proceso de broker que tenga uno o más integration servers instrumentados

**Ejemplo de estructura:**
```
/opt/ibm/ace-12.0/server/BRKR_PROD/
├── node.conf.yaml  (UserExits vacío)
└── servers/
    ├── Server1/
    │   └── server.conf.yaml  (UserExits configurado - INSTRUMENTADO)
    ├── Server2/
    │   └── server.conf.yaml  (UserExits vacío - NO instrumentado)
    └── Server3/
        └── server.conf.yaml  (UserExits configurado - INSTRUMENTADO)
```

**Verificar configuración:**
```bash
# Verificar node.conf.yaml está vacío
grep -A 2 "UserExits" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/node.conf.yaml

# Verificar server.conf.yaml de cada integration server
grep -A 2 "UserExits" <ACE_INSTALL_DIR>/server/<BROKER_NAME>/servers/<SERVER_NAME>/server.conf.yaml
```

---

**Última actualización:** Enero 2025  
**Versión del documento:** 2.0  
**Referencia:** [AppDynamics IIB Agent Documentation](https://docs.appdynamics.com/appd/24.x/latest/en/application-monitoring/install-app-server-agents/ibm-integration-bus-agent/install-the-iib-agent)
