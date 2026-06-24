#!/usr/bin/env bash
# Configura credencial Redis en ACE (ejecutar en el servidor donde corre el integration server).
set -euo pipefail

CREDENTIAL_NAME="${1:-redis::pocRedisCredential}"
REDIS_HOST="${2:-localhost}"
REDIS_PORT="${3:-6379}"
REDIS_PASSWORD="${4:-}"

echo "==> Configurando credencial ACE: ${CREDENTIAL_NAME}"
echo "    Host: ${REDIS_HOST}:${REDIS_PORT}"

if [[ -n "${REDIS_PASSWORD}" ]]; then
  mqsisetdbparms create -n "${CREDENTIAL_NAME}" -u "${REDIS_HOST}:${REDIS_PORT}" -p "${REDIS_PASSWORD}"
else
  # PoC local sin password: usuario = host:port, password vacío o placeholder según política local
  mqsisetdbparms create -n "${CREDENTIAL_NAME}" -u "${REDIS_HOST}:${REDIS_PORT}" -p " "
fi

echo "OK  Credencial creada. Verificar con:"
echo "    mqsireportdbparms -n ${CREDENTIAL_NAME}"
