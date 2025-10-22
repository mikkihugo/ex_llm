defmodule Singularity.Analysis.MetadataValidator do
  @moduledoc """
  AI Metadata Validator - Validates v2.2.0 documentation completeness

  **PURPOSE**: Analyze ingested code and check if it has complete v2.2.0 AI metadata

  ## What It Validates

  During or after code ingestion, checks if @moduledoc has:

  1. **Human Content (Top):**
     - Overview and purpose
     - Quick start examples
     - Public API list
     - Error handling

  2. **Separator:**
     - `---`
     - "## AI Navigation Metadata" heading

  3. **AI Metadata (Below separator):**
     - Module Identity (JSON)
     - Architecture Diagram (Mermaid)
     - Call Graph (YAML)
     - Anti-Patterns
     - Search Keywords

  ## Usage

  ### During Ingestion (Real-time validation)
  ```elixir
  # In HTDAGAutoBootstrap.persist_module_to_db/2
  validation = MetadataValidator.validate_file(file_path, content)

  # Store validation result in metadata
  attrs = %{
    metadata: %{
      ...existing...,
      v2_2_validation: validation
    }
  }
  ```

  ### After Ingestion (Batch analysis)
  ```elixir
  # Scan all ingested files
  report = MetadataValidator.validate_codebase("singularity")

  # Report shows:
  # - Files with complete metadata
  # - Files missing metadata
  # - What's missing from each file
  ```

  ## Validation Levels

  - **complete** - All v2.2.0 requirements met
  - **partial** - Has some AI metadata but incomplete
  - **missing** - No AI metadata at all
  - **legacy** - Has docs but not v2.2.0 structure

  ## How We Handle Incomplete Metadata

  ### Option 1: Generate Missing Metadata (Recommended)
  ```elixir
  # Auto-generate missing AI metadata
  MetadataValidator.fix_incomplete_metadata(file_path)
  # → Calls LLM with add-missing-docs-production.hbs template
  # → Adds missing JSON/YAML/Mermaid sections
  ```

  ### Option 2: Mark for Manual Review
  ```elixir
  # Flag for human review
  MetadataValidator.mark_for_review(file_path, missing: [:module_identity, :call_graph])
  # → Creates TODO in database
  # → SelfImprovingAgent picks it up later
  ```

  ### Option 3: Accept as Legacy (Ignore)
  ```elixir
  # Mark as acceptable legacy code
  MetadataValidator.mark_as_legacy(file_path)
  # → Won't validate v2.2.0 requirements
  # → Still usable for semantic search
  ```

  ## Integration Points

  - `HTDAGAutoBootstrap` - Validates during ingestion
  - `CodeFileWatcher` - Validates on file changes
  - `SelfImprovingAgent` - Fixes incomplete metadata
  - `mix metadata.validate` - Manual validation task
  """

  require Logger

  @doc """
  Validate a single file's metadata for v2.2.0 completeness.

  Returns:
  ```elixir
  %{
    level: :complete | :partial | :missing | :legacy,
    score: 0.0..1.0,
    has: %{
      human_content: bool,
      separator: bool,
      module_identity: bool,
      architecture_diagram: bool,
      call_graph: bool,
      anti_patterns: bool,
      search_keywords: bool
    },
    missing: [:module_identity, :call_graph, ...],
    recommendations: ["Add Module Identity JSON", ...]
  }
  ```
  """
  def validate_file(file_path, content) do
    moduledoc = extract_moduledoc(content)

    if moduledoc do
      validate_moduledoc(moduledoc)
    else
      %{
        level: :missing,
        score: 0.0,
        has: %{
          human_content: false,
          separator: false,
          module_identity: false,
          architecture_diagram: false,
          call_graph: false,
          anti_patterns: false,
          search_keywords: false
        },
        missing: [
          :moduledoc,
          :human_content,
          :separator,
          :module_identity,
          :architecture_diagram,
          :call_graph,
          :anti_patterns,
          :search_keywords
        ],
        recommendations: ["Add @moduledoc with v2.2.0 structure"]
      }
    end
  end

  @doc """
  Validate all files in a codebase.

  Returns summary report:
  ```elixir
  %{
    total_files: 251,
    complete: 50,  # 20%
    partial: 100,  # 40%
    missing: 101,  # 40%
    by_file: %{
      "lib/singularity/llm/service.ex" => %{level: :complete, score: 1.0},
      "lib/singularity/agent.ex" => %{level: :partial, score: 0.6, missing: [:call_graph]}
    }
  }
  ```
  """
  def validate_codebase(codebase_id) do
    alias Singularity.{Repo, Schemas.CodeFile}
    import Ecto.Query

    files =
      CodeFile
      |> where([cf], cf.project_name == ^codebase_id)
      |> select([cf], %{file_path: cf.file_path, content: cf.content})
      |> Repo.all()

    results =
      Enum.map(files, fn file ->
        validation = validate_file(file.file_path, file.content)
        {file.file_path, validation}
      end)
      |> Map.new()

    # Calculate summary
    total = length(files)

    complete = Enum.count(results, fn {_path, v} -> v.level == :complete end)
    partial = Enum.count(results, fn {_path, v} -> v.level == :partial end)
    missing = Enum.count(results, fn {_path, v} -> v.level == :missing end)

    %{
      total_files: total,
      complete: complete,
      complete_pct: if(total > 0, do: Float.round(complete / total * 100, 1), else: 0),
      partial: partial,
      partial_pct: if(total > 0, do: Float.round(partial / total * 100, 1), else: 0),
      missing: missing,
      missing_pct: if(total > 0, do: Float.round(missing / total * 100, 1), else: 0),
      by_file: results
    }
  end

  @doc """
  Auto-generate missing AI metadata using LLM + HBS template.

  Uses the appropriate `add-missing-docs-production.hbs` template
  to generate complete v2.2.0 documentation.
  """
  def fix_incomplete_metadata(file_path) do
    Logger.info("Auto-fixing v2.2.0 metadata for: #{file_path}")
    
    with {:ok, content} <- File.read(file_path),
         {:ok, language} <- detect_language(file_path),
         {:ok, template} <- load_template(language),
         {:ok, updated_content} <- generate_docs_with_llm(content, template, language) do
      
      # Write updated content back to file
      File.write!(file_path, updated_content)
      Logger.info("✓ Updated #{file_path} with v2.2.0 metadata")
      
      # Re-ingest the file to update database
      reingest_file(file_path)
      
      {:ok, :fixed}
    else
      {:error, reason} ->
        Logger.error("Failed to fix #{file_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp detect_language(file_path) do
    # Convert charlist to string if needed
    file_path_str = if is_list(file_path), do: List.to_string(file_path), else: file_path
    
    cond do
      String.ends_with?(file_path_str, [".ex", ".exs"]) -> {:ok, "elixir"}
      String.ends_with?(file_path_str, ".rs") -> {:ok, "rust"}
      String.ends_with?(file_path_str, [".ts", ".tsx"]) -> {:ok, "typescript"}
      String.ends_with?(file_path_str, [".js", ".jsx"]) -> {:ok, "javascript"}
      String.ends_with?(file_path_str, ".go") -> {:ok, "go"}
      String.ends_with?(file_path_str, ".java") -> {:ok, "java"}
      true -> {:error, :unsupported_language}
    end
  end

  defp load_template(language) do
    # Templates are in the project root, not relative to singularity
    template_path = Path.join([File.cwd!(), "..", "templates_data", "prompt_library", "quality", language, "add-missing-docs-production.hbs"])
    
    if File.exists?(template_path) do
      {:ok, File.read!(template_path)}
    else
      {:error, :template_not_found}
    end
  end

  defp generate_docs_with_llm(content, template, language) do
    # Use LLM Service to generate documentation
    alias Singularity.LLM.Service
    
    # Language-specific system prompt
    system_prompt = case language do
      "elixir" -> "You are an expert Elixir documentation generator. Generate complete v2.2.0 AI metadata for Elixir modules."
      "rust" -> "You are an expert Rust documentation generator. Generate complete v2.2.0 AI metadata for Rust modules."
      "typescript" -> "You are an expert TypeScript documentation generator. Generate complete v2.2.0 AI metadata for TypeScript modules."
      "javascript" -> "You are an expert JavaScript documentation generator. Generate complete v2.2.0 AI metadata for JavaScript modules."
      "go" -> "You are an expert Go documentation generator. Generate complete v2.2.0 AI metadata for Go modules."
      "java" -> "You are an expert Java documentation generator. Generate complete v2.2.0 AI metadata for Java modules."
      _ -> "You are an expert documentation generator. Generate complete v2.2.0 AI metadata for the provided code."
    end
    
    messages = [
      %{
        role: "system",
        content: system_prompt
      },
      %{
        role: "user", 
        content: template |> String.replace("{{code}}", content)
      }
    ]
    
    case Service.call(:medium, messages, task_type: :documentation) do
      {:ok, %{content: generated_content}} ->
        # Extract the code from the response (remove markdown code blocks)
        cleaned_content = extract_code_from_response(generated_content)
        {:ok, cleaned_content}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_code_from_response(response) do
    # Remove markdown code blocks and extract the actual code
    response
    |> String.split("```")
    |> Enum.at(1)  # Get content between first ``` and second ```
    |> String.trim()
  end

  defp reingest_file(file_path) do
    # Trigger re-ingestion via CodeFileWatcher or HTDAGAutoBootstrap
    alias Singularity.Execution.Planning.HTDAGAutoBootstrap
    
    # Create a minimal module structure for re-ingestion
    module = %{
      file_path: file_path,
      module_name: extract_module_name_from_path(file_path),
      has_moduledoc: true,
      issues: []
    }
    
    HTDAGAutoBootstrap.persist_module_to_db(module, "singularity")
  end

  defp extract_module_name_from_path(file_path) do
    # Convert charlist to string if needed
    file_path_str = if is_list(file_path), do: List.to_string(file_path), else: file_path
    
    file_path_str
    |> String.replace(~r/^.*\/lib\//, "")
    |> String.replace(".ex", "")
    |> String.split("/")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(".")
  end

  @doc """
  Mark file for manual review.
  """
  def mark_for_review(file_path, opts \\ []) do
    missing = Keyword.get(opts, :missing, [])
    Logger.info("Marking #{file_path} for review. Missing: #{inspect(missing)}")
    # TODO: Store in database as TODO for SelfImprovingAgent
    {:ok, :marked}
  end

  @doc """
  Mark file as acceptable legacy code (skip v2.2.0 validation).
  """
  def mark_as_legacy(file_path) do
    Logger.info("Marking #{file_path} as legacy (skip v2.2.0 validation)")
    # TODO: Store in database
    {:ok, :legacy}
  end

  ## Private Functions

  defp extract_moduledoc(content) do
    # Extract @moduledoc content using regex
    case Regex.run(~r/@moduledoc\s+"""(.*?)"""/s, content) do
      [_, moduledoc] -> String.trim(moduledoc)
      nil -> nil
    end
  end

  defp validate_moduledoc(moduledoc) do
    # Check for v2.2.0 AI metadata structure
    has_human_content = has_human_content?(moduledoc)
    has_separator = has_separator?(moduledoc)
    has_module_identity = has_module_identity?(moduledoc)
    has_architecture_diagram = has_architecture_diagram?(moduledoc)
    has_call_graph = has_call_graph?(moduledoc)
    has_anti_patterns = has_anti_patterns?(moduledoc)
    has_search_keywords = has_search_keywords?(moduledoc)

    has_map = %{
      human_content: has_human_content,
      separator: has_separator,
      module_identity: has_module_identity,
      architecture_diagram: has_architecture_diagram,
      call_graph: has_call_graph,
      anti_patterns: has_anti_patterns,
      search_keywords: has_search_keywords
    }

    missing = Enum.filter([
      :human_content,
      :separator,
      :module_identity,
      :architecture_diagram,
      :call_graph,
      :anti_patterns,
      :search_keywords
    ], fn key -> !Map.get(has_map, key) end)

    score = calculate_score(has_map)
    level = determine_level(score, has_map)
    recommendations = generate_recommendations(missing)

    %{
      level: level,
      score: score,
      has: has_map,
      missing: missing,
      recommendations: recommendations
    }
  end

  defp has_human_content?(moduledoc) do
    # Check for human-readable content (not just AI metadata)
    moduledoc
    |> String.split("---")
    |> List.first()
    |> String.trim()
    |> String.length() > 100
  end

  defp has_separator?(moduledoc) do
    String.contains?(moduledoc, "---") and 
    String.contains?(moduledoc, "AI Navigation Metadata")
  end

  defp has_module_identity?(moduledoc) do
    String.contains?(moduledoc, "Module Identity") and
    String.contains?(moduledoc, "{")
  end

  defp has_architecture_diagram?(moduledoc) do
    String.contains?(moduledoc, "Architecture Diagram") and
    String.contains?(moduledoc, "```mermaid")
  end

  defp has_call_graph?(moduledoc) do
    String.contains?(moduledoc, "Call Graph") and
    String.contains?(moduledoc, "```yaml")
  end

  defp has_anti_patterns?(moduledoc) do
    String.contains?(moduledoc, "Anti-Patterns")
  end

  defp has_search_keywords?(moduledoc) do
    String.contains?(moduledoc, "Search Keywords")
  end

  defp calculate_score(has_map) do
    total = map_size(has_map)
    true_count = Enum.count(has_map, fn {_k, v} -> v end)
    true_count / total
  end

  defp determine_level(score, has_map) do
    cond do
      score == 1.0 -> :complete
      score >= 0.5 and has_map.human_content -> :partial
      has_map.human_content -> :legacy
      true -> :missing
    end
  end

  defp generate_recommendations(missing) do
    Enum.map(missing, fn
      :human_content -> "Add human-readable content (overview, examples, API docs)"
      :separator -> "Add separator (---) and 'AI Navigation Metadata' heading"
      :module_identity -> "Add Module Identity JSON block"
      :architecture_diagram -> "Add Architecture Diagram (Mermaid)"
      :call_graph -> "Add Call Graph (YAML)"
      :anti_patterns -> "Add Anti-Patterns section"
      :search_keywords -> "Add Search Keywords (comma-separated)"
    end)
  end

  defp has_human_content?(moduledoc) do
    # Check for typical human content: Quick Start, Examples, etc.
    String.contains?(moduledoc, "Quick Start") or
      String.contains?(moduledoc, "## Examples") or
      String.contains?(moduledoc, "## Usage")
  end

  defp has_separator?(moduledoc) do
    # Check for separator: ---
    String.contains?(moduledoc, "---") and
      String.contains?(moduledoc, "AI Navigation Metadata")
  end

  defp has_module_identity?(moduledoc) do
    # Check for JSON block with module identity
    String.contains?(moduledoc, "\"module\"") and
      String.contains?(moduledoc, "\"purpose\"") and
      (String.contains?(moduledoc, "```json") or String.contains?(moduledoc, "```elixir"))
  end

  defp has_architecture_diagram?(moduledoc) do
    # Check for Mermaid diagram
    String.contains?(moduledoc, "```mermaid") and
      String.contains?(moduledoc, "graph")
  end

  defp has_call_graph?(moduledoc) do
    # Check for YAML call graph
    String.contains?(moduledoc, "calls_out:") or
      String.contains?(moduledoc, "called_by:")
  end

  defp has_anti_patterns?(moduledoc) do
    # Check for anti-patterns section
    String.contains?(moduledoc, "Anti-Pattern") or
      String.contains?(moduledoc, "❌ DO NOT")
  end

  defp has_search_keywords?(moduledoc) do
    # Check for search keywords (usually comma-separated at end)
    # Heuristic: Look for lines with multiple comma-separated lowercase-hyphenated words
    moduledoc
    |> String.split("\n")
    |> Enum.any?(fn line ->
      # Keywords line typically looks like: "llm-service, ai-call, claude, gemini"
      words = String.split(line, ",")
      length(words) >= 3 and Enum.all?(words, &String.contains?(&1, "-"))
    end)
  end

  defp build_recommendations(missing) do
    Enum.map(missing, fn item ->
      case item do
        :human_content -> "Add human-readable content at top (Quick Start, Examples, API list)"
        :separator -> "Add separator (---) and 'AI Navigation Metadata' heading"
        :module_identity -> "Add Module Identity JSON block"
        :architecture_diagram -> "Add Architecture Diagram (Mermaid)"
        :call_graph -> "Add Call Graph (YAML)"
        :anti_patterns -> "Add Anti-Patterns section"
        :search_keywords -> "Add Search Keywords (comma-separated)"
      end
    end)
  end
end
