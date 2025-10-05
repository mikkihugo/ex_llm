defmodule Singularity.CodeAnalysis.RustToolingAnalyzer do
  @moduledoc """
  Extends the codebase analysis database using Rust development tools.

  Runs various cargo-* tools and stores their structured output in the
  embeddings database for enhanced code understanding and AI analysis.
  """

  require Logger
  alias Singularity.Repo

  @doc """
  Run comprehensive Rust tooling analysis and extend the analysis database.

  This function runs multiple cargo tools and stores their results as
  embeddings with metadata for semantic search and AI analysis.
  """
  @spec analyze_codebase() :: :ok | {:error, term()}
  def analyze_codebase do
    Logger.info("🔍 Starting comprehensive Rust tooling analysis...")

    with :ok <- analyze_module_structure(),
         :ok <- analyze_security_vulnerabilities(),
         :ok <- analyze_binary_size(),
         :ok <- analyze_licenses(),
         :ok <- analyze_outdated_dependencies(),
         :ok <- analyze_unused_dependencies() do
      Logger.info("✅ Codebase analysis database extended successfully!")
      :ok
    else
      error ->
        Logger.error("❌ Failed to extend analysis database: #{inspect(error)}")
        error
    end
  end

  @doc """
  Analyze module structure using cargo-modules and store in database.
  """
  @spec analyze_module_structure() :: :ok | {:error, term()}
  def analyze_module_structure do
    Logger.info("📦 Analyzing module structure...")

    case run_cargo_command("cargo-modules", ["structure", "--package", "analysis_suite"]) do
      {:ok, output} ->
        # Parse the tree output and extract modules
        modules = parse_module_tree(output)

        Enum.each(modules, fn module ->
          insert_analysis(
            "rust/src/#{module}",
            "Module: #{module}",
            %{
              type: "module",
              tool: "cargo-modules",
              language: "rust",
              module_name: module
            }
          )
        end)

        :ok

      {:error, reason} ->
        Logger.warning("⚠️  Could not analyze module structure: #{inspect(reason)}")
        :ok  # Non-critical, continue
    end
  end

  @doc """
  Analyze security vulnerabilities using cargo-audit.
  """
  @spec analyze_security_vulnerabilities() :: :ok | {:error, term()}
  def analyze_security_vulnerabilities do
    Logger.info("🔒 Analyzing security vulnerabilities...")

    case run_cargo_command("cargo-audit", ["audit", "--json"]) do
      {:ok, json_output} ->
        case Jason.decode(json_output) do
          {:ok, %{"vulnerabilities" => %{"list" => vulnerabilities}}} ->
            Enum.each(vulnerabilities, fn vuln ->
              package = get_in(vuln, ["package", "name"])
              severity = get_in(vuln, ["advisory", "severity"])

              insert_analysis(
                "rust/Cargo.lock:#{package}",
                "Security: #{package} (#{severity})",
                %{
                  type: "security",
                  tool: "cargo-audit",
                  severity: severity,
                  package: package,
                  vulnerability_data: vuln
                }
              )
            end)

          _ ->
            Logger.warning("⚠️  Could not parse cargo-audit output")
        end

        :ok

      {:error, reason} ->
        Logger.warning("⚠️  Could not run security analysis: #{inspect(reason)}")
        :ok
    end
  end

  @doc """
  Analyze binary size using cargo-bloat.
  """
  @spec analyze_binary_size() :: :ok | {:error, term()}
  def analyze_binary_size do
    Logger.info("📏 Analyzing binary size...")

    case run_cargo_command("cargo-bloat", ["--release", "--message-format", "json"]) do
      {:ok, json_output} ->
        case Jason.decode(json_output) do
          {:ok, items} when is_list(items) ->
            Enum.each(items, fn item ->
              name = item["name"] || item["Name"]
              size = item["size"] || item["Size"]

              if name && size do
                insert_analysis(
                  "rust/src/#{name}",
                  "Binary: #{name} (#{size} bytes)",
                  %{
                    type: "binary_size",
                    tool: "cargo-bloat",
                    size: size,
                    component_name: name
                  }
                )
              end
            end)

          _ ->
            Logger.warning("⚠️  Could not parse cargo-bloat output")
        end

        :ok

      {:error, reason} ->
        Logger.warning("⚠️  Could not analyze binary size: #{inspect(reason)}")
        :ok
    end
  end

  @doc """
  Analyze dependency licenses using cargo-license.
  """
  @spec analyze_licenses() :: :ok | {:error, term()}
  def analyze_licenses do
    Logger.info("📄 Analyzing dependency licenses...")

    case run_cargo_command("cargo-license", ["--json"]) do
      {:ok, json_output} ->
        case Jason.decode(json_output) do
          {:ok, dependencies} when is_list(dependencies) ->
            Enum.each(dependencies, fn dep ->
              name = dep["name"]
              license = dep["license"]

              if name && license do
                insert_analysis(
                  "rust/Cargo.lock:#{name}",
                  "License: #{name} (#{license})",
                  %{
                    type: "license",
                    tool: "cargo-license",
                    license: license,
                    dependency_name: name
                  }
                )
              end
            end)

          _ ->
            Logger.warning("⚠️  Could not parse cargo-license output")
        end

        :ok

      {:error, reason} ->
        Logger.warning("⚠️  Could not analyze licenses: #{inspect(reason)}")
        :ok
    end
  end

  @doc """
  Analyze outdated dependencies using cargo-outdated.
  """
  @spec analyze_outdated_dependencies() :: :ok | {:error, term()}
  def analyze_outdated_dependencies do
    Logger.info("⏰ Analyzing outdated dependencies...")

    case run_cargo_command("cargo-outdated", ["--format", "json"]) do
      {:ok, json_output} ->
        case Jason.decode(json_output) do
          {:ok, dependencies} when is_list(dependencies) ->
            Enum.each(dependencies, fn dep ->
              name = dep["name"]
              current = dep["project"]
              latest = dep["latest"]

              if name && current && latest do
                insert_analysis(
                  "rust/Cargo.toml:#{name}",
                  "Outdated: #{name} (#{current} → #{latest})",
                  %{
                    type: "outdated",
                    tool: "cargo-outdated",
                    current_version: current,
                    latest_version: latest,
                    dependency_name: name
                  }
                )
              end
            end)

          _ ->
            Logger.warning("⚠️  Could not parse cargo-outdated output")
        end

        :ok

      {:error, reason} ->
        Logger.warning("⚠️  Could not analyze outdated dependencies: #{inspect(reason)}")
        :ok
    end
  end

  @doc """
  Analyze unused dependencies using cargo-machete.
  """
  @spec analyze_unused_dependencies() :: :ok | {:error, term()}
  def analyze_unused_dependencies do
    Logger.info("🗑️  Analyzing unused dependencies...")

    case run_cargo_command("cargo-machete", []) do
      {:ok, output} ->
        # Parse the output to find unused dependencies
        unused_deps = parse_unused_dependencies(output)

        Enum.each(unused_deps, fn dep ->
          insert_analysis(
            "rust/Cargo.toml:#{dep}",
            "Unused: #{dep}",
            %{
              type: "unused_dependency",
              tool: "cargo-machete",
              dependency_name: dep
            }
          )
        end)

        :ok

      {:error, reason} ->
        Logger.warning("⚠️  Could not analyze unused dependencies: #{inspect(reason)}")
        :ok
    end
  end

  # Private helper functions

  @spec run_cargo_command(String.t(), [String.t()]) :: {:ok, String.t()} | {:error, term()}
  defp run_cargo_command(command, args) do
    try do
      case System.cmd(command, args, cd: "rust", stderr_to_stdout: true) do
        {output, 0} ->
          {:ok, output}

        {error_output, exit_code} ->
          Logger.warning("Command failed: #{command} #{Enum.join(args, " ")} (exit: #{exit_code})")
          Logger.warning("Error: #{error_output}")
          {:error, {:command_failed, exit_code, error_output}}
      end
    rescue
      e ->
        Logger.warning("Could not run command #{command}: #{inspect(e)}")
        {:error, {:command_error, e}}
    end
  end

  @spec parse_module_tree(String.t()) :: [String.t()]
  defp parse_module_tree(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ["├─", "└─"]))
    |> Enum.map(&extract_module_name/1)
    |> Enum.reject(&is_nil/1)
  end

  @spec extract_module_name(String.t()) :: String.t() | nil
  defp extract_module_name(line) do
    case Regex.run(~r/[├└]─\s*(.+)$/, line) do
      [_, module] -> String.trim(module)
      _ -> nil
    end
  end

  @spec parse_unused_dependencies(String.t()) :: [String.t()]
  defp parse_unused_dependencies(output) do
    # cargo-machete typically outputs one dependency per line
    output
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" || String.starts_with?(&1, "cargo-machete")))
  end

  @spec insert_analysis(String.t(), String.t(), map()) :: :ok
  defp insert_analysis(path, label, metadata) do
    # Generate real semantic embedding using Google AI
    text = "#{label} #{path} #{inspect(metadata)}"
    embedding = generate_real_embedding(text)

    # Insert into the embeddings database
    case insert_embedding(path, label, metadata, embedding) do
      :ok ->
        Logger.debug("Inserted analysis with embedding: #{path}")

      {:error, reason} ->
        Logger.warning("Failed to insert analysis for #{path}: #{inspect(reason)}")
    end
  end

  @spec generate_real_embedding(String.t()) :: Pgvector.t()
  defp generate_real_embedding(text) do
    # Use shared EmbeddingService with automatic fallback
    case Singularity.EmbeddingService.embed(text) do
      {:ok, embedding} -> embedding
      {:error, reason} ->
        Logger.warning("EmbeddingService failed: #{inspect(reason)}, using zero vector")
        Pgvector.new(List.duplicate(0.0, 768))
    end
  end

  @spec insert_embedding(String.t(), String.t(), map(), Pgvector.t()) :: :ok | {:error, term()}
  defp insert_embedding(path, label, metadata, %Pgvector{} = embedding) do
    # Insert into code_embeddings table with real Google AI embeddings
    metadata_json = Jason.encode!(metadata)

    # Extract metadata fields
    language = Map.get(metadata, :language, "rust")
    analysis_type = Map.get(metadata, :type, "unknown")
    tool_used = Map.get(metadata, :tool, "unknown")

    sql = """
    INSERT INTO code_embeddings (path, label, metadata, embedding, language, analysis_type, tool_used, inserted_at, updated_at)
    VALUES ($1, $2, $3, $4, $5, $6, $7, now(), now())
    ON CONFLICT (path) DO UPDATE SET
        label = EXCLUDED.label,
        metadata = EXCLUDED.metadata,
        embedding = EXCLUDED.embedding,
        language = EXCLUDED.language,
        analysis_type = EXCLUDED.analysis_type,
        tool_used = EXCLUDED.tool_used,
        updated_at = now()
    """

    case Repo.query(sql, [path, label, metadata_json, embedding, language, analysis_type, tool_used]) do
      {:ok, _} -> :ok
      error -> error
    end
  rescue
    error ->
      # Fallback: log the error and data
      Logger.warning("Failed to insert embedding: #{inspect(error)}")
      Logger.info("Analysis data: #{path} | #{label} | #{inspect(metadata)}")
      :ok
  end
end