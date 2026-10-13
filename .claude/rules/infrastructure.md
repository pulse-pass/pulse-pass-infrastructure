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
- This repository holds the shared local infrastructure used by every service: Keycloak today; Redis, Kafka, Kafka UI, Mailpit and MinIO are added only when a task needs them.
- Layout: `docker-compose.yml`, `.env.example`, `infrastructure-start.sh`, `infrastructure-stop.sh` and one folder per component (`keycloak/` with the realm import).
- Every container is named `pulse-pass-<component>` and joins the external `pulse-pass` network, which is shared with the services' own composes.
- The start script creates the `pulse-pass` network if missing and copies `.env.example` on first run; `infrastructure-stop.sh` creates the network if missing (the compose declares it external) and removes containers and volumes (`down -v`). Both scripts use `set -euo pipefail` and `cd "$(dirname "${BASH_SOURCE[0]}")"`. Never remove the network, other composes may be using it.
- Published ports bind to loopback only (`127.0.0.1:${PORT:-default}:<container port>`); services reach each other through the Docker network by container name. Compose variables always carry `${VAR:-default}` defaults.
- The compose fixes the project name (`name: pulse-pass-infrastructure`), like every service compose.
- Image versions are always pinned (never `latest`). Images without `curl` use a `bash` `/dev/tcp` healthcheck that checks the HTTP status line (200), never a substring of the body.
- Keycloak runs `start-dev --import-realm` with the embedded database (the realm is imported only when the container is created); the realm `pulse-pass` is versioned in `keycloak/pulse-pass-realm.json` with development-only secrets.
- Workflows: `pull-request.yml` (name `CI`) with a single `validate` job that validates the compose and realm JSON, starts the infrastructure and checks the realm, the service account token and the realm roles. It has `permissions: contents: read` and a timeout. Third-party actions are pinned by full commit SHA with the version in a comment (Sonar rule S7637); `actions/*` may use tags.
