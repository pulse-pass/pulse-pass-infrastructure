#!/usr/bin/env bash
# Usage: ./infrastructure-start.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

docker network inspect pulse-pass >/dev/null 2>&1 || docker network create pulse-pass >/dev/null

if [ ! -f .env ]; then
    cp .env.example .env
fi

docker compose up -d --wait

keycloak_port=$(grep -E '^KEYCLOAK_PORT=' .env | cut -d= -f2 || true)
echo "pulse-pass infrastructure is up (Keycloak at http://localhost:${keycloak_port:-8180})"
