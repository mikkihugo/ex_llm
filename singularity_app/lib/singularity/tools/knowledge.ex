defmodule Singularity.Tools.Knowledge do
  @moduledoc """
  Agent tools for knowledge discovery and pattern matching.

  Wraps existing knowledge capabilities:
  - PackageRegistryKnowledge - Package ecosystem search
  - PatternMiner - Code pattern search
  - FrameworkPatternStore - Framework patterns
  - CodeDeduplicator - Duplicate detection
  """

  require Logger

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
      knowledge_documentation_tool(),
      package_search_tool()
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

    documentation = generate_documentation_from_knowledge_base(doc_type, args)

    {:ok,
     %{
       query: query,
       doc_type: doc_type,
       format: format,
       include_examples: include_examples,
       documentation: documentation,
       status: "success"
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

  defp generate_documentation_from_knowledge_base(knowledge_type, args) do
    try do
      # Generate documentation based on knowledge type
      case knowledge_type do
        "api" -> generate_api_documentation(args)
        "tutorial" -> generate_tutorial_documentation(args)
        "reference" -> generate_reference_documentation(args)
        "guide" -> generate_guide_documentation(args)
        "architecture" -> generate_architecture_documentation(args)
        "patterns" -> generate_patterns_documentation(args)
        "frameworks" -> generate_frameworks_documentation(args)
        _ -> generate_generic_documentation(knowledge_type, args)
      end
    rescue
      error ->
        Logger.warning("Failed to generate documentation for #{knowledge_type}: #{inspect(error)}")
        "Documentation generation failed: #{inspect(error)}"
    end
  end

  defp generate_api_documentation(args) do
    # Generate API documentation from existing knowledge base
    format = Map.get(args, "format", "markdown")
    include_examples = Map.get(args, "include_examples", true)
    
    # Query existing API patterns and examples
    api_patterns = get_api_patterns_from_knowledge_base()
    api_examples = if include_examples, do: get_api_examples_from_knowledge_base(), else: []
    
    # Generate structured API documentation
    case format do
      "markdown" -> generate_markdown_api_doc(api_patterns, api_examples)
      "html" -> generate_html_api_doc(api_patterns, api_examples)
      "json" -> generate_json_api_doc(api_patterns, api_examples)
      _ -> generate_markdown_api_doc(api_patterns, api_examples)
    end
  end

  defp generate_tutorial_documentation(args) do
    # Generate tutorial documentation from existing knowledge base
    format = Map.get(args, "format", "markdown")
    topic = Map.get(args, "topic", "general")
    
    # Query existing tutorial patterns and examples
    tutorial_patterns = get_tutorial_patterns_from_knowledge_base(topic)
    tutorial_examples = get_tutorial_examples_from_knowledge_base(topic)
    
    # Generate structured tutorial documentation
    case format do
      "markdown" -> generate_markdown_tutorial_doc(topic, tutorial_patterns, tutorial_examples)
      "html" -> generate_html_tutorial_doc(topic, tutorial_patterns, tutorial_examples)
      "json" -> generate_json_tutorial_doc(topic, tutorial_patterns, tutorial_examples)
      _ -> generate_markdown_tutorial_doc(topic, tutorial_patterns, tutorial_examples)
    end
  end

  defp generate_reference_documentation(args) do
    # Generate reference documentation from existing knowledge base
    format = Map.get(args, "format", "markdown")
    reference_type = Map.get(args, "reference_type", "general")
    
    # Query existing reference patterns and examples
    reference_patterns = get_reference_patterns_from_knowledge_base(reference_type)
    reference_examples = get_reference_examples_from_knowledge_base(reference_type)
    
    # Generate structured reference documentation
    case format do
      "markdown" -> generate_markdown_reference_doc(reference_type, reference_patterns, reference_examples)
      "html" -> generate_html_reference_doc(reference_type, reference_patterns, reference_examples)
      "json" -> generate_json_reference_doc(reference_type, reference_patterns, reference_examples)
      _ -> generate_markdown_reference_doc(reference_type, reference_patterns, reference_examples)
    end
  end

  defp generate_guide_documentation(args) do
    # Generate guide documentation from existing knowledge base
    format = Map.get(args, "format", "markdown")
    guide_type = Map.get(args, "guide_type", "general")
    
    # Query existing guide patterns and examples
    guide_patterns = get_guide_patterns_from_knowledge_base(guide_type)
    guide_examples = get_guide_examples_from_knowledge_base(guide_type)
    
    # Generate structured guide documentation
    case format do
      "markdown" -> generate_markdown_guide_doc(guide_type, guide_patterns, guide_examples)
      "html" -> generate_html_guide_doc(guide_type, guide_patterns, guide_examples)
      "json" -> generate_json_guide_doc(guide_type, guide_patterns, guide_examples)
      _ -> generate_markdown_guide_doc(guide_type, guide_patterns, guide_examples)
    end
  end

  defp generate_architecture_documentation(args) do
    # Generate architecture documentation from existing knowledge base
    format = Map.get(args, "format", "markdown")
    architecture_type = Map.get(args, "architecture_type", "general")
    
    # Query existing architecture patterns and examples
    architecture_patterns = get_architecture_patterns_from_knowledge_base(architecture_type)
    architecture_examples = get_architecture_examples_from_knowledge_base(architecture_type)
    
    # Generate structured architecture documentation
    case format do
      "markdown" -> generate_markdown_architecture_doc(architecture_type, architecture_patterns, architecture_examples)
      "html" -> generate_html_architecture_doc(architecture_type, architecture_patterns, architecture_examples)
      "json" -> generate_json_architecture_doc(architecture_type, architecture_patterns, architecture_examples)
      _ -> generate_markdown_architecture_doc(architecture_type, architecture_patterns, architecture_examples)
    end
  end

  defp generate_patterns_documentation(args) do
    # Generate patterns documentation from existing knowledge base
    format = Map.get(args, "format", "markdown")
    pattern_type = Map.get(args, "pattern_type", "general")
    
    # Query existing patterns and examples
    patterns = get_patterns_from_knowledge_base(pattern_type)
    pattern_examples = get_pattern_examples_from_knowledge_base(pattern_type)
    
    # Generate structured patterns documentation
    case format do
      "markdown" -> generate_markdown_patterns_doc(pattern_type, patterns, pattern_examples)
      "html" -> generate_html_patterns_doc(pattern_type, patterns, pattern_examples)
      "json" -> generate_json_patterns_doc(pattern_type, patterns, pattern_examples)
      _ -> generate_markdown_patterns_doc(pattern_type, patterns, pattern_examples)
    end
  end

  defp generate_frameworks_documentation(args) do
    # Generate frameworks documentation from existing knowledge base
    format = Map.get(args, "format", "markdown")
    framework_type = Map.get(args, "framework_type", "general")
    
    # Query existing frameworks and examples
    frameworks = get_frameworks_from_knowledge_base(framework_type)
    framework_examples = get_framework_examples_from_knowledge_base(framework_type)
    
    # Generate structured frameworks documentation
    case format do
      "markdown" -> generate_markdown_frameworks_doc(framework_type, frameworks, framework_examples)
      "html" -> generate_html_frameworks_doc(framework_type, frameworks, framework_examples)
      "json" -> generate_json_frameworks_doc(framework_type, frameworks, framework_examples)
      _ -> generate_markdown_frameworks_doc(framework_type, frameworks, framework_examples)
    end
  end

  defp generate_generic_documentation(knowledge_type, args) do
    # Generate generic documentation for unknown knowledge types
    format = Map.get(args, "format", "markdown")
    
    # Query existing knowledge base for generic patterns
    generic_patterns = get_generic_patterns_from_knowledge_base(knowledge_type)
    generic_examples = get_generic_examples_from_knowledge_base(knowledge_type)
    
    # Generate structured generic documentation
    case format do
      "markdown" -> generate_markdown_generic_doc(knowledge_type, generic_patterns, generic_examples)
      "html" -> generate_html_generic_doc(knowledge_type, generic_patterns, generic_examples)
      "json" -> generate_json_generic_doc(knowledge_type, generic_patterns, generic_examples)
      _ -> generate_markdown_generic_doc(knowledge_type, generic_patterns, generic_examples)
    end
  end

  # Helper functions for knowledge base queries
  defp get_api_patterns_from_knowledge_base do
    # Query existing knowledge base for API patterns
    case Singularity.Code.Patterns.FrameworkPatternStore.search("API patterns", %{top_k: 10}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_api_examples_from_knowledge_base do
    # Query existing knowledge base for API examples
    case Singularity.Search.CodeSearch.search("API examples", %{top_k: 5}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_tutorial_patterns_from_knowledge_base(topic) do
    # Query existing knowledge base for tutorial patterns
    case Singularity.Code.Patterns.FrameworkPatternStore.search("tutorial patterns #{topic}", %{top_k: 8}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_tutorial_examples_from_knowledge_base(topic) do
    # Query existing knowledge base for tutorial examples
    case Singularity.Search.CodeSearch.search("tutorial examples #{topic}", %{top_k: 5}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_reference_patterns_from_knowledge_base(reference_type) do
    # Query existing knowledge base for reference patterns
    case Singularity.Code.Patterns.FrameworkPatternStore.search("reference patterns #{reference_type}", %{top_k: 8}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_reference_examples_from_knowledge_base(reference_type) do
    # Query existing knowledge base for reference examples
    case Singularity.Search.CodeSearch.search("reference examples #{reference_type}", %{top_k: 5}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_guide_patterns_from_knowledge_base(guide_type) do
    # Query existing knowledge base for guide patterns
    case Singularity.Code.Patterns.FrameworkPatternStore.search("guide patterns #{guide_type}", %{top_k: 8}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_guide_examples_from_knowledge_base(guide_type) do
    # Query existing knowledge base for guide examples
    case Singularity.Search.CodeSearch.search("guide examples #{guide_type}", %{top_k: 5}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_architecture_patterns_from_knowledge_base(architecture_type) do
    # Query existing knowledge base for architecture patterns
    case Singularity.Code.Patterns.FrameworkPatternStore.search("architecture patterns #{architecture_type}", %{top_k: 8}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_architecture_examples_from_knowledge_base(architecture_type) do
    # Query existing knowledge base for architecture examples
    case Singularity.Search.CodeSearch.search("architecture examples #{architecture_type}", %{top_k: 5}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_patterns_from_knowledge_base(pattern_type) do
    # Query existing knowledge base for patterns
    case Singularity.Code.Patterns.FrameworkPatternStore.search("patterns #{pattern_type}", %{top_k: 10}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_pattern_examples_from_knowledge_base(pattern_type) do
    # Query existing knowledge base for pattern examples
    case Singularity.Search.CodeSearch.search("pattern examples #{pattern_type}", %{top_k: 5}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_frameworks_from_knowledge_base(framework_type) do
    # Query existing knowledge base for frameworks
    case Singularity.Code.Patterns.FrameworkPatternStore.search("frameworks #{framework_type}", %{top_k: 10}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_framework_examples_from_knowledge_base(framework_type) do
    # Query existing knowledge base for framework examples
    case Singularity.Search.CodeSearch.search("framework examples #{framework_type}", %{top_k: 5}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_generic_patterns_from_knowledge_base(knowledge_type) do
    # Query existing knowledge base for generic patterns
    case Singularity.Code.Patterns.FrameworkPatternStore.search("patterns #{knowledge_type}", %{top_k: 8}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_generic_examples_from_knowledge_base(knowledge_type) do
    # Query existing knowledge base for generic examples
    case Singularity.Search.CodeSearch.search("examples #{knowledge_type}", %{top_k: 5}) do
      {:ok, results} -> results
      _ -> []
    end
  end

  # Documentation generation functions
  defp generate_markdown_api_doc(patterns, examples) do
    """
    # API Documentation
    
    ## Overview
    This document provides comprehensive API documentation generated from the knowledge base.
    
    ## API Patterns
    #{Enum.map_join(patterns, "\n", &format_pattern_markdown/1)}
    
    ## Examples
    #{Enum.map_join(examples, "\n", &format_example_markdown/1)}
    
    ## Generated at
    #{DateTime.utc_now() |> DateTime.to_iso8601()}
    """
  end

  defp generate_markdown_tutorial_doc(topic, patterns, examples) do
    """
    # Tutorial: #{topic}
    
    ## Overview
    This tutorial provides step-by-step guidance for #{topic}.
    
    ## Patterns
    #{Enum.map_join(patterns, "\n", &format_pattern_markdown/1)}
    
    ## Examples
    #{Enum.map_join(examples, "\n", &format_example_markdown/1)}
    
    ## Generated at
    #{DateTime.utc_now() |> DateTime.to_iso8601()}
    """
  end

  defp generate_markdown_reference_doc(reference_type, patterns, examples) do
    """
    # Reference: #{reference_type}
    
    ## Overview
    This reference document provides detailed information about #{reference_type}.
    
    ## Patterns
    #{Enum.map_join(patterns, "\n", &format_pattern_markdown/1)}
    
    ## Examples
    #{Enum.map_join(examples, "\n", &format_example_markdown/1)}
    
    ## Generated at
    #{DateTime.utc_now() |> DateTime.to_iso8601()}
    """
  end

  defp generate_markdown_guide_doc(guide_type, patterns, examples) do
    """
    # Guide: #{guide_type}
    
    ## Overview
    This guide provides comprehensive information about #{guide_type}.
    
    ## Patterns
    #{Enum.map_join(patterns, "\n", &format_pattern_markdown/1)}
    
    ## Examples
    #{Enum.map_join(examples, "\n", &format_example_markdown/1)}
    
    ## Generated at
    #{DateTime.utc_now() |> DateTime.to_iso8601()}
    """
  end

  defp generate_markdown_architecture_doc(architecture_type, patterns, examples) do
    """
    # Architecture: #{architecture_type}
    
    ## Overview
    This document describes the #{architecture_type} architecture patterns and practices.
    
    ## Patterns
    #{Enum.map_join(patterns, "\n", &format_pattern_markdown/1)}
    
    ## Examples
    #{Enum.map_join(examples, "\n", &format_example_markdown/1)}
    
    ## Generated at
    #{DateTime.utc_now() |> DateTime.to_iso8601()}
    """
  end

  defp generate_markdown_patterns_doc(pattern_type, patterns, examples) do
    """
    # Patterns: #{pattern_type}
    
    ## Overview
    This document describes #{pattern_type} patterns and their usage.
    
    ## Patterns
    #{Enum.map_join(patterns, "\n", &format_pattern_markdown/1)}
    
    ## Examples
    #{Enum.map_join(examples, "\n", &format_example_markdown/1)}
    
    ## Generated at
    #{DateTime.utc_now() |> DateTime.to_iso8601()}
    """
  end

  defp generate_markdown_frameworks_doc(framework_type, frameworks, examples) do
    """
    # Frameworks: #{framework_type}
    
    ## Overview
    This document describes #{framework_type} frameworks and their usage.
    
    ## Frameworks
    #{Enum.map_join(frameworks, "\n", &format_pattern_markdown/1)}
    
    ## Examples
    #{Enum.map_join(examples, "\n", &format_example_markdown/1)}
    
    ## Generated at
    #{DateTime.utc_now() |> DateTime.to_iso8601()}
    """
  end

  defp generate_markdown_generic_doc(knowledge_type, patterns, examples) do
    """
    # #{String.capitalize(knowledge_type)} Documentation
    
    ## Overview
    This document provides information about #{knowledge_type}.
    
    ## Patterns
    #{Enum.map_join(patterns, "\n", &format_pattern_markdown/1)}
    
    ## Examples
    #{Enum.map_join(examples, "\n", &format_example_markdown/1)}
    
    ## Generated at
    #{DateTime.utc_now() |> DateTime.to_iso8601()}
    """
  end

  defp format_pattern_markdown(pattern) do
    """
    ### #{Map.get(pattern, :pattern_name, "Unknown Pattern")}
    #{Map.get(pattern, :description, "No description available")}
    """
  end

  defp format_example_markdown(example) do
    """
    ### Example
    #{Map.get(example, :content, "No example available")}
    """
  end

  # HTML generation functions (simplified)
  defp generate_html_api_doc(patterns, examples) do
    "<html><body><h1>API Documentation</h1><p>Generated from knowledge base</p></body></html>"
  end

  defp generate_html_tutorial_doc(topic, patterns, examples) do
    "<html><body><h1>Tutorial: #{topic}</h1><p>Generated from knowledge base</p></body></html>"
  end

  defp generate_html_reference_doc(reference_type, patterns, examples) do
    "<html><body><h1>Reference: #{reference_type}</h1><p>Generated from knowledge base</p></body></html>"
  end

  defp generate_html_guide_doc(guide_type, patterns, examples) do
    "<html><body><h1>Guide: #{guide_type}</h1><p>Generated from knowledge base</p></body></html>"
  end

  defp generate_html_architecture_doc(architecture_type, patterns, examples) do
    "<html><body><h1>Architecture: #{architecture_type}</h1><p>Generated from knowledge base</p></body></html>"
  end

  defp generate_html_patterns_doc(pattern_type, patterns, examples) do
    "<html><body><h1>Patterns: #{pattern_type}</h1><p>Generated from knowledge base</p></body></html>"
  end

  defp generate_html_frameworks_doc(framework_type, frameworks, examples) do
    "<html><body><h1>Frameworks: #{framework_type}</h1><p>Generated from knowledge base</p></body></html>"
  end

  defp generate_html_generic_doc(knowledge_type, patterns, examples) do
    "<html><body><h1>#{String.capitalize(knowledge_type)} Documentation</h1><p>Generated from knowledge base</p></body></html>"
  end

  # JSON generation functions (simplified)
  defp generate_json_api_doc(patterns, examples) do
    Jason.encode!(%{type: "api", patterns: patterns, examples: examples, generated_at: DateTime.utc_now()})
  end

  defp generate_json_tutorial_doc(topic, patterns, examples) do
    Jason.encode!(%{type: "tutorial", topic: topic, patterns: patterns, examples: examples, generated_at: DateTime.utc_now()})
  end

  defp generate_json_reference_doc(reference_type, patterns, examples) do
    Jason.encode!(%{type: "reference", reference_type: reference_type, patterns: patterns, examples: examples, generated_at: DateTime.utc_now()})
  end

  defp generate_json_guide_doc(guide_type, patterns, examples) do
    Jason.encode!(%{type: "guide", guide_type: guide_type, patterns: patterns, examples: examples, generated_at: DateTime.utc_now()})
  end

  defp generate_json_architecture_doc(architecture_type, patterns, examples) do
    Jason.encode!(%{type: "architecture", architecture_type: architecture_type, patterns: patterns, examples: examples, generated_at: DateTime.utc_now()})
  end

  defp generate_json_patterns_doc(pattern_type, patterns, examples) do
    Jason.encode!(%{type: "patterns", pattern_type: pattern_type, patterns: patterns, examples: examples, generated_at: DateTime.utc_now()})
  end

  defp generate_json_frameworks_doc(framework_type, frameworks, examples) do
    Jason.encode!(%{type: "frameworks", framework_type: framework_type, frameworks: frameworks, examples: examples, generated_at: DateTime.utc_now()})
  end

  defp generate_json_generic_doc(knowledge_type, patterns, examples) do
    Jason.encode!(%{type: "generic", knowledge_type: knowledge_type, patterns: patterns, examples: examples, generated_at: DateTime.utc_now()})
  end

  defp package_search_tool do
    Tool.new!(%{
      name: "package_search",
      description: "Search for packages across ecosystems via NATS service with real database data",
      display_text: "Package Search (NATS)",
      parameters: [
        %{name: "query", type: :string, required: true, description: "Search query for packages"},
        %{
          name: "ecosystem",
          type: :string,
          required: false,
          description: "Ecosystem: 'npm', 'cargo', 'hex', 'pypi', or 'all' (default: 'all')"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Max results (default: 10)"
        }
      ],
      execute: fn params ->
        query = Map.get(params, "query", "")
        ecosystem = Map.get(params, "ecosystem", "all") |> String.to_atom()
        limit = Map.get(params, "limit", 10)
        
        case Singularity.Tools.PackageSearch.search_packages(query, ecosystem, limit) do
          {:ok, results} -> {:ok, results}
          {:error, reason} -> {:error, reason}
        end
      end
    })
  end
end
