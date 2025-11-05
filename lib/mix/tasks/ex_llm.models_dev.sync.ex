defmodule Mix.Tasks.ExLlm.ModelsDev.Sync do
  @moduledoc """
  Syncs model data from models.dev to SingularityLLM YAML configs.

  models.dev is a community-maintained database of 300+ LLM models across
  40+ providers with current pricing, capabilities, and specifications.

  This task fetches the latest model data and merges it with existing configs,
  preserving your custom settings (complexity scores, notes, etc).

  ## Usage

      mix singularity_llm.models_dev.sync

  ## What It Does

  1. Fetches all models from https://models.dev/api.json
  2. Groups by provider
  3. Merges with existing YAML configs:
     - Updates: pricing, capabilities, context windows
     - Preserves: task_complexity_score, notes, default_model
     - Detects: new models, deprecations

  ## Output

  Updates YAML files in `config/models/` directory:
  - anthropic.yml
  - openai.yml
  - google.yml
  - groq.yml
  - mistral.yml
  - etc.

  ## Example

  Before:
  ```yaml
  # config/models/anthropic.yml
  models:
    claude-3-5-sonnet-20241022:
      name: Claude 3.5 Sonnet
      context_window: 200000
      task_complexity_score:
        simple: 1.5
        medium: 3.0
        complex: 4.2
  ```

  After:
  ```yaml
  # config/models/anthropic.yml
  models:
    claude-3-5-sonnet-20241022:
      name: Claude 3.5 Sonnet
      context_window: 200000
      pricing: {input: 3.0, output: 15.0}  # Updated from API
      capabilities: [streaming, vision, function_calling, ...]  # From API
      task_complexity_score:
        simple: 1.5
        medium: 3.0
        complex: 4.2  # YOUR SCORE PRESERVED!
  ```

  ## Caching

  Results are cached locally (~/.cache/models_dev.json) for 60 minutes
  to avoid rate limiting and improve performance.

  ## Error Handling

  - If models.dev API is unreachable, uses cached data if available
  - Continues if individual provider sync fails
  - Non-blocking: existing configs remain valid if sync fails

  ## See Also

      mix singularity_llm.models_dev.fetch  # Fetch without syncing
      mix singularity_llm.models_dev.cache  # Manage cache
  """

  use Mix.Task
  require Logger

  alias SingularityLLM.ModelDiscovery.ModelsDevSyncer

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Syncing models from models.dev...")

    case ModelsDevSyncer.sync_to_configs() do
      :ok ->
        Mix.shell().info("✓ Successfully synced models.dev data")
        Mix.shell().info("")
        Mix.shell().info("Config files updated:")
        list_config_files()

      {:error, reason} ->
        Mix.shell().error("✗ Failed to sync models: #{inspect(reason)}")
        exit(1)
    end
  end

  defp list_config_files do
    config_dir = SingularityLLM.Infrastructure.Config.ModelConfig.config_dir()

    case File.ls(config_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".yml"))
        |> Enum.sort()
        |> Enum.each(fn file ->
          Mix.shell().info("  - #{file}")
        end)

      {:error, _} ->
        Mix.shell().info("  (config/models directory not found)")
    end
  end
end
