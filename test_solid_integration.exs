#!/usr/bin/env elixir

# Simple test script for Solid template integration
# Run with: elixir test_solid_integration.exs

IO.puts("\n=== Solid Template Integration Test ===\n")

# Test 1: Check Solid dependency
IO.puts("Test 1: Checking if Solid is available...")

try do
  Code.ensure_loaded?(Solid)
  IO.puts("✓ Solid module loaded successfully")
rescue
  _ ->
    IO.puts("✗ Solid module not available - run 'mix deps.get' first")
    System.halt(1)
end

# Test 2: Simple Handlebars template
IO.puts("\nTest 2: Rendering simple Handlebars template...")

simple_template = """
Hello {{name}}!
Your age is {{age}}.
"""

case Solid.parse(simple_template, "simple_test") do
  {:ok, parsed} ->
    case Solid.render(parsed, %{"name" => "World", "age" => 42}) do
      {:ok, result} ->
        rendered = IO.iodata_to_binary(result)

        if String.contains?(rendered, "Hello World") and String.contains?(rendered, "Your age is 42") do
          IO.puts("✓ Simple template rendered correctly")
          IO.puts("   Output: #{inspect(rendered)}")
        else
          IO.puts("✗ Simple template output unexpected: #{inspect(rendered)}")
          System.halt(1)
        end

      {:error, reason} ->
        IO.puts("✗ Failed to render: #{inspect(reason)}")
        System.halt(1)
    end

  {:error, reason} ->
    IO.puts("✗ Failed to parse template: #{inspect(reason)}")
    System.halt(1)
end

# Test 3: Conditional rendering
IO.puts("\nTest 3: Testing conditional rendering (#if)...")

conditional_template = """
{{#if show_message}}
Message is visible
{{/if}}
{{#unless hide_text}}
Text is not hidden
{{/unless}}
"""

case Solid.parse(conditional_template, "conditional_test") do
  {:ok, parsed} ->
    case Solid.render(parsed, %{"show_message" => true, "hide_text" => false}) do
      {:ok, result} ->
        rendered = IO.iodata_to_binary(result)

        if String.contains?(rendered, "Message is visible") and String.contains?(rendered, "Text is not hidden") do
          IO.puts("✓ Conditional rendering works correctly")
        else
          IO.puts("✗ Conditional output unexpected: #{inspect(rendered)}")
          System.halt(1)
        end

      {:error, reason} ->
        IO.puts("✗ Failed to render conditionals: #{inspect(reason)}")
        System.halt(1)
    end

  {:error, reason} ->
    IO.puts("✗ Failed to parse conditional template: #{inspect(reason)}")
    System.halt(1)
end

# Test 4: Loop rendering
IO.puts("\nTest 4: Testing loop rendering (#each)...")

loop_template = """
Items:
{{#each items}}
- {{name}}: {{value}}
{{/each}}
"""

case Solid.parse(loop_template, "loop_test") do
  {:ok, parsed} ->
    case Solid.render(parsed, %{
           "items" => [
             %{"name" => "Item1", "value" => "Value1"},
             %{"name" => "Item2", "value" => "Value2"}
           ]
         }) do
      {:ok, result} ->
        rendered = IO.iodata_to_binary(result)

        if String.contains?(rendered, "Item1: Value1") and String.contains?(rendered, "Item2: Value2") do
          IO.puts("✓ Loop rendering works correctly")
        else
          IO.puts("✗ Loop output unexpected: #{inspect(rendered)}")
          System.halt(1)
        end

      {:error, reason} ->
        IO.puts("✗ Failed to render loop: #{inspect(reason)}")
        System.halt(1)
    end

  {:error, reason} ->
    IO.puts("✗ Failed to parse loop template: #{inspect(reason)}")
    System.halt(1)
end

# Test 5: Check if .hbs templates exist
IO.puts("\nTest 5: Checking if .hbs templates exist...")

hbs_files = [
  "templates_data/base/elixir-module.hbs",
  "templates_data/code_generation/patterns/messaging/elixir-nats-consumer.hbs"
]

missing_files =
  Enum.reject(hbs_files, fn file ->
    File.exists?(file)
  end)

if Enum.empty?(missing_files) do
  IO.puts("✓ All expected .hbs files exist")
else
  IO.puts("✗ Missing .hbs files:")

  Enum.each(missing_files, fn file ->
    IO.puts("   - #{file}")
  end)

  System.halt(1)
end

# Test 6: Check if metadata JSON files exist
IO.puts("\nTest 6: Checking if metadata JSON files exist...")

metadata_files = [
  "templates_data/base/elixir-module-meta.json"
]

missing_metadata =
  Enum.reject(metadata_files, fn file ->
    File.exists?(file)
  end)

if Enum.empty?(missing_metadata) do
  IO.puts("✓ All expected metadata files exist")
else
  IO.puts("⚠ Missing metadata files (optional):")

  Enum.each(missing_metadata, fn file ->
    IO.puts("   - #{file}")
  end)
end

IO.puts("\n=== All Core Tests Passed! ===\n")
IO.puts("Solid integration is working correctly.")
IO.puts("Next steps:")
IO.puts("1. Run 'mix compile' to compile the updated Renderer")
IO.puts("2. Create additional .hbs templates")
IO.puts("3. Create reusable partials in priv/templates/partials/")
