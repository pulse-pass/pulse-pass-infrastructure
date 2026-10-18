---
description: Shared local infrastructure, Docker and pipeline conventions
paths:
  - "docker-compose.yml"
  - "*.sh"
  - "keycloak/**"
  - ".github/**"
  - "README.md"
---

# Infrastructure and pipeline

- Polyrepo in the `pulse-pass` GitHub organization, `main` only, PRs from `feature/<ID>-<slug>`, merge commits only (squash and rebase disabled).
- This repository holds the shared local infrastructure used by every service: Keycloak, MySQL, Redis and Kafka today; Kafka UI, Mailpit and MinIO are added only when a task needs them. Services use it only in `development` mode and start their own dependencies in `test` mode (Redis and Kafka only when the service starts using them), so the default ports (3306, 6379, 9094, 8180) must not be used by services in `test` mode.
- Layout: `docker-compose.yml`, `.env.example`, `infrastructure-start.sh`, `infrastructure-stop.sh` and one folder per component (`keycloak/` with the realm import).
- Every container is named `pulse-pass-<component>` and joins the external `pulse-pass` network, which is shared with the services' own composes.
- MySQL starts empty with only root (`MYSQL_ROOT_PASSWORD`, no init scripts); each service applies its own `database.sql` (own schema and user, database per service). Kafka runs KRaft with one node and two listeners: internal `pulse-pass-kafka:9092` and external `localhost:${KAFKA_PORT:-9094}`. The external port is published on the same number in the host and in the container (`${KAFKA_PORT}:${KAFKA_PORT}`) because the listener is advertised as `localhost:${KAFKA_PORT}`.
- The start script calls `infrastructure-stop.sh` before bringing the stack up, so every start is from scratch. It creates the `pulse-pass` network if missing and copies `.env.example` on first run; `infrastructure-stop.sh` creates the network if missing (the compose declares it external) and removes containers and volumes (`down -v`). Both scripts use `set -euo pipefail` and `cd "$(dirname "${BASH_SOURCE[0]}")"`. Never remove the network, other composes may be using it.
- Published ports bind to loopback only (`127.0.0.1:${PORT:-default}:<container port>`); services reach each other through the Docker network by container name. Compose variables always carry `${VAR:-default}` defaults.
- The compose fixes the project name (`name: pulse-pass-infrastructure`), like every service compose.
- Image versions are always pinned (never `latest`). Images without `curl` use a `bash` `/dev/tcp` healthcheck that checks the HTTP status line (200), never a substring of the body.
- Keycloak runs `start-dev --import-realm` with the embedded database (the realm is imported only when the container is created); the realm `pulse-pass` is versioned in `keycloak/pulse-pass-realm.json` with development-only secrets.
- Workflows: `pull-request.yml` (name `CI`) with a single `validate` job that validates the compose and realm JSON, starts the infrastructure and checks the realm, the service account token and the realm roles, then MySQL (`SELECT 1` with the password read inside the container), Redis (`PONG`) and Kafka (create a topic and list it through the internal listener, the external listener and from another container on the network). It has `permissions: contents: read` and a timeout. Third-party actions are pinned by full commit SHA with the version in a comment (Sonar rule S7637); `actions/*` may use tags.
- No comments in the compose, scripts, `.env.example`, realm or workflows: names and structure must explain them, and decisions go to this file or the README. The only exception is the version next to a workflow action pinned by SHA.
