# Quick Start — PoC Redis + IBM ACE 13

Guía paso a paso para ejecutar la PoC en un entorno de laboratorio.

## Fase 1: Redis local (15 min)

### 1.1 Levantar Redis

```bash
cd poc-redis-ace13/infra
cp .env.example .env
docker compose up -d
```

Opcional — UI para inspeccionar claves:

```bash
docker compose --profile ui up -d
# Redis Insight: http://localhost:5540
# Conectar a host: redis, port: 6379 (desde el contenedor) o localhost:6379 desde tu máquina
```

### 1.2 Verificar

```bash
cd ..
./scripts/verify-redis.sh
./scripts/seed-redis.sh
```

Comprobar datos manualmente:

```bash
docker exec ace13-poc-redis redis-cli HGETALL ace13:poc:customer:1001
docker exec ace13-poc-redis redis-cli TTL ace13:poc:rate:USD-MXN
```

### 1.3 Latencia (opcional)

```bash
./scripts/test-redis-latency.sh 1000
```

Útil para comparar con latencia de un backend HTTP/SOAP en la demo.

---

## Fase 2: Preparar IBM ACE 13 (30–60 min)

### 2.1 Verificar versión

```bash
mqsi version
# Mínimo 13.0.3 para Redis Global Cache
# Mínimo 13.0.5 para Redis Request node
```

### 2.2 Credencial Redis en el integration server

En el **servidor donde corre ACE** (no necesariamente donde está Docker):

```bash
cd poc-redis-ace13
./scripts/setup-ace-credential.sh redis::pocRedisCredential <IP_REDIS> 6379
```

Si Redis tiene password:

```bash
./scripts/setup-ace-credential.sh redis::pocRedisCredential <IP_REDIS> 6379 'tu-password'
```

Verificar:

```bash
mqsireportdbparms -n redis::pocRedisCredential
```

### 2.3 Redis Connection Policy (Toolkit)

1. Abrir **IBM ACE Toolkit 13**.
2. Crear **Policy Project**: `RedisPolicies`.
3. **New → Policy → Redis Connection**.
   - Name: `RedisConnectionPoC`
   - Host / Port: IP y puerto de Redis
   - Security identity: `redis::pocRedisCredential`
4. Referencia XML: `ace/policies/example-redis-connection.policy.xml`

### 2.4 Integration project y flujos

Guía **paso a paso en el Toolkit** (crear nodos, propiedades, ESQL/Java):  
**[flows/DISENO_FLUJOS.md](flows/DISENO_FLUJOS.md)**

| Prioridad | Flujo | ACE mínimo |
|-----------|-------|------------|
| 1 | `RedisCustomerLookup` — Redis Request | 13.0.5 |
| 2 | `RedisGlobalCacheLookup` — Global Map + JavaCompute | 13.0.3 |

### 2.5 Desplegar

```bash
# Generar BAR desde Toolkit, luego:
mqsideploy <BROKER_NAME> -e <INTEGRATION_SERVER> -a RedisPoC.bar
```

Reiniciar o recargar el integration server si aplica políticas nuevas.

---

## Fase 3: Pruebas de la PoC

### 3.1 Conectividad ACE → Redis

Desde el host ACE:

```bash
# Si tienes redis-cli
redis-cli -h <REDIS_HOST> -p 6379 ping

# O telnet/nc al puerto 6379
nc -zv <REDIS_HOST> 6379
```

### 3.2 Prueba funcional (HTTP)

Tras desplegar el flujo `RedisCustomerLookup`:

```bash
curl -s "http://<ACE_HOST>:<HTTP_PORT>/poc/redis/customer/1001" | jq .
```

**Éxito:** respuesta con datos del cliente (desde Redis tras `seed-redis.sh`).

### 3.3 Prueba cache hit/miss (Global Cache)

1. Primera llamada → `CACHE_MISS` (o latencia mayor).
2. Segunda llamada misma clave → `CACHE_HIT` (respuesta más rápida).

### 3.4 Criterios de éxito

Ver checklist en [docs/ESCENARIOS_POC.md](../docs/ESCENARIOS_POC.md).

---

## Fase 4: Redis en otro host (ACE en Linux, Redis en Docker Mac)

Si ACE corre en un servidor Linux y Redis en tu laptop:

1. En `docker-compose.yml`, el puerto `6379` ya está expuesto.
2. Usa la **IP alcanzable** del host Docker (no `localhost` desde ACE remoto).
3. Actualiza credencial y policy con esa IP.

---

## Solución de problemas

| Síntoma | Acción |
|---------|--------|
| `Connection refused` a Redis | `docker compose ps`; firewall; IP correcta en policy |
| Credencial no encontrada | `mqsireportdbparms`; nombre exacto `redis::pocRedisCredential` |
| Redis Request no aparece en Toolkit | Actualizar a ACE **13.0.5+** |
| Global map no usa Redis | Pasar policy project/name en `getGlobalMap()` |
| WXS / cacheOn deprecado | Migrar a Redis (ACE 13.0.3+) |

---

## Siguiente paso

- Presentar resultados con [docs/BENEFICIOS_INTEGRACION.md](../docs/BENEFICIOS_INTEGRACION.md)
- Definir arquitectura objetivo con [docs/ARQUITECTURA.md](../docs/ARQUITECTURA.md)
