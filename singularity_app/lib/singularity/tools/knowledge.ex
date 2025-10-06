defmodule Singularity.Tools.Knowledge do
  @moduledoc """
  Agent tools for knowledge discovery and pattern matching.

  Wraps existing knowledge capabilities:
  - PackageRegistryKnowledge - Package ecosystem search
  - PatternMiner - Code pattern search
  - FrameworkPatternStore - Framework patterns
  - CodeDeduplicator - Duplicate detection
  """

  alias Singularity.Tools.Tool
  alias Singularity.Search.PackageRegistryKnowledge
  alias Singularity.Code.Patterns.PatternMiner
  alias Singularity.Detection.FrameworkPatternStore
  alias Singularity.Code.Quality.CodeDeduplicator

  @doc "Register knowledge tools with the shared registry."
  def register(provider) do
    Singularity.Tools.Catalog.add_tools(provider, [
      knowledge_packages_tool(),
      knowledge_patterns_tool(),
      knowledge_frameworks_tool(),
      knowledge_examples_tool(),
      knowledge_duplicates_tool(),
      knowledge_documentation_tool()
    ])
  end

  defp knowledge_packages_tool do
    Tool.new!(%{
      name: "knowledge_packages",
      description: "Search package registries (npm, cargo, hex, pypi) for libraries and tools.",
      display_text: "Package Search",
      parameters: [
        %{name: "query", type: :string, required: true, description: "Search query for packages"},
        %{
          name: "ecosystem",
          type: :string,
          required: false,
          description: "Ecosystem: 'npm', 'cargo', 'hex', 'pypi' (optional)"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Max results (default: 10)"
        },
        %{
          name: "include_examples",
          type: :boolean,
          required: false,
          description: "Include usage examples (default: true)"
        }
      ],
      function: &knowledge_packages/2
    })
  end

  defp knowledge_patterns_tool do
    Tool.new!(%{
      name: "knowledge_patterns",
      description: "Find code patterns and templates from existing codebases.",
      display_text: "Pattern Search",
      parameters: [
        %{
          name: "query",
          type: :string,
          required: true,
          description: "Pattern description or search query"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Programming language filter (optional)"
        },
        %{
          name: "pattern_type",
          type: :string,
          required: false,
          description: "Type: 'semantic', 'structural', 'behavioral' (default: 'semantic')"
        },
        %{name: "limit", type: :integer, required: false, description: "Max results (default: 5)"}
      ],
      function: &knowledge_patterns/2
    })
  end

  defp knowledge_frameworks_tool do
    Tool.new!(%{
      name: "knowledge_frameworks",
      description: "Search framework patterns and best practices.",
      display_text: "Framework Patterns",
      parameters: [
        %{
          name: "query",
          type: :string,
          required: true,
          description: "Framework or pattern search query"
        },
        %{
          name: "framework",
          type: :string,
          required: false,
          description: "Specific framework: 'react', 'phoenix', 'actix', 'django' (optional)"
        },
        %{
          name: "category",
          type: :string,
          required: false,
          description: "Category: 'routing', 'auth', 'database', 'api' (optional)"
        },
        %{name: "limit", type: :integer, required: false, description: "Max results (default: 5)"}
      ],
      function: &knowledge_frameworks/2
    })
  end

  defp knowledge_examples_tool do
    Tool.new!(%{
      name: "knowledge_examples",
      description: "Find code examples and usage patterns from package registries.",
      display_text: "Code Examples",
      parameters: [
        %{
          name: "package_name",
          type: :string,
          required: true,
          description: "Package name to find examples for"
        },
        %{
          name: "ecosystem",
          type: :string,
          required: false,
          description: "Ecosystem: 'npm', 'cargo', 'hex', 'pypi' (optional)"
        },
        %{
          name: "example_type",
          type: :string,
          required: false,
          description: "Type: 'basic', 'advanced', 'integration' (default: 'basic')"
        },
        %{name: "limit", type: :integer, required: false, description: "Max results (default: 3)"}
      ],
      function: &knowledge_examples/2
    })
  end

  defp knowledge_duplicates_tool do
    Tool.new!(%{
      name: "knowledge_duplicates",
      description: "Find duplicate or similar code patterns in the codebase.",
      display_text: "Duplicate Detection",
      parameters: [
        %{
          name: "codebase_path",
          type: :string,
          required: true,
          description: "Path to codebase to analyze"
        },
        %{
          name: "similarity_threshold",
          type: :number,
          required: false,
          description: "Similarity threshold 0.0-1.0 (default: 0.8)"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Programming language filter (optional)"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Max results (default: 10)"
        }
      ],
      function: &knowledge_duplicates/2
    })
  end

  defp knowledge_documentation_tool do
    Tool.new!(%{
      name: "knowledge_documentation",
      description: "Generate or find documentation for code, patterns, or frameworks.",
      display_text: "Documentation",
      parameters: [
        %{
          name: "query",
          type: :string,
          required: true,
          description: "What to document or search for"
        },
        %{
          name: "doc_type",
          type: :string,
          required: false,
          description: "Type: 'api', 'tutorial', 'reference', 'guide' (default: 'api')"
        },
        %{
          name: "format",
          type: :string,
          required: false,
          description: "Format: 'markdown', 'html', 'plain' (default: 'markdown')"
        },
        %{
          name: "include_examples",
          type: :boolean,
          required: false,
          description: "Include code examples (default: true)"
        }
      ],
      function: &knowledge_documentation/2
    })
  end

  # Tool implementations

  def knowledge_packages(%{"query" => query} = args, _ctx) do
    ecosystem = Map.get(args, "ecosystem")
    limit = Map.get(args, "limit", 10)
    include_examples = Map.get(args, "include_examples", true)

    case PackageRegistryKnowledge.search(query, ecosystem: ecosystem, limit: limit) do
      {:ok, packages} ->
        enhanced_packages =
          if include_examples do
            Enum.map(packages, fn package ->
              case PackageRegistryKnowledge.search_examples(package.name, ecosystem: ecosystem) do
                {:ok, examples} -> Map.put(package, :examples, examples)
                _ -> package
              end
            end)
          else
            packages
          end

        {:ok,
         %{
           query: query,
           ecosystem: ecosystem,
           packages: enhanced_packages,
           count: length(enhanced_packages)
         }}

      {:error, reason} ->
        {:error, "Package search failed: #{inspect(reason)}"}
    end
  end

  def knowledge_patterns(%{"query" => query} = args, _ctx) do
    language = Map.get(args, "language")
    pattern_type = Map.get(args, "pattern_type", "semantic")
    limit = Map.get(args, "limit", 5)

    case PatternMiner.search_semantic_patterns(query,
           language: language,
           type: pattern_type,
           limit: limit
         ) do
      {:ok, patterns} ->
        {:ok,
         %{
           query: query,
           language: language,
           pattern_type: pattern_type,
           patterns: patterns,
           count: length(patterns)
         }}

      {:error, reason} ->
        {:error, "Pattern search failed: #{inspect(reason)}"}
    end
  end

  def knowledge_frameworks(%{"query" => query} = args, _ctx) do
    framework = Map.get(args, "framework")
    category = Map.get(args, "category")
    limit = Map.get(args, "limit", 5)

    case FrameworkPatternStore.search_similar_patterns(query, top_k: limit) do
      {:ok, patterns} ->
        filtered_patterns =
          patterns
          |> maybe_filter_by_framework(framework)
          |> maybe_filter_by_category(category)

        {:ok,
         %{
           query: query,
           framework: framework,
           category: category,
           patterns: filtered_patterns,
           count: length(filtered_patterns)
         }}

      {:error, reason} ->
        {:error, "Framework pattern search failed: #{inspect(reason)}"}
    end
  end

  def knowledge_examples(%{"package_name" => package_name} = args, _ctx) do
    ecosystem = Map.get(args, "ecosystem")
    example_type = Map.get(args, "example_type", "basic")
    limit = Map.get(args, "limit", 3)

    case PackageRegistryKnowledge.search_examples(package_name,
           ecosystem: ecosystem,
           type: example_type,
           limit: limit
         ) do
      {:ok, examples} ->
        {:ok,
         %{
           package_name: package_name,
           ecosystem: ecosystem,
           example_type: example_type,
           examples: examples,
           count: length(examples)
         }}

      {:error, reason} ->
        {:error, "Example search failed: #{inspect(reason)}"}
    end
  end

  def knowledge_duplicates(%{"codebase_path" => path} = args, _ctx) do
    similarity_threshold = Map.get(args, "similarity_threshold", 0.8)
    language = Map.get(args, "language")
    limit = Map.get(args, "limit", 10)

    case CodeDeduplicator.find_duplicates(path,
           similarity_threshold: similarity_threshold,
           language: language,
           limit: limit
         ) do
      {:ok, duplicates} ->
        {:ok,
         %{
           codebase_path: path,
           similarity_threshold: similarity_threshold,
           language: language,
           duplicates: duplicates,
           count: length(duplicates)
         }}

      {:error, reason} ->
        {:error, "Duplicate detection failed: #{inspect(reason)}"}
    end
  end

  def knowledge_documentation(%{"query" => query} = args, _ctx) do
    doc_type = Map.get(args, "doc_type", "api")
    format = Map.get(args, "format", "markdown")
    include_examples = Map.get(args, "include_examples", true)

    # This would integrate with documentation generation
    # For now, return a structured response
    {:ok,
     %{
       query: query,
       doc_type: doc_type,
       format: format,
       include_examples: include_examples,
       documentation: "Documentation generation not yet implemented",
       status: "placeholder"
     }}
  end

  # Helper functions

  defp maybe_filter_by_framework(patterns, nil), do: patterns

  defp maybe_filter_by_framework(patterns, framework) do
    Enum.filter(patterns, fn pattern ->
      String.contains?(String.downcase(pattern.framework || ""), String.downcase(framework))
    end)
  end

  defp maybe_filter_by_category(patterns, nil), do: patterns

  defp maybe_filter_by_category(patterns, category) do
    Enum.filter(patterns, fn pattern ->
      String.contains?(String.downcase(pattern.category || ""), String.downcase(category))
    end)
  end
end
