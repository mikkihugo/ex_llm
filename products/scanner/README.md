# Singularity Scanner (Product)

- Source: `packages/code_quality_engine` (bins: `singularity-scanner`, `scanner`)
- Purpose: Portable CLI to analyze repositories and emit results for CentralCloud.
- Release: Built via GitHub Actions, uploaded as release assets per OS/arch.

## Build (local)

```bash
cargo build --release -p code_quality_engine --no-default-features --features cli
# Output: target/release/singularity-scanner
```

## Run (local)

```bash
./target/release/singularity-scanner --help
```

## Release (CI)

- See `.github/workflows/release-scanner.yml` for tagged builds and multi-OS artifacts.
- Artifacts: `singularity-scanner-$OS-$ARCH` (zipped on Windows).

## Roadmap (Pro/offline)

- Encrypted redb cache is loaded by default when learned patterns are enabled.
- ETag persistence with the cache will avoid unnecessary CentralCloud downloads (planned).
