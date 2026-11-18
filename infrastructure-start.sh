#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

docker network inspect pulse-pass >/dev/null 2>&1 || docker network create pulse-pass >/dev/null

if [ ! -f .env ]; then
    cp .env.example .env
fi

./infrastructure-stop.sh

docker compose up -d --wait

port() {
    local value
    value=$(grep -E "^$1=" .env | cut -d= -f2 || true)
    echo "${value:-$2}"
}

echo "pulse-pass infrastructure is up"
echo "  Keycloak: localhost:$(port KEYCLOAK_PORT 8180)"
echo "  MySQL: localhost:$(port MYSQL_PORT 3306)"
echo "  Redis: localhost:$(port REDIS_PORT 6379)"
echo "  Kafka: localhost:$(port KAFKA_PORT 9094)"
