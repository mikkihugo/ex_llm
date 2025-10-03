set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Default verification pipeline
default:
	just verify

verify:
	MIX_ENV=dev mix quality
	MIX_ENV=test mix test.ci

setup:
	cd seed_agent && MIX_ENV=dev mix deps.get
	cd seed_agent && MIX_ENV=dev mix deps.compile
	cd seed_agent && mix gleam.deps.get
	if [ -f bun.lock ] || [ -f bun.lockb ]; then \
		bun install --frozen-lockfile; \
	else \
		bun install; \
	fi

fmt:
	mix format
	gleam format

lint:
	MIX_ENV=dev mix credo --strict
	semgrep scan --config auto || true

coverage:
	MIX_ENV=test mix coveralls.html

unit:
	MIX_ENV=test mix test

watch-tests:
	watchexec -w lib -w test -w gleam "MIX_ENV=test mix test"

fly-deploy:
	flyctl deploy --strategy bluegreen

fly-status:
	flyctl status

release-micro:
	./scripts/release.sh micro

release-baseline:
	./scripts/release.sh baseline
