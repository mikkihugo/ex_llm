defmodule Singularity.CodeParser do
  @moduledoc """
  Enhanced Code Parser - Multi-language code parsing and analysis
  
  Provides advanced code parsing capabilities:
  - Parse files in 30+ languages
  - Extract AST, functions, classes, imports
  - Language detection and validation
  - Cross-file dependency analysis
  """

  use Rustler, otp_app: :singularity_app, crate: :singularity_unified

  # Code parsing functions
  def parse_file(_file_path, _language \\ nil), do: :erlang.nif_error(:nif_not_loaded)
  def detect_language(_file_path), do: :erlang.nif_error(:nif_not_loaded)
  def extract_ast(_file_path, _language), do: :erlang.nif_error(:nif_not_loaded)
  def find_dependencies(_file_path), do: :erlang.nif_error(:nif_not_loaded)
  def extract_functions(_file_path), do: :erlang.nif_error(:nif_not_loaded)
  def extract_classes(_file_path), do: :erlang.nif_error(:nif_not_loaded)
  def extract_imports(_file_path), do: :erlang.nif_error(:nif_not_loaded)
  def extract_exports(_file_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Parse a single file with optional language hint
  
  ## Examples
  
      iex> Singularity.CodeParser.parse_file("src/app.js", "javascript")
      %{
        language: "javascript",
        ast: %{...},
        functions: [...],
        classes: [...],
        imports: [...],
        exports: [...]
      }
  """
  def parse_file(file_path, language \\ nil) do
    parse_file(file_path, language)
  end

  @doc """
  Detect programming language from file
  
  ## Examples
  
      iex> Singularity.CodeParser.detect_language("src/app.js")
      "javascript"
      
      iex> Singularity.CodeParser.detect_language("lib/app.ex")
      "elixir"
  """
  def detect_language(file_path) do
    detect_language(file_path)
  end

  @doc """
  Extract Abstract Syntax Tree from file
  
  ## Examples
  
      iex> Singularity.CodeParser.extract_ast("src/app.js", "javascript")
      %{
        type: "Program",
        body: [...],
        sourceType: "module"
      }
  """
  def extract_ast(file_path, language) do
    extract_ast(file_path, language)
  end

  @doc """
  Find file dependencies and imports
  
  ## Examples
  
      iex> Singularity.CodeParser.find_dependencies("src/app.js")
      [
        %{type: "import", source: "./utils", specifiers: [...]},
        %{type: "require", source: "react", specifiers: [...]}
      ]
  """
  def find_dependencies(file_path) do
    find_dependencies(file_path)
  end

  @doc """
  Extract function definitions from file
  
  ## Examples
  
      iex> Singularity.CodeParser.extract_functions("src/app.js")
      [
        %{name: "handleClick", line: 15, params: ["event"], return_type: "void"},
        %{name: "calculateTotal", line: 42, params: ["items"], return_type: "number"}
      ]
  """
  def extract_functions(file_path) do
    extract_functions(file_path)
  end

  @doc """
  Extract class definitions from file
  
  ## Examples
  
      iex> Singularity.CodeParser.extract_classes("src/User.js")
      [
        %{name: "User", line: 5, methods: [...], properties: [...]}
      ]
  """
  def extract_classes(file_path) do
    extract_classes(file_path)
  end

  @doc """
  Extract import statements from file
  
  ## Examples
  
      iex> Singularity.CodeParser.extract_imports("src/app.js")
      [
        %{source: "react", specifiers: ["useState", "useEffect"]},
        %{source: "./components/Button", specifiers: ["Button"]}
      ]
  """
  def extract_imports(file_path) do
    extract_imports(file_path)
  end

  @doc """
  Extract export statements from file
  
  ## Examples
  
      iex> Singularity.CodeParser.extract_exports("src/utils.js")
      [
        %{type: "default", name: "calculateTotal"},
        %{type: "named", name: "formatDate"}
      ]
  """
  def extract_exports(file_path) do
    extract_exports(file_path)
  end
end
