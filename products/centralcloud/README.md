# CentralCloud (Product)

CentralCloud is the hosted backend that powers learning, policy enforcement, and canonical IDs for the Singularity ecosystem.

- Source code: `central_cloud/`
- Responsibilities:
  - Issue canonical `server_run_id` (Postgres `pg_uuidv7`) for scanner runs
  - Enforce policies: `telemetry_enabled`, `learning_enabled`, enterprise flags
  - Synchronize and serve encrypted pattern snapshots (ETag/SHA-based freshness)
  - Queue internal processing via Postgres `pgmq` (server-side only)
  - Post PR statuses/Checks for the GitHub App

## External API (HTTPS)

- POST `/scanner/runs`
  - Request: `{ "local_run_id": string, "repo": {"owner": string, "name": string}, "commit": string, "etag": string | null }`
  - Response: `{ "server_run_id": string, "patterns_etag": string, "policies": { "telemetry_enabled": bool, "learning_enabled": bool } }`
  - Behavior: If `etag` unchanged, skip full pattern payload; else return new ETag.

- POST `/scanner/events`
  - Request: `{ "server_run_id": string, "results": { ... }, "metrics": { ... } }`
  - Response: `{ "status": "ok" }`

- GET `/patterns/snapshot`
  - Headers: `If-None-Match: <etag>`
  - Response: `200` with encrypted payload and `ETag`, or `304 Not Modified`.

Notes:
- Clients never connect to Postgres or `pgmq` directly.
- All IDs persisted by CentralCloud are UUIDv7 from Postgres.

## Internal Processing (Server-only)

- `pgmq` queues:
  - `centralcloud_learning` (ingest anonymized insights)
  - `centralcloud_checks` (PR checks generation)
  - `centralcloud_patterns_sync` (snapshot build & publish)
- Workers consume queues, update Postgres, emit events.

## Security & Keys

- App private key for GitHub App lives in server secrets
- API authentication via token (per org) or GitHub App installation context
- Pattern snapshots stored encrypted at rest (AEAD) with server-managed keys

## Release Process

- Docker image build & push (CI): `centralcloud:<version>`
- Database migrations (Postgres 17): run via CI step against target env
- Blue/green or rolling deploy; verify health and ETag endpoints

Example CI outline:

```yaml
name: Release CentralCloud
on:
  push:
    tags: ["centralcloud-v*.*.*", "centralcloud-v*.*.*-beta*"]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: docker build -t ghcr.io/ORG/centralcloud:${{ github.ref_name }} central_cloud
      - name: Push image
        run: echo "$GHCR_TOKEN" | docker login ghcr.io -u ORG --password-stdin && docker push ghcr.io/ORG/centralcloud:${{ github.ref_name }}
  migrate-and-deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Run migrations
        run: ./scripts/migrate-centralcloud.sh ${{ github.ref_name }}
      - name: Deploy
        run: ./scripts/deploy-centralcloud.sh ${{ github.ref_name }}
```

## Observability

- Metrics: request rate/latency, ETag hit ratio, queue depth, checks publish latency
- Logs keyed by `server_run_id`
- Audit events for policy decisions
