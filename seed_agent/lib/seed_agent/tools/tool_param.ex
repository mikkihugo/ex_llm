defmodule SeedAgent.Tools.ToolParam do
  @moduledoc """
  Defines the schema for tool parameters and converts them into JSON Schema maps.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:type, Ecto.Enum, values: [:string, :integer, :number, :boolean, :array, :object])
    field(:item_type, :string)
    field(:enum, {:array, :any}, default: [])
    field(:description, :string)
    field(:required, :boolean, default: false)
    field(:object_properties, {:array, :any}, default: [])
  end

  @cast_fields [:name, :type, :item_type, :enum, :description, :required, :object_properties]
  @required_fields [:name, :type]

  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, @cast_fields)
    |> validate_required(@required_fields)
    |> validate_enum_values()
    |> validate_array_type()
    |> validate_object_type()
    |> apply_action(:insert)
  end

  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, struct} -> struct
      {:error, changeset} -> raise ArgumentError, inspect(changeset)
    end
  end

  def to_schema(params) when is_list(params) do
    normalized =
      Enum.map(params, fn
        %__MODULE__{} = param -> param
        attrs -> new!(attrs)
      end)

    %{
      type: "object",
      properties: Map.new(normalized, fn param -> {param.name, schema_for(param)} end),
      required: normalized |> Enum.filter(& &1.required) |> Enum.map(& &1.name)
    }
  end

  defp schema_for(%__MODULE__{type: :array, item_type: "object", object_properties: props}) do
    %{
      type: "array",
      items: %{
        type: "object",
        properties: Map.new(props, fn param -> {param.name, schema_for(param)} end)
      }
    }
  end

  defp schema_for(%__MODULE__{type: :array, item_type: item}) when is_binary(item) do
    %{type: "array", items: %{type: item}}
  end

  defp schema_for(%__MODULE__{type: :array}) do
    %{type: "array"}
  end

  defp schema_for(%__MODULE__{type: :object, object_properties: props}) do
    %{
      type: "object",
      properties: Map.new(props, fn param -> {param.name, schema_for(param)} end)
    }
  end

  defp schema_for(%__MODULE__{type: primitive, enum: enum})
       when primitive in [:string, :integer, :number, :boolean] do
    schema = %{type: Atom.to_string(primitive)}
    if Enum.empty?(enum), do: schema, else: Map.put(schema, :enum, enum)
  end

  defp schema_for(_), do: %{}

  defp validate_enum_values(changeset) do
    values = get_field(changeset, :enum, [])
    type = get_field(changeset, :type)

    cond do
      type in [:string, :integer, :number] -> changeset
      Enum.empty?(values) -> changeset
      true -> add_error(changeset, :enum, "not allowed for type #{inspect(type)}")
    end
  end

  defp validate_array_type(changeset) do
    item_type = get_field(changeset, :item_type)
    type = get_field(changeset, :type)

    cond do
      type == :array -> changeset
      is_nil(item_type) -> changeset
      true -> add_error(changeset, :item_type, "not allowed for type #{inspect(type)}")
    end
  end

  defp validate_object_type(changeset) do
    type = get_field(changeset, :type)
    item_type = get_field(changeset, :item_type)
    props = get_field(changeset, :object_properties)

    cond do
      requires_object_properties?(type, props) ->
        add_error(changeset, :object_properties, "required for object type")

      requires_object_properties_for_array_items?(type, item_type, props) ->
        add_error(changeset, :object_properties, "required when array items are objects")

      allows_object_properties?(type, item_type, props) ->
        changeset

      true ->
        add_error(changeset, :object_properties, "not allowed for type #{inspect(type)}")
    end
  end

  defp requires_object_properties?(type, props) do
    type == :object and Enum.empty?(props)
  end

  defp requires_object_properties_for_array_items?(type, item_type, props) do
    type == :array and item_type == "object" and Enum.empty?(props)
  end

  defp allows_object_properties?(type, item_type, props) do
    (type in [:object] and not Enum.empty?(props)) or
      (type == :array and item_type == "object") or
      Enum.empty?(props)
  end
end
