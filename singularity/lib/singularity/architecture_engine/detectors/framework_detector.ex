defmodule Singularity.Architecture.Detectors.FrameworkDetector do
  @moduledoc """
  Framework Pattern Detector - Detects web frameworks, build tools, etc.

  Implements `@behaviour PatternType` to detect framework patterns in codebases.
  Uses configuration-driven approach via PatternDetector.

  ## Detected Frameworks

  - **Web UI**: React, Vue, Angular, Svelte, Next.js
  - **Web Servers**: Express, Rails, Django, FastAPI, Laravel
  - **Build Tools**: Webpack, Vite, Maven, Gradle, Cargo
  - **Other**: NestJS, Remix, Sails.js, etc.
  """

  @behaviour Singularity.Architecture.PatternType
  require Logger

  @impl true
  def pattern_type, do: :framework

  @impl true
  def description, do: "Detect web frameworks, build tools, and runtime frameworks"

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
  def detect(path, _opts \\ []) when is_binary(path) do
    path
    |> detect_frameworks()
    |> Enum.uniq_by(& &1.name)
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
    if has_file?(path, "vue.config.js") || (has_file?(path, "package.json") && has_file?(path, "src/App.vue")) do
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
