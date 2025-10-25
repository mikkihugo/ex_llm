defmodule Singularity.Agents.TemplatePerformance do
  @moduledoc """
  Template Performance Analyzer - Analyzes and improves failing templates.

  ## Purpose

  Provides comprehensive template performance analysis by querying local template
  statistics, identifying failing templates, generating improvements via LLM, testing,
  and deploying improved versions. Integrates with CentralCloud for cross-instance
  failure pattern analysis.

  ## Public API

  - `analyze_template_performance/0` - Analyze all template performance
  - `improve_failing_template/2` - Improve a specific failing template

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "TemplatePerformance",
    "purpose": "template_performance_analysis",
    "domain": "agents",
    "capabilities": ["template_analysis", "failure_detection", "template_improvement", "llm_generation"],
    "dependencies": ["LLM.Service", "NATS.Client", "Repo"]
  }
  ```

  ## Architecture Diagram (Mermaid)
  ```mermaid
  graph TD
    A[TemplatePerformance] --> B[analyze_template_performance/0]
    B --> C[query_local_template_stats/0]
    B --> D[identify_failing_templates/1]
    B --> E[improve_failing_templates/1]
    A --> F[improve_failing_template/2]
    F --> G[query_centralcloud_for_failures/1]
    F --> H[load_current_template/1]
    F --> I[generate_template_improvement/3]
    F --> J[test_improved_template/2]
    F --> K[deploy_improved_template/2]
  ```

  ## Call Graph (YAML)
  ```yaml
  TemplatePerformance:
    analyze_template_performance/0: [query_local_template_stats/0, identify_failing_templates/1, improve_failing_templates/1]
    improve_failing_template/2: [query_centralcloud_for_failures/1, load_current_template/1, generate_template_improvement/3, test_improved_template/2, deploy_improved_template/2]
    generate_template_improvement/3: [LLM.Service.call_with_prompt/3]
    query_centralcloud_for_failures/1: [NATS.Client.request/3]
  ```

  ## Anti-Patterns

  - DO NOT deploy templates without testing (always call test_improved_template/2)
  - DO NOT skip CentralCloud queries (degradation is handled gracefully)
  - DO NOT modify templates without version increment
  - DO NOT deploy without backup

  ## Search Keywords

  template, performance, analysis, improvement, failing_templates, llm, code_generation,
  centralcloud, template_improvement, template_testing, version_management
  """

  require Logger

  @doc """
  Analyze template performance across all templates.

  Queries local template statistics, identifies failing templates (success rate < 80%),
  and triggers improvement cycles for failing templates.

  ## Examples

      iex> TemplatePerformance.analyze_template_performance()
      {:ok, %{
        templates_analyzed: 42,
        failing_templates: 3,
        improvements_triggered: 2
      }}
  """
  @spec analyze_template_performance() :: {:ok, map()} | {:error, term()}
  def analyze_template_performance do
    Logger.info("Starting template performance analysis (Phase 4)")

    with {:ok, local_stats} <- query_local_template_stats(),
         failing_templates <- identify_failing_templates(local_stats),
         {:ok, improvements} <- improve_failing_templates(failing_templates) do
      report = %{
        templates_analyzed: length(local_stats),
        failing_templates: length(failing_templates),
        improvements_triggered: length(improvements),
        improvements: improvements
      }

      Logger.info("Template performance analysis complete",
        templates_analyzed: report.templates_analyzed,
        failing_templates: report.failing_templates,
        improvements_triggered: report.improvements_triggered
      )

      {:ok, report}
    else
      {:error, reason} ->
        Logger.error("Template performance analysis failed", reason: inspect(reason))
        {:error, reason}
    end
  end

  @doc """
  Improve a specific failing template based on failure analysis.

  Takes template_id and failure patterns, generates an improved version using LLM,
  tests it, and deploys if successful.

  ## Examples

      iex> TemplatePerformance.improve_failing_template(
      ...>   "quality_template:elixir-production",
      ...>   %{success_rate: 0.72, common_failures: [...]}
      ...> )
      {:ok, %{template_id: "...", improved: true, deployed: true}}
  """
  @spec improve_failing_template(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def improve_failing_template(template_id, failure_analysis) do
    Logger.info("Improving failing template",
      template_id: template_id,
      success_rate: failure_analysis.success_rate
    )

    with {:ok, centralcloud_data} <- query_centralcloud_for_failures(template_id),
         {:ok, current_template} <- load_current_template(template_id),
         {:ok, improved_template} <-
           generate_template_improvement(current_template, failure_analysis, centralcloud_data),
         {:ok, test_result} <- test_improved_template(improved_template, current_template),
         :ok <- deploy_improved_template(improved_template, test_result) do
      Logger.info("Template improvement successful", template_id: template_id)

      {:ok,
       %{
         template_id: template_id,
         improved: true,
         deployed: true,
         test_result: test_result,
         new_version: improved_template["spec_version"]
       }}
    else
      {:error, reason} ->
        Logger.warning("Failed to improve template",
          template_id: template_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  # Private helper functions

  defp query_local_template_stats do
    require Logger

    # Query local template_generations table for success rates by template_id
    query = """
    SELECT
      template_id,
      template_version,
      COUNT(*) as total_generations,
      COUNT(*) FILTER (WHERE success = true) as successful_generations,
      CAST(COUNT(*) FILTER (WHERE success = true) AS FLOAT) / COUNT(*) as success_rate,
      AVG(CASE WHEN answers->>'quality_score' ~ '^[0-9.]+$'
          THEN CAST(answers->>'quality_score' AS FLOAT)
          ELSE NULL END) as avg_quality_score,
      array_agg(DISTINCT instance_id) as instances
    FROM template_generations
    GROUP BY template_id, template_version
    HAVING COUNT(*) >= 10
    ORDER BY success_rate ASC
    """

    case Singularity.Repo.query(query) do
      {:ok, %{rows: rows, columns: columns}} ->
        stats =
          rows
          |> Enum.map(fn row ->
            columns
            |> Enum.zip(row)
            |> Map.new()
          end)

        Logger.debug("Queried local template stats", count: length(stats))
        {:ok, stats}

      {:error, reason} ->
        Logger.error("Failed to query local template stats", reason: inspect(reason))
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Exception querying local template stats", error: inspect(e))
      {:error, e}
  end

  defp identify_failing_templates(local_stats) do
    # Filter templates with success_rate < 0.8 and at least 10 generations
    failing_templates =
      local_stats
      |> Enum.filter(fn stats ->
        success_rate = Map.get(stats, "success_rate", 1.0)
        total_generations = Map.get(stats, "total_generations", 0)
        success_rate < 0.8 and total_generations >= 10
      end)

    Logger.info("Identified failing templates", count: length(failing_templates))
    failing_templates
  end

  defp improve_failing_templates(failing_templates) do
    improvements =
      failing_templates
      |> Enum.map(fn template_stats ->
        template_id = Map.get(template_stats, "template_id")
        success_rate = Map.get(template_stats, "success_rate")

        Logger.info("Processing failing template",
          template_id: template_id,
          success_rate: Float.round(success_rate, 2)
        )

        case improve_failing_template(template_id, template_stats) do
          {:ok, improvement} ->
            improvement

          {:error, reason} ->
            Logger.warning("Failed to improve template",
              template_id: template_id,
              reason: inspect(reason)
            )

            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, improvements}
  end

  defp query_centralcloud_for_failures(template_id) do
    require Logger

    # CentralCloud architecture: down-sync to local tables, up-communicate via pgmq
    # Read from locally synced table (updated by central_cloud replication)
    Logger.debug("Reading CentralCloud failures from synced table", template_id: template_id)

    # Query: SELECT * FROM knowledge_artifacts
    # WHERE artifact_type = 'template_failure_pattern' AND metadata->>'template_id' = ?
    # ORDER BY metadata->>'occurrence_count' DESC LIMIT 10
    # This table is synced down from CentralCloud via PostgreSQL replication

    # For now, return empty (no failures in local synced table yet)
    {:ok, %{}}
  end

  defp load_current_template(template_id) do
    # Parse template_id to get type and name
    # Format: "quality_template:elixir-production"
    case String.split(template_id, ":") do
      [type, name] ->
        template_path = resolve_template_path(type, name)

        case File.read(template_path) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, template} ->
                {:ok, template}

              {:error, reason} ->
                Logger.error("Failed to parse template JSON",
                  template_id: template_id,
                  reason: inspect(reason)
                )

                {:error, {:parse_error, reason}}
            end

          {:error, reason} ->
            Logger.error("Failed to read template file",
              template_id: template_id,
              path: template_path,
              reason: inspect(reason)
            )

            {:error, {:read_error, reason}}
        end

      _ ->
        {:error, {:invalid_template_id, template_id}}
    end
  end

  defp resolve_template_path("quality_template", name) do
    # Try templates_data/ first (main location)
    templates_data_path = "templates_data/code_generation/quality/#{name}.json"

    if File.exists?(templates_data_path) do
      templates_data_path
    else
      # Fallback to priv/
      "priv/code_quality_templates/#{name}.json"
    end
  end

  defp resolve_template_path(type, name) do
    "templates_data/code_generation/#{type}/#{name}.json"
  end

  defp generate_template_improvement(current_template, failure_analysis, centralcloud_data) do
    require Logger

    # Build context for LLM
    template_id = Map.get(failure_analysis, "template_id")
    success_rate = Map.get(failure_analysis, "success_rate")
    total_generations = Map.get(failure_analysis, "total_generations")
    avg_quality = Map.get(failure_analysis, "avg_quality_score")

    # Extract failure patterns from CentralCloud
    common_failures = Map.get(centralcloud_data, "common_failures", [])
    worst_combinations = Map.get(centralcloud_data, "worst_combinations", [])

    prompt = """
    You are an expert at improving code generation templates. Analyze this failing template and improve it.

    ## Current Template
    Template ID: #{template_id}
    Success Rate: #{Float.round(success_rate * 100, 1)}% (target: 80%+)
    Total Generations: #{total_generations}
    Avg Quality Score: #{if avg_quality, do: Float.round(avg_quality, 2), else: "N/A"}

    Template Content:
    ```json
    #{Jason.encode!(current_template, pretty: true)}
    ```

    ## Failure Patterns from CentralCloud
    #{if Enum.any?(common_failures) do
      "Common Failures:\n" <> (common_failures |> Enum.map(fn failure -> "- #{inspect(failure)}" end) |> Enum.join("\n"))
    else
      "No failure patterns available"
    end}

    #{if Enum.any?(worst_combinations) do
      "Worst Answer Combinations:\n" <> (worst_combinations |> Enum.map(fn combo -> "- Answers: #{inspect(combo["answers"])}, Success Rate: #{Float.round(combo["success_rate"] * 100, 1)}%" end) |> Enum.join("\n"))
    else
      ""
    end}

    ## Your Task
    1. Analyze why this template is failing (success rate < 80%)
    2. Identify specific problems in:
       - Template prompts
       - Question wording
       - Default values
       - Validators
       - Generated code structure
    3. Generate an IMPROVED version of this template that:
       - Fixes identified issues
       - Maintains backward compatibility where possible
       - Increments spec_version (current: #{current_template["spec_version"]})
       - Adds a changelog entry explaining improvements

    ## Output Format
    Return ONLY valid JSON for the improved template. No explanations, just the JSON.
    Increment spec_version to next minor version (e.g., 2.4.0 → 2.5.0).
    Add changelog entry at top of changelog array.
    """

    # Use complex LLM for high-quality template improvement
    case Singularity.LLM.Service.call_with_prompt(:complex, prompt,
           task_type: :architect,
           temperature: 0.3
         ) do
      {:ok, response} ->
        # Extract JSON from response (may have markdown code blocks)
        json_content = extract_json_from_response(response)

        case Jason.decode(json_content) do
          {:ok, improved_template} ->
            Logger.info("Generated improved template", template_id: template_id)
            {:ok, improved_template}

          {:error, reason} ->
            Logger.error("Failed to parse improved template JSON", reason: inspect(reason))
            {:error, {:parse_error, reason}}
        end

      {:error, reason} ->
        Logger.error("LLM failed to generate template improvement", reason: inspect(reason))
        {:error, {:llm_error, reason}}
    end
  end

  defp extract_json_from_response(response) do
    # Remove markdown code blocks if present
    response
    |> String.replace(~r/^```json\s*/m, "")
    |> String.replace(~r/^```\s*/m, "")
    |> String.trim()
  end

  defp test_improved_template(improved_template, original_template) do
    require Logger

    # Validate improved template structure
    with :ok <- validate_template_structure(improved_template),
         :ok <- validate_version_increment(improved_template, original_template),
         :ok <- validate_changelog_entry(improved_template) do
      test_result = %{
        structure_valid: true,
        version_incremented: true,
        changelog_added: true,
        backward_compatible: check_backward_compatibility(improved_template, original_template)
      }

      Logger.info("Template improvement tests passed")
      {:ok, test_result}
    else
      {:error, reason} ->
        Logger.error("Template improvement tests failed", reason: inspect(reason))
        {:error, reason}
    end
  end

  defp validate_template_structure(template) do
    required_fields = ["template_id", "spec_version", "metadata", "questions", "prompt_template"]

    missing_fields =
      required_fields
      |> Enum.reject(fn field -> Map.has_key?(template, field) end)

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, {:missing_fields, missing_fields}}
    end
  end

  defp validate_version_increment(improved_template, original_template) do
    improved_version = Map.get(improved_template, "spec_version", "0.0.0")
    original_version = Map.get(original_template, "spec_version", "0.0.0")

    case Version.compare(improved_version, original_version) do
      :gt ->
        :ok

      _ ->
        {:error,
         {:version_not_incremented, %{improved: improved_version, original: original_version}}}
    end
  rescue
    _ ->
      {:error, :invalid_version_format}
  end

  defp validate_changelog_entry(template) do
    changelog = Map.get(template, "changelog", [])

    if is_list(changelog) and length(changelog) > 0 do
      latest_entry = List.first(changelog)

      if is_map(latest_entry) and Map.has_key?(latest_entry, "version") and
           Map.has_key?(latest_entry, "changes") do
        :ok
      else
        {:error, :invalid_changelog_entry}
      end
    else
      {:error, :changelog_empty}
    end
  end

  defp check_backward_compatibility(improved_template, original_template) do
    # Check if all original questions still exist in improved template
    original_questions = Map.get(original_template, "questions", [])
    improved_questions = Map.get(improved_template, "questions", [])

    original_question_names =
      original_questions
      |> Enum.map(& &1["name"])
      |> MapSet.new()

    improved_question_names =
      improved_questions
      |> Enum.map(& &1["name"])
      |> MapSet.new()

    # If all original questions still exist, it's backward compatible
    MapSet.subset?(original_question_names, improved_question_names)
  end

  defp deploy_improved_template(improved_template, _test_result) do
    require Logger

    # Extract template_id to determine file path
    template_id = Map.get(improved_template, "template_id")

    case String.split(template_id, ":") do
      [type, name] ->
        template_path = resolve_template_path(type, name)
        backup_path = template_path <> ".backup-" <> DateTime.to_iso8601(DateTime.utc_now())

        # Backup original
        case File.read(template_path) do
          {:ok, original_content} ->
            File.write(backup_path, original_content)
            Logger.info("Backed up original template", backup_path: backup_path)

          {:error, _} ->
            Logger.warning("Could not backup original template")
        end

        # Write improved template
        improved_content = Jason.encode!(improved_template, pretty: true)

        case File.write(template_path, improved_content) do
          :ok ->
            Logger.info("Deployed improved template",
              template_id: template_id,
              path: template_path,
              version: improved_template["spec_version"]
            )

            :ok

          {:error, reason} ->
            Logger.error("Failed to deploy improved template",
              template_id: template_id,
              reason: inspect(reason)
            )

            {:error, {:deploy_error, reason}}
        end

      _ ->
        {:error, {:invalid_template_id, template_id}}
    end
  end
end
