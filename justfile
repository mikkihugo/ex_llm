set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Default verification pipeline
default:
	just verify

verify:
	cd singularity_app && MIX_ENV=dev mix quality
	cd singularity_app && MIX_ENV=test mix test.ci

# Environment management
dev:
	nix develop .#dev --command bash

test:
	nix develop .#test --command bash

prod:
	nix develop .#prod --command bash

fly:
	nix develop .#fly --command bash

# Environment-specific commands
dev-server:
	nix develop .#dev --command bash -c "cd singularity_app && mix phx.server"

test-run:
	nix develop .#test --command bash -c "cd singularity_app && mix test"

prod-build:
	nix develop .#prod --command bash -c "cd singularity_app && mix release"

setup:
	cd singularity_app && MIX_ENV=dev mix deps.get
	cd singularity_app && MIX_ENV=dev mix deps.compile
	cd singularity_app && mix gleam.deps.get
	if [ -f bun.lock ] || [ -f bun.lockb ]; then \
		bun install --frozen-lockfile; \
	else \
		bun install; \
	fi

fmt:
	cd singularity_app && mix format
	cd singularity_app && gleam format

lint:
	cd singularity_app && MIX_ENV=dev mix credo --strict
	semgrep scan --config auto || true

coverage:
	cd singularity_app && MIX_ENV=test mix coveralls.html

unit:
	cd singularity_app && MIX_ENV=test mix test

watch-tests:
	cd singularity_app && watchexec -w lib -w test -w gleam "MIX_ENV=test mix test"

fly-deploy:
	flyctl deploy --strategy bluegreen

fly-status:
	flyctl status

release-micro:
	./scripts/release.sh micro

release-baseline:
	./scripts/release.sh baseline
