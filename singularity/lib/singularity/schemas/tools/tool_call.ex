defmodule Singularity.Schemas.Tools.ToolCall do
  @moduledoc """
  Represents a tool call emitted by a model.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:status, Ecto.Enum, values: [:incomplete, :complete], default: :incomplete)
    field(:type, Ecto.Enum, values: [:function], default: :function)
    field(:call_id, :string)
    field(:name, :string)
    field(:arguments, :any, virtual: true)
    field(:index, :integer)
  end

  @fields [:status, :type, :call_id, :name, :arguments, :index]

  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, @fields)
    |> parse_arguments(attrs)
    |> validate_call()
    |> apply_action(:insert)
  end

  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, struct} -> struct
      {:error, changeset} -> raise ArgumentError, inspect(changeset)
    end
  end

  def merge(nil, %__MODULE__{} = part), do: part

  def merge(%__MODULE__{index: i1}, %__MODULE__{index: i2})
      when not is_nil(i1) and not is_nil(i2) and i1 != i2 do
    raise ArgumentError, "cannot merge tool calls with different indices"
  end

  def merge(%__MODULE__{} = primary, %__MODULE__{} = part) do
    primary
    |> maybe_concat(:name, part)
    |> maybe_concat(:arguments, part)
    |> maybe_update(:index, part)
    |> maybe_update(:call_id, part)
    |> maybe_update(:type, part)
    |> maybe_update(:status, part)
  end

  defp maybe_concat(primary, field, part) do
    case Map.get(part, field) do
      value when is_binary(value) -> Map.update(primary, field, value, &((&1 || "") <> value))
      _ -> primary
    end
  end

  defp maybe_update(primary, field, part) do
    case Map.get(part, field) do
      nil -> primary
      value -> Map.put(primary, field, value)
    end
  end

  defp parse_arguments(changeset, %{arguments: args}) when is_binary(args) do
    case Jason.decode(args) do
      {:ok, map} when is_map(map) -> put_change(changeset, :arguments, map)
      {:ok, _} -> add_error(changeset, :arguments, "arguments must decode to a map")
      {:error, _} -> add_error(changeset, :arguments, "invalid json")
    end
  end

  defp parse_arguments(changeset, %{arguments: args}) when is_map(args) do
    put_change(changeset, :arguments, args)
  end

  defp parse_arguments(changeset, _), do: changeset

  defp validate_call(%{changes: %{status: :incomplete}} = changeset),
    do: validate_required(changeset, [:status, :type])

  defp validate_call(changeset) do
    changeset
    |> validate_required([:status, :type, :call_id, :name])
  end
end
