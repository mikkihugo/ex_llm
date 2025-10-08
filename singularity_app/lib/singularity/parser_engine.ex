defmodule Singularity.ParserEngine do
  @moduledoc """
  Parser Engine - Single source of truth for code parsing
  
  Provides unified AST parsing capabilities using the Rust parser-engine NIF.
  This is the ONLY parser interface - all other parsing should go through this module.
  
  ## Features:
  - Parse files in 30+ languages
  - Extract AST, functions, classes, imports, exports
  - Language detection and validation
  - Cross-file dependency analysis
  - Tree parsing for entire directories
  
  ## Usage:
  
      # Parse a single file
      {:ok, document} = ParserEngine.parse_file("src/app.js")
      
      # Parse entire directory tree
      {:ok, documents} = ParserEngine.parse_tree("src/")
      
      # Get AST from parsed document
      ast = document.ast
      functions = document.functions
      classes = document.classes
  """

  use Rustler, otp_app: :singularity, crate: :parser_engine

  # ============================================================================
  # NIF FUNCTIONS (Fast Local)
  # ============================================================================

  @doc """
  Parse a single file and return structured document
  
  ## Examples
  
      iex> ParserEngine.parse_file("src/app.js")
      {:ok, %{
        language: "javascript",
        ast: %{...},
        functions: [...],
        classes: [...],
        imports: [...],
        exports: [...],
        metadata: %{...}
      }}
  """
  def parse_file(_file_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Parse entire directory tree and return all documents
  
  ## Examples
  
      iex> ParserEngine.parse_tree("src/")
      {:ok, [
        %{path: "src/app.js", language: "javascript", ...},
        %{path: "src/utils.js", language: "javascript", ...},
        %{path: "lib/app.ex", language: "elixir", ...}
      ]}
  """
  def parse_tree(_root_path), do: :erlang.nif_error(:nif_not_loaded)

  # ============================================================================
  # CONVENIENCE FUNCTIONS (Elixir Layer)
  # ============================================================================

  @doc """
  Parse file and extract just the AST
  
  ## Examples
  
      iex> ParserEngine.extract_ast("src/app.js")
      {:ok, %{type: "Program", body: [...]}}
  """
  def extract_ast(file_path) do
    case parse_file(file_path) do
      {:ok, document} -> {:ok, document.ast}
      error -> error
    end
  end

  @doc """
  Parse file and extract just the functions
  
  ## Examples
  
      iex> ParserEngine.extract_functions("src/app.js")
      {:ok, [
        %{name: "handleClick", line: 15, params: [...]},
        %{name: "calculateTotal", line: 42, params: [...]}
      ]}
  """
  def extract_functions(file_path) do
    case parse_file(file_path) do
      {:ok, document} -> {:ok, document.functions || []}
      error -> error
    end
  end

  @doc """
  Parse file and extract just the classes
  
  ## Examples
  
      iex> ParserEngine.extract_classes("src/User.js")
      {:ok, [
        %{name: "User", line: 5, methods: [...]}
      ]}
  """
  def extract_classes(file_path) do
    case parse_file(file_path) do
      {:ok, document} -> {:ok, document.classes || []}
      error -> error
    end
  end

  @doc """
  Parse file and extract just the imports
  
  ## Examples
  
      iex> ParserEngine.extract_imports("src/app.js")
      {:ok, [
        %{source: "react", specifiers: [...]},
        %{source: "./utils", specifiers: [...]}
      ]}
  """
  def extract_imports(file_path) do
    case parse_file(file_path) do
      {:ok, document} -> {:ok, document.imports || []}
      error -> error
    end
  end

  @doc """
  Parse file and extract just the exports
  
  ## Examples
  
      iex> ParserEngine.extract_exports("src/utils.js")
      {:ok, [
        %{type: "default", name: "calculateTotal"},
        %{type: "named", name: "formatDate"}
      ]}
  """
  def extract_exports(file_path) do
    case parse_file(file_path) do
      {:ok, document} -> {:ok, document.exports || []}
      error -> error
    end
  end

  @doc """
  Parse file and detect language
  
  ## Examples
  
      iex> ParserEngine.detect_language("src/app.js")
      {:ok, "javascript"}
      
      iex> ParserEngine.detect_language("lib/app.ex")
      {:ok, "elixir"}
  """
  def detect_language(file_path) do
    case parse_file(file_path) do
      {:ok, document} -> {:ok, document.language}
      error -> error
    end
  end

  @doc """
  Parse file and find dependencies
  
  ## Examples
  
      iex> ParserEngine.find_dependencies("src/app.js")
      {:ok, [
        %{type: "import", source: "./utils"},
        %{type: "require", source: "react"}
      ]}
  """
  def find_dependencies(file_path) do
    case parse_file(file_path) do
      {:ok, document} -> {:ok, document.imports || []}
      error -> error
    end
  end

  # ============================================================================
  # BATCH OPERATIONS (Elixir Layer)
  # ============================================================================

  @doc """
  Parse multiple files in parallel
  
  ## Examples
  
      iex> ParserEngine.parse_files(["src/app.js", "src/utils.js"])
      {:ok, [
        %{path: "src/app.js", language: "javascript", ...},
        %{path: "src/utils.js", language: "javascript", ...}
      ]}
  """
  def parse_files(file_paths) when is_list(file_paths) do
    file_paths
    |> Task.async_stream(&parse_file/1, max_concurrency: 10)
    |> Enum.map(fn {:ok, result} -> result end)
    |> case do
      results when is_list(results) -> {:ok, results}
      error -> error
    end
  end

  @doc """
  Parse directory and filter by language
  
  ## Examples
  
      iex> ParserEngine.parse_tree_by_language("src/", "javascript")
      {:ok, [
        %{path: "src/app.js", language: "javascript", ...},
        %{path: "src/utils.js", language: "javascript", ...}
      ]}
  """
  def parse_tree_by_language(root_path, language) do
    case parse_tree(root_path) do
      {:ok, documents} -> 
        filtered = Enum.filter(documents, &(&1.language == language))
        {:ok, filtered}
      error -> error
    end
  end

  @doc """
  Parse directory and extract all functions across all files
  
  ## Examples
  
      iex> ParserEngine.extract_all_functions("src/")
      {:ok, [
        %{file: "src/app.js", name: "handleClick", line: 15},
        %{file: "src/utils.js", name: "calculateTotal", line: 42}
      ]}
  """
  def extract_all_functions(root_path) do
    case parse_tree(root_path) do
      {:ok, documents} ->
        functions = 
          documents
          |> Enum.flat_map(fn doc ->
            (doc.functions || [])
            |> Enum.map(&Map.put(&1, :file, doc.path))
          end)
        {:ok, functions}
      error -> error
    end
  end

  @doc """
  Parse directory and extract all classes across all files
  
  ## Examples
  
      iex> ParserEngine.extract_all_classes("src/")
      {:ok, [
        %{file: "src/User.js", name: "User", line: 5},
        %{file: "src/Product.js", name: "Product", line: 12}
      ]}
  """
  def extract_all_classes(root_path) do
    case parse_tree(root_path) do
      {:ok, documents} ->
        classes = 
          documents
          |> Enum.flat_map(fn doc ->
            (doc.classes || [])
            |> Enum.map(&Map.put(&1, :file, doc.path))
          end)
        {:ok, classes}
      error -> error
    end
  end
end