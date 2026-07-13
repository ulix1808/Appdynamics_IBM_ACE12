# Diseño y construcción de flujos — PoC Redis + IBM ACE 13

Guía **paso a paso en IBM ACE Toolkit 13** para construir los dos flujos de la PoC.

> Los `.msgflow` no vienen en el repo: se crean en el Toolkit. Este documento indica **qué crear, en qué orden y qué propiedades configurar**.

---

## Prerrequisitos (antes de armar los flujos)

### A. Versión ACE

```bash
mqsi version
# Escenario 1 (Redis Request): 13.0.5+
# Escenario 2 (Global Map + Redis): 13.0.3+
```

### B. Credencial en el servidor ACE

```bash
./scripts/setup-ace-credential.sh redis::pocRedisCredential <HOST_DB1> <PUERTO_DB1> '<PASSWORD>'
mqsireportdbparms -n redis::pocRedisCredential
```

(Ajusta host/puerto/password a Redis Enterprise `db1` o a tu Redis de lab.)

### C. Network: ¿ACE llega a Redis?

Sin `redis-cli` en el host ACE:

```bash
nc -zv <HOST_DB1> <PUERTO_DB1>
```

---

## Parte 0 — Proyectos base en el Toolkit (común a ambos flujos)

### 0.1 Crear Policy Project

1. **File → New → Policy Project**
2. Nombre: `RedisPolicies`
3. Finish

### 0.2 Crear Redis Connection policy

1. Clic derecho en `RedisPolicies` → **New → Policy → Redis Connection** (o tipo Redis Connection de tu fix pack)
2. Nombre: `RedisConnectionPoC`
3. Propiedades típicas:
   - **Host:** IP/DNS de Redis (o endpoint `db1`)
   - **Port:** puerto de la base (Enterprise: a menudo no es 6379)
   - **Security identity:** `redis::pocRedisCredential`
   - **TLS:** activar solo si `db1` lo exige
4. Guardar

Referencia XML: [`ace/policies/example-redis-connection.policy.xml`](../ace/policies/example-redis-connection.policy.xml)

### 0.3 Crear Integration Project / Application

1. **File → New → Application** (o Integration Project según plantilla del Toolkit)
2. Nombre: `RedisPoC`
3. Finish

### 0.4 Asociar Policy Project al Application / Integration Server

Según tu versión de Toolkit:

- En propiedades del Application, incluir el Policy Project `RedisPolicies`, **o**
- En el Integration Server (Integration Explorer), asociar `RedisPolicies` como policy project desplegable

Sin esto, el nodo Redis Request / Global Map no resuelve la policy.

---

## Escenario 1: construir el flujo `RedisCustomerLookup`

**Requisito:** ACE **13.0.5+** (nodo **Redis Request**).  
**Objetivo:** leer Redis sin Java externo.

```
[HTTP Input] → [Compute: normalizar] → [Redis Request] → [Compute: JSON] → [HTTP Reply]
```

*(Opcional en PoC avanzada: rama “cache miss” con HTTP Request a CRM.)*

### 1.1 Crear el message flow

1. Clic derecho en `RedisPoC` → **New → Message Flow**
2. Nombre: `RedisCustomerLookup`
3. Finish → se abre el canvas

### 1.2 Arrastrar nodos (palette)

Del palette, en este orden:

| Orden | Nodo | Cómo encontrarlo |
|------:|------|------------------|
| 1 | **HTTP Input** | HTTP / Connectivity |
| 2 | **Compute** | Transformation (ESQL) — nombre sugerido: `NormalizeRequest` |
| 3 | **Redis Request** | Discovery / Redis (Toolkit 13.0.5+) — si no aparece, tu ACE &lt; 13.0.5 |
| 4 | **Compute** | nombre: `BuildJsonResponse` |
| 5 | **HTTP Reply** | HTTP |

### 1.3 Conectar terminals

1. `HTTP Input` **Out** → `NormalizeRequest` **In**
2. `NormalizeRequest` **Out** → `Redis Request` **In**
3. `Redis Request` **Out** → `BuildJsonResponse` **In**  
   *(si el nodo tiene Failure: puede ir a un Trace o Compute de error)*
4. `BuildJsonResponse` **Out** → `HTTP Reply` **In**

### 1.4 Configurar HTTP Input

Doble clic → **Basic** / **HTTP**:

| Propiedad | Valor |
|-----------|--------|
| Path suffix for URL | `/poc/redis/customer` (o `/poc/redis/customer/*` según UI) |
| Use HTTPS | false (lab) |

Opcional: Query string `customerId` → se usa en ESQL.

### 1.5 Configurar Redis Request

1. Doble clic en **Redis Request**
2. **Policy:** elegir `RedisPolicies/RedisConnectionPoC` (o Policy name + Policy project)
3. Abrir **Discovery** / connector (panel Basic) si el Toolkit lo pide
4. Operación para la PoC (elige una):

| Opción PoC | Tipo | Acción típica en el nodo |
|------------|------|--------------------------|
| **A (recomendada)** | Hash | Get field value / Retrieve hash fields |
| **B** | String | Get value |

**Datos de seed** (si usaste `scripts/seed-redis.sh`):

- Key hash: `ace13:poc:customer:1001`
- Campos: `id`, `name`, `segment`, `status`

En Discovery / mapeo de request:

- **Key** (o equivalente): `ace13:poc:customer:1001`  
  o dinámico: `'ace13:poc:customer:' \|\| $LocalEnvironment...` según ESQL/Mapping disponible
- Si es hash: pedir campos `name`, `id`

> Los nombres exactos de menú en Discovery varían por fix pack. Busca operaciones sobre **Hash** / **String** / **Key**.

### 1.6 ESQL — NormalizeRequest (mínimo)

En el Compute `NormalizeRequest`, crear módulo y en `Main`:

```esql
CREATE COMPUTE MODULE RedisCustomerLookup_NormalizeRequest
CREATE FUNCTION Main() RETURNS BOOLEAN
BEGIN
    -- Extrae id de la URL o query; fallback 1001
    DECLARE customerId CHARACTER;
    SET customerId = COALESCE(
        InputLocalEnvironment.REST.Input.Parameters.customerId,
        InputLocalEnvironment.HTTP.Input.QueryString.customerId,
        '1001'
    );

    -- Deja el id disponible para Redis Request / Compute siguiente
    SET OutputLocalEnvironment.Variables.customerId = customerId;
    SET OutputLocalEnvironment.Variables.redisKey = 'ace13:poc:customer:' || customerId;

    RETURN TRUE;
END;
END MODULE;
```

> Ajusta rutas (`REST` vs `HTTP`) según cómo configures el HTTP Input en tu Toolkit.

Si el Redis Request **no** acepta variables locales fácilmente, en PoC usa key fija `ace13:poc:customer:1001` y luego parametriza.

### 1.7 ESQL — BuildJsonResponse (mínimo)

Asigna al mensaje de salida un JSON legible. Ejemplo conceptual:

```esql
CREATE COMPUTE MODULE RedisCustomerLookup_BuildJsonResponse
CREATE FUNCTION Main() RETURNS BOOLEAN
BEGIN
    -- Copia respuesta Redis (la ruta exacta depende del Discovery Connector)
    -- Inspecciona el árbol con Trace o Debugger tras la primera ejecución.
    CREATE LASTCHILD OF OutputRoot DOMAIN('JSON') NAME 'JSON';
    CREATE LASTCHILD OF OutputRoot.JSON.Data NAME 'status' VALUE 'OK';
    -- SET OutputRoot.JSON.Data.customer = <ruta_respuesta_redis>;

    SET OutputLocalEnvironment.Destination.HTTP.ReplyStatusCode = 200;
    RETURN TRUE;
END;
END MODULE;
```

**Cómo averiguar la ruta de la respuesta Redis:**

1. Poner un **Trace** después de Redis Request, o
2. Ejecutar en debugger y mirar `OutputRoot` / LocalEnvironment tras el nodo.

### 1.8 (Opcional) Rama cache miss — NO necesaria para la primera demo

Solo si quieren la tipología avanzada del diagrama:

1. Tras Normalize, un **Route** o Compute decide “¿hay dato?”
2. Rama miss → **HTTP Request** (mock CRM) → luego otro Redis Request (**Set** / Create hash) → HTTP Reply

Para la primera entrega: **saltarse esta rama**.

### 1.9 Guardar y validar

1. Save All
2. Clic derecho en el flujo → **Validate** (corregir errores)
3. Continuar en [Despliegue](#despliegue-bar)

### 1.10 Prueba

```bash
curl "http://<ACE_HOST>:<HTTP_PORT>/poc/redis/customer?customerId=1001"
# o path /poc/redis/customer/1001 según URLSpecifier
```

Esperado: datos del hash (tras seed) o respuesta OK mapeada.

---

## Escenario 2: construir el flujo `RedisGlobalCacheLookup`

**Requisito:** ACE **13.0.3+**.  
**Objetivo:** Global Map con backend Redis (sin Redis Request node).

```
[HTTP Input] → [JavaCompute: RedisGlobalCachePoC] → [HTTP Reply]
```

*(Mapping JSON es opcional; el JavaCompute puede dejar el resultado en Environment y un Compute armar el JSON.)*

### 2.1 Proyecto Java en el Toolkit

1. **File → New → Java Project** (o “Java compute” asociado al Application)
2. Nombre sugerido: `RedisPoC_Java`
3. Crear package: `com.example.ace.redis.poc`
4. Copiar la clase del repo:
   - Origen: [`ace/java/RedisGlobalCachePoC.java`](../ace/java/RedisGlobalCachePoC.java)
5. Asegurar que el proyecto Java referencia las librerías ACE (`MbJavaComputeNode`, etc. — el Toolkit suele hacerlo al crear JavaCompute)

**Importante:** en ACE 13 con External Redis Global Cache **no** hace falta el ZIP Jedis. La API es `MbGlobalMap` + policy Redis.

### 2.2 Crear el message flow

1. En `RedisPoC` → **New → Message Flow**
2. Nombre: `RedisGlobalCacheLookup`

### 2.3 Arrastrar nodos

| Orden | Nodo |
|------:|------|
| 1 | HTTP Input |
| 2 | JavaCompute |
| 3 | HTTP Reply |
| (opc.) | Compute o Mapping para JSON |

Conectar: HTTP Input → JavaCompute → HTTP Reply

### 2.4 Configurar HTTP Input

| Propiedad | Valor |
|-----------|--------|
| Path | `/poc/redis/cache` |
| Query | `customerId` (opcional) |

Ejemplo de prueba: `/poc/redis/cache?customerId=1001`

### 2.5 Configurar JavaCompute

1. Doble clic en JavaCompute
2. **Java class:** `com.example.ace.redis.poc.RedisGlobalCachePoC`
3. Compilar el proyecto Java (Project → Build) sin errores
4. Verificar en la clase:

```java
POLICY_PROJECT = "RedisPolicies"
POLICY_NAME   = "RedisConnectionPoC"
MAP_NAME      = "ace13PocCatalog"
```

Deben coincidir con el Policy Project / policy reales.

### 2.6 (Opcional) Compute para respuesta HTTP JSON

Si el Java deja `Environment.RedisPoC.status` y `payload` (como en el ejemplo del repo), un Compute posterior arma:

```esql
CREATE LASTCHILD OF OutputRoot DOMAIN('JSON') NAME 'JSON';
SET OutputRoot.JSON.Data.status = Environment.RedisPoC.status;
SET OutputRoot.JSON.Data.payload = Environment.RedisPoC.payload;
SET OutputLocalEnvironment.Destination.HTTP.ReplyStatusCode = 200;
RETURN TRUE;
```

Ajusta rutas `Environment` si en debugger ves otra estructura.

### 2.7 Comportamiento esperado

| Llamada | Resultado |
|---------|-----------|
| 1ª a `customerId=1001` | `CACHE_MISS` → simula backend → PUT en Redis (mapa global) |
| 2ª a `customerId=1001` | `CACHE_HIT` → lee de Redis |

### 2.8 Si `MbGlobalMap.getGlobalMap(...)` no compila

La firma de la API puede variar por fix pack. Revisar en el Toolkit la Javadoc / samples de:

- `MbGlobalMap.getGlobalMap(String mapName)`
- sobrecargas con policy project / policy name

Actualiza `RedisGlobalCachePoC.java` a la firma de tu instalación y vuelve a compilar.

---

## Despliegue (BAR)

### Crear BAR

1. **File → New → BAR File** (o Integration Project → New BAR)
2. Nombre: `RedisPoC.bar`
3. Incluir:
   - Application `RedisPoC` (flujos)
   - Policy project `RedisPolicies`
   - Proyecto Java (Escenario 2)
4. Build / Compile BAR

### Desplegar

```bash
mqsideploy <BROKER> -e <INTEGRATION_SERVER> -a RedisPoC.bar
```

O desde Toolkit: Integration Explorer → drag BAR al Integration Server.

### Verificar HTTP listener

Puerto HTTP típico lab: `7800` (confirmar en `server.conf.yaml` / administración).

---

## Checklist Toolkit (ambos flujos)

**Común**

- [ ] Policy Project `RedisPolicies` + policy `RedisConnectionPoC`
- [ ] Credencial `redis::pocRedisCredential` en el servidor ACE
- [ ] Application `RedisPoC`
- [ ] BAR con Application + Policies
- [ ] Red ACE → Redis (`nc -zv host port`)

**Escenario 1 — Redis Request**

- [ ] Flujo `RedisCustomerLookup` con HTTP Input + Redis Request + HTTP Reply
- [ ] Policy asignada en el nodo Redis Request
- [ ] Operación Hash o String configurada
- [ ] ACE 13.0.5+

**Escenario 2 — Global Map**

- [ ] Proyecto Java + clase `RedisGlobalCachePoC`
- [ ] Flujo `RedisGlobalCacheLookup` con JavaCompute
- [ ] Policy project/name correctos en el código
- [ ] ACE 13.0.3+

---

## Qué flujo construir primero

| Prioridad | Flujo | Por qué |
|-----------|--------|---------|
| **1** | `RedisCustomerLookup` (Redis Request) | Sin Java; demo más clara con Redis Enterprise |
| **2** | `RedisGlobalCacheLookup` (Global Map) | Útil si ya usan mapas globales / migración WXS |

Con Redis Enterprise `db1`: mismos pasos; solo cambian **host, puerto y password** en credencial + policy.

---

## Relación con el resto del repo

| Tema | Documento |
|------|-----------|
| Inicio rápido | [QUICK_START.md](../QUICK_START.md) |
| Arquitectura | [docs/ARQUITECTURA.md](../docs/ARQUITECTURA.md) |
| ACE 12 + Jedis | [docs/ACE12-JEDIS-ZIP.md](../docs/ACE12-JEDIS-ZIP.md) — **no** usar para Escenario 1 en ACE 13 |
| Policy ejemplo | [ace/policies/example-redis-connection.policy.xml](../ace/policies/example-redis-connection.policy.xml) |
| Java ejemplo | [ace/java/RedisGlobalCachePoC.java](../ace/java/RedisGlobalCachePoC.java) |
