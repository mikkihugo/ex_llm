defmodule Singularity.Templates.SolidYieldHelper do
  @moduledoc """
  Solid (Handlebars) helper for bulk file generation - Pure Elixir implementation.

  Pattern extracted from Copier, implemented using Solid instead of Jinja.

  ## Usage in Solid Templates

  ```handlebars
  {{#each agents}}
  lib/singularity/agents/{{this}}_agent.ex
  {{/each}}
  ```

  Or for more complex scenarios:

  ```handlebars
  {{#each modules as |module|}}
  # File: lib/my_app/{{module.name}}.ex
  defmodule MyApp.{{module.name}} do
    # Generated from {{module.template}}
  end
  {{/each}}
  ```

  ## Registering the Helper

  This helper is automatically registered with Solid via `TemplateFormatters.register_all()`.

  ## Examples

  ### Generate Multiple Agent Files

  Template: `agent-bulk.hbs`
  ```handlebars
  {{#each agent_types}}
  # lib/singularity/agents/{{this}}_agent.ex
  defmodule Singularity.Agents.{{pascal_case this}}Agent do
    @moduledoc "{{capitalize this}} agent"
  end
  {{/each}}
  ```

  Variables:
  ```elixir
  %{agent_types: ["self_improving", "cost_optimized", "refactoring"]}
  ```

  Result: Generates 3 separate files

  ### Generate Module with Tests

  Template: `module-with-tests.hbs`
  ```handlebars
  {{#each modules as |mod|}}
  # lib/{{app_name}}/{{mod.path}}.ex
  defmodule {{app_name}}.{{mod.name}} do
    # ...
  end

  # test/{{app_name}}/{{mod.path}}_test.exs
  defmodule {{app_name}}.{{mod.name}}Test do
    use ExUnit.Case
    # ...
  end
  {{/each}}
  ```
  """

  @doc """
  Helper to split bulk template output into multiple files.

  Parse Solid template output containing file markers and split into map of files.

  ## File Marker Format

  ```
  # File: path/to/file.ex
  <content>

  # File: path/to/another.ex
  <content>
  ```

  ## Example

      iex> parse_bulk_output(\"\"\"
      ...> # File: lib/worker.ex
      ...> defmodule Worker do
      ...> end
      ...>
      ...> # File: test/worker_test.exs
      ...> defmodule WorkerTest do
      ...> end
      ...> \"\"\")
      {:ok, %{
        "lib/worker.ex" => "defmodule Worker do\\nend",
        "test/worker_test.exs" => "defmodule WorkerTest do\\nend"
      }}
  """
  def parse_bulk_output(output) when is_binary(output) do
    files =
      output
      |> String.split(~r/^#\s*File:\s*(.+)$/m, include_captures: true, trim: true)
      |> Enum.chunk_every(2)
      |> Enum.reduce(%{}, fn
        [path_match, content], acc ->
          # Extract path from "# File: path/to/file.ex"
          path =
            path_match
            |> String.trim()
            |> String.replace(~r/^#\s*File:\s*/, "")
            |> String.trim()

          content = String.trim(content)
          Map.put(acc, path, content)

        _, acc ->
          acc
      end)

    {:ok, files}
  end

  @doc """
  Register yield-related helpers with Solid.

  Automatically called by TemplateFormatters.register_all().
  """
  def register_helpers do
    # Solid uses built-in {{#each}} - no custom registration needed
    # This is here for consistency with the pattern
    :ok
  end
end
