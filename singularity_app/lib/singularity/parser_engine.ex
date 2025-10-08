defmodule Singularity.ParserEngine do
  @moduledoc """
  Parser Engine - Consolidated parsing and database streaming

  Provides a unified interface for parsing code files and streaming AST data
  directly into PostgreSQL. Replaces the old code_parser NIF with enhanced
  database integration capabilities.

  ## Features

  - Universal AST parsing for 30+ languages
  - Direct database streaming (no intermediate files)
  - AST element extraction (functions, classes, imports, exports)
  - Language detection and dependency analysis
  - Batch processing capabilities

  ## Usage

      # Parse and store a single file
      {:ok, result} = ParserEngine.parse_and_store_file("lib/my_module.ex")

      # Parse and store entire directory tree
      {:ok, results} = ParserEngine.parse_and_store_tree("lib/")

      # Extract specific AST elements
      functions = ParserEngine.extract_functions("lib/my_module.ex")
      classes = ParserEngine.extract_classes("lib/my_module.ex")

  ## Database Integration

  All parsed data is automatically stored in the `code_files` table with:
  - Raw file content and metadata
  - Complete AST as JSONB
  - Extracted elements (functions, classes, imports, exports, symbols)
  - Language detection and file hashing
  - Parsing timestamps

  This enables rich querying and analysis across the entire codebase.
  """

  require Logger
  alias Singularity.Repo
  alias Singularity.Schemas.CodeFile

  # Public API - Parse and store functions
  @doc """
  Parse a single file and store the AST data in the database.

  Returns `{:ok, result}` on success or `{:error, reason}` on failure.
  """
  def parse_and_store_file(file_path) do
    Logger.info("Parsing and storing file: #{file_path}")
    
    case File.read(file_path) do
      {:ok, content} ->
        case detect_language(file_path) do
          {:ok, language} ->
            case parse_file(file_path) do
              {:ok, ast_data} ->
                store_document(file_path, language, content, ast_data)
              {:error, reason} -> {:error, "Failed to parse file: #{reason}"}
            end
          {:error, reason} -> {:error, "Failed to detect language: #{reason}"}
        end
      {:error, reason} -> {:error, "Failed to read file: #{reason}"}
    end
  end

  @doc """
  Parse an entire directory tree and store all AST data in the database.

  Returns `{:ok, results}` with a list of parsing results.
  """
  def parse_and_store_tree(directory_path) do
    Logger.info("Parsing and storing directory tree: #{directory_path}")
    
    case File.ls(directory_path) do
      {:ok, files} ->
        results = 
          files
          |> Enum.map(fn file ->
            full_path = Path.join(directory_path, file)
            if File.dir?(full_path) do
              parse_and_store_tree(full_path)
            else
              parse_and_store_file(full_path)
            end
          end)
          |> List.flatten()
        
        {:ok, results}
      {:error, reason} -> {:error, "Failed to list directory: #{reason}"}
    end
  end

  # Legacy API - Parse only functions (for backward compatibility)
  @doc """
  Parse a single file and return AST data (legacy function).

  Use `parse_and_store_file/1` for new code that needs database storage.
  """
  def parse_file(file_path) do
    # Call the native NIF directly - no need to read file content
    # The NIF handles file reading internally
    case :parser_engine.parse_file(file_path) do
      {:ok, ast_document} ->
        # Convert Rust struct to Elixir map for easier handling
        ast_data = convert_ast_to_map(ast_document)
        {:ok, ast_data}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Parse an entire directory tree (legacy function).

  Use `parse_and_store_tree/1` for new code that needs database storage.
  """
  def parse_tree(directory_path) do
    # Call the native NIF directly - handles directory traversal internally
    case :parser_engine.parse_tree(directory_path) do
      {:ok, ast_documents} ->
        # Convert Rust structs to Elixir maps
        ast_data = Enum.map(ast_documents, &convert_ast_to_map/1)
        {:ok, ast_data}
      {:error, reason} -> {:error, reason}
    end
  end

  # AST element extraction functions
  @doc """
  Extract all functions from a file's AST.
  """
  def extract_functions(file_path) do
    case parse_file(file_path) do
      {:ok, ast_data} -> extract_ast_elements(ast_data, "functions")
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extract all classes from a file's AST.
  """
  def extract_classes(file_path) do
    case parse_file(file_path) do
      {:ok, ast_data} -> extract_ast_elements(ast_data, "classes")
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extract all imports from a file's AST.
  """
  def extract_imports(file_path) do
    case parse_file(file_path) do
      {:ok, ast_data} -> extract_ast_elements(ast_data, "imports")
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extract all exports from a file's AST.
  """
  def extract_exports(file_path) do
    case parse_file(file_path) do
      {:ok, ast_data} -> extract_ast_elements(ast_data, "exports")
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extract all symbols from a file's AST.
  """
  def extract_symbols(file_path) do
    case parse_file(file_path) do
      {:ok, ast_data} -> extract_ast_elements(ast_data, "symbols")
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extract all AST elements from a file.
  """
  def extract_ast(file_path) do
    case parse_file(file_path) do
      {:ok, ast_data} -> {:ok, ast_data}
      {:error, reason} -> {:error, reason}
    end
  end

  # Language detection
  @doc """
  Detect the programming language of a file based on its extension.
  """
  def detect_language(file_path) do
    extension = Path.extname(file_path) |> String.downcase()
    
    language = case extension do
      ".ex" -> "elixir"
      ".exs" -> "elixir"
      ".gleam" -> "gleam"
      ".rs" -> "rust"
      ".js" -> "javascript"
      ".ts" -> "typescript"
      ".tsx" -> "typescript"
      ".jsx" -> "javascript"
      ".py" -> "python"
      ".go" -> "go"
      ".java" -> "java"
      ".c" -> "c"
      ".cpp" -> "cpp"
      ".h" -> "c"
      ".hpp" -> "cpp"
      ".cs" -> "csharp"
      ".php" -> "php"
      ".rb" -> "ruby"
      ".swift" -> "swift"
      ".kt" -> "kotlin"
      ".scala" -> "scala"
      ".clj" -> "clojure"
      ".hs" -> "haskell"
      ".ml" -> "ocaml"
      ".fs" -> "fsharp"
      ".dart" -> "dart"
      ".lua" -> "lua"
      ".r" -> "r"
      ".m" -> "matlab"
      ".jl" -> "julia"
      ".sh" -> "bash"
      ".zsh" -> "zsh"
      ".fish" -> "fish"
      ".ps1" -> "powershell"
      ".bat" -> "batch"
      ".cmd" -> "batch"
      ".sql" -> "sql"
      ".html" -> "html"
      ".css" -> "css"
      ".scss" -> "scss"
      ".sass" -> "sass"
      ".less" -> "less"
      ".xml" -> "xml"
      ".yaml" -> "yaml"
      ".yml" -> "yaml"
      ".json" -> "json"
      ".toml" -> "toml"
      ".ini" -> "ini"
      ".cfg" -> "config"
      ".conf" -> "config"
      ".env" -> "env"
      ".dockerfile" -> "dockerfile"
      ".md" -> "markdown"
      ".rst" -> "restructuredtext"
      ".tex" -> "latex"
      ".txt" -> "text"
      _ -> "unknown"
    end

    if language == "unknown" do
      {:error, "Unknown file type: #{extension}"}
    else
      {:ok, language}
    end
  end

  # Dependency analysis
  @doc """
  Find dependencies for a file based on its language and content.
  """
  def find_dependencies(file_path) do
    case detect_language(file_path) do
      {:ok, _language} ->
        case parse_file(file_path) do
          {:ok, ast_data} ->
            dependencies = extract_ast_elements(ast_data, "dependencies") || []
            {:ok, dependencies}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  # Batch processing functions
  @doc """
  Parse multiple files in parallel.
  """
  def parse_files(file_paths) do
    file_paths
    |> Task.async_stream(&parse_file/1, max_concurrency: 10)
    |> Enum.map(fn {:ok, result} -> result end)
  end

  @doc """
  Parse files by language filter.
  """
  def parse_tree_by_language(directory_path, language_filter) do
    case File.ls(directory_path) do
      {:ok, files} ->
        filtered_files = 
          files
          |> Enum.filter(fn file ->
            full_path = Path.join(directory_path, file)
            case detect_language(full_path) do
              {:ok, language} -> language == language_filter
              {:error, _} -> false
            end
          end)
        
        parse_files(filtered_files)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extract all functions from multiple files.
  """
  def extract_all_functions(file_paths) do
    file_paths
    |> Task.async_stream(&extract_functions/1, max_concurrency: 10)
    |> Enum.map(fn {:ok, result} -> result end)
  end

  @doc """
  Extract all classes from multiple files.
  """
  def extract_all_classes(file_paths) do
    file_paths
    |> Task.async_stream(&extract_classes/1, max_concurrency: 10)
    |> Enum.map(fn {:ok, result} -> result end)
  end

  # Private helper functions
  defp convert_ast_to_map(ast_document) do
    # Convert Rust ParsedDocument struct to Elixir map
    %{
      "descriptor" => %{
        "path" => ast_document.descriptor.path,
        "kind" => ast_document.descriptor.kind,
        "language" => ast_document.descriptor.language
      },
      "metadata" => %{
        "parser_version" => ast_document.metadata.parser_version,
        "analyzed_at" => ast_document.metadata.analyzed_at,
        "additional" => ast_document.metadata.additional
      },
      "symbols" => Enum.map(ast_document.symbols, &convert_symbol_to_map/1),
      "classes" => Enum.map(ast_document.classes, &convert_class_to_map/1),
      "enums" => Enum.map(ast_document.enums, &convert_enum_to_map/1),
      "docstrings" => Enum.map(ast_document.docstrings, &convert_docstring_to_map/1),
      "stats" => %{
        "byte_length" => ast_document.stats.byte_length,
        "total_nodes" => ast_document.stats.total_nodes,
        "total_tokens" => ast_document.stats.total_tokens,
        "duration_ms" => ast_document.stats.duration_ms
      },
      "diagnostics" => ast_document.diagnostics
    }
  end

  defp convert_symbol_to_map(symbol) do
    %{
      "name" => symbol.name,
      "kind" => symbol.kind,
      "range" => symbol.range,
      "signature" => symbol.signature
    }
  end

  defp convert_class_to_map(class) do
    %{
      "name" => class.name,
      "bases" => class.bases,
      "decorators" => Enum.map(class.decorators, &convert_decorator_to_map/1),
      "docstring" => class.docstring,
      "range" => class.range
    }
  end

  defp convert_enum_to_map(enum) do
    %{
      "name" => enum.name,
      "variants" => Enum.map(enum.variants, &convert_enum_variant_to_map/1),
      "decorators" => Enum.map(enum.decorators, &convert_decorator_to_map/1),
      "docstring" => enum.docstring,
      "range" => enum.range
    }
  end

  defp convert_enum_variant_to_map(variant) do
    %{
      "name" => variant.name,
      "value" => variant.value,
      "range" => variant.range
    }
  end

  defp convert_decorator_to_map(decorator) do
    %{
      "name" => decorator.name,
      "arguments" => decorator.arguments
    }
  end

  defp convert_docstring_to_map(docstring) do
    %{
      "owner" => docstring.owner,
      "kind" => docstring.kind,
      "value" => docstring.value,
      "range" => docstring.range
    }
  end

  defp extract_ast_elements(ast_data, element_type) do
    case ast_data do
      %{^element_type => elements} when is_list(elements) -> elements
      _ -> []
    end
  end

  # Database storage functions
  defp store_document(file_path, language, content, ast_data) do
    case normalize_document(file_path, language, content, ast_data) do
      {:ok, document} ->
        case Repo.insert(document) do
          {:ok, inserted} -> {:ok, inserted}
          {:error, changeset} -> {:error, changeset}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_document(file_path, language, content, ast_data) do
    try do
      # Extract AST elements from the new structure
      functions = extract_functions_from_ast(ast_data)
      classes = extract_classes_from_ast(ast_data)
      imports = extract_imports_from_ast(ast_data)
      exports = extract_exports_from_ast(ast_data)
      symbols = extract_symbols_from_ast(ast_data)

      # Create changeset
      changeset = CodeFile.changeset(%CodeFile{}, %{
        file_path: file_path,
        language: language,
        content: content,
        size: byte_size(content),
        hash: :crypto.hash(:sha256, content) |> Base.encode16(),
        ast_json: ast_data,
        functions: functions,
        classes: classes,
        imports: imports,
        exports: exports,
        symbols: symbols,
        parsed_at: DateTime.utc_now()
      })

      {:ok, changeset}
    rescue
      error -> {:error, "Failed to normalize document: #{inspect(error)}"}
    end
  end

  defp extract_functions_from_ast(ast_data) do
    ast_data["symbols"]
    |> Enum.filter(fn symbol -> symbol["kind"] == "function" end)
    |> Enum.map(fn symbol ->
      %{
        "name" => symbol["name"],
        "signature" => symbol["signature"],
        "range" => symbol["range"]
      }
    end)
  end

  defp extract_classes_from_ast(ast_data) do
    ast_data["classes"]
    |> Enum.map(fn class ->
      %{
        "name" => class["name"],
        "bases" => class["bases"],
        "decorators" => class["decorators"],
        "docstring" => class["docstring"],
        "range" => class["range"]
      }
    end)
  end

  defp extract_imports_from_ast(ast_data) do
    ast_data["symbols"]
    |> Enum.filter(fn symbol -> symbol["kind"] == "import" end)
    |> Enum.map(fn symbol ->
      %{
        "name" => symbol["name"],
        "signature" => symbol["signature"],
        "range" => symbol["range"]
      }
    end)
  end

  defp extract_exports_from_ast(ast_data) do
    ast_data["symbols"]
    |> Enum.filter(fn symbol -> symbol["kind"] == "export" end)
    |> Enum.map(fn symbol ->
      %{
        "name" => symbol["name"],
        "signature" => symbol["signature"],
        "range" => symbol["range"]
      }
    end)
  end

  defp extract_symbols_from_ast(ast_data) do
    ast_data["symbols"]
  end
end
