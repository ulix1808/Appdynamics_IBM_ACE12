# Escenarios y criterios de éxito — PoC Redis + ACE 13

## Escenarios de prueba

### E1 — Infraestructura Redis

| Paso | Acción | Resultado esperado |
|------|--------|-------------------|
| E1.1 | `docker compose up -d` | Contenedor `ace13-poc-redis` healthy |
| E1.2 | `./scripts/verify-redis.sh` | PING, SET/GET, HSET/HGET OK |
| E1.3 | `./scripts/seed-redis.sh` | Claves `ace13:poc:*` creadas |

---

### E2 — Conectividad ACE → Redis

| Paso | Acción | Resultado esperado |
|------|--------|-------------------|
| E2.1 | `setup-ace-credential.sh` en servidor ACE | Credencial reportada por `mqsireportdbparms` |
| E2.2 | Policy desplegada en integration server | Sin errores al iniciar servidor |
| E2.3 | `redis-cli -h <REDIS> ping` desde host ACE | `PONG` |

---

### E3 — Redis Request: lectura de catálogo (13.0.5+)

**Flujo:** `RedisCustomerLookup` o variante catálogo SKU.

| Paso | Acción | Resultado esperado |
|------|--------|-------------------|
| E3.1 | GET HTTP `/poc/redis/catalog/SKU-001` | JSON con name, price |
| E3.2 | Consultar key inexistente | Error controlado o 404 en flujo |
| E3.3 | Inspeccionar en Redis Insight | Key leída coincide con respuesta |

**Datos previos:** `seed-redis.sh` → `ace13:poc:catalog:SKU-001`

---

### E4 — Global Map + Redis: cache hit/miss (13.0.3+)

**Flujo:** `RedisGlobalCacheLookup` con `RedisGlobalCachePoC.java`.

| Paso | Acción | Resultado esperado |
|------|--------|-------------------|
| E4.1 | Primera petición `customerId=1001` | `CACHE_MISS`, datos de backend simulado |
| E4.2 | Segunda petición misma clave | `CACHE_HIT`, misma payload, menor tiempo |
| E4.3 | Ver Redis | Clave presente en instancia externa |

---

### E5 — Idempotencia

| Paso | Acción | Resultado esperado |
|------|--------|-------------------|
| E5.1 | Enviar mensaje con `messageId=msg-0001` | Flujo detecta ya procesado (`seed` creó clave) |
| E5.2 | Enviar mensaje nuevo | Procesamiento normal + SET idempotency key |

---

## Criterios de éxito de la PoC

La PoC se considera **exitosa** si se cumple:

- [ ] Redis operativo y accesible desde el servidor ACE
- [ ] Al menos **un flujo ACE** lee o escribe en Redis correctamente
- [ ] Credencial y policy documentadas y repetibles en otro entorno
- [ ] Demostración de **cache hit** (segunda llamada más rápida o explícita en payload)
- [ ] Documento de beneficios revisado con el equipo ([BENEFICIOS_INTEGRACION.md](BENEFICIOS_INTEGRACION.md))
- [ ] Decisión registrada: Redis Request vs Global Map + Redis para cada caso de uso piloto

---

## Métricas sugeridas para la demo

| Métrica | Cómo medir |
|---------|------------|
| Latencia cache hit | Logs ACE timestamps o `curl -w '%{time_total}'` |
| Latencia cache miss | Primera llamada vs segunda |
| Latencia Redis pura | `./scripts/test-redis-latency.sh` |
| Reducción llamadas backend | Contador en flujo o logs HTTP Request |

---

## Matriz de trazabilidad

| Requisito negocio | Escenario | Artefacto |
|-------------------|-----------|-----------|
| Respuesta rápida consultas cliente | E3, E4 | Redis Request / Global Map |
| Evitar doble procesamiento | E5 | String idempotency |
| Catálogo compartido | E3 | Hash catalog |
| Modernización ACE 13 | E4 | Redis Global Cache + policy |
| Operación en lab | E1, E2 | Docker + scripts |

---

## Próximos pasos post-PoC

1. Definir topología Redis producción (single, Sentinel, Cluster).
2. TLS y secrets management.
3. Naming convention de keys (`<dominio>:<entidad>:<id>`).
4. Runbook: backup, monitoreo, escalado.
5. Plan migración WXS → Redis si aplica.
