---
description: Repository, branch and CI workflow conventions
paths:
  - ".github/**"
---

# Pipeline

- **INF-032** Polyrepo in the `pulse-pass` GitHub organization, `main` only.
- **INF-033** The workflow is `pull-request.yml` (name `CI`) with a single `validate` job, with `permissions: contents: read` and a timeout.
- **INF-034** The `validate` job validates the compose and realm JSON, starts the infrastructure and checks the realm, the service account token and the realm roles.
- **INF-035** The `validate` job checks refresh token rotation: the old token is refused with `invalid_grant` and the session is terminated after the reuse.
- **INF-036** The `validate` job checks MySQL (`SELECT 1` with the password read inside the container), Redis (`PONG`) and Kafka (create a topic and list it through the internal listener, the external listener and from another container on the network).
- **INF-037** Third-party actions are pinned by full commit SHA (Sonar rule S7637) with the version in a comment; `actions/*` may use tags. That version is the only comment allowed in workflows.
- **INF-038** The CI copies `.env.example` to `.env` and loads it into `$GITHUB_ENV` once (`Load environment` step).
- **INF-039** Every step reads secrets as environment variables (`$ONBOARDING_SERVICE_CLIENT_SECRET`, `$BACKOFFICE_ADMIN_PASSWORD`), never a literal and never a `grep` of `.env` per step.
- **INF-040** A password is read by `curl` itself from the environment (`--variable %BACKOFFICE_ADMIN_PASSWORD --expand-data-urlencode 'password={{BACKOFFICE_ADMIN_PASSWORD}}'`, curl 8.3+), never expanded by the shell inside the form field (Sonar S2068 flags it as a hard-coded credential).
- **INF-041** No comments in workflows: names and structure must explain them, and decisions go to the rules or the README.
- **INF-042** PRs come from `feature/<ID>-<slug>`; merge commits only (squash and rebase disabled).
- **INF-044** No SonarQube Cloud project and no static analysis job: the repository has no application code, and `validate` is the required check of the `main` ruleset, like the pipeline check of the other repositories.
