#!/usr/bin/env bash
# Carga datos de ejemplo para probar flujos ACE (lookup de cliente, idempotencia, catálogo).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${POC_DIR}/infra/.env" ]]; then
  # shellcheck disable=SC1091
  source "${POC_DIR}/infra/.env"
fi

REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"

if command -v redis-cli >/dev/null 2>&1; then
  CLI=(redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}")
else
  CLI=(docker exec ace13-poc-redis redis-cli)
fi

echo "==> Sembrando datos de ejemplo en Redis"

# Catálogo de productos (hash por SKU)
"${CLI[@]}" HSET "ace13:poc:catalog:SKU-001" sku SKU-001 name "Cuenta Corriente" price 0 currency USD >/dev/null
"${CLI[@]}" HSET "ace13:poc:catalog:SKU-002" sku SKU-002 name "Tarjeta Crédito" price 25 currency USD >/dev/null

# Clientes
"${CLI[@]}" HSET "ace13:poc:customer:1001" id 1001 name "Ana García" segment retail status active >/dev/null
"${CLI[@]}" HSET "ace13:poc:customer:1002" id 1002 name "Luis Pérez" segment corporate status active >/dev/null

# Cache de respuesta (simula resultado de backend lento)
"${CLI[@]}" SET "ace13:poc:rate:USD-MXN" "17.42" EX 300 >/dev/null

# Idempotencia (clave de correlación ya procesada)
"${CLI[@]}" SET "ace13:poc:idempotency:msg-0001" "PROCESSED" EX 3600 >/dev/null

# Índice para pruebas de sorted set (prioridad de cola)
"${CLI[@]}" ZADD "ace13:poc:queue:priority" 10 "payment-001" 20 "payment-002" 5 "payment-003" >/dev/null

echo "OK  Datos cargados:"
echo "    - ace13:poc:catalog:SKU-001"
echo "    - ace13:poc:customer:1001"
echo "    - ace13:poc:rate:USD-MXN (TTL 300s)"
echo "    - ace13:poc:idempotency:msg-0001"
echo "    - ace13:poc:queue:priority"
