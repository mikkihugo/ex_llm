defmodule Singularity.Templates.TemplateFormatters do
  @moduledoc """
  Custom Solid (Handlebars) helpers for Singularity templates.

  Provides domain-specific transformations for code generation templates:
  - Module/function name formatting
  - Path conversions
  - List formatting (bullets, numbered)
  - Error matrix formatting
  - Relationship formatting

  ## Usage

  Register helpers on application startup:

      Singularity.Templates.TemplateFormatters.register_all()

  Then use in templates:

      {{module_to_path module_name}}
      {{#bullet_list relationships}}
      {{#error_matrix errors}}
  """

  @doc """
  Register all helpers with Solid.

  Call this once during application startup (e.g., in Application.start/2).
  """
  def register_all do
    Solid.Helpers.register(:module_to_path, &module_to_path/2)
    Solid.Helpers.register(:module_list, &module_list/2)
    Solid.Helpers.register(:bullet_list, &bullet_list/2)
    Solid.Helpers.register(:numbered_list, &numbered_list/2)
    Solid.Helpers.register(:error_matrix, &error_matrix/2)
    Solid.Helpers.register(:relationship_list, &relationship_list/2)
    Solid.Helpers.register(:format_spec, &format_spec/2)
    Solid.Helpers.register(:indent, &indent/2)
    :ok
  end

  ## Helper Implementations

  @doc """
  Convert module name to file path.

  ## Examples

      iex> module_to_path(%{"value" => "MyApp.UserService"}, %{})
      "lib/my_app/user_service.ex"

      iex> module_to_path(%{"value" => "MyAppWeb.UserController"}, %{})
      "lib/my_app_web/user_controller.ex"
  """
  def module_to_path(node, _context) do
    module_name = extract_value(node)

    module_name
    |> String.replace(".", "/")
    |> Macro.underscore()
    |> then(&"lib/#{&1}.ex")
  end

  @doc """
  Format a list of modules as bullet points with descriptions.

  ## Examples

      iex> module_list(%{"value" => [
      ...>   %{"module" => "MyApp.Repo", "purpose" => "Database operations"},
      ...>   %{"module" => "MyApp.Cache", "purpose" => "Caching"}
      ...> ]}, %{})
      "- **MyApp.Repo** - Database operations\\n- **MyApp.Cache** - Caching"
  """
  def module_list(node, _context) do
    modules = extract_value(node)

    modules
    |> Enum.map(fn
      %{"module" => mod, "purpose" => purpose} ->
        "- **#{mod}** - #{purpose}"

      %{"name" => name, "description" => desc} ->
        "- **#{name}** - #{desc}"

      module when is_binary(module) ->
        "- **#{module}**"
    end)
    |> Enum.join("\n")
  end

  @doc """
  Format a list as markdown bullets.

  ## Examples

      iex> bullet_list(%{"value" => ["Feature 1", "Feature 2", "Feature 3"]}, %{})
      "- Feature 1\\n- Feature 2\\n- Feature 3"
  """
  def bullet_list(node, _context) do
    items = extract_value(node)

    items
    |> Enum.map(fn
      item when is_binary(item) -> "- #{item}"
      item -> "- #{inspect(item)}"
    end)
    |> Enum.join("\n")
  end

  @doc """
  Format a list as numbered list.

  ## Examples

      iex> numbered_list(%{"value" => ["First", "Second", "Third"]}, %{})
      "1. First\\n2. Second\\n3. Third"
  """
  def numbered_list(node, _context) do
    items = extract_value(node)

    items
    |> Enum.with_index(1)
    |> Enum.map(fn {item, idx} ->
      "#{idx}. #{item}"
    end)
    |> Enum.join("\n")
  end

  @doc """
  Format error matrix as markdown list.

  ## Examples

      iex> error_matrix(%{"value" => [
      ...>   %{"atom" => "invalid_input", "description" => "When input validation fails"},
      ...>   %{"atom" => "not_found", "description" => "When resource doesn't exist"}
      ...> ]}, %{})
      "- `:invalid_input` - When input validation fails\\n- `:not_found` - When resource doesn't exist"
  """
  def error_matrix(node, _context) do
    errors = extract_value(node)

    errors
    |> Enum.map(fn
      %{"atom" => atom, "description" => desc} ->
        "- `:#{atom}` - #{desc}"

      %{"name" => name, "desc" => desc} ->
        "- `:#{name}` - #{desc}"

      error when is_binary(error) ->
        "- #{error}"
    end)
    |> Enum.join("\n")
  end

  @doc """
  Format relationship list (calls, called_by, depends_on, integrates_with).

  ## Examples

      iex> relationship_list(%{"value" => [
      ...>   %{"type" => "calls", "module" => "MyApp.Repo", "function" => "insert", "arity" => 1, "purpose" => "Save data"},
      ...>   %{"type" => "called_by", "module" => "MyAppWeb.UserController", "purpose" => "HTTP requests"}
      ...> ]}, %{})
      "- **Calls:** MyApp.Repo.insert/1 - Save data\\n- **Called by:** MyAppWeb.UserController - HTTP requests"
  """
  def relationship_list(node, _context) do
    relationships = extract_value(node)

    relationships
    |> Enum.group_by(fn rel -> rel["type"] end)
    |> Enum.flat_map(fn {type, rels} ->
      type_label = format_relationship_type(type)

      rels
      |> Enum.map(fn rel ->
        format_single_relationship(type_label, rel)
      end)
    end)
    |> Enum.join("\n")
  end

  defp format_relationship_type(type) do
    case type do
      "calls" -> "Calls"
      "called_by" -> "Called by"
      "depends_on" -> "Depends on"
      "integrates_with" -> "Integrates with"
      _ -> String.capitalize(type)
    end
  end

  defp format_single_relationship(type_label, rel) do
    module = rel["module"]
    function = rel["function"]
    arity = rel["arity"]
    purpose = rel["purpose"]

    function_part =
      if function && arity do
        ".#{function}/#{arity}"
      else
        ""
      end

    purpose_part = if purpose, do: " - #{purpose}", else: ""

    "- **#{type_label}:** #{module}#{function_part}#{purpose_part}"
  end

  @doc """
  Format function spec.

  ## Examples

      iex> format_spec(%{"value" => %{
      ...>   "name" => "register",
      ...>   "args" => "map()",
      ...>   "return" => "{:ok, user} | {:error, reason}"
      ...> }}, %{})
      "@spec register(map()) :: {:ok, user} | {:error, reason}"
  """
  def format_spec(node, _context) do
    spec = extract_value(node)

    name = spec["name"]
    args = spec["args"]
    return_type = spec["return"]

    "@spec #{name}(#{args}) :: #{return_type}"
  end

  @doc """
  Indent text by N spaces.

  ## Examples

      iex> indent(%{"value" => "line 1\\nline 2", "indent" => 2}, %{})
      "  line 1\\n  line 2"
  """
  def indent(node, _context) do
    text = extract_value(node)
    indent_size = node["indent"] || 2

    padding = String.duplicate(" ", indent_size)

    text
    |> String.split("\n")
    |> Enum.map(&"#{padding}#{&1}")
    |> Enum.join("\n")
  end

  ## Private Helpers

  defp extract_value(%{"value" => value}), do: value
  defp extract_value(node) when is_binary(node), do: node
  defp extract_value(node), do: node
end
