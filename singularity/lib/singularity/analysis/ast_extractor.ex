defmodule Singularity.Analysis.AstExtractor do
  @moduledoc """
  AST Metadata Extractor - Enhanced dependency and call graph extraction

  **PURPOSE**: Parse tree-sitter AST JSON and extract structured metadata

  ## What It Extracts

  1. **Dependency Graph**: Internal vs external dependencies
  2. **Call Graph**: Function calls (who calls whom)
  3. **Type Information**: From @spec annotations
  4. **Documentation**: Full @moduledoc and @doc text

  ## Module Identity

  ```json
  {
    "module_name": "Singularity.Analysis.AstExtractor",
    "purpose": "Extract structured metadata from tree-sitter AST",
    "type": "Pure function module (no GenServer)",
    "operates_on": "AST JSON strings from CodeEngine NIF",
    "output": "Enhanced metadata map"
  }
  ```

  ## Call Graph (YAML)

  ```yaml
  AstExtractor:
    calls:
      - Jason.decode/1  # Parse AST JSON
      - extract_dependencies/1  # Extract deps
      - extract_call_graph/1  # Extract function calls
      - extract_type_info/1  # Extract @spec
      - extract_documentation/1  # Extract @doc
    called_by:
      - HTDAGAutoBootstrap.persist_module_to_db/2
      - CodeFileWatcher.reingest_file/2
  ```

  ## Anti-Patterns

  **DO NOT create these duplicates:**
  - ❌ `AstParser` - This IS the AST parser
  - ❌ `MetadataExtractor` - Same purpose
  - ❌ `DependencyAnalyzer` - Subset of this module

  ## Usage

      iex> ast_json = CodeEngine.parse_file("lib/foo.ex").ast_json
      iex> metadata = AstExtractor.extract_metadata(ast_json, "lib/foo.ex")
      %{
        dependencies: %{internal: [...], external: [...]},
        call_graph: %{...},
        type_info: %{...},
        documentation: %{...}
      }

  ## Search Keywords

  ast-parsing, dependency-extraction, call-graph, type-analysis, tree-sitter,
  metadata-enhancement, code-analysis, static-analysis, elixir-ast
  """

  require Logger

  @doc """
  Extract enhanced metadata from tree-sitter AST JSON.

  Returns map with:
  - `:dependencies` - Internal and external dependencies
  - `:call_graph` - Function call relationships
  - `:type_info` - Type signatures from @spec
  - `:documentation` - Full documentation text
  """
  def extract_metadata(ast_json, file_path) when is_binary(ast_json) do
    case Jason.decode(ast_json) do
      {:ok, ast} ->
        %{
          dependencies: extract_dependencies(ast, file_path),
          call_graph: extract_call_graph(ast),
          type_info: extract_type_info(ast),
          documentation: extract_documentation(ast)
        }

      {:error, reason} ->
        Logger.warning("Failed to parse AST JSON for #{file_path}: #{inspect(reason)}")
        %{dependencies: %{}, call_graph: %{}, type_info: %{}, documentation: %{}}
    end
  end

  def extract_metadata(nil, _file_path), do: %{}

  # ------------------------------------------------------------------------------
  # Dependency Extraction
  # ------------------------------------------------------------------------------

  @doc """
  Extract dependencies from AST.

  Returns:
  ```elixir
  %{
    internal: ["Singularity.Foo", "Singularity.Bar"],
    external: ["Ecto.Schema", "Phoenix.Controller"]
  }
  ```
  """
  def extract_dependencies(ast, file_path) do
    aliases = extract_aliases(ast)
    imports = extract_imports(ast)
    uses = extract_uses(ast)

    all_deps = (aliases ++ imports ++ uses) |> Enum.uniq()

    # Classify as internal vs external
    internal = Enum.filter(all_deps, &internal_module?(&1, file_path))
    external = Enum.filter(all_deps, &(!internal_module?(&1, file_path)))

    %{
      internal: internal,
      external: external,
      all: all_deps
    }
  end

  defp extract_aliases(ast) do
    # Find all `alias Foo` nodes in AST
    find_nodes(ast, "alias")
    |> Enum.map(&extract_module_name/1)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_imports(ast) do
    # Find all `import Foo` nodes in AST
    find_nodes(ast, "import")
    |> Enum.map(&extract_module_name/1)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_uses(ast) do
    # Find all `use Foo` nodes in AST
    find_nodes(ast, "use")
    |> Enum.map(&extract_module_name/1)
    |> Enum.reject(&is_nil/1)
  end

  defp internal_module?(module_name, file_path) do
    # Internal if starts with "Singularity." or in same directory
    String.starts_with?(module_name, "Singularity.") or
      same_directory?(module_name, file_path)
  end

  defp same_directory?(module_name, file_path) do
    # Check if module is in same directory (relative import)
    file_dir = Path.dirname(file_path)
    module_file = module_name_to_file_path(module_name)

    String.starts_with?(module_file, file_dir)
  end

  defp module_name_to_file_path(module_name) do
    # Convert "Singularity.Foo.Bar" -> "lib/singularity/foo/bar.ex"
    module_name
    |> String.split(".")
    |> Enum.map(&Macro.underscore/1)
    |> Path.join()
    |> Kernel.<>(".ex")
  end

  # ------------------------------------------------------------------------------
  # Call Graph Extraction
  # ------------------------------------------------------------------------------

  @doc """
  Extract call graph (who calls whom) from AST.

  Returns:
  ```elixir
  %{
    "my_function/2" => %{
      calls: ["other_func/1", "Ecto.Repo.get/2"],
      line: 42
    }
  }
  ```
  """
  def extract_call_graph(ast) do
    functions = find_nodes(ast, "function")

    Enum.reduce(functions, %{}, fn func_node, acc ->
      func_name = extract_function_signature(func_node)
      calls = extract_function_calls(func_node)
      line = get_node_line(func_node)

      Map.put(acc, func_name, %{
        calls: calls,
        line: line
      })
    end)
  end

  defp extract_function_calls(func_node) do
    # Find all function call nodes within this function
    find_nodes(func_node, "call")
    |> Enum.map(&extract_call_target/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp extract_call_target(call_node) do
    # Extract target function from call node
    # Example: "Foo.bar()" -> "Foo.bar"
    case get_node_text(call_node) do
      text when is_binary(text) ->
        text
        |> String.trim()
        # Remove arguments
        |> String.replace(~r/\(.*\)$/, "")

      _ ->
        nil
    end
  end

  defp extract_function_signature(func_node) do
    # Extract function name and arity
    # Example: "def foo(a, b)" -> "foo/2"
    name = get_node_field(func_node, "name")
    arity = count_parameters(func_node)

    if name, do: "#{name}/#{arity}", else: nil
  end

  defp count_parameters(func_node) do
    # Count parameters in function definition
    params = find_nodes(func_node, "parameter")
    length(params)
  end

  # ------------------------------------------------------------------------------
  # Type Information Extraction
  # ------------------------------------------------------------------------------

  @doc """
  Extract type information from @spec annotations.

  Returns:
  ```elixir
  %{
    "my_function/2" => %{
      args: ["integer()", "string()"],
      return: "{:ok, map()} | {:error, term()}"
    }
  }
  ```
  """
  def extract_type_info(ast) do
    specs = find_nodes(ast, "spec")

    Enum.reduce(specs, %{}, fn spec_node, acc ->
      func_name = extract_spec_function_name(spec_node)
      type_sig = extract_spec_signature(spec_node)

      if func_name do
        Map.put(acc, func_name, type_sig)
      else
        acc
      end
    end)
  end

  defp extract_spec_function_name(spec_node) do
    # Extract function name from @spec
    # Example: "@spec foo(integer) :: string" -> "foo"
    get_node_field(spec_node, "name")
  end

  defp extract_spec_signature(spec_node) do
    # Extract full type signature
    args = extract_spec_args(spec_node)
    return_type = extract_spec_return(spec_node)

    %{
      args: args,
      return: return_type,
      full: get_node_text(spec_node)
    }
  end

  defp extract_spec_args(spec_node) do
    find_nodes(spec_node, "type_arg")
    |> Enum.map(&get_node_text/1)
  end

  defp extract_spec_return(spec_node) do
    return_nodes = find_nodes(spec_node, "return_type")

    case return_nodes do
      [node | _] -> get_node_text(node)
      [] -> nil
    end
  end

  # ------------------------------------------------------------------------------
  # Documentation Extraction
  # ------------------------------------------------------------------------------

  @doc """
  Extract documentation from @moduledoc and @doc.

  Returns:
  ```elixir
  %{
    moduledoc: "Module documentation...",
    function_docs: %{
      "foo/2" => "Function documentation..."
    }
  }
  ```
  """
  def extract_documentation(ast) do
    %{
      moduledoc: extract_moduledoc(ast),
      function_docs: extract_function_docs(ast)
    }
  end

  defp extract_moduledoc(ast) do
    # Find @moduledoc node
    case find_nodes(ast, "moduledoc") do
      [node | _] ->
        get_node_text(node)
        |> String.trim()
        |> remove_doc_markers()

      [] ->
        nil
    end
  end

  defp extract_function_docs(ast) do
    # Find all @doc nodes and associate with following function
    doc_nodes = find_nodes(ast, "doc")

    Enum.reduce(doc_nodes, %{}, fn doc_node, acc ->
      doc_text = get_node_text(doc_node) |> remove_doc_markers()
      next_func = find_next_function(doc_node)

      if next_func do
        func_sig = extract_function_signature(next_func)
        Map.put(acc, func_sig, doc_text)
      else
        acc
      end
    end)
  end

  defp find_next_function(_doc_node) do
    # Find the function definition following this @doc
    # (Implementation depends on AST structure)
    # For now, return nil (would need to traverse siblings)
    nil
  end

  defp remove_doc_markers(text) when is_binary(text) do
    text
    |> String.replace(~r/@(moduledoc|doc)\s+"""/, "")
    |> String.replace(~r/"""$/, "")
    |> String.trim()
  end

  defp remove_doc_markers(nil), do: nil

  # ------------------------------------------------------------------------------
  # AST Traversal Helpers
  # ------------------------------------------------------------------------------

  @doc """
  Find all nodes of a given type in AST (recursive).
  """
  def find_nodes(ast, node_type) when is_map(ast) do
    results = []

    # Check if current node matches
    results =
      if Map.get(ast, "type") == node_type do
        [ast | results]
      else
        results
      end

    # Recursively search children
    children = Map.get(ast, "children", [])

    child_results =
      Enum.flat_map(children, fn child ->
        find_nodes(child, node_type)
      end)

    results ++ child_results
  end

  def find_nodes(_ast, _node_type), do: []

  defp get_node_field(node, field_name) do
    Map.get(node, field_name)
  end

  defp get_node_text(node) do
    Map.get(node, "text")
  end

  defp get_node_line(node) do
    case Map.get(node, "position") do
      %{"line" => line} -> line
      _ -> nil
    end
  end

  defp extract_module_name(node) do
    # Extract module name from alias/import/use node
    # Example: alias Foo.Bar -> "Foo.Bar"
    case get_node_field(node, "module") do
      module when is_binary(module) -> module
      _ -> get_node_text(node) |> parse_module_from_text()
    end
  end

  defp parse_module_from_text(text) when is_binary(text) do
    # Parse "alias Foo.Bar" -> "Foo.Bar"
    text
    |> String.replace(~r/^(alias|import|use)\s+/, "")
    |> String.split(",")
    |> List.first()
    |> String.trim()
  end

  defp parse_module_from_text(nil), do: nil
end
