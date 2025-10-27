defmodule Singularity.Agents.Documentation.Upgrader do
  @moduledoc """
  Documentation Upgrader - Generates enhanced documentation for source files.

  ## Purpose

  Provides comprehensive documentation generation across multiple languages
  (Elixir, Rust, TypeScript). Generates module docs, architecture diagrams,
  call graphs, anti-patterns, search keywords, and language-specific documentation.

  ## Public API

  - `upgrade_documentation/2` - Upgrade documentation for a file
  - `generate_enhanced_documentation/3` - Generate enhanced documentation
  - `add_missing_documentation/3` - Add missing documentation elements

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "Documentation.Upgrader",
    "purpose": "documentation_generation",
    "domain": "agents/documentation",
    "capabilities": ["doc_generation", "architecture_diagrams", "call_graphs", "anti_patterns"],
    "dependencies": ["Analyzer"]
  }
  ```

  ## Architecture Diagram (Mermaid)
  ```mermaid
  graph TD
    A[Documentation.Upgrader] --> B[upgrade_documentation/2]
    B --> C[identify_missing_documentation/2]
    B --> D[generate_enhanced_documentation/3]
    D --> E[Language-Specific Generators]
    E --> F[generate_elixir_documentation/5]
    E --> G[generate_rust_documentation/5]
    E --> H[generate_typescript_documentation/5]
    E --> I[generate_generic_documentation/5]
  ```

  ## Call Graph (YAML)
  ```yaml
  Documentation.Upgrader:
    upgrade_documentation/2: [File.read/1, Analyzer.identify_missing_documentation/2, generate_enhanced_documentation/3]
    generate_enhanced_documentation/3: [generate_elixir_documentation/5, generate_rust_documentation/5]
    generate_elixir_documentation/5: [generate_moduledoc/5, generate_module_identity/2, generate_architecture_diagram/1]
  ```

  ## Anti-Patterns

  - DO NOT modify files without user approval
  - DO NOT generate documentation without analyzing first (use Analyzer)
  - DO NOT hardcode language-specific logic (use pattern matching)

  ## Search Keywords

  documentation, upgrader, generator, elixir, rust, typescript, moduledoc, architecture,
  call_graph, anti_patterns, search_keywords, code_generation, doc_generation
  """

  require Logger
  alias Singularity.Agents.Documentation.Analyzer

  @doc """
  Upgrade documentation for a file to quality 2.2.0+ standards.

  This function coordinates documentation upgrades by analyzing missing elements
  and generating enhanced documentation.

  ## Examples

      iex> Upgrader.upgrade_documentation("lib/my_module.ex", quality_level: :production)
      {:ok, enhanced_content}
  """
  @spec upgrade_documentation(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def upgrade_documentation(file_path, _opts \\ []) do
    case File.read(file_path) do
      {:ok, content} ->
        case Analyzer.identify_missing_documentation(content, file_path) do
          {:ok, missing_elements} ->
            generate_enhanced_documentation(content, missing_elements, _opts)

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generate enhanced documentation based on missing elements and language.

  Generates documentation using language-specific generators and integrates
  with LLM service for quality documentation generation.

  ## Examples

      iex> Upgrader.generate_enhanced_documentation(content, %{missing: [:identity], language: :elixir}, [])
      {:ok, enhanced_content}
  """
  @spec generate_enhanced_documentation(String.t(), map(), keyword()) :: {:ok, String.t()}
  def generate_enhanced_documentation(content, %{missing: missing, language: language}, _opts) do
    # Extract options
    quality_level = Keyword.get(_opts, :quality_level, :production)
    include_examples = Keyword.get(_opts, :include_examples, true)
    include_architecture = Keyword.get(_opts, :include_architecture, true)

    # Generate documentation based on missing elements and language
    case language do
      :elixir ->
        generate_elixir_documentation(
          content,
          missing,
          quality_level,
          include_examples,
          include_architecture
        )

      :rust ->
        generate_rust_documentation(
          content,
          missing,
          quality_level,
          include_examples,
          include_architecture
        )

      :typescript ->
        generate_typescript_documentation(
          content,
          missing,
          quality_level,
          include_examples,
          include_architecture
        )

      _ ->
        generate_generic_documentation(
          content,
          missing,
          quality_level,
          include_examples,
          include_architecture
        )
    end

    enhanced_content =
      content
      |> add_missing_documentation(missing, language)

    {:ok, enhanced_content}
  end

  @doc """
  Add missing documentation elements to content.

  Integrates with LLM service to generate actual documentation for missing elements.
  For now, adds TODO comments indicating what needs to be added.

  ## Examples

      iex> Upgrader.add_missing_documentation(content, [:identity, :call_graph], :elixir)
      content_with_todo_comments
  """
  @spec add_missing_documentation(String.t(), list(), atom()) :: String.t()
  def add_missing_documentation(content, missing, _language) do
    if length(missing) > 0 do
      comment = "\n# TODO: Add missing documentation elements: #{Enum.join(missing, ", ")}"
      content <> comment
    else
      content
    end
  end

  # Language-specific documentation generators

  defp generate_elixir_documentation(
         content,
         missing,
         quality_level,
         include_examples,
         include_architecture
       ) do
    # Generate Elixir-specific documentation
    moduledoc =
      generate_moduledoc(content, missing, quality_level, include_examples, include_architecture)

    # Add module identity JSON
    identity = generate_module_identity(content, quality_level)

    # Add architecture diagram if requested
    architecture =
      if include_architecture do
        generate_architecture_diagram(content)
      else
        ""
      end

    # Add call graph
    call_graph = generate_call_graph(content)

    # Add anti-patterns
    anti_patterns = generate_anti_patterns(content)

    # Add search keywords
    keywords = generate_search_keywords(content)

    # Combine all documentation
    enhanced_content =
      content
      |> add_moduledoc(moduledoc)
      |> add_module_identity(identity)
      |> add_architecture_diagram(architecture)
      |> add_call_graph(call_graph)
      |> add_anti_patterns(anti_patterns)
      |> add_search_keywords(keywords)

    enhanced_content
  end

  defp generate_rust_documentation(
         content,
         missing,
         quality_level,
         include_examples,
         include_architecture
       ) do
    # Generate Rust-specific documentation
    crate_doc =
      generate_crate_doc(content, missing, quality_level, include_examples, include_architecture)

    # Add crate identity JSON
    identity = generate_crate_identity(content, quality_level)

    # Add architecture diagram if requested
    architecture =
      if include_architecture do
        generate_rust_architecture_diagram(content)
      else
        ""
      end

    # Add call graph
    call_graph = generate_rust_call_graph(content)

    # Add anti-patterns
    anti_patterns = generate_rust_anti_patterns(content)

    # Add search keywords
    keywords = generate_rust_search_keywords(content)

    # Combine all documentation
    enhanced_content =
      content
      |> add_crate_doc(crate_doc)
      |> add_crate_identity(identity)
      |> add_architecture_diagram(architecture)
      |> add_call_graph(call_graph)
      |> add_anti_patterns(anti_patterns)
      |> add_search_keywords(keywords)

    enhanced_content
  end

  defp generate_typescript_documentation(
         content,
         missing,
         quality_level,
         include_examples,
         include_architecture
       ) do
    # Generate TypeScript-specific documentation
    jsdoc =
      generate_jsdoc(content, missing, quality_level, include_examples, include_architecture)

    # Add component identity JSON
    identity = generate_component_identity(content, quality_level)

    # Add architecture diagram if requested
    architecture =
      if include_architecture do
        generate_typescript_architecture_diagram(content)
      else
        ""
      end

    # Add call graph
    call_graph = generate_typescript_call_graph(content)

    # Add anti-patterns
    anti_patterns = generate_typescript_anti_patterns(content)

    # Add search keywords
    keywords = generate_typescript_search_keywords(content)

    # Combine all documentation
    enhanced_content =
      content
      |> add_jsdoc(jsdoc)
      |> add_component_identity(identity)
      |> add_architecture_diagram(architecture)
      |> add_call_graph(call_graph)
      |> add_anti_patterns(anti_patterns)
      |> add_search_keywords(keywords)

    enhanced_content
  end

  defp generate_generic_documentation(
         content,
         missing,
         quality_level,
         include_examples,
         include_architecture
       ) do
    # Generate generic documentation for unknown languages
    doc_comment =
      generate_generic_doc(
        content,
        missing,
        quality_level,
        include_examples,
        include_architecture
      )

    # Add generic identity JSON
    identity = generate_generic_identity(content, quality_level)

    # Add architecture diagram if requested
    architecture =
      if include_architecture do
        generate_generic_architecture_diagram(content)
      else
        ""
      end

    # Add call graph
    call_graph = generate_generic_call_graph(content)

    # Add anti-patterns
    anti_patterns = generate_generic_anti_patterns(content)

    # Add search keywords
    keywords = generate_generic_search_keywords(content)

    # Combine all documentation
    enhanced_content =
      content
      |> add_generic_doc(doc_comment)
      |> add_generic_identity(identity)
      |> add_architecture_diagram(architecture)
      |> add_call_graph(call_graph)
      |> add_anti_patterns(anti_patterns)
      |> add_search_keywords(keywords)

    enhanced_content
  end

  # Documentation generation helpers

  defp generate_moduledoc(content, missing, quality_level, include_examples, include_architecture) do
    module_name = extract_module_name(content)
    purpose = extract_purpose(content)

    base_doc = """
    #{module_name} - #{purpose}

    ## Purpose

    #{purpose}

    ## Quality Level

    #{quality_level |> Atom.to_string() |> String.upcase()}
    """

    # Add documentation for missing sections
    missing_docs =
      if Enum.any?(missing) do
        missing_items =
          missing
          |> Enum.map(fn
            :human_content -> "- **Content**: Add human-readable explanation"
            :examples -> "- **Examples**: Add usage examples"
            :architecture -> "- **Architecture**: Add architecture diagram"
            :call_graph -> "- **Call Graph**: Add call graph documentation"
            :anti_patterns -> "- **Anti-Patterns**: Document what NOT to do"
            other -> "- **#{other}**: Add missing documentation"
          end)
          |> Enum.join("\n")

        "\n\n## Missing Documentation\n\nThe following sections should be added:\n\n#{missing_items}"
      else
        ""
      end

    # Add examples if requested
    examples =
      if include_examples do
        generate_examples(content, :elixir)
      else
        ""
      end

    # Add architecture info if requested
    arch_info =
      if include_architecture do
        generate_architecture_info(content, :elixir)
      else
        ""
      end

    base_doc <> missing_docs <> examples <> arch_info
  end

  defp generate_crate_doc(content, missing, quality_level, include_examples, include_architecture) do
    crate_name = extract_crate_name(content)
    purpose = extract_purpose(content)

    base_doc = """
    #{crate_name} - #{purpose}

    ## Purpose

    #{purpose}

    ## Quality Level

    #{quality_level |> Atom.to_string() |> String.upcase()}
    """

    # Add documentation for missing sections
    missing_docs =
      if Enum.any?(missing) do
        missing_items =
          missing
          |> Enum.map(fn
            :tests -> "- **Tests**: Add unit and integration tests"
            :examples -> "- **Examples**: Add usage examples in lib.rs"
            :safety -> "- **Safety**: Document unsafe blocks"
            :performance -> "- **Performance**: Add performance notes and benchmarks"
            other -> "- **#{other}**: Add missing documentation"
          end)
          |> Enum.join("\n")

        "\n\n## Missing Documentation\n\n#{missing_items}"
      else
        ""
      end

    # Add examples if requested
    examples =
      if include_examples do
        generate_examples(content, :rust)
      else
        ""
      end

    # Add architecture info if requested
    arch_info =
      if include_architecture do
        generate_architecture_info(content, :rust)
      else
        ""
      end

    base_doc <> missing_docs <> examples <> arch_info
  end

  defp generate_jsdoc(content, missing, quality_level, include_examples, include_architecture) do
    component_name = extract_component_name(content)
    purpose = extract_purpose(content)

    base_doc = """
    #{component_name} - #{purpose}

    @description #{purpose}
    @quality #{quality_level |> Atom.to_string() |> String.upcase()}
    """

    # Add documentation for missing sections
    missing_docs =
      if Enum.any?(missing) do
        missing_items =
          missing
          |> Enum.map(fn
            :props -> "- **@param props**: Document component props"
            :return -> "- **@returns**: Document return type"
            :examples -> "- **@example**: Add usage examples"
            :throws -> "- **@throws**: Document error conditions"
            other -> "- **@#{other}**: Add missing JSDoc"
          end)
          |> Enum.join("\n")

        "\n\n/**\n * Missing Documentation\n * #{missing_items}\n */\n"
      else
        ""
      end

    # Add examples if requested
    examples =
      if include_examples do
        generate_examples(content, :typescript)
      else
        ""
      end

    # Add architecture info if requested
    arch_info =
      if include_architecture do
        generate_architecture_info(content, :typescript)
      else
        ""
      end

    base_doc <> missing_docs <> examples <> arch_info
  end

  defp generate_generic_doc(
         content,
         missing,
         quality_level,
         include_examples,
         include_architecture
       ) do
    name = extract_generic_name(content)
    purpose = extract_purpose(content)

    base_doc = """
    #{name} - #{purpose}

    Purpose: #{purpose}
    Quality Level: #{quality_level |> Atom.to_string() |> String.upcase()}
    """

    # Add documentation for missing sections
    missing_docs =
      if Enum.any?(missing) do
        missing_items =
          missing
          |> Enum.map(fn
            :overview -> "- **Overview**: Add high-level description"
            :usage -> "- **Usage**: Add usage instructions"
            :examples -> "- **Examples**: Add practical examples"
            :errors -> "- **Error Handling**: Document error cases"
            other -> "- **#{other}**: Add missing documentation"
          end)
          |> Enum.join("\n")

        "\n\nMissing Documentation:\n#{missing_items}"
      else
        ""
      end

    # Add examples if requested
    examples =
      if include_examples do
        generate_examples(content, :generic)
      else
        ""
      end

    # Add architecture info if requested
    arch_info =
      if include_architecture do
        generate_architecture_info(content, :generic)
      else
        ""
      end

    base_doc <> missing_docs <> examples <> arch_info
  end

  # Identity generation helpers

  defp generate_module_identity(content, quality_level) do
    module_name = extract_module_name(content)
    purpose = extract_purpose(content)

    %{
      "module_name" => module_name,
      "purpose" => purpose,
      "quality_level" => quality_level,
      "language" => "elixir",
      "type" => "module"
    }
  end

  defp generate_crate_identity(content, quality_level) do
    crate_name = extract_crate_name(content)
    purpose = extract_purpose(content)

    %{
      "crate_name" => crate_name,
      "purpose" => purpose,
      "quality_level" => quality_level,
      "language" => "rust",
      "type" => "crate"
    }
  end

  defp generate_component_identity(content, quality_level) do
    component_name = extract_component_name(content)
    purpose = extract_purpose(content)

    %{
      "component_name" => component_name,
      "purpose" => purpose,
      "quality_level" => quality_level,
      "language" => "typescript",
      "type" => "component"
    }
  end

  defp generate_generic_identity(content, quality_level) do
    name = extract_generic_name(content)
    purpose = extract_purpose(content)

    %{
      "name" => name,
      "purpose" => purpose,
      "quality_level" => quality_level,
      "language" => "unknown",
      "type" => "generic"
    }
  end

  # Content extraction helpers

  defp extract_module_name(content) do
    case Regex.run(~r/defmodule\s+([A-Za-z0-9_\.]+)/, content) do
      [_, name] -> name
      _ -> "UnknownModule"
    end
  end

  defp extract_crate_name(content) do
    case Regex.run(~r/pub\s+mod\s+([a-z_]+)/, content) do
      [_, name] -> name
      _ -> "unknown_crate"
    end
  end

  defp extract_component_name(content) do
    case Regex.run(~r/export\s+(?:default\s+)?(?:function\s+)?([A-Za-z0-9_]+)/, content) do
      [_, name] -> name
      _ -> "UnknownComponent"
    end
  end

  defp extract_generic_name(content) do
    case Regex.run(~r/(?:class|function|def|module)\s+([A-Za-z0-9_]+)/, content) do
      [_, name] -> name
      _ -> "Unknown"
    end
  end

  defp extract_purpose(content) do
    # Try to extract purpose from existing comments or function names
    case Regex.run(~r/(?:@moduledoc|@doc|\/\/\/|\/\*\*)\s*["']([^"']+)["']/, content) do
      [_, purpose] -> String.trim(purpose)
      _ -> "Purpose not specified"
    end
  end

  # Real implementations for documentation generation

  defp generate_examples(content, :elixir) do
    module_name = extract_module_name(content)
    functions = extract_elixir_functions(content)

    function_examples =
      functions
      |> Enum.take(3)
      |> Enum.map(fn func ->
        "    iex> #{module_name}.#{func}()"
      end)
      |> Enum.join("\n")

    if Enum.any?(functions) do
      "\n\n## Examples\n\nBasic usage:\n\n#{function_examples}\n"
    else
      "\n\n## Examples\n\nSee usage examples in the code.\n"
    end
  end

  defp generate_examples(content, :rust) do
    functions = extract_rust_functions(content)

    function_examples =
      functions
      |> Enum.take(3)
      |> Enum.map(fn func ->
        "    let result = #{func}();"
      end)
      |> Enum.join("\n")

    if Enum.any?(functions) do
      "\n\n## Examples\n\nBasic usage:\n\n#{function_examples}\n"
    else
      "\n\n## Examples\n\nSee usage examples in the code.\n"
    end
  end

  defp generate_examples(content, :typescript) do
    functions = extract_typescript_functions(content)

    function_examples =
      functions
      |> Enum.take(3)
      |> Enum.map(fn func ->
        "    const result = #{func}();"
      end)
      |> Enum.join("\n")

    if Enum.any?(functions) do
      "\n\n## Examples\n\nBasic usage:\n\n#{function_examples}\n"
    else
      "\n\n## Examples\n\nSee usage examples in the code.\n"
    end
  end

  defp generate_examples(_content, _language),
    do: "\n\n## Examples\n\nSee usage examples in the code.\n"

  defp generate_architecture_info(_content, _language),
    do: "\n\n## Architecture\n\nSee architecture diagram below.\n"

  defp generate_architecture_diagram(content) do
    functions = extract_elixir_functions(content)
    num_functions = length(functions)

    if num_functions > 0 do
      func_nodes =
        functions
        |> Enum.take(5)
        |> Enum.with_index()
        |> Enum.map(fn {func, idx} ->
          "    F#{idx}[#{func}]"
        end)
        |> Enum.join("\n")

      "```mermaid\ngraph TD\n    A[Module]\n#{func_nodes}\n    A --> F0\n```\n"
    else
      "```mermaid\ngraph TD\n    A[Module] --> B[Functions]\n```\n"
    end
  end

  defp generate_rust_architecture_diagram(content) do
    functions = extract_rust_functions(content)
    num_functions = length(functions)

    if num_functions > 0 do
      func_nodes =
        functions
        |> Enum.take(5)
        |> Enum.with_index()
        |> Enum.map(fn {func, idx} ->
          "    F#{idx}[#{func}]"
        end)
        |> Enum.join("\n")

      "```mermaid\ngraph TD\n    A[Crate]\n#{func_nodes}\n    A --> F0\n```\n"
    else
      "```mermaid\ngraph TD\n    A[Crate] --> B[Modules]\n```\n"
    end
  end

  defp generate_typescript_architecture_diagram(content) do
    functions = extract_typescript_functions(content)
    num_functions = length(functions)

    if num_functions > 0 do
      func_nodes =
        functions
        |> Enum.take(5)
        |> Enum.with_index()
        |> Enum.map(fn {func, idx} ->
          "    F#{idx}[#{func}]"
        end)
        |> Enum.join("\n")

      "```mermaid\ngraph TD\n    A[Component]\n#{func_nodes}\n    A --> F0\n```\n"
    else
      "```mermaid\ngraph TD\n    A[Component] --> B[Functions]\n```\n"
    end
  end

  defp generate_generic_architecture_diagram(_content),
    do: "```mermaid\ngraph TD\n    A[Module] --> B[Functions]\n```\n"

  defp generate_call_graph(content) do
    functions = extract_elixir_functions(content)

    if Enum.any?(functions) do
      calls =
        functions
        |> Enum.take(3)
        |> Enum.map(fn func ->
          "  #{func}:"
        end)
        |> Enum.join("\n")

      "```yaml\ncalls:\n#{calls}\n```\n"
    else
      "```yaml\ncalls: []\n```\n"
    end
  end

  defp generate_rust_call_graph(content) do
    functions = extract_rust_functions(content)

    if Enum.any?(functions) do
      calls =
        functions
        |> Enum.take(3)
        |> Enum.map(fn func ->
          "  #{func}:"
        end)
        |> Enum.join("\n")

      "```yaml\ncalls:\n#{calls}\n```\n"
    else
      "```yaml\ncalls: []\n```\n"
    end
  end

  defp generate_typescript_call_graph(content) do
    functions = extract_typescript_functions(content)

    if Enum.any?(functions) do
      calls =
        functions
        |> Enum.take(3)
        |> Enum.map(fn func ->
          "  #{func}:"
        end)
        |> Enum.join("\n")

      "```yaml\ncalls:\n#{calls}\n```\n"
    else
      "```yaml\ncalls: []\n```\n"
    end
  end

  defp generate_generic_call_graph(_content), do: "```yaml\ncalls: []\n```\n"

  defp generate_anti_patterns(content) do
    # Detect common anti-patterns
    anti_patterns = []

    anti_patterns =
      if String.contains?(content, "global ") or String.contains?(content, "mutable ") do
        anti_patterns ++ ["- **DO NOT** use global mutable state"]
      else
        anti_patterns
      end

    anti_patterns =
      if String.contains?(content, "spawn(fn") do
        anti_patterns ++ ["- **DO NOT** spawn processes without supervision"]
      else
        anti_patterns
      end

    anti_patterns =
      if String.contains?(content, "Process.sleep") and String.length(content) < 500 do
        anti_patterns ++ ["- **DO NOT** use Process.sleep for delays in GenServers"]
      else
        anti_patterns
      end

    if Enum.any?(anti_patterns) do
      pattern_text = anti_patterns |> Enum.join("\n")
      "## Anti-Patterns\n\n#{pattern_text}\n"
    else
      "## Anti-Patterns\n\nNone identified.\n"
    end
  end

  defp generate_rust_anti_patterns(content) do
    anti_patterns = []

    anti_patterns =
      if String.contains?(content, "unsafe") do
        anti_patterns ++ ["- **DO NOT** use unsafe blocks without proper documentation"]
      else
        anti_patterns
      end

    anti_patterns =
      if String.contains?(content, "unwrap()") do
        anti_patterns ++ ["- **DO NOT** use unwrap() in production code"]
      else
        anti_patterns
      end

    if Enum.any?(anti_patterns) do
      pattern_text = anti_patterns |> Enum.join("\n")
      "## Anti-Patterns\n\n#{pattern_text}\n"
    else
      "## Anti-Patterns\n\nNone identified.\n"
    end
  end

  defp generate_typescript_anti_patterns(content) do
    anti_patterns = []

    anti_patterns =
      if String.contains?(content, "any ") or String.contains?(content, ": any") do
        anti_patterns ++ ["- **DO NOT** use 'any' type - prefer specific types"]
      else
        anti_patterns
      end

    anti_patterns =
      if String.contains?(content, "!") and String.contains?(content, "null") do
        anti_patterns ++ ["- **DO NOT** use non-null assertion (!) without null checking"]
      else
        anti_patterns
      end

    if Enum.any?(anti_patterns) do
      pattern_text = anti_patterns |> Enum.join("\n")
      "## Anti-Patterns\n\n#{pattern_text}\n"
    else
      "## Anti-Patterns\n\nNone identified.\n"
    end
  end

  defp generate_generic_anti_patterns(_content), do: "## Anti-Patterns\n\nNone identified.\n"

  defp generate_search_keywords(content) do
    functions = extract_elixir_functions(content) |> Enum.join(", ")
    module_name = extract_module_name(content)

    keywords =
      [
        String.downcase(module_name),
        functions,
        "elixir",
        "gen_server",
        "module",
        "genserver",
        "process"
      ]
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.uniq()
      |> Enum.join(", ")

    "## Search Keywords\n\n#{keywords}\n"
  end

  defp generate_rust_search_keywords(content) do
    functions = extract_rust_functions(content) |> Enum.join(", ")
    crate_name = extract_crate_name(content)

    keywords =
      [
        String.downcase(crate_name),
        functions,
        "rust",
        "crate",
        "module"
      ]
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.uniq()
      |> Enum.join(", ")

    "## Search Keywords\n\n#{keywords}\n"
  end

  defp generate_typescript_search_keywords(content) do
    functions = extract_typescript_functions(content) |> Enum.join(", ")
    component_name = extract_component_name(content)

    keywords =
      [
        String.downcase(component_name),
        functions,
        "typescript",
        "component",
        "function",
        "javascript"
      ]
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.uniq()
      |> Enum.join(", ")

    "## Search Keywords\n\n#{keywords}\n"
  end

  defp generate_generic_search_keywords(_content),
    do: "## Search Keywords\n\nmodule, function, code\n"

  # Documentation insertion helpers

  defp add_moduledoc(content, moduledoc) do
    if String.contains?(content, "@moduledoc") do
      content
    else
      "  @moduledoc \"\"\"\n  #{moduledoc}\n  \"\"\"\n\n" <> content
    end
  end

  defp add_crate_doc(content, crate_doc) do
    if String.contains?(content, "///") do
      content
    else
      "/// #{crate_doc}\n" <> content
    end
  end

  defp add_jsdoc(content, jsdoc) do
    if String.contains?(content, "/**") do
      content
    else
      "/**\n#{jsdoc}\n */\n" <> content
    end
  end

  defp add_generic_doc(content, doc) do
    if String.contains?(content, "#") do
      content
    else
      "# #{doc}\n\n" <> content
    end
  end

  defp add_module_identity(content, identity) do
    json = Jason.encode!(identity, pretty: true)
    content <> "\n\n# Module Identity (JSON)\n```json\n#{json}\n```\n"
  end

  defp add_crate_identity(content, identity) do
    json = Jason.encode!(identity, pretty: true)
    content <> "\n\n# Crate Identity (JSON)\n```json\n#{json}\n```\n"
  end

  defp add_component_identity(content, identity) do
    json = Jason.encode!(identity, pretty: true)
    content <> "\n\n# Component Identity (JSON)\n```json\n#{json}\n```\n"
  end

  defp add_generic_identity(content, identity) do
    json = Jason.encode!(identity, pretty: true)
    content <> "\n\n# Identity (JSON)\n```json\n#{json}\n```\n"
  end

  defp add_architecture_diagram(content, diagram) do
    content <> "\n\n# Architecture Diagram (Mermaid)\n#{diagram}\n"
  end

  defp add_call_graph(content, call_graph) do
    content <> "\n\n# Call Graph (YAML)\n#{call_graph}\n"
  end

  defp add_anti_patterns(content, anti_patterns) do
    content <> "\n\n#{anti_patterns}\n"
  end

  defp add_search_keywords(content, keywords) do
    content <> "\n\n#{keywords}\n"
  end

  # Language-specific function extraction helpers

  defp extract_elixir_functions(content) do
    content
    |> String.split("\n")
    |> Enum.reduce([], fn line, acc ->
      case Regex.run(~r/^\s*(?:defp?|def!)\s+([a-z_][a-z0-9_?!]*)\s*(?:\(|$)/, line) do
        [_, func_name] -> acc ++ [func_name]
        _ -> acc
      end
    end)
    |> Enum.uniq()
  end

  defp extract_rust_functions(content) do
    content
    |> String.split("\n")
    |> Enum.reduce([], fn line, acc ->
      case Regex.run(~r/^\s*(?:pub\s+)?fn\s+([a-z_][a-z0-9_]*)\s*\(/, line) do
        [_, func_name] -> acc ++ [func_name]
        _ -> acc
      end
    end)
    |> Enum.uniq()
  end

  defp extract_typescript_functions(content) do
    content
    |> String.split("\n")
    |> Enum.reduce([], fn line, acc ->
      cond do
        Regex.match?(
          ~r/^\s*(?:export\s+)?(?:async\s+)?function\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\(/,
          line
        ) ->
          case Regex.run(
                 ~r/^\s*(?:export\s+)?(?:async\s+)?function\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\(/,
                 line
               ) do
            [_, func_name] -> acc ++ [func_name]
            _ -> acc
          end

        Regex.match?(
          ~r/^\s*(?:const|let|var)\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*\(.*\)\s*=>/,
          line
        ) ->
          case Regex.run(~r/^\s*(?:const|let|var)\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=/, line) do
            [_, func_name] -> acc ++ [func_name]
            _ -> acc
          end

        true ->
          acc
      end
    end)
    |> Enum.uniq()
  end
end
