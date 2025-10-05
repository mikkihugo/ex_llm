defmodule Mix.Tasks.Code.Load do
  @moduledoc """
  Load code into the active Singularity code store.

  Reads source code from a file (or STDIN when `--code` is omitted), stages it
  via `Singularity.CodeStore`, and optionally promotes the new version to the
  active workspace.

  ## Examples

      mix code.load --agent wb_agent --code lib/new_module.ex --version v1
      mix code.load --agent wb_agent --code lib/new_module.ex --promote
      cat snippet.exs | mix code.load --agent wb_agent --promote

  Use `--metadata` to provide a JSON map stored alongside the staged version.
  """

  @shortdoc "Stage (and optionally promote) code through Singularity.CodeStore"

  use Mix.Task

  @switches [
    agent: :string,
    code: :string,
    version: :string,
    metadata: :string,
    promote: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, invalid} = OptionParser.parse(args, switches: @switches)

    unless invalid == [] do
      invalid_opts = invalid |> Enum.map_join(", ", &elem(&1, 0))
      Mix.raise("Invalid options supplied: #{invalid_opts}")
    end

    agent = opts[:agent] || Mix.raise("--agent is required")
    code = read_code(opts[:code])
    version = opts[:version] || Integer.to_string(System.system_time(:second))
    metadata = decode_metadata(opts[:metadata])

    case Singularity.CodeStore.stage(agent, version, code, metadata) do
      {:ok, version_path} ->
        Mix.shell().info("Staged #{version_path}")

        if opts[:promote] do
          case Singularity.CodeStore.promote(agent, version_path) do
            {:ok, active_path} ->
              Mix.shell().info("Promoted to #{active_path}")

            {:error, reason} ->
              Mix.shell().error("Promotion failed: #{inspect(reason)}")
          end
        end

      {:error, reason} ->
        Mix.raise("Failed to stage code: #{inspect(reason)}")
    end
  end

  defp read_code(nil) do
    case IO.read(:stdio, :all) do
      :eof -> Mix.raise("No code provided on STDIN")
      data when is_binary(data) and byte_size(data) > 0 -> data
      _ -> Mix.raise("Unable to read code from STDIN")
    end
  end

  defp read_code(path) do
    path
    |> Path.expand()
    |> File.read!()
  rescue
    error -> Mix.raise("Failed to read code file #{path}: #{Exception.message(error)}")
  end

  defp decode_metadata(nil), do: %{}

  defp decode_metadata(json) do
    case Jason.decode(json) do
      {:ok, %{} = map} -> map
      {:ok, _} -> Mix.raise("Metadata JSON must decode to an object")
      {:error, reason} -> Mix.raise("Invalid metadata JSON: #{inspect(reason)}")
    end
  end
end
