#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

docker network inspect pulse-pass >/dev/null 2>&1 || docker network create pulse-pass >/dev/null

docker compose down -v --remove-orphans
