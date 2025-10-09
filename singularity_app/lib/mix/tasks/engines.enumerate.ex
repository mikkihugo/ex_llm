defmodule Mix.Tasks.Engines.Enumerate do
  @moduledoc """
  Enumerate all Singularity engines and their capabilities.

  This demonstrates the Engine behaviour + Registry pattern for clean capability discovery.

  ## Usage

      mix engines.enumerate
      mix engines.enumerate --engine prompt
      mix engines.enumerate --capabilities
      mix engines.enumerate --json
  """

  use Mix.Task
  require Logger

  @shortdoc "Enumerate engines and capabilities"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _args, _invalid} =
      OptionParser.parse(args,
        strict: [engine: :string, capabilities: :boolean, json: :boolean, health: :boolean]
      )

    cond do
      opts[:engine] ->
        show_engine(opts[:engine], opts)

      opts[:capabilities] ->
        show_capabilities(opts)

      true ->
        show_all_engines(opts)
    end
  end

  defp show_all_engines(opts) do
    engines = Singularity.Engine.Registry.all()

    if opts[:json] do
      engines |> Jason.encode!(pretty: true) |> IO.puts()
    else
      IO.puts("\n" <> IO.ANSI.cyan() <> "🔧 Singularity Engines" <> IO.ANSI.reset())
      IO.puts(String.duplicate("=", 80))

      Enum.each(engines, fn engine ->
        print_engine_summary(engine, opts[:health])
      end)

      IO.puts("\n" <> IO.ANSI.green() <> "Total: #{length(engines)} engines" <> IO.ANSI.reset())
    end
  end

  defp show_engine(identifier, opts) do
    case Singularity.Engine.Registry.fetch(String.to_existing_atom(identifier)) do
      {:ok, engine} ->
        if opts[:json] do
          engine |> Jason.encode!(pretty: true) |> IO.puts()
        else
          print_engine_detail(engine)
        end

      :error ->
        IO.puts(IO.ANSI.red() <> "Engine not found: #{identifier}" <> IO.ANSI.reset())
        exit({:shutdown, 1})
    end
  rescue
    ArgumentError ->
      IO.puts(IO.ANSI.red() <> "Invalid engine identifier: #{identifier}" <> IO.ANSI.reset())
      exit({:shutdown, 1})
  end

  defp show_capabilities(opts) do
    capabilities = Singularity.Engine.Registry.capabilities_index()

    if opts[:json] do
      capabilities |> Jason.encode!(pretty: true) |> IO.puts()
    else
      IO.puts("\n" <> IO.ANSI.cyan() <> "📋 All Capabilities" <> IO.ANSI.reset())
      IO.puts(String.duplicate("=", 80))

      capabilities
      |> Enum.group_by(& &1.engine)
      |> Enum.each(fn {engine, caps} ->
        IO.puts("\n" <> IO.ANSI.yellow() <> "#{engine}" <> IO.ANSI.reset())

        Enum.each(caps, fn cap ->
          status = if cap.available?, do: IO.ANSI.green() <> "✓", else: IO.ANSI.red() <> "✗"
          IO.puts("  #{status} #{IO.ANSI.reset()}#{cap.label} (#{cap.id})")
          IO.puts("     #{IO.ANSI.faint()}#{cap.description}#{IO.ANSI.reset()}")
        end)
      end)

      IO.puts(
        "\n" <>
          IO.ANSI.green() <>
          "Total: #{length(capabilities)} capabilities" <> IO.ANSI.reset()
      )
    end
  end

  defp print_engine_summary(engine, show_health \\ false) do
    IO.puts("\n" <> IO.ANSI.yellow() <> "#{engine.label}" <> IO.ANSI.reset())
    IO.puts("  ID:          #{engine.id}")
    IO.puts("  Module:      #{inspect(engine.module)}")
    IO.puts("  Description: #{engine.description}")

    if show_health do
      health_status =
        case engine.health do
          :ok -> IO.ANSI.green() <> "OK"
          {:error, reason} -> IO.ANSI.red() <> "ERROR: #{inspect(reason)}"
        end

      IO.puts("  Health:      #{health_status}#{IO.ANSI.reset()}")
    end

    case engine.capabilities do
      [] -> :ok
      capabilities ->
        IO.puts("  Capabilities: #{length(capabilities)}")

        Enum.each(capabilities, fn cap ->
          status = if cap.available?, do: IO.ANSI.green() <> "✓", else: IO.ANSI.red() <> "✗"
          IO.puts("    #{status} #{IO.ANSI.reset()}#{cap.label}")
        end)
    end
  end

  defp print_engine_detail(engine) do
    IO.puts("\n" <> IO.ANSI.cyan() <> String.duplicate("=", 80) <> IO.ANSI.reset())
    IO.puts(IO.ANSI.yellow() <> IO.ANSI.bright() <> engine.label <> IO.ANSI.reset())
    IO.puts(IO.ANSI.cyan() <> String.duplicate("=", 80) <> IO.ANSI.reset())

    IO.puts("\n" <> IO.ANSI.bright() <> "Overview" <> IO.ANSI.reset())
    IO.puts("  ID:          #{engine.id}")
    IO.puts("  Module:      #{inspect(engine.module)}")
    IO.puts("  Description: #{engine.description}")

    health_status =
      case engine.health do
        :ok -> IO.ANSI.green() <> "OK"
        {:error, reason} -> IO.ANSI.red() <> "ERROR: #{inspect(reason)}"
      end

    IO.puts("  Health:      #{health_status}#{IO.ANSI.reset()}")

    IO.puts("\n" <> IO.ANSI.bright() <> "Capabilities (#{length(engine.capabilities)})" <> IO.ANSI.reset())

    if length(engine.capabilities) == 0 do
      IO.puts("  " <> IO.ANSI.faint() <> "No capabilities defined" <> IO.ANSI.reset())
    else
      Enum.each(engine.capabilities, fn cap ->
        status = if cap.available?, do: IO.ANSI.green() <> "✓ AVAILABLE", else: IO.ANSI.red() <> "✗ UNAVAILABLE"
        IO.puts("\n  #{status}#{IO.ANSI.reset()} #{IO.ANSI.yellow()}#{cap.label}#{IO.ANSI.reset()}")
        IO.puts("    ID:          #{cap.id}")
        IO.puts("    Description: #{cap.description}")

        case cap.tags do
          [] -> :ok
          tags -> IO.puts("    Tags:        #{inspect(tags)}")
        end
      end)
    end

    IO.puts("\n" <> IO.ANSI.cyan() <> String.duplicate("=", 80) <> IO.ANSI.reset())
  end
end
