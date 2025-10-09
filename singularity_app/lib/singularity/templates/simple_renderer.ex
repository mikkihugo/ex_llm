defmodule Singularity.Templates.SimpleRenderer do
  @moduledoc """
  Simple template renderer - no fancy logic, just practical rendering.

  Supports:
  - {{variable}} replacement (Mustache-style)
  - Template composition (extends, compose)
  - Multi-file snippets
  - Quality standards

  NO complex logic, NO Ecto, just simple string replacement!
  """

  alias Singularity.Knowledge.LocalTemplateCache

  @doc """
  Render a template with variables.

  ## Examples

      iex> render("base-elixir-module", %{
        module_name: "MyApp.Worker",
        description: "Background worker",
        content: "def work, do: :ok"
      })
      {:ok, "defmodule MyApp.Worker do..."}

  """
  def render(template_id, variables \\ %{}) do
    with {:ok, template} <- LocalTemplateCache.get_template(template_id),
         {:ok, resolved} <- resolve_composition(template, variables),
         {:ok, rendered} <- render_content(resolved, variables) do
      {:ok, rendered}
    end
  end

  @doc """
  Render multi-file snippets (returns map of file_path => code).

  ## Examples

      iex> render_snippets("phoenix-authenticated-api", %{app_name: "MyApp"})
      {:ok, %{
        "lib/my_app_web/router.ex" => "...",
        "lib/my_app_web/controllers/user_controller.ex" => "..."
      }}

  """
  def render_snippets(template_id, variables \\ %{}) do
    with {:ok, template} <- LocalTemplateCache.get_template(template_id),
         %{"type" => "snippets", "snippets" => snippets} <- template["content"] do

      rendered_snippets =
        Enum.reduce(snippets, %{}, fn {name, snippet}, acc ->
          code = snippet["code"]
          file_path = snippet["file_path"] || "#{name}.ex"

          # Compose bits if specified
          composed_code = if snippet["compose"] do
            compose_bits(code, snippet["compose"], variables)
          else
            code
          end

          rendered_code = replace_variables(composed_code, variables)
          rendered_path = replace_variables(file_path, variables)

          Map.put(acc, rendered_path, rendered_code)
        end)

      {:ok, rendered_snippets}
    else
      _ -> {:error, :invalid_snippet_template}
    end
  end

  ## Private Functions

  defp resolve_composition(template, variables) do
    # 1. Load base template if extends
    base_code = if template["extends"] do
      case LocalTemplateCache.get_template(template["extends"]) do
        {:ok, base} -> base["content"]["code"] || ""
        _ -> ""
      end
    else
      ""
    end

    # 2. Load composed bits
    bits_code = if template["compose"] do
      Enum.map(template["compose"], fn bit_id ->
        case LocalTemplateCache.get_template(bit_id) do
          {:ok, bit} -> bit["content"]["code"] || ""
          _ -> ""
        end
      end)
      |> Enum.join("\n\n")
    else
      ""
    end

    # 3. Get template content
    content_code = case template["content"] do
      %{"type" => "code", "code" => code} -> code
      _ -> ""
    end

    # 4. Combine: base + bits + content
    combined = [base_code, bits_code, content_code]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")

    {:ok, combined}
  end

  defp render_content(code, variables) do
    rendered = replace_variables(code, variables)
    {:ok, rendered}
  end

  defp replace_variables(code, variables) when is_binary(code) do
    Enum.reduce(variables, code, fn {key, value}, acc ->
      key_str = to_string(key)
      value_str = to_string(value)
      String.replace(acc, "{{#{key_str}}}", value_str)
    end)
  end

  defp compose_bits(code, bit_ids, variables) do
    bits = Enum.map(bit_ids, fn bit_id ->
      case LocalTemplateCache.get_template(bit_id) do
        {:ok, bit} ->
          bit_code = bit["content"]["code"] || ""
          replace_variables(bit_code, variables)
        _ ->
          ""
      end
    end)
    |> Enum.join("\n\n")

    # Insert bits before the main code
    bits <> "\n\n" <> code
  end
end
