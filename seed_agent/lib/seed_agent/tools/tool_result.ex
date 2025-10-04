defmodule SeedAgent.Tools.ToolResult do
  @moduledoc """
  Represents the result returned to the model after executing a tool.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, Ecto.Enum, values: [:function], default: :function)
    field(:tool_call_id, :string)
    field(:name, :string)
    field(:content, :any, virtual: true)
    field(:processed_content, :any, virtual: true)
    field(:display_text, :string)
    field(:is_error, :boolean, default: false)
    field(:options, :map)
  end

  @fields [
    :type,
    :tool_call_id,
    :name,
    :content,
    :processed_content,
    :display_text,
    :is_error,
    :options
  ]

  def new(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, @fields)
    |> validate_required([:type, :tool_call_id, :name, :content])
    |> apply_action(:insert)
  end

  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, struct} -> struct
      {:error, changeset} -> raise ArgumentError, inspect(changeset)
    end
  end
end
