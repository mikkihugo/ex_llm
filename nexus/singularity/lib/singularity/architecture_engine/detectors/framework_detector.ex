defmodule Singularity.Architecture.Detectors.FrameworkDetector do
  @moduledoc """
  Framework Pattern Detector - Detects web frameworks, build tools, etc.

  Implements `@behaviour PatternType` to detect framework patterns in codebases.
  Uses configuration-driven approach via PatternDetector.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Architecture.Detectors.FrameworkDetector",
    "type": "detector",
    "purpose": "Detect web frameworks, build tools, and runtime frameworks",
    "layer": "architecture_engine",
    "behavior": "PatternType",
    "registered_in": "config :singularity, :pattern_types, framework: ...",
    "scope": "Framework detection via package managers, config files, imports"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A[detect/2] --> B[detect_frameworks]
      B --> C[check package.json]
      B --> D[check pom.xml]
      B --> E[check Gemfile]
      B --> F[check requirements.txt]
      C --> G[extract framework names]
      D --> G
      E --> G
      F --> G
      G --> H[uniq by name]
      H --> I[return results]
  ```

  ## Call Graph (YAML)

  ```yaml
  calls:
    - Singularity.Architecture.PatternStore (confidence tracking)
    - Logger (error handling)

  called_by:
    - Singularity.Architecture.PatternDetector (orchestrator)
    - Architecture analysis pipelines
    - Technology assessment tools
  ```

  ## Anti-Patterns

  - ❌ `FrameworkDetectorUtil` - Use FrameworkDetector behavior
  - ❌ `FrameworkRegistry` - Use PatternStore for persistence
  - ✅ Use PatternDetector for discovery
  - ✅ Learn patterns via `learn_pattern/1` callback

  ## Detected Frameworks

  - **Web UI**: React, Vue, Angular, Svelte, Next.js
  - **Web Servers**: Express, Rails, Django, FastAPI, Laravel
  - **Build Tools**: Webpack, Vite, Maven, Gradle, Cargo
  - **Other**: NestJS, Remix, Sails.js, etc.

  ## Search Keywords

  framework detection, pattern detection, web frameworks, build tools,
  technology detection, package detection, dependency analysis
  """

  @behaviour Singularity.Architecture.PatternType
  require Logger
  alias Singularity.Architecture.PatternStore

  @impl true
  def pattern_type, do: :framework

  @impl true
  def description,
    do: "Detect web frameworks, build tools, and runtime frameworks (with learned patterns)"

  @impl true
  def supported_types do
    [
      "web_ui_framework",
      "web_server_framework",
      "build_tool",
      "test_framework",
      "orm_framework"
    ]
  end

  @impl true
  def detect(path, opts \\ []) when is_binary(path) do
    use_learned_patterns = Keyword.get(opts, :use_learned_patterns, true)
    max_depth = Keyword.get(opts, :max_depth, 3)

    Logger.debug(
      "Framework detection for #{path}: learned_patterns=#{use_learned_patterns}, max_depth=#{max_depth}"
    )

    # Step 1: Run hardcoded detectors
    hardcoded_results = detect_frameworks(path)

    # Step 2: Fetch learned patterns from database (if enabled)
    learned_patterns = if use_learned_patterns, do: fetch_learned_patterns(), else: []

    # Step 3: Enhance results with learned pattern confidence
    enhanced_results = enhance_with_learned_patterns(hardcoded_results, learned_patterns)

    # Step 4: Apply learned patterns not yet detected
    all_results = apply_learned_patterns(enhanced_results, learned_patterns, path)

    # Return unique results
    all_results
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(& &1.confidence, :desc)
  end

  @impl true
  def learn_pattern(result) do
    # Update framework confidence in PatternStore
    case result do
      %{name: name, success: true} ->
        Singularity.Architecture.PatternStore.update_confidence(:framework, name, success: true)

      %{name: name, success: false} ->
        Singularity.Architecture.PatternStore.update_confidence(:framework, name, success: false)

      _ ->
        :ok
    end
  end

  # Private: Pattern learning integration

  defp fetch_learned_patterns do
    case PatternStore.list_patterns(:framework, limit: 100) do
      {:ok, patterns} ->
        Enum.filter(patterns, &(&1.confidence > 0.5))

      {:error, reason} ->
        Logger.warning("Failed to fetch learned patterns: #{inspect(reason)}")
        []
    end
  end

  defp enhance_with_learned_patterns(hardcoded_results, learned_patterns) do
    Enum.map(hardcoded_results, fn result ->
      # Look up pattern in learned patterns
      case Enum.find(learned_patterns, &(&1.name == result.name)) do
        nil ->
          result

        learned ->
          # Use learned confidence if it's higher
          %{
            result
            | confidence: max(result.confidence, learned.confidence),
              learned: true
          }
      end
    end)
  end

  defp apply_learned_patterns(results, learned_patterns, path) do
    # Find learned patterns that match the path but weren't detected
    new_detections =
      learned_patterns
      |> Enum.reject(&Enum.any?(results, fn r -> r.name == &1.name end))
      |> Enum.filter(&pattern_matches_path?(&1, path))

    results ++ new_detections
  end

  defp pattern_matches_path?(_pattern, ""), do: false

  defp pattern_matches_path?(pattern, path) do
    # Try to match file patterns from the learned pattern
    file_patterns = Map.get(pattern, :file_patterns, [])
    directory_patterns = Map.get(pattern, :directory_patterns, [])
    config_files = Map.get(pattern, :config_files, [])

    all_patterns = (file_patterns ++ directory_patterns ++ config_files) |> Enum.uniq()

    # Check if any patterns match files in the path
    Enum.any?(all_patterns, &has_file?(path, &1))
  end

  # Private: Framework detection logic

  defp detect_frameworks(path) do
    [
      detect_react(path),
      detect_vue(path),
      detect_angular(path),
      detect_nextjs(path),
      detect_nestjs(path),
      detect_express(path),
      detect_rails(path),
      detect_django(path),
      detect_fastapi(path),
      detect_laravel(path),
      detect_webpack(path),
      detect_vite(path),
      detect_maven(path),
      detect_gradle(path),
      detect_cargo(path)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  defp detect_react(path) do
    if has_file?(path, "package.json") && has_file?(path, "src/App.jsx") do
      %{
        name: "React",
        type: "web_ui_framework",
        confidence: 0.95,
        description: "React web UI framework"
      }
    else
      nil
    end
  end

  defp detect_vue(path) do
    if has_file?(path, "vue.config.js") ||
         (has_file?(path, "package.json") && has_file?(path, "src/App.vue")) do
      %{
        name: "Vue",
        type: "web_ui_framework",
        confidence: 0.92,
        description: "Vue.js web UI framework"
      }
    else
      nil
    end
  end

  defp detect_angular(path) do
    if has_file?(path, "angular.json") do
      %{
        name: "Angular",
        type: "web_ui_framework",
        confidence: 0.98,
        description: "Angular web framework"
      }
    else
      nil
    end
  end

  defp detect_nextjs(path) do
    if has_file?(path, "next.config.js") || has_file?(path, "next.config.mjs") do
      %{
        name: "Next.js",
        type: "web_server_framework",
        confidence: 0.97,
        description: "Next.js React meta-framework"
      }
    else
      nil
    end
  end

  defp detect_nestjs(path) do
    if has_file?(path, "nest-cli.json") do
      %{
        name: "NestJS",
        type: "web_server_framework",
        confidence: 0.99,
        description: "NestJS TypeScript framework"
      }
    else
      nil
    end
  end

  defp detect_express(path) do
    if has_file?(path, "package.json") && contains_dependency?(path, "express") do
      %{
        name: "Express",
        type: "web_server_framework",
        confidence: 0.88,
        description: "Express.js web server"
      }
    else
      nil
    end
  end

  defp detect_rails(path) do
    if has_file?(path, "Gemfile") && has_file?(path, "config/rails_env.rb") do
      %{
        name: "Rails",
        type: "web_server_framework",
        confidence: 0.96,
        description: "Ruby on Rails framework"
      }
    else
      nil
    end
  end

  defp detect_django(path) do
    if has_file?(path, "manage.py") && has_file?(path, "settings.py") do
      %{
        name: "Django",
        type: "web_server_framework",
        confidence: 0.95,
        description: "Django Python framework"
      }
    else
      nil
    end
  end

  defp detect_fastapi(path) do
    if has_file?(path, "pyproject.toml") && contains_dependency?(path, "fastapi") do
      %{
        name: "FastAPI",
        type: "web_server_framework",
        confidence: 0.85,
        description: "FastAPI Python framework"
      }
    else
      nil
    end
  end

  defp detect_laravel(path) do
    if has_file?(path, "composer.json") && has_file?(path, "artisan") do
      %{
        name: "Laravel",
        type: "web_server_framework",
        confidence: 0.94,
        description: "Laravel PHP framework"
      }
    else
      nil
    end
  end

  defp detect_webpack(path) do
    if has_file?(path, "webpack.config.js") do
      %{
        name: "Webpack",
        type: "build_tool",
        confidence: 0.98,
        description: "Webpack bundler"
      }
    else
      nil
    end
  end

  defp detect_vite(path) do
    if has_file?(path, "vite.config.js") || has_file?(path, "vite.config.ts") do
      %{
        name: "Vite",
        type: "build_tool",
        confidence: 0.97,
        description: "Vite bundler"
      }
    else
      nil
    end
  end

  defp detect_maven(path) do
    if has_file?(path, "pom.xml") do
      %{
        name: "Maven",
        type: "build_tool",
        confidence: 0.99,
        description: "Apache Maven build tool"
      }
    else
      nil
    end
  end

  defp detect_gradle(path) do
    if has_file?(path, "build.gradle") || has_file?(path, "build.gradle.kts") do
      %{
        name: "Gradle",
        type: "build_tool",
        confidence: 0.99,
        description: "Gradle build tool"
      }
    else
      nil
    end
  end

  defp detect_cargo(path) do
    if has_file?(path, "Cargo.toml") do
      %{
        name: "Cargo",
        type: "build_tool",
        confidence: 0.99,
        description: "Rust Cargo package manager"
      }
    else
      nil
    end
  end

  # Helpers

  defp has_file?(path, filename) do
    File.exists?(Path.join(path, filename))
  end

  defp contains_dependency?(path, dep_name) do
    package_json = Path.join(path, "package.json")

    if File.exists?(package_json) do
      case File.read(package_json) do
        {:ok, content} ->
          String.contains?(content, "\"#{dep_name}\"")

        {:error, _} ->
          false
      end
    else
      false
    end
  end
end
