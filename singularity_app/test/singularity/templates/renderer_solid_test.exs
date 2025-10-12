defmodule Singularity.Templates.RendererSolidTest do
  use ExUnit.Case, async: true

  alias Singularity.Templates.Renderer

  describe "render/3 with Handlebars templates" do
    test "renders simple elixir-module template with Solid" do
      variables = %{
        module_name: "MyApp.TestModule",
        description: "A test module for Solid integration",
        overview: "This module demonstrates Solid (Handlebars) template rendering with conditionals and loops.",
        api_functions: [
          %{
            name: "test_function",
            args: "arg1, arg2",
            return_type: "{:ok, result} | {:error, reason}",
            purpose: "Performs a test operation"
          }
        ],
        error_types: [
          %{atom: "invalid_input", description: "When input is invalid"},
          %{atom: "not_found", description: "When resource not found"}
        ],
        examples: [
          %{
            comment: "Success case",
            code: "{:ok, result} = MyApp.TestModule.test_function(\"valid\", \"input\")"
          },
          %{
            comment: "Error case",
            code: "{:error, :invalid_input} = MyApp.TestModule.test_function(nil, nil)"
          }
        ],
        template_id: "base-elixir-module",
        template_version: "2.1.0",
        applied_date: "2025-10-12",
        use_genserver: false,
        content: "# Module implementation here\n\ndef test_function(arg1, arg2) do\n  # Implementation\n  {:ok, :result}\nend"
      }

      case Renderer.render("elixir-module", variables) do
        {:ok, rendered} ->
          # Verify module name
          assert rendered =~ "defmodule MyApp.TestModule do"

          # Verify @moduledoc
          assert rendered =~ "@moduledoc"
          assert rendered =~ "A test module for Solid integration"

          # Verify API functions rendered with #each
          assert rendered =~ "test_function(arg1, arg2)"
          assert rendered =~ "Performs a test operation"

          # Verify error matrix rendered with #each
          assert rendered =~ ":invalid_input"
          assert rendered =~ "When input is invalid"

          # Verify examples rendered with #each
          assert rendered =~ "Success case"
          assert rendered =~ "{:ok, result}"

          # Verify GenServer NOT included (use_genserver: false)
          refute rendered =~ "use GenServer"

          # Verify content included
          assert rendered =~ "def test_function(arg1, arg2) do"

        {:error, reason} ->
          flunk("Template rendering failed: #{inspect(reason)}")
      end
    end

    test "renders elixir-module with GenServer when use_genserver: true" do
      variables = %{
        module_name: "MyApp.GenServerModule",
        description: "A GenServer module",
        overview: "Demonstrates GenServer integration",
        api_functions: [],
        error_types: [],
        examples: [],
        template_id: "base-elixir-module",
        template_version: "2.1.0",
        applied_date: "2025-10-12",
        use_genserver: true,
        content: "# GenServer callbacks here"
      }

      case Renderer.render("elixir-module", variables) do
        {:ok, rendered} ->
          # Verify GenServer IS included (use_genserver: true)
          assert rendered =~ "use GenServer"

        {:error, reason} ->
          flunk("Template rendering failed: #{inspect(reason)}")
      end
    end

    test "renders with imports and aliases when provided" do
      variables = %{
        module_name: "MyApp.ModuleWithImports",
        description: "Module with imports",
        overview: "Test imports and aliases",
        api_functions: [],
        error_types: [],
        examples: [],
        template_id: "base-elixir-module",
        template_version: "2.1.0",
        applied_date: "2025-10-12",
        imports: ["require Logger"],
        aliases: ["Singularity.Repo", "Singularity.Schema"],
        content: "# Implementation"
      }

      case Renderer.render("elixir-module", variables) do
        {:ok, rendered} ->
          assert rendered =~ "require Logger"
          assert rendered =~ "alias Singularity.Repo"
          assert rendered =~ "alias Singularity.Schema"

        {:error, reason} ->
          flunk("Template rendering failed: #{inspect(reason)}")
      end
    end

    test "renders with relationships when provided" do
      variables = %{
        module_name: "MyApp.ModuleWithRelationships",
        description: "Module with relationships",
        overview: "Test relationship rendering",
        api_functions: [],
        error_types: [],
        examples: [],
        template_id: "base-elixir-module",
        template_version: "2.1.0",
        applied_date: "2025-10-12",
        relationships: %{
          calls: [
            %{module: "Singularity.Repo", function: "insert", arity: 1, purpose: "Save to DB"}
          ],
          called_by: [
            %{module: "MyAppWeb.Controller", purpose: "HTTP handling"}
          ],
          depends_on: [
            %{name: "PostgreSQL", purpose: "Database"}
          ],
          integrates_with: [
            %{name: "NATS", purpose: "Messaging"}
          ]
        },
        content: "# Implementation"
      }

      case Renderer.render("elixir-module", variables) do
        {:ok, rendered} ->
          assert rendered =~ "**Calls:**"
          assert rendered =~ "Singularity.Repo.insert/1 - Save to DB"
          assert rendered =~ "**Called by:**"
          assert rendered =~ "MyAppWeb.Controller"
          assert rendered =~ "**Depends on:**"
          assert rendered =~ "PostgreSQL - Database"
          assert rendered =~ "**Integrates with:**"
          assert rendered =~ "NATS - Messaging"

        {:error, reason} ->
          flunk("Template rendering failed: #{inspect(reason)}")
      end
    end
  end

  describe "render_mode detection" do
    test "detects Solid mode when .hbs file exists" do
      # elixir-module.hbs exists
      assert Renderer.render("elixir-module", %{module_name: "Test"}) |> elem(0) == :ok
    end
  end
end
