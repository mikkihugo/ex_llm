defmodule Singularity.Validation.Validators.TemplateValidator do
  @moduledoc """
  Template Validator - Validates template structure and content.

  Implements ValidatorType behavior for unified validation.
  """

  @behaviour Singularity.Validation.ValidatorType
  require Logger

  @impl true
  def validator_type, do: :template

  @impl true
  def description, do: "Validate template structure and content"

  @impl true
  def capabilities do
    ["schema_validation", "required_fields", "content_validation"]
  end

  @impl true
  def schema do
    %{
      "type" => "object",
      "required" => ["name", "content"],
      "properties" => %{
        "name" => %{"type" => "string"},
        "content" => %{"type" => "string"},
        "metadata" => %{"type" => "object"}
      }
    }
  end

  @impl true
  def validate(input, _opts \\ []) when is_map(input) do
    try do
      case validate_template(input) do
        [] -> :ok
        errors -> {:error, errors}
      end
    rescue
      e ->
        Logger.error("Template validation failed", error: inspect(e))
        {:error, ["Validation error: #{inspect(e)}"]}
    end
  end

  # Private helpers

  defp validate_template(template) do
    errors = []

    # Check required fields
    errors =
      if Map.has_key?(template, "name") and is_binary(template["name"]) do
        errors
      else
        ["Missing or invalid 'name' field" | errors]
      end

    errors =
      if Map.has_key?(template, "content") and is_binary(template["content"]) do
        errors
      else
        ["Missing or invalid 'content' field" | errors]
      end

    Enum.reverse(errors)
  end
end
