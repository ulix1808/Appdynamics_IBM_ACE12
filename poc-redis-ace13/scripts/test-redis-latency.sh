#!/usr/bin/env bash
# Mide latencia básica de Redis (útil para comparar con llamadas a backend).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${POC_DIR}/infra/.env" ]]; then
  # shellcheck disable=SC1091
  source "${POC_DIR}/infra/.env"
fi

REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
ITERATIONS="${1:-1000}"

if command -v redis-cli >/dev/null 2>&1; then
  CLI=(redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}")
else
  CLI=(docker exec ace13-poc-redis redis-cli)
fi

echo "==> Latencia Redis (${ITERATIONS} operaciones SET/GET)"
"${CLI[@]}" --latency-history -i 1 2>/dev/null || {
  echo "redis-cli --latency-history no disponible; usando benchmark simple..."
  START=$(date +%s%N)
  for ((i=1; i<=ITERATIONS; i++)); do
    "${CLI[@]}" SET "ace13:poc:bench:${i}" "${i}" EX 60 >/dev/null
    "${CLI[@]}" GET "ace13:poc:bench:${i}" >/dev/null
  done
  END=$(date +%s%N)
  ELAPSED_MS=$(( (END - START) / 1000000 ))
  AVG_US=$(( ELAPSED_MS * 1000 / (ITERATIONS * 2) ))
  echo "Tiempo total: ${ELAPSED_MS} ms"
  echo "Promedio aprox.: ${AVG_US} µs por operación"
}
