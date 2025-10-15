# Copilot Setup Testing

This directory contains tools for testing and validating the GitHub Copilot setup workflow without requiring Nix installation.

## Overview

The `test-copilot-setup.sh` script validates that the `.github/workflows/copilot-setup-steps.yml` workflow is properly configured to run on GitHub Actions without Nix dependencies.

## Files

- **test-copilot-setup.sh**: Main test script that validates the workflow configuration
- **.github/workflows/copilot-setup-steps.yml**: The GitHub Actions workflow file being tested

## What Gets Tested

The test script validates:

1. **YAML Syntax**: Ensures the workflow file is valid YAML with no syntax errors
2. **Tool Availability**: Documents what tools the workflow will install (Elixir, Erlang, Bun)
3. **PostgreSQL Service**: Checks database configuration in the workflow
4. **Project Structure**: Verifies required directories and files exist
5. **Workflow Completeness**: Ensures all necessary setup steps are present
6. **Nix Independence**: Confirms the workflow doesn't require Nix installation

## Usage

### Run the Test

```bash
./scripts/test-copilot-setup.sh
```

### Expected Output

The script will output a detailed report showing:
- ✓ Successful checks (green)
- ⚠ Warnings (yellow)
- ✗ Errors (red)
- ℹ Information messages

### Exit Codes

- `0`: All checks passed or only warnings present
- `1`: Critical errors found (workflow has structural issues)

## Understanding the Results

### Missing Tools (Expected)

The script may report that Elixir, Erlang, Bun, or Mix are not found. **This is normal!** The workflow is designed to install these tools, so they don't need to be present when running the test locally.

### Warnings vs Errors

- **Warnings**: Optional features or missing tools that the workflow will install
- **Errors**: Structural problems with the workflow file itself (YAML syntax, missing steps, etc.)

## Workflow Design Principles

The `copilot-setup-steps.yml` workflow follows these principles:

1. **No Nix Dependency**: Works without Nix installation on GitHub Actions
2. **Standard Actions**: Uses official GitHub Actions for tool installation
3. **Caching**: Implements dependency and build caching for speed
4. **Service Containers**: Uses PostgreSQL service container for database
5. **Complete Setup**: Installs Elixir, Erlang, Bun, and all dependencies

## What the Workflow Does

1. **Sets up Elixir/Erlang**: Using `erlef/setup-beam@v1`
2. **Installs Bun**: Using `oven-sh/setup-bun@v2`
3. **Starts PostgreSQL**: Via service container (postgres:16)
4. **Checks out code**: Using `actions/checkout@v4`
5. **Caches dependencies**: For faster subsequent runs
6. **Installs deps**: Runs `mix deps.get` and `bun install`
7. **Compiles code**: Runs `mix compile`
8. **Verifies setup**: Checks all tools are working

## Comparison with Nix Setup

### Local Development (with Nix)

For local development, the project uses Nix + direnv:
- Defined in `flake.nix` and `.envrc`
- Provides reproducible environment
- Automatically starts PostgreSQL and NATS
- See `.github/copilot-instructions.md` for setup

### GitHub Actions (without Nix)

For GitHub Actions and Copilot:
- Uses standard GitHub Actions
- No Nix installation required
- Faster startup (uses pre-built images)
- Defined in `.github/workflows/copilot-setup-steps.yml`

## Troubleshooting

### Test Script Fails

If the test script reports errors:

1. Check YAML syntax in the workflow file
2. Ensure all required workflow steps are present
3. Verify the workflow file path is correct

### Workflow Fails on GitHub Actions

If the workflow fails when run on GitHub Actions:

1. Check the GitHub Actions logs
2. Verify the Elixir/OTP versions are compatible
3. Ensure mix.lock is committed to the repository
4. Check that PostgreSQL service is accessible

## Future Improvements

Potential enhancements to consider:

- [ ] Add actual test execution (not just setup validation)
- [ ] Test Rust compilation if needed
- [ ] Add performance benchmarking
- [ ] Test with different Elixir/OTP versions
- [ ] Add security scanning

## Contributing

When modifying the workflow:

1. Update the workflow file
2. Run `./scripts/test-copilot-setup.sh` to validate
3. Commit both files together
4. Document any new setup steps in this README

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [erlef/setup-beam Action](https://github.com/erlef/setup-beam)
- [oven-sh/setup-bun Action](https://github.com/oven-sh/setup-bun)
- [Project Copilot Instructions](../.github/copilot-instructions.md)
