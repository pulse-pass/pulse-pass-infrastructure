#!/usr/bin/env bash
# Usage: ./infrastructure-stop.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

# The compose file declares the network as external, so it must exist even to tear down.
docker network inspect pulse-pass >/dev/null 2>&1 || docker network create pulse-pass >/dev/null

docker compose down -v --remove-orphans
