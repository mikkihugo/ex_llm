# Singularity Runtime

Singularity is an Elixir 1.20 + Gleam runtime for building self-improving agents designed to run on Fly.io first and migrate to Kubernetes later. It includes clustering, hot-reload scaffolding, and deployment assets for both environments.

## Stack Overview

- **Elixir 1.20-dev / Erlang OTP 28** – Custom toolchain with Gleam-friendly build and OTP supervision.
- **Gleam 1.5** – Still available for future hybrid strategies, though the default
  self-improvement loop now generates Elixir modules directly and hot-loads them
  in-process.
- **Bandit + Plug** – Lightweight HTTP API for health, metrics, and control.
- **libcluster** – DNS-based clustering for Fly.io and Kubernetes.
- **Persistent code store** – Writes artifacts to `/data/code` (volume in Fly, PVC in Kubernetes).
- **Quality toolchain** – Credo, Dialyzer, ExCoveralls, Semgrep, ESLint, TypeScript tooling for CI-ready checks.

## Prerequisites

### Nix + direnv (recommended)

The repository ships with a `flake.nix` dev shell. Install [direnv](https://direnv.net/), then allow the environment the first time you enter the directory:

```bash
direnv allow
```

This pulls in Elixir 1.20-dev on OTP 28 (custom build with Gleam support), Gleam, Flyctl, Node.js 20, PostgreSQL 17, Redis, Hex/Rebar, Semgrep, ESLint, and other helper CLI tools.

Additional shells:

```
nix develop            # full developer workstation (same as direnv)
nix develop .#fly      # minimal Fly.io deployment shell
```

### Manual tooling

1. Install Elixir ≥ 1.20 and Erlang OTP ≥ 28.
2. Install [Gleam](https://gleam.run/) and verify it is available on your `$PATH`:
   ```bash
   gleam --version
   ```
3. Authenticate with Fly.io (`fly auth login`) and create required volumes/buckets.

## Project Layout

```
lib/                    # Elixir application, supervision tree, HTTP layer
lib/singularity/hot_reload/  # Queue + pipeline stub for improvements
lib/singularity_web/     # Plug router exposing health + metrics
lib/singularity/dynamic_compiler.ex  # Validates & loads auto-generated Elixir modules
code/                   # Created at runtime for staged/active code
gleam/                  # Gleam modules compiled via the bundled Mix task
rel/                    # Release environment hooks
Dockerfile, fly.toml    # Fly.io deployment assets
deployment/k8s/         # StatefulSet + services for Kubernetes
```

## Local Development

```bash
cd singularity_app
mix deps.get
mix gleam.deps.get
mix test
PORT=4000 iex -S mix
```

With Nix/direnv you can lean on the bundled [Just](https://just.systems/) commands:

```bash
just setup       # Install Elixir + Gleam deps
just verify      # Format, Credo, Dialyzer, Sobelow, dependency audit, Elixir+Gleam tests
just coverage    # Generate HTML coverage via ExCoveralls
just fly-deploy  # Deploy to Fly.io (blue/green)

# Stage code snippets directly from the CLI (optional promotion with --promote)
mix code.load --agent cli-agent --code lib/new_feature.ex --version v1 --promote
```

Coverage reports are written to `_build/test/cover`, and Dialyzer PLTs live in `priv/plts/` (already gitignored).

### Additional quality checks

```
cd singularity_app && mix sobelow --exit-on-warning  # Web security scan
cd singularity_app && mix deps.audit                 # Hex package vulnerability scan
cd singularity_app && mix quality                    # Runs format, Credo, Dialyzer, Sobelow, deps.audit
```

### Editor / LSP support

The Nix dev shell now ships the language servers most editors expect:

- `elixir-ls` for Elixir (already included previously)
- `erlang_ls` for Erlang modules
- `gleam lsp` via the `gleam` tool
- `typescript-language-server` for TypeScript/Litellm utilities
- `rust-analyzer` and the Rust CLI suite (cargo-* tooling)

Launch `nix develop` (or allow direnv) before starting your editor so it picks up the binaries on `$PATH`. These LSPs are for developer use only; agents do **not** call them directly—instead they query the structured data stored via `Singularity.Analysis` / `Singularity.Quality`.

Health and metrics endpoints:
- `GET http://localhost:4000/health`
- `GET http://localhost:4000/health/deep`
- `GET http://localhost:4000/metrics`

Autonomous coordination:
- Every agent owns a background loop that calls
  `Singularity.Autonomy.Decider.decide/1` each tick (default 5 s). When the
  observed score drops or stagnation exceeds the configured threshold, the
  agent asks the planner to synthesise a new Elixir module and hands it to the
  hot-reload manager.
- `Singularity.record_outcome/2` and `Singularity.update_agent_metrics/2` let other
  processes feed observations (success/failure counts, latency, rewards) back
  into the loop.
- `Singularity.force_improvement/2` flips a flag that forces the next evaluation
  cycle to enqueue a new strategy—handy for manual experiments while keeping the
  same pipeline.
- `Singularity.Control.publish_improvement/2` still broadcasts a payload across
  the cluster when you need to coordinate multiple nodes manually. It falls back
  to a direct cast if no listeners have joined yet.

`Singularity.DynamicCompiler` already compiles and loads the generated Elixir
modules with `Code.compile_string/2`, so successful promotions replace runtime
behaviour immediately while keeping the artifact on disk for auditing.

### Git coordinator runtime

The git coordinator is optional and disabled by default. Enable it with
environment variables:

```
export GIT_COORDINATOR_ENABLED=true
export GIT_COORDINATOR_REPO_PATH=/absolute/path/to/shared/repo
export GIT_COORDINATOR_BASE_BRANCH=main
export GIT_COORDINATOR_REMOTE=origin   # optional; omit to skip pushes/PRs
```

- The coordinator runs under `Singularity.Git.Supervisor` and exposes a
  high-level façade via `Singularity.Git.Coordinator`.
- When enabled, each LLM-backed task receives an isolated working tree under
  `GIT_COORDINATOR_REPO_PATH`, branches are pushed to the configured remote,
  and merges are attempted automatically in dependency order.
- Assignment metadata, pending merges, and merge history are persisted in
  PostgreSQL via `git_agent_sessions`, `git_pending_merges`, and
  `git_merge_history`, so coordination survives restarts and can be queried by
  other services.
- For PR automation, ensure the [GitHub CLI](https://cli.github.com/) is
  installed and authenticated (`gh auth login`). If you skip
  `GIT_COORDINATOR_REMOTE`, pushes and PR creation are also skipped so you can
  run entirely local experiments.

## Fly.io Deployment

```bash
fly launch --copy-config --no-deploy
fly volumes create agent_code --region sea --size 5 --count 2
fly secrets set RELEASE_COOKIE=$(openssl rand -base64 32)
nix build ..#singularity-oci
podman load < ../result
podman tag singularity:latest registry.fly.io/singularity:$(git rev-parse --short HEAD)
podman push registry.fly.io/singularity:$(git rev-parse --short HEAD)
fly deploy --strategy bluegreen --image registry.fly.io/singularity:$(git rev-parse --short HEAD)
```

- `fly.toml` sets IPv6 clustering (`DNS_CLUSTER_QUERY`) and keeps two machines alive for hot upgrades.
- `/data/code` must be backed by a volume; blue/green deploys require temporarily scaling up if you mutate volumes in-place.
- Use `fly ssh console` to connect and inspect BEAM nodes with `:observer_cli`.
- While connected over `fly ssh console`, you can interact with the autonomous
  loop directly:
  ```elixir
  # Record observed outcomes
  Singularity.record_outcome("agent-123", :success)
  Singularity.record_outcome("agent-123", :failure)

  # Merge richer metrics (latency, reward)
  Singularity.update_agent_metrics("agent-123", %{latency_ms: 180, reward: 0.42})

  # Force a new strategy on the next evaluation cycle
  Singularity.force_improvement("agent-123", "manual test")
  ```
  Agents that drop below the configured score threshold or stagnate for 30+ tick
  cycles will self-synthesise a new Elixir module and push it through the same
  hot-reload queue—no HTTP ingress or external orchestration required.

## Kubernetes Migration Notes

Deployment manifests live in `deployment/k8s/`:
- `statefulset.yaml` mounts a per-pod PVC at `/data/code` and exposes HTTP + distribution ports.
- `service.yaml` publishes HTTP traffic and a headless service for node discovery.
- Set `DNS_CLUSTER_QUERY=seed-agent-headless.default.svc.cluster.local` for libcluster DNS polling.
- Provide a secret named `seed-agent-cookie` with a `cookie` key for the BEAM distribution cookie.

Suggested steps when migrating:
1. Build and push the same release image used on Fly (`docker build`, `docker push`).
2. Create Kubernetes secrets/configmaps for `RELEASE_COOKIE`, telemetry exporters, and cluster settings.
3. Roll out the StatefulSet and verify BEAM nodes appear via `kubectl exec` + `:net_adm.ping/1`.
4. Redirect traffic by swapping DNS or load balancer targets.

## Observability

- `/metrics` provides basic Prometheus gauges (queue depth, cluster size).
- `Singularity.Telemetry.metrics/0` enumerates metrics for exporters (PromEx, TelemetryMetricsPrometheus, etc.).
- Hot reload operations emit `[:singularity, :hot_reload, :start|:success|:error|:duration]` telemetry events.

## Release Workflow

This project keeps the semantic version number in `VERSION`, which `mix.exs` reads at compile time.

- **Micro releases** (`just release-micro`): bump the patch number, run `just verify` (format, Credo, Dialyzer, Elixir tests), and prepare an annotated tag `vX.Y.Z`. Use these for rapid Fly hot reloads.
- **Baseline releases** (`just release-baseline`): bump the minor number, run the same verification plus `just coverage` to enforce the 85% ExCoveralls gate, commit `VERSION` and the generated `RELEASE_SUMMARY.md`, and tag `baseline-vX.Y.0`. Baselines are the stable snapshots for Fly deployments and rollbacks.
- The scripts assume a clean git worktree and leave you with a commit and tag ready to push (`git push origin HEAD --tags`).
- Agents can automate release prep, but keep merges gated on the verification pipeline so humans can review larger promotion jumps.

If you need to perform a manual bump, call `./scripts/bump_version.sh [micro|baseline|major]` and edit `RELEASE_SUMMARY.md` before committing.

## Claude & GitHub Integration

1. **Claude credentials**
   - Install the Claude Code native binary with `./scripts/install_claude_native.sh` (stable by default). The script backs up any existing `claude` binary and restores it automatically if the install fails.
   - Run `claude setup-token` once interactively (or `claude setup-token --headless --output json`) to obtain the OAuth token; copy the printed `CLAUDE_CODE_OAUTH_TOKEN` into `.envrc` and keep the generated `~/.claude` directory.
   - Optional overrides: `CLAUDE_DEFAULT_MODEL` (defaults to `sonnet`), `CLAUDE_MAX_TOKENS`, `CLAUDE_API_URL`, `CLAUDE_CLI_PATH`, and `CLAUDE_HOME` if you store the `.claude` directory elsewhere (e.g. on a Fly volume).
   - Use `scripts/sync_secrets.sh` to push `CLAUDE_CODE_OAUTH_TOKEN`/`GITHUB_TOKEN` to both Fly secrets and the GitHub repository. The script keeps `HTTP_SERVER_ENABLED=true` on Fly so the router stays running.

2. **GitHub access**
   - Authenticate the GitHub CLI once with `gh auth login` (the nix shell bundles `gh`).
   - Export a PAT with repo + workflow scopes as `GITHUB_TOKEN`; run `scripts/sync_secrets.sh` to propagate it to Fly and GitHub so CI and Fly machines share the same credentials.
   - The release scripts produce git tags; push with `git push origin HEAD --tags` so GitHub Actions can build, test, and deploy.

3. **Secrets in Fly**
   - Recommended set: `fly secrets set CLAUDE_CODE_OAUTH_TOKEN=... GITHUB_TOKEN=... HTTP_SERVER_ENABLED=true`.
   - Store the `.claude` directory on a Fly volume (e.g. `/data/claude`) and set `CLAUDE_HOME=/data/claude` via `fly.toml` env if you prefer persistence beyond the token.

4. **Agent behaviour**
   - `Singularity.Integration.Claude.chat/2` shells out to the CLI with the OAuth token. Provide either a prompt string or a Claude Code messages payload.
   - If no token is available the helper returns `{:error, :missing_api_key}` so the autonomous agent can escalate.


## Using Vercel AI with Native CLIs

The repository includes custom language models under `tools/providers/cli.ts` so you can reuse the existing Claude Code and Codex CLIs through the [Vercel AI SDK](https://sdk.vercel.ai/). Example:

```ts
import { generateText } from "ai";
import { claudeCliLanguageModel } from "../tools/providers/cli";

const result = await generateText({
  model: claudeCliLanguageModel,
  prompt: "Summarise the latest release notes",
});

console.log(result.text);
```

The Claude model shells out to `claude --print --output-format json` and expects
`CLAUDE_CODE_OAUTH_TOKEN` (or a mounted `.claude` directory). The Codex model
uses `codex exec --experimental-json --skip-git-repo-check` and relies on the
existing Codex CLI login. Both return plain text completions that work with
`generateText`, `streamText`, or higher-level chat helpers.

Run `bun install --frozen-lockfile` (already part of `just setup`) to make the
`ai` package available when exercising these models.
Set `CODEX_SANDBOX` if you want to override the default Codex CLI sandbox (defaults to read-only).

- Bundle existing CLI tokens (for Fly/CI):
  ```bash
  ./scripts/bundle_cli_state.sh                 # produces bundles/cli-state.tar.gz
  tar xzf bundles/cli-state.tar.gz -C /         # restore on a machine (adjust path)
  ```
  This captures both `~/.claude` and `~/.codex` if they exist. Mount them on Fly and set `CLAUDE_HOME` / `CODEX_HOME` so the CLIs stay logged in.

## Extending Hot Reload

1. Expand `Singularity.DynamicCompiler` to support richer guardrails (sandboxed
   evaluation, resource quotas) before modules are made live.
2. Persist comparison metrics across improvements and feed them into a
   longer-term optimiser (e.g. bandit-based strategy selection).
3. Add CRDT or PostgreSQL-backed metadata to coordinate agent state across clusters.
4. Introduce request authentication and agent control endpoints before exposing externally.

## Pending Improvements

- Implement real compilation/loading of generated modules.
- Persist compiled bytecode artifacts per version for auditing.
- Add self-healing tasks for Fly volume constraints (e.g. optional remote object storage sync).
- Harden `/metrics` with authentication/ingress policies.
