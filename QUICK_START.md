# Quick Start: AppDynamics en IBM ACE 12

Guía rápida para instrumentación en 5 pasos.

> **⚠️ IMPORTANTE:** El agente de AppDynamics para IBM ACE/IIB es un **User Exit nativo**, NO un agente Java. Se instala usando `mqsichangebroker`.

## ⚡ Inicio Rápido (5 Pasos)

### 1. Preparar Agente

```bash
# Crear directorio
sudo mkdir -p /opt/appdynamics
cd /opt/appdynamics

# Extraer agente IIB descargado (NO el Java Agent)
unzip iib-agent.zip
```

### 2. Configurar controller-info.xml

Editar: `/opt/appdynamics/iib-agent/conf/controller-info.xml`

```xml
<controller-host>TU_CONTROLLER_HOST</controller-host>
<controller-port>443</controller-port>
<controller-ssl-enabled>1</controller-ssl-enabled>
<account-name>TU_ACCOUNT</account-name>
<account-access-key>TU_ACCESS_KEY</account-access-key>
<application-name>IBM_ACE_Production</application-name>
<tier-name>ACE12-Production</tier-name>
<user-exit>wmqi</user-exit>
<log-dir>/opt/appdynamics/iib-agent/logs</log-dir>
<log-level>info</log-level>
```

**⚠️ IMPORTANTE:** El Controller exige **`wmqi`** en `controller-info.xml` y en el YAML. Con "AppDynamics" o "AppDynamicsExit" no funciona.

### 3. Detener el Broker

```bash
mqsi stop <BROKER_NAME>
```

### 4. Instalar el User Exit

**Opción A: Usando mqsichangebroker** (solo en versiones donde no esté deprecado)
```bash
mqsichangebroker <BROKER_NAME> -x /opt/appdynamics/iib-agent -e wmqi
```

**⚠️ En ACE 12.0.12.x el comando está deprecado.** Si recibes **BIP8161E** o **BIP8101E** (*"now available using the mqsichangeproperties command"*), usar:
```bash
mqsichangeproperties <BROKER_NAME> -n userExitPath -v /opt/appdynamics/iib-agent
mqsichangeproperties <BROKER_NAME> -n activeUserExitList -v wmqi
```

**Opción B: Usando node.conf.yaml (ACE 11, ACE 12)**
Editar: `<ACE_INSTALL_DIR>/server/<BROKER_NAME>/node.conf.yaml`

```yaml
UserExits:
  activeUserExitList: 'wmqi'
  userExitPath: '/opt/appdynamics/iib-agent'
```

**Parámetros:**
- `<BROKER_NAME>`: Nombre de tu broker
- `-x`: Directorio donde se extrajo el agente
- `-e`: Debe ser **wmqi** (mismo valor que en controller-info.xml y en el YAML)

### 5. Iniciar y Verificar

```bash
# Iniciar el broker
mqsi start <BROKER_NAME>

# Verificar logs del agente
tail -f /opt/appdynamics/iib-agent/logs/*.log

# Verificar en Controller
# Navegar a: Applications > IBM_ACE_Production
```

## 📚 Documentación Completa

- [README.md](README.md) - Documentación general
- [INSTRUMENTACION.md](INSTRUMENTACION.md) - Guía detallada paso a paso
- [DIAGNOSTICO_AGENTE_NO_CARGA.md](DIAGNOSTICO_AGENTE_NO_CARGA.md) - **Diagnóstico si el agente no se carga**

## 🔗 Referencia Oficial

- [AppDynamics IIB Agent Documentation](https://docs.appdynamics.com/appd/24.x/latest/en/application-monitoring/install-app-server-agents/ibm-integration-bus-agent/install-the-iib-agent)
