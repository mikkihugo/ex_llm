defmodule SeedAgent.Tools.Tool do
  @moduledoc """
  Defines a callable tool, including metadata, parameter schema, and execution function.
  """

  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  alias SeedAgent.Tools.ToolParam

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:description, :string)
    field(:display_text, :string)
    field(:async, :boolean, default: false)
    field(:parameters_schema, :map)
    field(:options, :map)
    field(:function, :any, virtual: true)
    field(:parameters, {:array, :map}, virtual: true)
  end

  @required_fields [:name, :function]
  @optional_fields [
    :description,
    :display_text,
    :async,
    :parameters_schema,
    :options,
    :parameters
  ]

  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, max: 64)
    |> ensure_single_parameter_option()
    |> put_param_schema()
    |> validate_function()
    |> apply_action(:insert)
  end

  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, tool} -> tool
      {:error, changeset} -> raise ArgumentError, inspect(changeset)
    end
  end

  def execute(%__MODULE__{function: fun, name: name}, arguments, context)
      when is_function(fun, 2) do
    Logger.debug("Executing tool #{name}")

    try do
      case fun.(arguments, context) do
        {:ok, content, processed} ->
          {:ok, content, processed}

        {:ok, content} ->
          {:ok, content}

        {:error, reason} when is_binary(reason) ->
          {:error, reason}

        {:error, reason} ->
          {:error, inspect(reason)}

        content when is_binary(content) ->
          {:ok, content}

        other ->
          Logger.error("Tool #{name} returned unexpected value #{inspect(other)}")
          {:error, "Unexpected tool response"}
      end
    rescue
      exception ->
        Logger.error(
          "Tool #{name} failed: #{Exception.format(:error, exception, __STACKTRACE__)}"
        )

        {:error, Exception.message(exception)}
    end
  end

  def execute(%__MODULE__{}, _arguments, _context), do: {:error, "tool function not set"}

  defp ensure_single_parameter_option(changeset) do
    params = get_field(changeset, :parameters)
    schema = get_field(changeset, :parameters_schema)

    cond do
      is_map(schema) and is_list(params) and params != [] ->
        add_error(changeset, :parameters, "cannot supply both :parameters and :parameters_schema")

      true ->
        changeset
    end
  end

  defp put_param_schema(%{changes: %{parameters: params}} = changeset) when is_list(params) do
    normalized =
      Enum.map(params, fn
        %ToolParam{} = param -> param
        attrs -> ToolParam.new!(attrs)
      end)

    schema = ToolParam.to_schema(normalized)

    changeset
    |> delete_change(:parameters)
    |> put_change(:parameters_schema, schema)
  end

  defp put_param_schema(changeset), do: changeset

  defp validate_function(changeset) do
    case get_field(changeset, :function) do
      fun when is_function(fun, 2) ->
        changeset

      fun when is_function(fun) ->
        add_error(changeset, :function, "expected arity 2, got #{function_arity(fun)}")

      nil ->
        add_error(changeset, :function, "is required")

      _ ->
        add_error(changeset, :function, "must be a function with arity 2")
    end
  end

  defp function_arity(fun) do
    case Function.info(fun, :arity) do
      {:arity, value} -> value
      _ -> "unknown"
    end
  end
end
