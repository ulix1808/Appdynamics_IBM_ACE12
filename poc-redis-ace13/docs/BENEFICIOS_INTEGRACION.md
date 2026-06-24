# Beneficios de Redis para equipos de integración (IBM ACE 13)

Documento orientado a **arquitectos de integración**, **desarrolladores de message flows** y **operaciones**, para justificar y explicar el valor de Redis en un entorno ACE 13.

---

## 1. Rendimiento y experiencia del consumidor

| Beneficio | Impacto en integración |
|-----------|------------------------|
| **Latencia sub-milisegundo** | Respuestas API más rápidas cuando los datos ya están en cache |
| **Menos llamadas al backend** | Menor carga a mainframe, ERP, CRM y bases relacionales |
| **TTL configurable** | Datos de catálogo o tipos de cambio con caducidad automática sin lógica extra en cada sistema |

**Ejemplo PoC:** La clave `ace13:poc:rate:USD-MXN` con TTL 300 s evita consultar un servicio de tasas en cada transacción.

---

## 2. Patrones de integración habilitados

### Cache-aside (lectura)
El flujo ACE consulta Redis primero; si no hay dato, llama al origen y guarda el resultado. Ideal para **consultas repetitivas** (cliente, producto, configuración).

### Idempotencia
Clave `ace13:poc:idempotency:<messageId>` evita reprocesar el mismo mensaje en reintentos MQ/HTTP. Crítico en **pagos y órdenes**.

### Catálogo compartido
Hashes Redis (`ace13:poc:catalog:SKU-001`) permiten que **varios flujos ACE** y **otras aplicaciones** lean el mismo catálogo sin duplicar llamadas al maestro de productos.

### Colas y priorización (sorted sets)
Sorted sets para priorizar trabajo (`ace13:poc:queue:priority`) sin añadir complejidad en el broker de mensajería principal.

### Sesión y contexto de correlación
Almacenar estado de conversación o tokens de corta duración entre pasos de un proceso de integración compuesto.

---

## 3. Ventajas frente a integrar sin cache (o solo con WXS legacy)

| Necesidad del negocio | Sin Redis / WXS legacy | Con Redis en ACE 13 |
|----------------------|------------------------|---------------------|
| Microservicio .NET/Java lee el mismo cache | No | Sí |
| Persistencia tras reinicio de ACE | No / limitada (WXS) | Sí (AOF/RDB) |
| Cluster / failover dedicado | Acoplado a ACE o inexistente | Redis Sentinel/Cluster |
| Operaciones avanzadas (hash, ZSET) | No | Sí (Redis Request) |
| Desacoplar releases de cache y ACE | No | Sí |
| Skills y herramientas en el mercado | WXS en declive | Redis estándar |

Redis posiciona a ACE 13 con una **capa de cache enterprise-wide**, compartida y operable de forma independiente.

---

## 4. Ventajas frente a ACE 12 / WXS

| Tema | ACE 12 + WXS | ACE 13 + Redis |
|------|--------------|----------------|
| Java 17 / contenedores | WXS limitado | Redis estándar en K8s |
| Mantenimiento IBM | WXS sin nuevas features | Redis ampliamente adoptado |
| Skills del equipo | WXS especializado | Redis común en DevOps |
| Ecosistema | Cerrado | Herramientas (Insight, exporters) |

Migrar a ACE 13 con Redis permite **modernizar** sin perder el patrón de mapa global en muchos casos (Mapping/JavaCompute).

---

## 5. Beneficios operativos

- **Visibilidad:** Redis Insight, `redis-cli`, métricas de memoria y keys
- **Escalado horizontal:** Añadir réplicas sin redesplegar todos los flujos ACE
- **Aislamiento de fallos:** Problemas de cache no requieren reiniciar integration servers (modelo externo)
- **Pruebas:** La misma instancia Redis de lab (`docker compose`) sirve para desarrollo y demos

---

## 6. Beneficios para desarrolladores de message flows

### Menos código custom (ACE 13.0.5+)
Antes: JavaCompute + librería Jedis/Lettuce + manejo de conexiones.  
Ahora: **Redis Request node** con discovery connector y policy.

### Políticas reutilizables
Una **Redis Connection policy** (`RedisConnectionPoC`) se comparte entre varios flujos y entornos (DEV/QA con distintas credenciales).

### Convivencia con Mapping
Quienes ya usan **Global Map** en mappings no reescriben todo: cambian el backend a Redis vía policy.

---

## 7. Casos de uso recomendados para la PoC → producción

| Caso | Prioridad | Mecanismo ACE 13 |
|------|-----------|------------------|
| Lookup cliente/producto | Alta | Redis Request o Global Map |
| Cache tipo de cambio / parámetros | Alta | String + TTL |
| Idempotencia en APIs | Alta | String / hash |
| Reemplazo WXS grid | Media | External Redis Global Cache |
| Cola priorizada interna | Media | Sorted set + Redis Request |
| Sincronización estado entre flujos ACE | Alta | Hash / string en Redis |

---

## 8. Mensaje para stakeholders

> **Redis en ACE 13** no sustituye al broker ni a la lógica de integración: **acelera y desacopla** el acceso a datos repetidos y compartidos. La PoC demuestra que el equipo puede levantar Redis en minutos, conectar ACE con policy estándar y medir mejoras de latencia y reducción de llamadas al backend — con un camino claro hacia HA y seguridad en producción.

---

## 9. Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Cache inconsistente | TTL corto, invalidación en eventos de cambio |
| Redis caído | Fallback a backend; circuit breaker en flujo |
| Datos sensibles en Redis | Cifrar en tránsito (TLS); no guardar PII sin cifrar |
| Soporte IBM Redis on-prem | Validar en PoC con tu fix pack; considerar IBM Cloud Redis si aplica |

---

## Referencias internas PoC

- Implementación: [QUICK_START.md](../QUICK_START.md)
- Arquitectura: [ARQUITECTURA.md](ARQUITECTURA.md)
- Casos de prueba: [ESCENARIOS_POC.md](ESCENARIOS_POC.md)
