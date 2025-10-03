{
  description = "LiteLLM proxy development shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          name = "litellm-shell";
          buildInputs = with pkgs; [ python3 uv openssl cacert jq curl ];
          shellHook = ''
            export LITELLM_CONFIG=${LITELLM_CONFIG:-$PWD/litellm.config.yaml}
            export LITELLM_PORT=${LITELLM_PORT:-4000}

            litellm-proxy() {
              uv tool run --from-pypi litellm --config "${LITELLM_CONFIG}" "$@"
            }

            export -f litellm-proxy

            if [ -z "${LITELLM_AUTOSTARTED:-}" ]; then
              mkdir -p .litellm
              find .litellm -name 'litellm-*.log' -mtime +7 -delete || true
              LOG_FILE=".litellm/litellm-$(date +%Y%m%d-%H%M%S).log"
              echo "Starting LiteLLM proxy on port ${LITELLM_PORT} (logs: ${LOG_FILE})..."
              litellm-proxy --host 0.0.0.0 --port "${LITELLM_PORT}" >"${LOG_FILE}" 2>&1 &
              export LITELLM_AUTOSTARTED=$!
              trap 'if [ -n "${LITELLM_AUTOSTARTED}" ]; then kill ${LITELLM_AUTOSTARTED} 2>/dev/null; fi' EXIT
              echo "LiteLLM proxy PID ${LITELLM_AUTOSTARTED}"
            fi
          '';
        };
      });
}
