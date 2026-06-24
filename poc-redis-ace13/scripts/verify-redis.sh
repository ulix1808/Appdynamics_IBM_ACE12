#!/usr/bin/env bash
# Verifica que Redis esté accesible y responda a operaciones básicas.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${POC_DIR}/infra/.env" ]]; then
  # shellcheck disable=SC1091
  source "${POC_DIR}/infra/.env"
fi

REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"

echo "==> Verificando Redis en ${REDIS_HOST}:${REDIS_PORT}"

if command -v redis-cli >/dev/null 2>&1; then
  CLI=(redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}")
else
  if ! docker ps --format '{{.Names}}' | grep -q '^ace13-poc-redis$'; then
    echo "ERROR: Redis no responde y el contenedor ace13-poc-redis no está en ejecución."
    echo "Ejecuta: cd poc-redis-ace13/infra && docker compose up -d"
    exit 1
  fi
  CLI=(docker exec ace13-poc-redis redis-cli)
fi

"${CLI[@]}" ping | grep -q PONG
echo "OK  PING -> PONG"

KEY="ace13:poc:healthcheck"
"${CLI[@]}" SET "${KEY}" "ok" EX 60 >/dev/null
VALUE="$("${CLI[@]}" GET "${KEY}")"
[[ "${VALUE}" == "ok" ]] || { echo "ERROR: GET no devolvió valor esperado"; exit 1; }
echo "OK  SET/GET string"

"${CLI[@]}" HSET "ace13:poc:customer:1001" id 1001 name "Cliente PoC" tier "gold" >/dev/null
HASH_NAME="$("${CLI[@]}" HGET "ace13:poc:customer:1001" name)"
[[ "${HASH_NAME}" == "Cliente PoC" ]] || { echo "ERROR: HGET no devolvió valor esperado"; exit 1; }
echo "OK  HSET/HGET hash"

echo ""
echo "Redis listo para la PoC ACE 13."
