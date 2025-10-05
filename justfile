set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Smart dependency management recipes
smart-deps:
	@echo "🧠 Checking and installing dependencies..."
	nix develop .#dev --command bash -c "cd singularity_app && mix deps.get"
	nix develop .#dev --command bash -c "cd singularity_app && gleam deps download"
	@if [ -f "ai-server/package.json" ]; then \
		echo "🧠 Installing AI server dependencies..."; \
		cd ai-server && nix develop ..#dev --command bun install; \
	fi

smart-fmt:
	@echo "🧠 Formatting code..."
	nix develop .#dev --command bash -c "cd singularity_app && mix format && gleam format"

smart-lint:
	@echo "🧠 Running linters..."
	nix develop .#dev --command bash -c "cd singularity_app && mix credo --strict || true"

smart-setup: smart-deps smart-fmt
	@echo "🧠 Smart setup complete!"

smart-watch:
	@echo "🧠 Starting file watcher..."
	nix develop .#dev --command watchexec -w singularity_app/lib -w singularity_app/test -w singularity_app/src "cd singularity_app && mix test"

smart-full: smart-deps smart-fmt smart-lint
	@echo "🧠 Full development cycle..."
	nix develop .#dev --command bash -c "cd singularity_app && mix compile && MIX_ENV=test mix test"

# Individual component commands
gleam-build:
	nix develop .#dev --command bash -c "cd singularity_app && gleam build"

gleam-check:
	nix develop .#dev --command bash -c "cd singularity_app && gleam check"

gleam-test:
	nix develop .#dev --command bash -c "cd singularity_app && gleam test"

deps-get:
	nix develop .#dev --command bash -c "cd singularity_app && mix deps.get"

deps-compile:
	nix develop .#dev --command bash -c "cd singularity_app && mix deps.compile"

credo:
	nix develop .#dev --command bash -c "cd singularity_app && mix credo --strict || true"

format:
	nix develop .#dev --command bash -c "cd singularity_app && mix format && gleam format"

ai-server-deps:
	cd ai-server && nix develop ..#dev --command bun install

ai-server-test:
	cd ai-server && nix develop ..#dev --command bash -c "bun test 2>/dev/null | grep -E '(pass|skip|fail|Ran)' | tail -4"

rust-build:
	cd rust && nix develop ..#dev --command cargo build --release

# Standard commands (now smart!)
compile: smart-deps smart-fmt
	@echo "🧠 Compiling..."
	nix develop .#dev --command bash -c "cd singularity_app && mix deps.get && gleam deps download && mix compile"

dev: smart-setup
	@echo "🧠 Starting development environment..."
	nix develop .#dev --command bash -c "cd singularity_app && mix phx.server"

test: smart-deps
	@echo "🧠 Running tests..."
	nix develop .#dev --command bash -c "cd singularity_app && MIX_ENV=test mix test"

setup: smart-deps
	@echo "🧠 Setup complete!"

deps: smart-deps
	@echo "🧠 Dependencies ready!"

fmt: smart-fmt
	@echo "🧠 Code formatted!"

lint: smart-lint
	@echo "🧠 Linting complete!"

clean:
	@echo "🧠 Cleaning build artifacts..."
	nix develop .#dev --command bash -c "cd singularity_app && mix clean"
	nix develop .#dev --command bash -c "cd singularity_app && rm -rf _build .gleam"
	@if [ -d "node_modules" ]; then \
		echo "🧠 Cleaning node_modules..."; \
		rm -rf node_modules; \
	fi

watch: smart-watch
	@echo "🧠 Watching files..."

full: smart-full
	@echo "🧠 Full development cycle complete!"

# Quick commands (skip checks for speed)
quick-compile:
	nix develop .#dev --command bash -c "cd singularity_app && mix compile"

quick-test:
	nix develop .#dev --command bash -c "cd singularity_app && MIX_ENV=test mix test"

quick-fmt:
	nix develop .#dev --command bash -c "cd singularity_app && mix format && gleam format"

# Default verification pipeline
default:
	just verify

verify:
	cd singularity_app && MIX_ENV=dev mix quality
	cd singularity_app && MIX_ENV=test mix test.ci

# Environment management
dev-shell:
	nix develop .#dev --command bash

test-shell:
	nix develop .#test --command bash

prod-shell:
	nix develop .#prod --command bash

fly-shell:
	nix develop .#fly --command bash

# Environment-specific commands
dev-server:
	nix develop .#dev --command bash -c "cd singularity_app && mix phx.server"

test-run:
	nix develop .#test --command bash -c "cd singularity_app && mix test"

prod-build:
	nix develop .#prod --command bash -c "cd singularity_app && mix release"

# Legacy setup (kept for compatibility)
setup-legacy:
	cd singularity_app && MIX_ENV=dev mix deps.get
	cd singularity_app && MIX_ENV=dev mix deps.compile
	cd singularity_app && mix gleam.deps.get
	if [ -f bun.lock ] || [ -f bun.lockb ]; then \
		bun install --frozen-lockfile; \
	else \
		bun install; \
	fi

# Legacy commands (kept for compatibility)
fmt-legacy:
	cd singularity_app && mix format
	cd singularity_app && gleam format

lint-legacy:
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
