# ZIP ace12-jedis-deps — diagnóstico y paquete corregido

## ¿El ZIP estaba mal?

Se verificó el archivo original en Mac:

```
/Users/ulix/Documents/Code/RedisIBMACE/packages/ace12-jedis-deps-whatsapp.zip
```

| Prueba | Resultado |
|--------|-----------|
| `zip -T` (integridad) | **OK** |
| Extracción | **OK** |
| JARs (`jar tf`) | **OK** — no corruptos |
| SHA256 carpeta vs ZIP | **Coinciden** |

**Conclusión:** el ZIP **no estaba mal comprimido** en origen. Lo más probable es una de estas causas:

### 1. Descarga / envío por WhatsApp (muy frecuente)

- WhatsApp a veces **recomprime** o altera archivos.
- El receptor puede haber guardado el archivo **sin descomprimir** y lo trató como si fuera un JAR.
- Descarga incompleta en móvil o red inestable.

**Qué hacer:** reenviar por **Google Drive, correo corporativo o Git**, no solo WhatsApp. Tras descargar, ejecutar `shasum -a 256 -c SHA256SUMS.txt`.

### 2. Paquete incompleto (causa técnica real)

El ZIP original solo tenía **2 JARs**:

- `jedis-4.4.8.jar`
- `commons-pool2-2.12.0.jar`

Pero **Jedis 4.4.8** declara dependencias de runtime que **no estaban en el ZIP**:

| JAR faltante | Para qué |
|--------------|----------|
| `gson-2.10.1.jar` | Import-Package `com.google.gson` |
| `json-20231013.jar` | Import-Package `org.json` |
| `slf4j-api-1.7.36.jar` | Import-Package `org.slf4j` |

Sin estos, en ACE 12 suele aparecer:

```
ClassNotFoundException: com.google.gson...
ClassNotFoundException: org.json...
ClassNotFoundException: org.slf4j...
```

Eso puede interpretarse como “el zip no sirve”, aunque el archivo ZIP en sí esté bien.

### 3. Uso incorrecto en Toolkit

- Añadir solo `jedis-4.4.8.jar` y olvidar `commons-pool2`.
- No incluir los JAR en el **BAR**.
- Apuntar al `.zip` en lugar de a los `.jar` extraídos.

---

## Paquete corregido (5 JARs)

Ubicación en este repo:

```
poc-redis-ace13/packages/ace12-jedis-deps/
├── jedis-4.4.8.jar
├── commons-pool2-2.12.0.jar
├── gson-2.10.1.jar
├── json-20231013.jar
├── slf4j-api-1.7.36.jar
├── LEEME.txt
└── SHA256SUMS.txt
```

Generar ZIP para compartir:

```bash
cd poc-redis-ace13/packages
zip -j ace12-jedis-deps.zip ace12-jedis-deps/*.jar ace12-jedis-deps/LEEME.txt ace12-jedis-deps/SHA256SUMS.txt
```

Verificar en destino:

```bash
unzip ace12-jedis-deps.zip -d ace12-jedis-deps
cd ace12-jedis-deps
shasum -a 256 -c SHA256SUMS.txt
```

---

## Cómo saber que el paquete está completo

### 1. Fuente oficial: POM de Maven (Jedis 4.4.8)

Dependencias **compile** (runtime), según  
https://repo1.maven.org/maven2/redis/clients/jedis/4.4.8/jedis-4.4.8.pom :

| Artefacto | En nuestro ZIP |
|-----------|----------------|
| `jedis` | Sí |
| `commons-pool2` | Sí |
| `gson` | Sí |
| `json` | Sí |
| `slf4j-api` | Sí |
| `junixsocket`, `jts-core`, `junit`, etc. | **No** — scope `test` en el POM (no hacen falta en ACE) |

No hay más dependencias **compile** en ese POM.

### 2. Prueba automática en este repo

```bash
# Con Redis local (Docker):
cd poc-redis-ace13/infra && docker compose up -d
cd ../packages/verify-jedis-deps && ./verify-jedis-deps.sh
```

El script:

1. Comprueba que existen los 5 JAR.
2. Valida `SHA256SUMS.txt`.
3. **Compila** `JedisSmokeTest.java` usando **solo** esos 5 JAR (si falta alguno → `ClassNotFoundException` al compilar o ejecutar).
4. Ejecuta `PING`, `SET`, `GET` contra Redis.

Salida esperada:

```
PASS: Paquete completo para operaciones basicas Jedis (PING, SET, GET).
```

### 3. Aviso SLF4J (normal)

Puede aparecer:

```
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder"
```

No es error: `slf4j-api` está incluido; el **binding** de log es opcional. En ACE el runtime suele resolver logging por su cuenta. No hace falta añadir `slf4j-simple` para cache básico.

### 4. Límites de la prueba

| Cubierto por el smoke test | No cubierto (requeriría features extra) |
|----------------------------|----------------------------------------|
| PING, GET, SET, DEL, pool | RedisJSON / RediSearch avanzado |
| Classpath completo compile | UNIX socket (`junixsocket` — solo tests IBM) |

Para **JavaCompute + cache** en ACE 12 (get/set, TTL, idempotencia), el paquete de 5 JARs es el conjunto correcto según Maven.

---

## Mensaje sugerido para Diego / equipo

> El ZIP anterior no estaba corrupto, pero era **incompleto**: faltaban 3 dependencias de Jedis 4.4.8. Les comparto `ace12-jedis-deps.zip` con **5 JARs** y archivo `SHA256SUMS.txt` para validar la descarga. Deben **descomprimir** y agregar **todos** los JAR al Java Build Path y al BAR.

---

## ACE 13 vs ACE 12

- **ACE 12:** JavaCompute + Jedis (este paquete).
- **ACE 13.0.5+:** preferir **Redis Request node** o **Global Map + Redis policy** (sin Jedis).
