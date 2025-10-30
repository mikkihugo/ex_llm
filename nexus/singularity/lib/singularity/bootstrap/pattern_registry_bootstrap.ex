defmodule Singularity.Bootstrap.PatternRegistryBootstrap do
  @moduledoc """
  Pattern Registry Bootstrap - Seed code quality patterns on startup.

  ## Purpose

  Ensures all 55 code quality patterns are loaded into the knowledge_artifacts table
  on application startup. Patterns are loaded from templates_data/ JSON files.

  ## Automatic Flow

  ```
  Application Startup
    ↓
  PatternRegistryBootstrap.ensure_initialized()
    ├─ Check if patterns already seeded
    ├─ If missing, call PatternRegistry.seed_base_patterns()
    ├─ Load 55 patterns from templates_data/
    │  ├─ Security (20): OWASP + CWE
    │  ├─ Compliance (5): SOC2, HIPAA, PCI-DSS, GDPR, ISO27001
    │  ├─ Language (4): Elixir, Python, Go, JavaScript
    │  ├─ Package Intelligence (4): License, Health, Vulnerabilities, Supply Chain
    │  ├─ Architecture (6): Monolith, Coupling, Bottlenecks, etc.
    │  └─ Framework (5): Django, Rails, Spring, FastAPI, Express
    ├─ Upsert into knowledge_artifacts table (idempotent)
    └─ Log results
  ```

  ## Configuration

  Add to `config.exs`:
  ```elixir
  config :singularity, Singularity.Bootstrap.PatternRegistryBootstrap,
    enabled: true,
    auto_init: true  # Seed patterns on startup
  ```

  ## Module Identity

  ```json
  {
    "module": "Singularity.Bootstrap.PatternRegistryBootstrap",
    "purpose": "Auto-seed code quality patterns into knowledge_artifacts on startup",
    "type": "bootstrap_service",
    "layer": "infrastructure",
    "startup_order": "after_repo",
    "dependencies": ["Repo", "CodeQuality.PatternRegistry"],
    "patterns_loaded": 55,
    "storage": "PostgreSQL (knowledge_artifacts table)"
  }
  ```

  ## Anti-Patterns

  ❌ DO NOT call seed_base_patterns multiple times in same startup
  **Why:** Upserts are idempotent but wasteful
  **Use:** This bootstrap ensures it's only called once per startup

  ❌ DO NOT block application startup if pattern seeding fails
  **Why:** Patterns are important but not critical for app function
  **Use:** Bootstrap logs errors but continues startup
  """

  require Logger

  alias Singularity.CodeQuality.PatternRegistry

  @doc """
  Ensure patterns are initialized on application startup.

  Checks if patterns have been seeded, and if not, seeds them from templates_data/.
  Idempotent - safe to call multiple times.

  Returns `:ok` or logs warning if seeding fails (doesn't block startup).
  """
  def ensure_initialized do
    enabled = Application.get_env(:singularity, __MODULE__, %{})[:auto_init] != false

    if enabled do
      Logger.info("PatternRegistryBootstrap: Checking if patterns need seeding...")

      case check_patterns_seeded() do
        true ->
          Logger.info("PatternRegistryBootstrap: Patterns already seeded, skipping")
          :ok

        false ->
          Logger.info("PatternRegistryBootstrap: Seeding code quality patterns...")

          case PatternRegistry.seed_base_patterns() do
            {:ok, count} ->
              Logger.info(
                "PatternRegistryBootstrap: Successfully seeded #{count} code quality patterns"
              )

              :ok

            {:error, reason} ->
              Logger.warn(
                "PatternRegistryBootstrap: Failed to seed patterns (app will continue): #{inspect(reason)}"
              )

              :ok
          end
      end
    else
      Logger.info("PatternRegistryBootstrap: Disabled in config, skipping")
      :ok
    end
  end

  # ============================================================================
  # Internal
  # ============================================================================

  defp check_patterns_seeded do
    case PatternRegistry.stats() do
      %{total_patterns: count} when count > 0 ->
        Logger.debug("PatternRegistryBootstrap: Found #{count} existing patterns")
        true

      _ ->
        false
    end
  end
end
