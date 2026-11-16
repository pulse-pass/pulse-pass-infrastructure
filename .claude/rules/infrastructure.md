---
description: Shared local infrastructure: Docker Compose, Keycloak realm, MySQL, Redis, Kafka and scripts
paths:
  - "docker-compose.yml"
  - ".env.example"
  - "*.sh"
  - "keycloak/**"
  - "README.md"
---

# Infrastructure

- **INF-001** This repository holds the shared local infrastructure used by every service: Keycloak, MySQL, Redis and Kafka today. Kafka UI, Mailpit and MinIO are added only when a task needs them.
- **INF-002** Services use this infrastructure only in `development` mode and start their own dependencies in `test` mode (Redis and Kafka only when the service starts using them).
- **INF-003** The default ports (3306, 6379, 9094, 8180) must not be used by services in `test` mode.
- **INF-004** Layout: `docker-compose.yml`, `.env.example`, `infrastructure-start.sh`, `infrastructure-stop.sh` and one folder per component (`keycloak/` with the realm import).
- **INF-005** Every container is named `pulse-pass-<component>` and joins the external `pulse-pass` network, shared with the services' own composes.
- **INF-006** The compose fixes the project name (`name: pulse-pass-infrastructure`), like every service compose.
- **INF-007** MySQL starts empty with only root (`MYSQL_ROOT_PASSWORD`, no init scripts). Each service applies its own `database.sql` (own schema and user, database per service).
- **INF-008** Kafka runs KRaft with one node and two listeners: internal `pulse-pass-kafka:9092` and external `localhost:${KAFKA_PORT:-9094}`.
- **INF-009** The external Kafka port is published on the same number in the host and in the container (`${KAFKA_PORT}:${KAFKA_PORT}`) because the listener is advertised as `localhost:${KAFKA_PORT}`.
- **INF-010** `infrastructure-start.sh` calls `infrastructure-stop.sh` before bringing the stack up, so every start is from scratch.
- **INF-011** The start script creates the `pulse-pass` network if missing and copies `.env.example` on first run.
- **INF-012** `infrastructure-stop.sh` creates the network if missing (the compose declares it external) and removes containers and volumes (`down -v`). Never remove the network, other composes may be using it.
- **INF-013** Both scripts use `set -euo pipefail` and `cd "$(dirname "${BASH_SOURCE[0]}")"`.
- **INF-014** Published ports bind to loopback only (`127.0.0.1:${PORT:-default}:<container port>`).
- **INF-015** Containers reach each other through the Docker network by container name.
- **INF-016** Compose variables always carry `${VAR:-default}` defaults, except secrets (client secrets, passwords, key material), which use `${VAR:?}` with no default so they are never versioned in the compose.
- **INF-017** Image versions are always pinned (never `latest`).
- **INF-018** Images without `curl` use a `bash` `/dev/tcp` healthcheck that checks the HTTP status line (200), never a substring of the body.
- **INF-019** Keycloak runs `start-dev --import-realm` with the embedded database; the realm is imported only when the container is created.
- **INF-020** The realm `pulse-pass` is versioned in `keycloak/pulse-pass-realm.json` without secrets: client secrets, user passwords and key material are `${VARIABLE}` placeholders that Keycloak resolves on import from the container environment.
- **INF-021** The compose passes each realm secret from `.env` as `${VARIABLE:?}`, so a missing value fails fast instead of versioning the secret in the compose.
- **INF-022** `.env.example` holds the development values of the realm secrets (`ONBOARDING_SERVICE_CLIENT_SECRET`, `BACKOFFICE_ADMIN_PASSWORD`, `KEYCLOAK_RSA_PRIVATE_KEY`, `KEYCLOAK_RSA_CERTIFICATE`).
- **INF-023** The realm declares a fixed RSA key pair (`rsa-pulse-pass`, RS256, priority 200, private key and certificate as base64 PEM bodies from `.env`) next to `hmac-generated` (HS512, refresh token) and `aes-generated`.
- **INF-024** The RSA key is fixed because the backoffice gateway validates JWTs with the public key in its configuration, so the signing key cannot be regenerated on each import.
- **INF-025** The matching public key lives in the gateway `.env.example`; it is development-only.
- **INF-026** The realm rotates refresh tokens: `revokeRefreshToken` true and `refreshTokenMaxReuse` 0, so each refresh token works for a single renewal.
- **INF-027** Rotation is on so a leaked or forgotten refresh token cannot open a new session; the backoffice serializes refreshes across tabs with Web Locks, so legitimate clients never reuse a token.
- **INF-028** Reusing an already used refresh token returns 400 `invalid_grant` and Keycloak also terminates the session (the newer refresh token is refused too, with `Session doesn't have required client`).
- **INF-043** Access tokens last 2 minutes (`accessTokenLifespan` 120): removing an organization disables its collaborators' users and ends their sessions, and the short lifespan bounds the access left by a token issued before the removal.
- **INF-029** The realm seeds a development admin (username = CPF `52998224725`, password from `BACKOFFICE_ADMIN_PASSWORD`, role `admin`, fixed `person_key`, no `legal_person_key`).
- **INF-030** `legal_person_key` is a user attribute mapped to a claim in `onboarding-service`, like `person_key`.
- **INF-031** No comments in the compose, scripts, `.env.example` or realm: names and structure must explain them, and decisions go to the rules or the README.
