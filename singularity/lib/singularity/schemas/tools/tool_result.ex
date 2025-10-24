defmodule Singularity.Schemas.Tools.ToolResult do
  @moduledoc """
  Represents the result returned to the model after executing a tool.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.Tools.ToolResult",
    "purpose": "Embedded schema for tool execution results returned to LLM",
    "role": "schema",
    "layer": "tools",
    "relationships": {}
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - type: Result type (function)
    - tool_call_id: Matching tool call identifier
    - name: Tool name that was executed
    - content: Raw tool output (virtual)
    - processed_content: Processed output for LLM (virtual)
    - display_text: Human-readable display
    - is_error: Whether execution failed
    - options: Additional result options

  relationships:
    embedded: true
  ```

  ### Anti-Patterns
  - ❌ DO NOT omit tool_call_id - LLM needs to match result to call
  - ✅ DO use processed_content for LLM-optimized output
  - ✅ DO set is_error=true for failures

  ### Search Keywords
  tool result, tool output, llm response, tool execution result,
  error handling, tool feedback
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
