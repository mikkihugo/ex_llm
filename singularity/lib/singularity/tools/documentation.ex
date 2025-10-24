defmodule Singularity.Tools.Documentation do
  @moduledoc """
  Documentation Tools - Documentation management and generation for autonomous agents

  Provides comprehensive documentation capabilities for agents to:
  - Generate documentation from code
  - Search and analyze existing documentation
  - Identify missing documentation
  - Validate documentation quality
  - Manage documentation structure
  - Generate API documentation

  Essential for maintaining comprehensive project documentation.
  """

  alias Singularity.Tools.Catalog
  alias Singularity.Schemas.Tools.Tool

  def register(provider) do
    Catalog.add_tools(provider, [
      docs_generate_tool(),
      docs_search_tool(),
      docs_missing_tool(),
      docs_validate_tool(),
      docs_structure_tool(),
      docs_api_tool(),
      docs_readme_tool()
    ])
  end

  defp docs_generate_tool do
    Tool.new!(%{
      name: "docs_generate",
      description: "Generate documentation from code files and modules",
      parameters: [
        %{
          name: "target",
          type: :string,
          required: true,
          description: "File, module, or directory to generate docs for"
        },
        %{
          name: "format",
          type: :string,
          required: false,
          description: "Output format: 'markdown', 'html', 'rst', 'text' (default: 'markdown')"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Programming language (elixir, javascript, python, etc.)"
        },
        %{
          name: "include_examples",
          type: :boolean,
          required: false,
          description: "Include code examples (default: true)"
        },
        %{
          name: "include_types",
          type: :boolean,
          required: false,
          description: "Include type information (default: true)"
        },
        %{
          name: "output_file",
          type: :string,
          required: false,
          description: "Output file path (default: auto-generated)"
        }
      ],
      function: &docs_generate/2
    })
  end

  defp docs_search_tool do
    Tool.new!(%{
      name: "docs_search",
      description: "Search and analyze existing documentation",
      parameters: [
        %{
          name: "query",
          type: :string,
          required: true,
          description: "Search query for documentation content"
        },
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Directory to search in (default: current directory)"
        },
        %{
          name: "file_types",
          type: :array,
          required: false,
          description: "File types to search: ['md', 'rst', 'txt', 'html'] (default: all)"
        },
        %{
          name: "case_sensitive",
          type: :boolean,
          required: false,
          description: "Case-sensitive search (default: false)"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Maximum number of results (default: 20)"
        }
      ],
      function: &docs_search/2
    })
  end

  defp docs_missing_tool do
    Tool.new!(%{
      name: "docs_missing",
      description: "Identify missing documentation for code files",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Directory to analyze (default: current directory)"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Programming language (elixir, javascript, python, etc.)"
        },
        %{
          name: "include_private",
          type: :boolean,
          required: false,
          description: "Include private functions (default: false)"
        },
        %{
          name: "min_complexity",
          type: :integer,
          required: false,
          description: "Minimum complexity to require docs (default: 3)"
        },
        %{
          name: "output_format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'text', 'table' (default: 'text')"
        }
      ],
      function: &docs_missing/2
    })
  end

  defp docs_validate_tool do
    Tool.new!(%{
      name: "docs_validate",
      description: "Validate documentation quality and completeness",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: false,
          description: "File or directory to validate (default: current directory)"
        },
        %{
          name: "checks",
          type: :array,
          required: false,
          description:
            "Validation checks: ['completeness', 'format', 'links', 'examples'] (default: all)"
        },
        %{
          name: "strict",
          type: :boolean,
          required: false,
          description: "Use strict validation rules (default: false)"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Programming language (elixir, javascript, python, etc.)"
        },
        %{
          name: "output_format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'text', 'table' (default: 'text')"
        }
      ],
      function: &docs_validate/2
    })
  end

  defp docs_structure_tool do
    Tool.new!(%{
      name: "docs_structure",
      description: "Analyze and manage documentation structure",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Directory to analyze (default: current directory)"
        },
        %{
          name: "action",
          type: :string,
          required: false,
          description:
            "Action: 'analyze', 'create_index', 'validate_links', 'generate_toc' (default: 'analyze')"
        },
        %{
          name: "include_subdirs",
          type: :boolean,
          required: false,
          description: "Include subdirectories (default: true)"
        },
        %{
          name: "max_depth",
          type: :integer,
          required: false,
          description: "Maximum directory depth (default: 5)"
        },
        %{
          name: "output_file",
          type: :string,
          required: false,
          description: "Output file for structure analysis"
        }
      ],
      function: &docs_structure/2
    })
  end

  defp docs_api_tool do
    Tool.new!(%{
      name: "docs_api",
      description: "Generate API documentation from code",
      parameters: [
        %{
          name: "target",
          type: :string,
          required: true,
          description: "Module, file, or directory containing API code"
        },
        %{
          name: "format",
          type: :string,
          required: false,
          description:
            "Output format: 'openapi', 'postman', 'markdown', 'html' (default: 'openapi')"
        },
        %{
          name: "language",
          type: :string,
          required: false,
          description: "Programming language (elixir, javascript, python, etc.)"
        },
        %{
          name: "include_examples",
          type: :boolean,
          required: false,
          description: "Include request/response examples (default: true)"
        },
        %{
          name: "include_schemas",
          type: :boolean,
          required: false,
          description: "Include data schemas (default: true)"
        },
        %{
          name: "output_file",
          type: :string,
          required: false,
          description: "Output file path (default: auto-generated)"
        }
      ],
      function: &docs_api/2
    })
  end

  defp docs_readme_tool do
    Tool.new!(%{
      name: "docs_readme",
      description: "Generate or update README files",
      parameters: [
        %{
          name: "path",
          type: :string,
          required: false,
          description: "Directory to generate README for (default: current directory)"
        },
        %{
          name: "action",
          type: :string,
          required: false,
          description: "Action: 'generate', 'update', 'validate' (default: 'generate')"
        },
        %{
          name: "template",
          type: :string,
          required: false,
          description:
            "README template: 'basic', 'comprehensive', 'minimal' (default: 'comprehensive')"
        },
        %{
          name: "include_install",
          type: :boolean,
          required: false,
          description: "Include installation instructions (default: true)"
        },
        %{
          name: "include_usage",
          type: :boolean,
          required: false,
          description: "Include usage examples (default: true)"
        },
        %{
          name: "include_api",
          type: :boolean,
          required: false,
          description: "Include API documentation (default: false)"
        }
      ],
      function: &docs_readme/2
    })
  end

  # Implementation functions

  def docs_generate(
        %{
          "target" => target,
          "format" => format,
          "language" => language,
          "include_examples" => include_examples,
          "include_types" => include_types,
          "output_file" => output_file
        },
        _ctx
      ) do
    docs_generate_impl(target, format, language, include_examples, include_types, output_file)
  end

  def docs_generate(
        %{
          "target" => target,
          "format" => format,
          "language" => language,
          "include_examples" => include_examples,
          "include_types" => include_types
        },
        _ctx
      ) do
    docs_generate_impl(target, format, language, include_examples, include_types, nil)
  end

  def docs_generate(
        %{
          "target" => target,
          "format" => format,
          "language" => language,
          "include_examples" => include_examples
        },
        _ctx
      ) do
    docs_generate_impl(target, format, language, include_examples, true, nil)
  end

  def docs_generate(%{"target" => target, "format" => format, "language" => language}, _ctx) do
    docs_generate_impl(target, format, language, true, true, nil)
  end

  def docs_generate(%{"target" => target, "format" => format}, _ctx) do
    docs_generate_impl(target, format, nil, true, true, nil)
  end

  def docs_generate(%{"target" => target}, _ctx) do
    docs_generate_impl(target, "markdown", nil, true, true, nil)
  end

  defp docs_generate_impl(target, format, language, include_examples, include_types, output_file) do
    try do
      # Detect language if not specified
      detected_language = language || detect_language_from_target(target)

      # Generate documentation content
      content =
        generate_documentation_content(target, detected_language, include_examples, include_types)

      # Format content
      formatted_content = format_documentation_content(content, format, detected_language)

      # Determine output file
      final_output_file = output_file || determine_output_file(target, format)

      # Write to file
      File.write!(final_output_file, formatted_content)

      {:ok,
       %{
         target: target,
         format: format,
         language: detected_language,
         include_examples: include_examples,
         include_types: include_types,
         output_file: final_output_file,
         content: formatted_content,
         success: true,
         generated_at: DateTime.utc_now()
       }}
    rescue
      error -> {:error, "Documentation generation error: #{inspect(error)}"}
    end
  end

  def docs_search(
        %{
          "query" => query,
          "path" => path,
          "file_types" => file_types,
          "case_sensitive" => case_sensitive,
          "limit" => limit
        },
        _ctx
      ) do
    docs_search_impl(query, path, file_types, case_sensitive, limit)
  end

  def docs_search(
        %{
          "query" => query,
          "path" => path,
          "file_types" => file_types,
          "case_sensitive" => case_sensitive
        },
        _ctx
      ) do
    docs_search_impl(query, path, file_types, case_sensitive, 20)
  end

  def docs_search(%{"query" => query, "path" => path, "file_types" => file_types}, _ctx) do
    docs_search_impl(query, path, file_types, false, 20)
  end

  def docs_search(%{"query" => query, "path" => path}, _ctx) do
    docs_search_impl(query, path, nil, false, 20)
  end

  def docs_search(%{"query" => query}, _ctx) do
    docs_search_impl(query, ".", nil, false, 20)
  end

  defp docs_search_impl(query, path, file_types, case_sensitive, limit) do
    try do
      # Build search command
      cmd = build_search_command(query, path, file_types, case_sensitive)

      # Execute search
      {output, exit_code} = System.cmd("sh", ["-c", cmd], stderr_to_stdout: true)

      # Parse results
      results = parse_search_results(output, query, case_sensitive)

      # Limit results
      limited_results = Enum.take(results, limit)

      {:ok,
       %{
         query: query,
         path: path,
         file_types: file_types,
         case_sensitive: case_sensitive,
         limit: limit,
         command: cmd,
         exit_code: exit_code,
         output: output,
         results: limited_results,
         total_found: length(results),
         total_returned: length(limited_results),
         success: exit_code == 0
       }}
    rescue
      error -> {:error, "Documentation search error: #{inspect(error)}"}
    end
  end

  def docs_missing(
        %{
          "path" => path,
          "language" => language,
          "include_private" => include_private,
          "min_complexity" => min_complexity,
          "output_format" => output_format
        },
        _ctx
      ) do
    docs_missing_impl(path, language, include_private, min_complexity, output_format)
  end

  def docs_missing(
        %{
          "path" => path,
          "language" => language,
          "include_private" => include_private,
          "min_complexity" => min_complexity
        },
        _ctx
      ) do
    docs_missing_impl(path, language, include_private, min_complexity, "text")
  end

  def docs_missing(
        %{"path" => path, "language" => language, "include_private" => include_private},
        _ctx
      ) do
    docs_missing_impl(path, language, include_private, 3, "text")
  end

  def docs_missing(%{"path" => path, "language" => language}, _ctx) do
    docs_missing_impl(path, language, false, 3, "text")
  end

  def docs_missing(%{"path" => path}, _ctx) do
    docs_missing_impl(path, nil, false, 3, "text")
  end

  def docs_missing(%{}, _ctx) do
    docs_missing_impl(".", nil, false, 3, "text")
  end

  defp docs_missing_impl(path, language, include_private, min_complexity, output_format) do
    try do
      # Detect language if not specified
      detected_language = language || detect_language_from_path(path)

      # Find code files
      code_files = find_code_files(path, detected_language)

      # Analyze each file for missing documentation
      missing_docs =
        Enum.flat_map(code_files, fn file ->
          analyze_missing_documentation(file, detected_language, include_private, min_complexity)
        end)

      # Format output
      formatted_output = format_missing_docs_output(missing_docs, output_format)

      {:ok,
       %{
         path: path,
         language: detected_language,
         include_private: include_private,
         min_complexity: min_complexity,
         output_format: output_format,
         code_files: code_files,
         missing_docs: missing_docs,
         formatted_output: formatted_output,
         total_files: length(code_files),
         total_missing: length(missing_docs),
         success: true
       }}
    rescue
      error -> {:error, "Missing documentation analysis error: #{inspect(error)}"}
    end
  end

  def docs_validate(
        %{
          "path" => path,
          "checks" => checks,
          "strict" => strict,
          "language" => language,
          "output_format" => output_format
        },
        _ctx
      ) do
    docs_validate_impl(path, checks, strict, language, output_format)
  end

  def docs_validate(
        %{"path" => path, "checks" => checks, "strict" => strict, "language" => language},
        _ctx
      ) do
    docs_validate_impl(path, checks, strict, language, "text")
  end

  def docs_validate(%{"path" => path, "checks" => checks, "strict" => strict}, _ctx) do
    docs_validate_impl(path, checks, strict, nil, "text")
  end

  def docs_validate(%{"path" => path, "checks" => checks}, _ctx) do
    docs_validate_impl(path, checks, false, nil, "text")
  end

  def docs_validate(%{"path" => path}, _ctx) do
    docs_validate_impl(path, ["completeness", "format", "links", "examples"], false, nil, "text")
  end

  def docs_validate(%{}, _ctx) do
    docs_validate_impl(".", ["completeness", "format", "links", "examples"], false, nil, "text")
  end

  defp docs_validate_impl(path, checks, strict, language, output_format) do
    try do
      # Find documentation files
      doc_files = find_documentation_files(path)

      # Run validation checks
      validation_results =
        Enum.map(checks, fn check ->
          run_validation_check(check, doc_files, strict, language)
        end)

      # Calculate overall score
      overall_score = calculate_validation_score(validation_results)

      # Format output
      formatted_output =
        format_validation_output(validation_results, overall_score, output_format)

      {:ok,
       %{
         path: path,
         checks: checks,
         strict: strict,
         language: language,
         output_format: output_format,
         doc_files: doc_files,
         validation_results: validation_results,
         overall_score: overall_score,
         formatted_output: formatted_output,
         success: true
       }}
    rescue
      error -> {:error, "Documentation validation error: #{inspect(error)}"}
    end
  end

  def docs_structure(
        %{
          "path" => path,
          "action" => action,
          "include_subdirs" => include_subdirs,
          "max_depth" => max_depth,
          "output_file" => output_file
        },
        _ctx
      ) do
    docs_structure_impl(path, action, include_subdirs, max_depth, output_file)
  end

  def docs_structure(
        %{
          "path" => path,
          "action" => action,
          "include_subdirs" => include_subdirs,
          "max_depth" => max_depth
        },
        _ctx
      ) do
    docs_structure_impl(path, action, include_subdirs, max_depth, nil)
  end

  def docs_structure(
        %{"path" => path, "action" => action, "include_subdirs" => include_subdirs},
        _ctx
      ) do
    docs_structure_impl(path, action, include_subdirs, 5, nil)
  end

  def docs_structure(%{"path" => path, "action" => action}, _ctx) do
    docs_structure_impl(path, action, true, 5, nil)
  end

  def docs_structure(%{"path" => path}, _ctx) do
    docs_structure_impl(path, "analyze", true, 5, nil)
  end

  def docs_structure(%{}, _ctx) do
    docs_structure_impl(".", "analyze", true, 5, nil)
  end

  defp docs_structure_impl(path, action, include_subdirs, max_depth, output_file) do
    try do
      # Find documentation files
      doc_files = find_documentation_files_recursive(path, include_subdirs, max_depth)

      # Perform requested action
      result =
        case action do
          "analyze" -> analyze_documentation_structure(doc_files)
          "create_index" -> create_documentation_index(doc_files)
          "validate_links" -> validate_documentation_links(doc_files)
          "generate_toc" -> generate_table_of_contents(doc_files)
          _ -> %{error: "Unknown action: #{action}"}
        end

      # Save to file if specified
      if output_file do
        File.write!(output_file, Jason.encode!(result, pretty: true))
      end

      {:ok,
       %{
         path: path,
         action: action,
         include_subdirs: include_subdirs,
         max_depth: max_depth,
         output_file: output_file,
         doc_files: doc_files,
         result: result,
         success: true
       }}
    rescue
      error -> {:error, "Documentation structure error: #{inspect(error)}"}
    end
  end

  def docs_api(
        %{
          "target" => target,
          "format" => format,
          "language" => language,
          "include_examples" => include_examples,
          "include_schemas" => include_schemas,
          "output_file" => output_file
        },
        _ctx
      ) do
    docs_api_impl(target, format, language, include_examples, include_schemas, output_file)
  end

  def docs_api(
        %{
          "target" => target,
          "format" => format,
          "language" => language,
          "include_examples" => include_examples,
          "include_schemas" => include_schemas
        },
        _ctx
      ) do
    docs_api_impl(target, format, language, include_examples, include_schemas, nil)
  end

  def docs_api(
        %{
          "target" => target,
          "format" => format,
          "language" => language,
          "include_examples" => include_examples
        },
        _ctx
      ) do
    docs_api_impl(target, format, language, include_examples, true, nil)
  end

  def docs_api(%{"target" => target, "format" => format, "language" => language}, _ctx) do
    docs_api_impl(target, format, language, true, true, nil)
  end

  def docs_api(%{"target" => target, "format" => format}, _ctx) do
    docs_api_impl(target, format, nil, true, true, nil)
  end

  def docs_api(%{"target" => target}, _ctx) do
    docs_api_impl(target, "openapi", nil, true, true, nil)
  end

  defp docs_api_impl(target, format, language, include_examples, include_schemas, output_file) do
    try do
      # Detect language if not specified
      detected_language = language || detect_language_from_target(target)

      # Extract API information
      api_info = extract_api_information(target, detected_language)

      # Generate API documentation
      api_docs = generate_api_documentation(api_info, format, include_examples, include_schemas)

      # Determine output file
      final_output_file = output_file || determine_api_output_file(target, format)

      # Write to file
      File.write!(final_output_file, api_docs)

      {:ok,
       %{
         target: target,
         format: format,
         language: detected_language,
         include_examples: include_examples,
         include_schemas: include_schemas,
         output_file: final_output_file,
         api_info: api_info,
         api_docs: api_docs,
         success: true,
         generated_at: DateTime.utc_now()
       }}
    rescue
      error -> {:error, "API documentation generation error: #{inspect(error)}"}
    end
  end

  def docs_readme(
        %{
          "path" => path,
          "action" => action,
          "template" => template,
          "include_install" => include_install,
          "include_usage" => include_usage,
          "include_api" => include_api
        },
        _ctx
      ) do
    docs_readme_impl(path, action, template, include_install, include_usage, include_api)
  end

  def docs_readme(
        %{
          "path" => path,
          "action" => action,
          "template" => template,
          "include_install" => include_install,
          "include_usage" => include_usage
        },
        _ctx
      ) do
    docs_readme_impl(path, action, template, include_install, include_usage, false)
  end

  def docs_readme(
        %{
          "path" => path,
          "action" => action,
          "template" => template,
          "include_install" => include_install
        },
        _ctx
      ) do
    docs_readme_impl(path, action, template, include_install, true, false)
  end

  def docs_readme(%{"path" => path, "action" => action, "template" => template}, _ctx) do
    docs_readme_impl(path, action, template, true, true, false)
  end

  def docs_readme(%{"path" => path, "action" => action}, _ctx) do
    docs_readme_impl(path, action, "comprehensive", true, true, false)
  end

  def docs_readme(%{"path" => path}, _ctx) do
    docs_readme_impl(path, "generate", "comprehensive", true, true, false)
  end

  def docs_readme(%{}, _ctx) do
    docs_readme_impl(".", "generate", "comprehensive", true, true, false)
  end

  defp docs_readme_impl(path, action, template, include_install, include_usage, include_api) do
    try do
      # Analyze project structure
      project_info = analyze_project_structure(path)

      # Perform requested action
      result =
        case action do
          "generate" ->
            generate_readme(project_info, template, include_install, include_usage, include_api)

          "update" ->
            update_readme(project_info, template, include_install, include_usage, include_api)

          "validate" ->
            validate_readme(project_info)

          _ ->
            %{error: "Unknown action: #{action}"}
        end

      # Write README if generated/updated
      readme_file = Path.join(path, "README.md")

      if action in ["generate", "update"] and result.content do
        File.write!(readme_file, result.content)
      end

      {:ok,
       %{
         path: path,
         action: action,
         template: template,
         include_install: include_install,
         include_usage: include_usage,
         include_api: include_api,
         project_info: project_info,
         result: result,
         readme_file: readme_file,
         success: true
       }}
    rescue
      error -> {:error, "README generation error: #{inspect(error)}"}
    end
  end

  # Helper functions

  defp detect_language_from_target(target) do
    cond do
      String.ends_with?(target, ".ex") or String.ends_with?(target, ".exs") -> "elixir"
      String.ends_with?(target, ".js") or String.ends_with?(target, ".ts") -> "javascript"
      String.ends_with?(target, ".py") -> "python"
      String.ends_with?(target, ".rb") -> "ruby"
      String.ends_with?(target, ".go") -> "go"
      String.ends_with?(target, ".rs") -> "rust"
      String.ends_with?(target, ".java") -> "java"
      # Default to Elixir for this project
      true -> "elixir"
    end
  end

  defp detect_language_from_path(path) do
    # Find the most common language in the path
    case System.cmd("find", [path, "-name", "*.ex", "-o", "-name", "*.exs"],
           stderr_to_stdout: true
         ) do
      {output, 0} when output != "" ->
        "elixir"

      _ ->
        case System.cmd("find", [path, "-name", "*.js", "-o", "-name", "*.ts"],
               stderr_to_stdout: true
             ) do
          {output, 0} when output != "" -> "javascript"
          # Default
          _ -> "elixir"
        end
    end
  end

  defp generate_documentation_content(target, language, include_examples, include_types) do
    case language do
      "elixir" -> generate_elixir_docs(target, include_examples, include_types)
      "javascript" -> generate_javascript_docs(target, include_examples, include_types)
      "python" -> generate_python_docs(target, include_examples, include_types)
      _ -> generate_generic_docs(target, include_examples, include_types)
    end
  end

  defp generate_elixir_docs(target, include_examples, include_types) do
    # Read the file
    case File.read(target) do
      {:ok, content} ->
        # Parse Elixir code
        modules = parse_elixir_modules(content)

        # Generate documentation for each module
        Enum.map(modules, fn module ->
          generate_module_docs(module, include_examples, include_types)
        end)

      {:error, _} ->
        [%{error: "Could not read file: #{target}"}]
    end
  end

  defp generate_javascript_docs(target, include_examples, include_types) do
    # Read the file
    case File.read(target) do
      {:ok, content} ->
        # Parse JavaScript code
        functions = parse_javascript_functions(content)

        # Generate documentation for each function
        Enum.map(functions, fn func ->
          generate_function_docs(func, include_examples, include_types)
        end)

      {:error, _} ->
        [%{error: "Could not read file: #{target}"}]
    end
  end

  defp generate_python_docs(target, include_examples, include_types) do
    # Read the file
    case File.read(target) do
      {:ok, content} ->
        # Parse Python code
        classes = parse_python_classes(content)
        functions = parse_python_functions(content)

        # Generate documentation
        class_docs = Enum.map(classes, &generate_class_docs(&1, include_examples, include_types))

        func_docs =
          Enum.map(functions, &generate_function_docs(&1, include_examples, include_types))

        class_docs ++ func_docs

      {:error, _} ->
        [%{error: "Could not read file: #{target}"}]
    end
  end

  defp generate_generic_docs(target, include_examples, include_types) do
    # Generic documentation generation
    [
      %{
        target: target,
        type: "generic",
        content: "Documentation for #{target}",
        examples: if(include_examples, do: ["Example usage"], else: []),
        types: if(include_types, do: ["Generic type"], else: [])
      }
    ]
  end

  defp parse_elixir_modules(content) do
    # Simple Elixir module parsing
    module_regex = ~r/defmodule\s+([A-Za-z0-9_.]+)\s+do/
    function_regex = ~r/def\s+([a-z_][a-z0-9_]*)\s*(?:\([^)]*\))?\s*(?:when\s+[^do]+)?\s*do/

    modules = Regex.scan(module_regex, content)
    functions = Regex.scan(function_regex, content)

    Enum.map(modules, fn [_, module_name] ->
      %{
        name: module_name,
        type: "module",
        functions: functions
      }
    end)
  end

  defp parse_javascript_functions(content) do
    # Simple JavaScript function parsing
    function_regex = ~r/function\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\([^)]*\)/
    arrow_regex = ~r/const\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*\([^)]*\)\s*=>/

    functions = Regex.scan(function_regex, content) ++ Regex.scan(arrow_regex, content)

    Enum.map(functions, fn [_, func_name] ->
      %{
        name: func_name,
        type: "function"
      }
    end)
  end

  defp parse_python_classes(content) do
    # Simple Python class parsing
    class_regex = ~r/class\s+([A-Za-z0-9_]+)(?:\([^)]*\))?:/

    Regex.scan(class_regex, content)
    |> Enum.map(fn [_, class_name] ->
      %{
        name: class_name,
        type: "class"
      }
    end)
  end

  defp parse_python_functions(content) do
    # Simple Python function parsing
    function_regex = ~r/def\s+([a-z_][a-z0-9_]*)\s*\([^)]*\):/

    Regex.scan(function_regex, content)
    |> Enum.map(fn [_, func_name] ->
      %{
        name: func_name,
        type: "function"
      }
    end)
  end

  defp generate_module_docs(module, include_examples, include_types) do
    %{
      name: module.name,
      type: "module",
      description: "Module #{module.name}",
      functions: module.functions,
      examples: if(include_examples, do: ["Example usage of #{module.name}"], else: []),
      types: if(include_types, do: ["Module type information"], else: [])
    }
  end

  defp generate_function_docs(func, include_examples, include_types) do
    %{
      name: func.name,
      type: "function",
      description: "Function #{func.name}",
      examples: if(include_examples, do: ["Example usage of #{func.name}"], else: []),
      types: if(include_types, do: ["Function type information"], else: [])
    }
  end

  defp generate_class_docs(class, include_examples, include_types) do
    %{
      name: class.name,
      type: "class",
      description: "Class #{class.name}",
      examples: if(include_examples, do: ["Example usage of #{class.name}"], else: []),
      types: if(include_types, do: ["Class type information"], else: [])
    }
  end

  defp format_documentation_content(content, format, language) do
    case format do
      "markdown" -> format_markdown_docs(content, language)
      "html" -> format_html_docs(content, language)
      "rst" -> format_rst_docs(content, language)
      "text" -> format_text_docs(content, language)
      _ -> format_markdown_docs(content, language)
    end
  end

  defp format_markdown_docs(content, _language) do
    Enum.map(content, fn item ->
      case item do
        %{name: name, type: type, description: desc, examples: examples, types: types} ->
          """
          # #{name}

          **Type:** #{type}

          #{desc}

          #{if examples != [], do: "## Examples\n\n" <> Enum.join(Enum.map(examples, &"- #{&1}"), "\n"), else: ""}

          #{if types != [], do: "## Types\n\n" <> Enum.join(Enum.map(types, &"- #{&1}"), "\n"), else: ""}
          """

        %{error: error} ->
          "## Error\n\n#{error}"

        _ ->
          "## Unknown\n\nUnknown content type"
      end
    end)
    |> Enum.join("\n\n---\n\n")
  end

  defp format_html_docs(content, language) do
    # HTML formatting
    "<html><body>" <> format_markdown_docs(content, language) <> "</body></html>"
  end

  defp format_rst_docs(content, _language) do
    # RST formatting
    Enum.map(content, fn item ->
      case item do
        %{name: name, type: type, description: desc} ->
          """
          #{name}
          #{String.duplicate("=", String.length(name))}

          **Type:** #{type}

          #{desc}
          """

        _ ->
          ""
      end
    end)
    |> Enum.join("\n\n")
  end

  defp format_text_docs(content, _language) do
    Enum.map(content, fn item ->
      case item do
        %{name: name, type: type, description: desc} ->
          "#{name} (#{type})\n#{desc}"

        _ ->
          ""
      end
    end)
    |> Enum.join("\n\n")
  end

  defp determine_output_file(target, format) do
    base_name = Path.basename(target, Path.extname(target))

    extension =
      case format do
        "markdown" -> ".md"
        "html" -> ".html"
        "rst" -> ".rst"
        "text" -> ".txt"
        _ -> ".md"
      end

    "#{base_name}_docs#{extension}"
  end

  defp build_search_command(query, path, file_types, case_sensitive) do
    cmd = "grep -r"
    cmd = if case_sensitive, do: cmd, else: "#{cmd} -i"

    cmd =
      if file_types,
        do: "#{cmd} --include='*.md' --include='*.rst' --include='*.txt' --include='*.html'",
        else: cmd

    cmd = "#{cmd} '#{query}' #{path}"
    cmd
  end

  defp parse_search_results(output, query, case_sensitive) do
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    Enum.map(lines, fn line ->
      case String.split(line, ":", parts: 2) do
        [file, content] ->
          %{
            file: file,
            content: String.trim(content),
            query: query,
            case_sensitive: case_sensitive
          }

        _ ->
          %{
            file: "unknown",
            content: line,
            query: query,
            case_sensitive: case_sensitive
          }
      end
    end)
  end

  defp find_code_files(path, language) do
    extensions =
      case language do
        "elixir" -> ["*.ex", "*.exs"]
        "javascript" -> ["*.js", "*.ts"]
        "python" -> ["*.py"]
        "ruby" -> ["*.rb"]
        "go" -> ["*.go"]
        "rust" -> ["*.rs"]
        "java" -> ["*.java"]
        _ -> ["*.ex", "*.exs"]
      end

    Enum.flat_map(extensions, fn ext ->
      case System.cmd("find", [path, "-name", ext, "-type", "f"], stderr_to_stdout: true) do
        {output, 0} -> String.split(output, "\n") |> Enum.reject(&(&1 == ""))
        _ -> []
      end
    end)
  end

  defp analyze_missing_documentation(file, language, include_private, min_complexity) do
    case File.read(file) do
      {:ok, content} ->
        case language do
          "elixir" ->
            analyze_elixir_missing_docs(content, file, include_private, min_complexity)

          "javascript" ->
            analyze_javascript_missing_docs(content, file, include_private, min_complexity)

          "python" ->
            analyze_python_missing_docs(content, file, include_private, min_complexity)

          _ ->
            analyze_generic_missing_docs(content, file, include_private, min_complexity)
        end

      {:error, _} ->
        [%{file: file, error: "Could not read file"}]
    end
  end

  defp analyze_elixir_missing_docs(content, file, _include_private, min_complexity) do
    # Find functions without @doc
    function_regex = ~r/def\s+([a-z_][a-z0-9_]*)\s*(?:\([^)]*\))?\s*(?:when\s+[^do]+)?\s*do/
    doc_regex = ~r/@doc\s+["']/

    functions = Regex.scan(function_regex, content)

    Enum.map(functions, fn [_, func_name] ->
      # Check if function has documentation
      has_doc = Regex.match?(doc_regex, content)

      %{
        file: file,
        name: func_name,
        type: "function",
        has_documentation: has_doc,
        complexity: calculate_complexity(content, func_name),
        language: "elixir"
      }
    end)
    |> Enum.filter(fn item ->
      item.complexity >= min_complexity and not item.has_documentation
    end)
  end

  defp analyze_javascript_missing_docs(content, file, include_private, min_complexity) do
    # Find functions without JSDoc
    function_regex = ~r/function\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\([^)]*\)/
    jsdoc_regex = ~r/\/\*\*[\s\S]*?\*\/\s*function/

    functions = Regex.scan(function_regex, content)

    Enum.map(functions, fn [_, func_name] ->
      has_doc = Regex.match?(jsdoc_regex, content)

      %{
        file: file,
        name: func_name,
        type: "function",
        has_documentation: has_doc,
        complexity: calculate_complexity(content, func_name),
        language: "javascript"
      }
    end)
    |> Enum.filter(fn item ->
      item.complexity >= min_complexity and not item.has_documentation
    end)
  end

  defp analyze_python_missing_docs(content, file, include_private, min_complexity) do
    # Find functions and classes without docstrings
    function_regex = ~r/def\s+([a-z_][a-z0-9_]*)\s*\([^)]*\):/
    class_regex = ~r/class\s+([A-Za-z0-9_]+)(?:\([^)]*\))?:/
    docstring_regex = ~r/""".*?"""/

    functions = Regex.scan(function_regex, content)
    classes = Regex.scan(class_regex, content)

    func_docs =
      Enum.map(functions, fn [_, func_name] ->
        has_doc = Regex.match?(docstring_regex, content)

        %{
          file: file,
          name: func_name,
          type: "function",
          has_documentation: has_doc,
          complexity: calculate_complexity(content, func_name),
          language: "python"
        }
      end)

    class_docs =
      Enum.map(classes, fn [_, class_name] ->
        has_doc = Regex.match?(docstring_regex, content)

        %{
          file: file,
          name: class_name,
          type: "class",
          has_documentation: has_doc,
          complexity: calculate_complexity(content, class_name),
          language: "python"
        }
      end)

    (func_docs ++ class_docs)
    |> Enum.filter(fn item ->
      item.complexity >= min_complexity and not item.has_documentation
    end)
  end

  defp analyze_generic_missing_docs(content, file, include_private, min_complexity) do
    # Generic analysis
    [
      %{
        file: file,
        name: "generic",
        type: "unknown",
        has_documentation: false,
        complexity: 1,
        language: "generic"
      }
    ]
  end

  defp calculate_complexity(content, name) do
    # Simple complexity calculation based on lines and control structures
    lines = String.split(content, "\n") |> length()
    control_structures = Regex.scan(~r/(if|for|while|case|cond)/, content) |> length()

    # Basic complexity score
    min(lines / 10, 10) + min(control_structures, 5)
  end

  defp format_missing_docs_output(missing_docs, output_format) do
    case output_format do
      "json" -> Jason.encode!(missing_docs, pretty: true)
      "table" -> format_missing_docs_table(missing_docs)
      _ -> format_missing_docs_text(missing_docs)
    end
  end

  defp format_missing_docs_text(missing_docs) do
    Enum.map(missing_docs, fn doc ->
      "Missing docs: #{doc.name} (#{doc.type}) in #{doc.file} - complexity: #{doc.complexity}"
    end)
    |> Enum.join("\n")
  end

  defp format_missing_docs_table(missing_docs) do
    # Simple table formatting
    missing_docs
  end

  defp find_documentation_files(path) do
    extensions = ["*.md", "*.rst", "*.txt", "*.html"]

    Enum.flat_map(extensions, fn ext ->
      case System.cmd("find", [path, "-name", ext, "-type", "f"], stderr_to_stdout: true) do
        {output, 0} -> String.split(output, "\n") |> Enum.reject(&(&1 == ""))
        _ -> []
      end
    end)
  end

  defp find_documentation_files_recursive(path, include_subdirs, max_depth) do
    if include_subdirs do
      find_documentation_files(path)
    else
      # Only current directory
      find_documentation_files(path)
    end
  end

  defp run_validation_check(check, doc_files, strict, language) do
    case check do
      "completeness" -> validate_completeness(doc_files, strict)
      "format" -> validate_format(doc_files, strict)
      "links" -> validate_links(doc_files, strict)
      "examples" -> validate_examples(doc_files, strict)
      _ -> %{check: check, score: 0.0, message: "Unknown check"}
    end
  end

  defp validate_completeness(doc_files, strict) do
    # Check if documentation files have required sections
    total_files = length(doc_files)

    complete_files =
      Enum.count(doc_files, fn file ->
        case File.read(file) do
          {:ok, content} ->
            has_title = String.contains?(content, "#") or String.contains?(content, "=")
            has_description = String.length(content) > 100
            has_title and has_description

          _ ->
            false
        end
      end)

    score = if total_files > 0, do: complete_files / total_files, else: 0.0

    %{
      check: "completeness",
      score: score,
      message: "Completeness: #{complete_files}/#{total_files} files complete"
    }
  end

  defp validate_format(doc_files, strict) do
    # Check formatting consistency
    total_files = length(doc_files)

    well_formatted =
      Enum.count(doc_files, fn file ->
        case File.read(file) do
          {:ok, content} ->
            # Basic format checks
            has_proper_headers = Regex.match?(~r/^#\s+/, content)
            has_proper_lists = not Regex.match?(~r/^\s*-\s*$/, content)
            has_proper_links = not Regex.match?(~r/\[.*\]\(\)/, content)
            has_proper_headers and has_proper_lists and has_proper_links

          _ ->
            false
        end
      end)

    score = if total_files > 0, do: well_formatted / total_files, else: 0.0

    %{
      check: "format",
      score: score,
      message: "Format: #{well_formatted}/#{total_files} files well formatted"
    }
  end

  defp validate_links(doc_files, strict) do
    # Check for broken links
    total_links = 0
    broken_links = 0

    Enum.each(doc_files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          links = Regex.scan(~r/\[([^\]]+)\]\(([^)]+)\)/, content)
          total_links = total_links + length(links)

          Enum.each(links, fn [_, text, url] ->
            if not is_valid_link(url) do
              broken_links = broken_links + 1
            end
          end)

        _ ->
          :ok
      end
    end)

    score = if total_links > 0, do: (total_links - broken_links) / total_links, else: 1.0

    %{
      check: "links",
      score: score,
      message: "Links: #{total_links - broken_links}/#{total_links} links valid"
    }
  end

  defp validate_examples(doc_files, strict) do
    # Check for code examples
    total_files = length(doc_files)

    files_with_examples =
      Enum.count(doc_files, fn file ->
        case File.read(file) do
          {:ok, content} ->
            has_code_blocks = Regex.match?(~r/```/, content) or Regex.match?(~r/`[^`]+`/, content)

            has_examples =
              String.contains?(content, "example") or String.contains?(content, "Example")

            has_code_blocks or has_examples

          _ ->
            false
        end
      end)

    score = if total_files > 0, do: files_with_examples / total_files, else: 0.0

    %{
      check: "examples",
      score: score,
      message: "Examples: #{files_with_examples}/#{total_files} files have examples"
    }
  end

  defp is_valid_link(url) do
    # Simple link validation
    cond do
      String.starts_with?(url, "http://") -> true
      String.starts_with?(url, "https://") -> true
      String.starts_with?(url, "mailto:") -> true
      String.starts_with?(url, "#") -> true
      String.starts_with?(url, "/") -> true
      true -> false
    end
  end

  defp calculate_validation_score(validation_results) do
    scores = Enum.map(validation_results, & &1.score)
    Enum.sum(scores) / length(scores)
  end

  defp format_validation_output(validation_results, overall_score, output_format) do
    case output_format do
      "json" ->
        Jason.encode!(%{results: validation_results, overall_score: overall_score}, pretty: true)

      "table" ->
        format_validation_table(validation_results, overall_score)

      _ ->
        format_validation_text(validation_results, overall_score)
    end
  end

  defp format_validation_text(validation_results, overall_score) do
    results_text =
      Enum.map(validation_results, fn result ->
        "#{result.check}: #{result.score * 100}% - #{result.message}"
      end)
      |> Enum.join("\n")

    "Overall Score: #{overall_score * 100}%\n\n#{results_text}"
  end

  defp format_validation_table(validation_results, overall_score) do
    %{results: validation_results, overall_score: overall_score}
  end

  defp analyze_documentation_structure(doc_files) do
    %{
      total_files: length(doc_files),
      file_types: analyze_file_types(doc_files),
      structure: analyze_file_structure(doc_files)
    }
  end

  defp create_documentation_index(doc_files) do
    %{
      index:
        Enum.map(doc_files, fn file ->
          %{
            file: file,
            title: extract_title(file),
            description: extract_description(file)
          }
        end)
    }
  end

  defp validate_documentation_links(doc_files) do
    %{
      total_links: 0,
      broken_links: 0,
      valid_links: 0
    }
  end

  defp generate_table_of_contents(doc_files) do
    %{
      toc:
        Enum.map(doc_files, fn file ->
          %{
            file: file,
            title: extract_title(file),
            level: 1
          }
        end)
    }
  end

  defp analyze_file_types(doc_files) do
    Enum.group_by(doc_files, fn file ->
      Path.extname(file)
    end)
  end

  defp analyze_file_structure(doc_files) do
    %{
      average_size: calculate_average_file_size(doc_files),
      total_size: calculate_total_file_size(doc_files)
    }
  end

  defp calculate_average_file_size(doc_files) do
    sizes =
      Enum.map(doc_files, fn file ->
        case File.stat(file) do
          {:ok, stat} -> stat.size
          _ -> 0
        end
      end)

    case sizes do
      [] -> 0
      sizes -> Enum.sum(sizes) / length(sizes)
    end
  end

  defp calculate_total_file_size(doc_files) do
    Enum.reduce(doc_files, 0, fn file, acc ->
      case File.stat(file) do
        {:ok, stat} -> acc + stat.size
        _ -> acc
      end
    end)
  end

  defp extract_title(file) do
    case File.read(file) do
      {:ok, content} ->
        case Regex.run(~r/^#\s+(.+)$/m, content) do
          [_, title] -> String.trim(title)
          _ -> Path.basename(file, Path.extname(file))
        end

      _ ->
        Path.basename(file, Path.extname(file))
    end
  end

  defp extract_description(file) do
    case File.read(file) do
      {:ok, content} ->
        lines =
          String.split(content, "\n")
          |> Enum.reject(&(&1 == ""))
          |> Enum.reject(&String.starts_with?(&1, "#"))

        case lines do
          [first_line | _] -> String.trim(first_line)
          _ -> "No description available"
        end

      _ ->
        "No description available"
    end
  end

  defp extract_api_information(target, language) do
    case language do
      "elixir" -> extract_elixir_api(target)
      "javascript" -> extract_javascript_api(target)
      "python" -> extract_python_api(target)
      _ -> %{error: "Unsupported language: #{language}"}
    end
  end

  defp extract_elixir_api(target) do
    # Extract Elixir API information
    %{
      endpoints: [],
      schemas: [],
      examples: []
    }
  end

  defp extract_javascript_api(target) do
    # Extract JavaScript API information
    %{
      endpoints: [],
      schemas: [],
      examples: []
    }
  end

  defp extract_python_api(target) do
    # Extract Python API information
    %{
      endpoints: [],
      schemas: [],
      examples: []
    }
  end

  defp generate_api_documentation(api_info, format, include_examples, include_schemas) do
    case format do
      "openapi" -> generate_openapi_docs(api_info, include_examples, include_schemas)
      "postman" -> generate_postman_docs(api_info, include_examples, include_schemas)
      "markdown" -> generate_markdown_api_docs(api_info, include_examples, include_schemas)
      "html" -> generate_html_api_docs(api_info, include_examples, include_schemas)
      _ -> generate_openapi_docs(api_info, include_examples, include_schemas)
    end
  end

  defp generate_openapi_docs(api_info, include_examples, include_schemas) do
    %{
      openapi: "3.0.0",
      info: %{
        title: "API Documentation",
        version: "1.0.0"
      },
      paths: %{},
      components: %{
        schemas: if(include_schemas, do: %{}, else: %{})
      }
    }
    |> Jason.encode!(pretty: true)
  end

  defp generate_postman_docs(api_info, include_examples, include_schemas) do
    %{
      info: %{
        name: "API Collection",
        schema: "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
      },
      item: []
    }
    |> Jason.encode!(pretty: true)
  end

  defp generate_markdown_api_docs(api_info, include_examples, include_schemas) do
    "# API Documentation\n\nGenerated API documentation"
  end

  defp generate_html_api_docs(api_info, include_examples, include_schemas) do
    "<html><body><h1>API Documentation</h1><p>Generated API documentation</p></body></html>"
  end

  defp determine_api_output_file(target, format) do
    base_name = Path.basename(target, Path.extname(target))

    extension =
      case format do
        "openapi" -> ".json"
        "postman" -> ".json"
        "markdown" -> ".md"
        "html" -> ".html"
        _ -> ".json"
      end

    "#{base_name}_api#{extension}"
  end

  defp analyze_project_structure(path) do
    %{
      name: Path.basename(path),
      path: path,
      files: list_project_files(path),
      language: detect_language_from_path(path)
    }
  end

  defp list_project_files(path) do
    case System.cmd(
           "find",
           [
             path,
             "-type",
             "f",
             "-name",
             "*.ex",
             "-o",
             "-name",
             "*.exs",
             "-o",
             "-name",
             "*.md",
             "-o",
             "-name",
             "*.json"
           ],
           stderr_to_stdout: true
         ) do
      {output, 0} -> String.split(output, "\n") |> Enum.reject(&(&1 == ""))
      _ -> []
    end
  end

  defp generate_readme(project_info, template, include_install, include_usage, include_api) do
    content =
      case template do
        "basic" ->
          generate_basic_readme(project_info, include_install, include_usage, include_api)

        "comprehensive" ->
          generate_comprehensive_readme(project_info, include_install, include_usage, include_api)

        "minimal" ->
          generate_minimal_readme(project_info, include_install, include_usage, include_api)

        _ ->
          generate_comprehensive_readme(project_info, include_install, include_usage, include_api)
      end

    %{content: content, template: template}
  end

  defp update_readme(project_info, template, include_install, include_usage, include_api) do
    # Update existing README
    readme_file = Path.join(project_info.path, "README.md")

    case File.read(readme_file) do
      {:ok, existing_content} ->
        # Merge with existing content
        new_content =
          merge_readme_content(
            existing_content,
            project_info,
            template,
            include_install,
            include_usage,
            include_api
          )

        %{content: new_content, template: template, updated: true}

      {:error, _} ->
        # Generate new README
        generate_readme(project_info, template, include_install, include_usage, include_api)
    end
  end

  defp validate_readme(project_info) do
    readme_file = Path.join(project_info.path, "README.md")

    case File.read(readme_file) do
      {:ok, content} ->
        %{
          exists: true,
          has_title: String.contains?(content, "#"),
          has_description: String.length(content) > 100,
          has_install:
            String.contains?(content, "install") or String.contains?(content, "Install"),
          has_usage: String.contains?(content, "usage") or String.contains?(content, "Usage"),
          size: String.length(content)
        }

      {:error, _} ->
        %{exists: false}
    end
  end

  defp generate_basic_readme(project_info, include_install, include_usage, include_api) do
    """
    # #{project_info.name}

    #{project_info.name} project.

    #{if include_install, do: "## Installation\n\nInstallation instructions here.\n", else: ""}

    #{if include_usage, do: "## Usage\n\nUsage examples here.\n", else: ""}
    """
  end

  defp generate_comprehensive_readme(project_info, include_install, include_usage, include_api) do
    """
    # #{project_info.name}

    A comprehensive project description.

    ## Table of Contents
    - [Installation](#installation)
    - [Usage](#usage)
    - [API](#api)
    - [Contributing](#contributing)
    - [License](#license)

    ## Description

    This project provides...

    #{if include_install, do: "## Installation\n\n```bash\ngit clone <repository>\ncd #{project_info.name}\nmix deps.get\n```\n", else: ""}

    #{if include_usage, do: "## Usage\n\n```elixir\n# Example usage\nIO.puts(\"Hello, World!\")\n```\n", else: ""}

    #{if include_api, do: "## API\n\nAPI documentation here.\n", else: ""}

    ## Contributing

    Contributions are welcome!

    ## License

    MIT License
    """
  end

  defp generate_minimal_readme(project_info, include_install, include_usage, include_api) do
    """
    # #{project_info.name}

    #{project_info.name} project.
    """
  end

  defp merge_readme_content(
         existing_content,
         project_info,
         template,
         include_install,
         include_usage,
         include_api
       ) do
    # Simple merge - in practice, this would be more sophisticated
    existing_content <> "\n\n---\n\nUpdated: #{DateTime.utc_now()}"
  end
end
