# Diseño de flujos — PoC Redis + IBM ACE 13

Los archivos `.msgflow` deben crearse en el **IBM ACE Toolkit 13**. Este documento describe los flujos a implementar para la PoC.

## Escenario 1: Lookup con Redis Request node (ACE 13.0.5+)

**Objetivo:** Demostrar lectura/escritura directa en Redis sin Java externo.

### Flujo: `RedisCustomerLookup`

```
[HTTP Input] --> [Compute: normalizar request] --> [Redis Request] --> [Compute: armar JSON] --> [HTTP Reply]
                      |                                ^
                      | (cache miss path)              |
                      +--> [HTTP Request: CRM mock] ---+
```

| Nodo | Configuración |
|------|----------------|
| HTTP Input | `URLSpecifier`: `/poc/redis/customer/*` |
| Redis Request | Policy: `RedisPolicies/RedisConnectionPoC`; acción: **Get field value** (hash) o **Get value** (string) |
| HTTP Request | Solo si no hay dato en Redis (opcional en PoC avanzada) |

### Prueba manual

```bash
# Tras seed-redis.sh
curl "http://<ACE_HOST>:<PORT>/poc/redis/customer/1001"
# Esperado: datos del hash ace13:poc:customer:1001
```

### Redis Request — operaciones sugeridas para la PoC

| Caso de uso | Tipo Redis | Operación en nodo |
|-------------|------------|-------------------|
| Catálogo producto | Hash | Get field value (`name`, `price`) |
| Tipo de cambio | String | Get value + TTL |
| Idempotencia | String | Check key presence / Get value |
| Cola prioridad | Sorted set | Get rank / Count by score range |

> **Nota:** El nodo Redis Request (13.0.5+) documenta soporte orientado a IBM Cloud Databases for Redis / Compose. Para Redis on-prem en PoC, validar conexión con la misma Redis Connection policy; el comportamiento puede depender del fix pack instalado.

---

## Escenario 2: External Redis Global Cache (ACE 13.0.3+)

**Objetivo:** Reutilizar la API de mapa global (Mapping / JavaCompute) con backend Redis.

### Flujo: `RedisGlobalCacheLookup`

```
[HTTP Input] --> [JavaCompute: RedisGlobalCachePoC] --> [Mapping: JSON salida] --> [HTTP Reply]
```

- Clase Java: `ace/java/RedisGlobalCachePoC.java`
- Policy en el BAR: `RedisPolicies` con `RedisConnectionPoC`
- Credencial: `redis::pocRedisCredential`

### Comportamiento esperado

1. Primera petición: `CACHE_MISS` → simula backend → `PUT` en mapa global (Redis).
2. Segunda petición (misma clave): `CACHE_HIT` → respuesta desde Redis.

---

## Despliegue en ACE

```bash
# 1. Credencial
./scripts/setup-ace-credential.sh redis::pocRedisCredential <REDIS_HOST> 6379

# 2. Desplegar BAR (desde Toolkit o CLI)
mqsideploy <BROKER> -e <INTEGRATION_SERVER> -a RedisPoC.bar

# 3. Aplicar policy al integration server (si no va embebida en BAR)
# Toolkit: asociar Policy Project al servidor

# 4. Probar
curl "http://localhost:7800/poc/redis/customer/1001"
```

## Checklist Toolkit

- [ ] Integration project `RedisPoC`
- [ ] Policy project `RedisPolicies` con Redis Connection
- [ ] Credencial `redis::pocRedisCredential` en el servidor
- [ ] Al menos un flujo HTTP de prueba
- [ ] BAR generado y desplegado
- [ ] Redis accesible desde el host ACE (`scripts/verify-redis.sh` desde el servidor ACE)
