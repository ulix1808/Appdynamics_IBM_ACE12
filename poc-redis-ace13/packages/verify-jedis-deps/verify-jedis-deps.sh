#!/usr/bin/env bash
# Verifica que el paquete ace12-jedis-deps tiene todas las dependencias runtime
# compilando y ejecutando JedisSmokeTest SOLO con esos 5 JARs (sin Maven/Gradle).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="$(cd "${SCRIPT_DIR}/../ace12-jedis-deps" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"

JARS=(
  "${DEPS_DIR}/jedis-4.4.8.jar"
  "${DEPS_DIR}/commons-pool2-2.12.0.jar"
  "${DEPS_DIR}/gson-2.10.1.jar"
  "${DEPS_DIR}/json-20231013.jar"
  "${DEPS_DIR}/slf4j-api-1.7.36.jar"
)

CP=$(IFS=:; echo "${JARS[*]}")

echo "==> 1. Verificar que existen los 5 JARs"
for j in "${JARS[@]}"; do
  [[ -f "$j" ]] || { echo "FALTA: $j"; exit 1; }
  jar tf "$j" >/dev/null
  echo "    OK $j"
done

echo ""
echo "==> 2. Verificar checksums (si hay SHA256SUMS.txt)"
if [[ -f "${DEPS_DIR}/SHA256SUMS.txt" ]]; then
  (cd "${DEPS_DIR}" && shasum -a 256 -c SHA256SUMS.txt)
else
  echo "    (omitido: no SHA256SUMS.txt)"
fi

echo ""
echo "==> 3. Compilar JedisSmokeTest con classpath = solo los 5 JARs"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
javac -cp "${CP}" -d "${BUILD_DIR}" "${SCRIPT_DIR}/JedisSmokeTest.java"
echo "    OK compilacion (sin ClassNotFoundException = dependencias compile OK)"

echo ""
echo "==> 4. Ejecutar contra Redis ${REDIS_HOST}:${REDIS_PORT}"
if java -cp "${BUILD_DIR}:${CP}" JedisSmokeTest "${REDIS_HOST}" "${REDIS_PORT}"; then
  echo ""
  echo "PASS: Paquete completo para operaciones basicas Jedis (PING, SET, GET)."
else
  echo ""
  echo "FAIL: Revisar que Redis este arriba (docker compose up -d en poc-redis-ace13/infra)"
  exit 1
fi
