# Quick Start: AppDynamics en IBM ACE 12

Guía rápida para instrumentación en 5 pasos.

## ⚡ Inicio Rápido (5 Pasos)

### 1. Preparar Agente

```bash
# Crear directorio
sudo mkdir -p /opt/appdynamics
cd /opt/appdynamics

# Extraer agente descargado
unzip javaagent.zip
```

### 2. Configurar controller-info.xml

Editar: `/opt/appdynamics/AppServerAgent/conf/controller-info.xml`

```xml
<controller-host>TU_CONTROLLER_HOST</controller-host>
<controller-port>8090</controller-port>
<account-name>TU_ACCOUNT</account-name>
<account-access-key>TU_ACCESS_KEY</account-access-key>
<application-name>IBM_ACE_Production</application-name>
<tier-name>ACE12-Production</tier-name>
<node-name>ACE12-Node-01</node-name>
```

### 3. Instrumentar ACE

Editar: `<ACE_INSTALL_DIR>/server/bin/mqsiprofile`

Agregar al final:
```bash
export JAVA_OPTS="${JAVA_OPTS} -javaagent:/opt/appdynamics/AppServerAgent/javaagent.jar"
```

### 4. Reiniciar Servidor

```bash
mqsi stop <BROKER_NAME>
mqsi start <BROKER_NAME>
```

### 5. Verificar

```bash
# Verificar logs
tail -f /opt/appdynamics/AppServerAgent/logs/agent.log

# Verificar en Controller
# Navegar a: Applications > IBM_ACE_Production
```

## 📚 Documentación Completa

- [README.md](README.md) - Documentación general
- [INSTRUMENTACION.md](INSTRUMENTACION.md) - Guía detallada paso a paso
