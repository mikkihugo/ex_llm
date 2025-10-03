# LiteLLM Shell

Standalone Nix flake providing a dev shell for running LiteLLM locally.

## Usage

```bash
cd litellm
nix develop
# inside the shell
litellm-proxy --port 4000
```

Environment variables:
- `GITHUB_TOKEN` – PAT with `repo` + `read:packages`
- `COPILOT_TOKEN` – GitHub Copilot PAT
- `LITELLM_CONFIG` – path to config file (defaults to `./litellm.config.yaml`)
- `LITELLM_PORT` – proxy port (defaults to `4000`)

Copy `litellm.config.example.yaml` to `litellm.config.yaml` and fill in your tokens before launching.
