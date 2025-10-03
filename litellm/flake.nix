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

            echo "LiteLLM shell ready. Start proxy with: litellm-proxy --port ${LITELLM_PORT}"
          '';
        };
      });
}
