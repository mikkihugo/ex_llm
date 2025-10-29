defmodule CentralCloud.FrameworkLearners.TemplateMatcher do
  @moduledoc """
  Template Matcher - Fast framework detection using predefined templates.

  Implements the FrameworkLearner behavior for quick, offline framework detection
  by matching package dependencies against known framework signatures.

  ## How It Works

  1. Load latest framework templates from knowledge_cache (no caching - frameworks update constantly)
  2. Match package dependencies against detector_signatures in templates
  3. Return first matching framework

  ## Performance

  - ⚡ Fast - No LLM calls, pure pattern matching
  - ✅ Offline - Works without network (after templates are loaded)
  - 📦 Dependency-based - Works for any ecosystem (npm, cargo, hex, etc.)

  ## Example

  Package with dependencies: `["react", "next.js", "webpack"]`
  Template with signature: `["react", "next.js"]`
  Result: ✅ Match → Return Next.js framework info

  ## When to Use

  ✅ First-line detection (priority 5-10)
  ❌ For unknown/custom frameworks (needs LLM)
  ❌ When templates aren't available (needs LLM fallback)
  """

  @behaviour CentralCloud.FrameworkLearner

  require Logger
  alias CentralCloud.{Repo, TemplateService}
  alias CentralCloud.Schemas.Package

  # ===========================
  # FrameworkLearner Behavior Callbacks
  # ===========================

  @impl CentralCloud.FrameworkLearner
  def learner_type, do: :template_matcher

  @impl CentralCloud.FrameworkLearner
  def description do
    "Fast template-based framework matching using dependency signatures"
  end

  @impl CentralCloud.FrameworkLearner
  def capabilities do
    ["fast", "offline", "dependency_based", "high_confidence"]
  end

  @impl CentralCloud.FrameworkLearner
  def learn(package_id, _code_samples) do
    package = Repo.get(Package, package_id)

    if package do
      if package.detected_framework != %{} do
        # Already known, return cached
        Logger.debug("Template matcher: Framework already known for #{package.name}")
        {:ok, package.detected_framework}
      else
        # Try to match against templates
        framework_templates = load_framework_templates()
        match_known_framework(package, framework_templates)
      end
    else
      {:error, :package_not_found}
    end
  end

  @impl CentralCloud.FrameworkLearner
  def record_success(package_id, framework) do
    package = Repo.get(Package, package_id)

    if package do
      import Ecto.Changeset

      package
      |> change(detected_framework: framework)
      |> change(last_updated: DateTime.utc_now())
      |> Repo.update()
      |> case do
        {:ok, _} ->
          Logger.debug("Recorded template matcher success for #{package_id}",
            framework: framework[:name]
          )

          :ok

        {:error, reason} ->
          Logger.error("Failed to record template matcher success",
            package_id: package_id,
            reason: inspect(reason)
          )

          {:error, reason}
      end
    else
      {:error, :package_not_found}
    end
  end

  # ===========================
  # Private Functions
  # ===========================

  defp match_known_framework(package, framework_templates) do
    matched_template =
      Enum.find(framework_templates, fn template ->
        matches_framework?(package, template)
      end)

    case matched_template do
      nil ->
        Logger.debug("Template matcher: No matching template for #{package.name}")
        :no_match

      template ->
        Logger.info("Template matcher: Matched #{package.name} to #{template["name"]}")
        {:ok, prepare_framework_result(template)}
    end
  end

  defp matches_framework?(package, template) do
    signatures = template["detector_signatures"] || %{}
    package_deps = package.dependencies || []
    required_deps = signatures["dependencies"] || []

    # Must match at least one dependency signature
    Enum.any?(required_deps, fn dep ->
      Enum.any?(package_deps, &String.contains?(&1, dep))
    end)
  end

  defp load_framework_templates do
    # ALWAYS fetch latest - frameworks release new versions constantly!
    # No caching to ensure we detect latest framework versions
    fetch_templates_from_knowledge_cache()
  end

  defp fetch_templates_from_knowledge_cache do
    case TemplateService.search_templates("", template_type: "framework", limit: 100) do
      {:ok, templates} ->
        Logger.debug("Template matcher: Loaded #{length(templates)} framework templates")
        templates

      {:error, reason} ->
        Logger.error("Template matcher: Failed to load templates", reason: inspect(reason))
        []
    end
  end

  defp prepare_framework_result(template) do
    %{
      "name" => template["name"],
      "type" => template["type"] || "web_framework",
      "ecosystem" => template["ecosystem"],
      "version" => template["latest_version"],
      "confidence" => 0.95,
      "detected_by" => "template_matcher"
    }
  end
end
