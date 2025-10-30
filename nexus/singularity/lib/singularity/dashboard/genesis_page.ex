defmodule Singularity.Dashboard.GenesisPage do
  @moduledoc """
  Phoenix LiveDashboard page for Genesis rule evolution and LLM configuration.

  Displays:
  - Validation rules (published, candidates, consensus)
  - LLM configuration rules (complexity/model mappings)
  - Cross-instance metrics
  - Publication history
  - Settings KV sync status
  """

  use Phoenix.LiveDashboard.PageBuilder

  require Jason

  alias Singularity.Evolution.{GenesisPublisher, RuleEvolutionSystem}
  alias Singularity.LLM.Config
  alias Singularity.Settings

  @impl true
  def menu_link(_, _) do
    {:ok, "Genesis"}
  end

  @impl true
  def render_page(_assigns) do
    # Fetch all Genesis data
    validation_rules = fetch_validation_rules()
    llm_config = fetch_llm_config()
    llm_config_rules = fetch_llm_config_rules()
    cross_instance_metrics = GenesisPublisher.get_cross_instance_metrics()
    publication_history = GenesisPublisher.get_publication_history(limit: 10)
    settings_sync = fetch_settings_sync_status()
    evolution_health = RuleEvolutionSystem.get_evolution_health()

    %{
      title: "Genesis - Rule Evolution & LLM Configuration",
      content:
        build_dashboard_content(
          validation_rules,
          llm_config,
          llm_config_rules,
          cross_instance_metrics,
          publication_history,
          settings_sync,
          evolution_health
        )
    }
  end

  defp fetch_validation_rules do
    case RuleEvolutionSystem.analyze_and_propose_rules(%{}, limit: 20) do
      {:ok, rules} ->
        %{
          total: length(rules),
          confident: Enum.count(rules, &(&1.confidence >= 0.85)),
          candidates: Enum.count(rules, &(&1.confidence < 0.85)),
          top_rules: rules |> Enum.take(5)
        }

      {:error, _} ->
        %{total: 0, confident: 0, candidates: 0, top_rules: []}
    end
  end

  defp fetch_llm_config do
    # Get current LLM configuration from Settings KV
    providers = ["claude", "gemini", "copilot", "codex"]

    config_by_provider =
      providers
      |> Enum.map(fn provider ->
        complexity_config = fetch_provider_complexity(provider)
        models_config = fetch_provider_models(provider)

        {provider,
         %{
           complexity: complexity_config,
           models: models_config
         }}
      end)
      |> Enum.reject(fn {_p, config} -> config.complexity == %{} && config.models == [] end)
      |> Enum.into(%{})

    config_by_provider
  end

  defp fetch_provider_complexity(provider) do
    task_types = [:architect, :coder, :refactoring, :code_generation, :planning]

    task_types
    |> Enum.map(fn task_type ->
      key = "llm.providers.#{provider}.complexity.#{task_type}"

      case Settings.get(key) do
        nil ->
          nil

        complexity when is_binary(complexity) ->
          normalized =
            case String.downcase(complexity) do
              "simple" -> :simple
              "medium" -> :medium
              "complex" -> :complex
              _ -> nil
            end

          if normalized, do: {task_type, normalized}, else: nil

        complexity when complexity in [:simple, :medium, :complex] ->
          {task_type, complexity}

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp fetch_provider_models(provider) do
    key = "llm.providers.#{provider}.models"

    case Settings.get(key) do
      nil ->
        []

      models when is_list(models) ->
        models

      models when is_binary(models) ->
        case Jason.decode(models) do
          {:ok, models_list} when is_list(models_list) -> models_list
          _ -> []
        end

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp fetch_llm_config_rules do
    case GenesisPublisher.synthesize_llm_config_rules(limit: 10) do
      {:ok, rules} ->
        %{
          total: length(rules),
          confident: Enum.count(rules, &(&1.confidence >= 0.85)),
          top_rules: rules |> Enum.take(5)
        }

      {:error, _} ->
        %{total: 0, confident: 0, top_rules: []}
    end
  end

  defp fetch_settings_sync_status do
    case GenesisPublisher.sync_llm_config_from_settings() do
      {:ok, config} ->
        %{
          synced: true,
          providers: Map.keys(config),
          last_sync: DateTime.utc_now()
        }

      {:error, reason} ->
        %{
          synced: false,
          error: inspect(reason),
          last_sync: nil
        }
    end
  end

  defp build_dashboard_content(
         validation_rules,
         llm_config,
         llm_config_rules,
         cross_instance_metrics,
         publication_history,
         settings_sync,
         evolution_health
       ) do
    """
    <div class="genesis-dashboard">
      <h2>Genesis Rule Evolution & LLM Configuration Dashboard</h2>
      
      <section class="validation-rules">
        <h3>Validation Rules</h3>
        <div class="stats">
          <div class="stat">
            <span class="label">Total Rules:</span>
            <span class="value">#{validation_rules.total}</span>
          </div>
          <div class="stat">
            <span class="label">Confident (≥0.85):</span>
            <span class="value">#{validation_rules.confident}</span>
          </div>
          <div class="stat">
            <span class="label">Candidates:</span>
            <span class="value">#{validation_rules.candidates}</span>
          </div>
        </div>
        
        <h4>Top Rules</h4>
        <table>
          <thead>
            <tr>
              <th>Pattern</th>
              <th>Action</th>
              <th>Confidence</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            #{format_rules_table(validation_rules.top_rules)}
          </tbody>
        </table>
      </section>

      <section class="llm-config">
        <h3>LLM Configuration (Settings KV)</h3>
        <div class="config-by-provider">
          #{format_llm_config(llm_config)}
        </div>
      </section>

      <section class="llm-config-rules">
        <h3>LLM Configuration Rules</h3>
        <div class="stats">
          <div class="stat">
            <span class="label">Total Rules:</span>
            <span class="value">#{llm_config_rules.total}</span>
          </div>
          <div class="stat">
            <span class="label">Confident:</span>
            <span class="value">#{llm_config_rules.confident}</span>
          </div>
        </div>
        
        <h4>Top LLM Config Rules</h4>
        <table>
          <thead>
            <tr>
              <th>Provider</th>
              <th>Task Type</th>
              <th>Complexity</th>
              <th>Models</th>
              <th>Confidence</th>
            </tr>
          </thead>
          <tbody>
            #{format_llm_config_rules_table(llm_config_rules.top_rules)}
          </tbody>
        </table>
      </section>

      <section class="cross-instance">
        <h3>Cross-Instance Metrics</h3>
        <div class="stats">
          <div class="stat">
            <span class="label">Total Rules:</span>
            <span class="value">#{cross_instance_metrics.total_rules || 0}</span>
          </div>
          <div class="stat">
            <span class="label">Published by Us:</span>
            <span class="value">#{cross_instance_metrics.published_by_us || 0}</span>
          </div>
          <div class="stat">
            <span class="label">Imported:</span>
            <span class="value">#{cross_instance_metrics.imported_from_others || 0}</span>
          </div>
          <div class="stat">
            <span class="label">Network Health:</span>
            <span class="value">#{cross_instance_metrics.network_health || "UNKNOWN"}</span>
          </div>
        </div>
      </section>

      <section class="settings-sync">
        <h3>Settings KV Sync Status</h3>
        <div class="stats">
          <div class="stat">
            <span class="label">Synced:</span>
            <span class="value">#{if settings_sync.synced, do: "✅ Yes", else: "❌ No"}</span>
          </div>
          #{if settings_sync.synced do
      """
      <div class="stat">
        <span class="label">Providers:</span>
        <span class="value">#{Enum.join(settings_sync.providers, ", ")}</span>
      </div>
      <div class="stat">
        <span class="label">Last Sync:</span>
        <span class="value">#{format_datetime(settings_sync.last_sync)}</span>
      </div>
      """
    else
      """
      <div class="stat">
        <span class="label">Error:</span>
        <span class="value">#{settings_sync.error}</span>
      </div>
      """
    end}
        </div>
      </section>

      <section class="evolution-health">
        <h3>Evolution Health</h3>
        <div class="stats">
          <div class="stat">
            <span class="label">Total Rules:</span>
            <span class="value">#{evolution_health.total_rules || 0}</span>
          </div>
          <div class="stat">
            <span class="label">Confident:</span>
            <span class="value">#{evolution_health.confident_rules || 0}</span>
          </div>
          <div class="stat">
            <span class="label">Candidates:</span>
            <span class="value">#{evolution_health.candidate_rules || 0}</span>
          </div>
          <div class="stat">
            <span class="label">Avg Confidence:</span>
            <span class="value">#{Float.round(evolution_health.avg_confidence || 0.0, 3)}</span>
          </div>
          <div class="stat">
            <span class="label">Status:</span>
            <span class="value">#{evolution_health.health_status || "UNKNOWN"}</span>
          </div>
        </div>
      </section>

      <section class="actions">
        <h3>Actions</h3>
        <div class="action-buttons">
          <button phx-click="sync_settings" class="btn btn-primary">Sync Settings KV</button>
          <button phx-click="synthesize_rules" class="btn btn-primary">Synthesize LLM Rules</button>
          <button phx-click="publish_rules" class="btn btn-primary">Publish Rules</button>
          <button phx-click="import_rules" class="btn btn-primary">Import Rules</button>
        </div>
      </section>
    </div>
    """
  end

  defp format_rules_table(rules) do
    rules
    |> Enum.map(fn rule ->
      pattern_str = format_pattern(rule.pattern)
      action_str = format_action(rule.action)
      confidence_str = Float.round(rule.confidence, 3)
      status_str = Atom.to_string(rule.status || :candidate)

      """
      <tr>
        <td>#{pattern_str}</td>
        <td>#{action_str}</td>
        <td>#{confidence_str}</td>
        <td>#{status_str}</td>
      </tr>
      """
    end)
    |> Enum.join("\n")
  end

  defp format_llm_config_rules_table(rules) do
    rules
    |> Enum.map(fn rule ->
      provider = rule.pattern[:provider] || rule.pattern["provider"] || "auto"
      task_type = rule.pattern[:task_type] || rule.pattern["task_type"] || "unknown"
      complexity = rule.action[:complexity] || rule.action["complexity"] || "unknown"
      models = (rule.action[:models] || rule.action["models"] || []) |> Enum.join(", ")
      confidence = Float.round(rule.confidence, 3)

      """
      <tr>
        <td>#{provider}</td>
        <td>#{task_type}</td>
        <td>#{complexity}</td>
        <td>#{models}</td>
        <td>#{confidence}</td>
      </tr>
      """
    end)
    |> Enum.join("\n")
  end

  defp format_llm_config(config) do
    config
    |> Enum.map(fn {provider, provider_config} ->
      complexity_rows =
        provider_config.complexity
        |> Enum.map(fn {task_type, complexity} ->
          "<tr><td>#{task_type}</td><td>#{complexity}</td></tr>"
        end)
        |> Enum.join("\n")

      models_list = Enum.join(provider_config.models, ", ")

      """
      <div class="provider-config">
        <h4>#{String.capitalize(provider)}</h4>
        <div class="complexity">
          <strong>Complexity by Task Type:</strong>
          <table>
            <thead>
              <tr><th>Task Type</th><th>Complexity</th></tr>
            </thead>
            <tbody>
              #{complexity_rows}
            </tbody>
          </table>
        </div>
        <div class="models">
          <strong>Models:</strong> #{models_list}
        </div>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  defp format_pattern(pattern) when is_map(pattern) do
    pattern
    |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
    |> Enum.join(", ")
  end

  defp format_pattern(pattern), do: inspect(pattern)

  defp format_action(action) when is_map(action) do
    if Map.has_key?(action, :checks) do
      checks = Map.get(action, :checks, [])
      "Checks: #{Enum.join(checks, ", ")}"
    else
      inspect(action)
    end
  end

  defp format_action(action), do: inspect(action)

  defp format_datetime(nil), do: "Never"
  defp format_datetime(dt) when is_map(dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(dt), do: inspect(dt)
end
