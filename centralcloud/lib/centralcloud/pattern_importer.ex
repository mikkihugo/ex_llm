defmodule CentralCloud.PatternImporter do
  @moduledoc """
  Imports architecture pattern definitions from JSON files into database.

  Reads pattern JSON files from templates_data/architecture_patterns/
  and inserts them into the architecture_patterns table.
  """

  require Logger
  alias CentralCloud.Repo
  alias CentralCloud.ArchitecturePattern

  @doc """
  Import all pattern definitions from directory.

  ## Examples

      PatternImporter.import_patterns("../templates_data/architecture_patterns")
  """
  def import_patterns(directory_path) do
    Logger.info("Importing patterns from #{directory_path}")

    case File.ls(directory_path) do
      {:ok, files} ->
        json_files = Enum.filter(files, &String.ends_with?(&1, ".json"))

        results =
          Enum.map(json_files, fn filename ->
            file_path = Path.join(directory_path, filename)
            import_pattern_file(file_path)
          end)

        success_count = Enum.count(results, &match?({:ok, _}, &1))
        error_count = Enum.count(results, &match?({:error, _}, &1))

        Logger.info("Pattern import complete: #{success_count} succeeded, #{error_count} failed")

        {:ok, %{success: success_count, errors: error_count}}

      {:error, reason} ->
        Logger.error("Failed to list directory #{directory_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Import a single pattern definition file.
  """
  def import_pattern_file(file_path) do
    Logger.debug("Importing pattern from #{file_path}")

    with {:ok, content} <- File.read(file_path),
         {:ok, pattern_data} <- Jason.decode(content),
         {:ok, pattern} <- insert_or_update_pattern(pattern_data) do
      Logger.info("Successfully imported pattern: #{pattern.pattern_id} v#{pattern.version}")
      {:ok, pattern}
    else
      {:error, reason} = error ->
        Logger.error("Failed to import pattern from #{file_path}: #{inspect(reason)}")
        error
    end
  end

  ## Private Functions

  defp insert_or_update_pattern(pattern_data) do
    attrs = %{
      id: Ecto.UUID.generate(),
      pattern_id: pattern_data["id"],
      name: pattern_data["name"],
      category: pattern_data["category"],
      version: pattern_data["version"],
      description: pattern_data["description"],
      metadata: pattern_data,
      indicators: pattern_data["indicators"],
      benefits: pattern_data["benefits"],
      concerns: pattern_data["concerns"],
      detection_template: pattern_data["metadata"]["detection_template"]
    }

    # Check if pattern already exists
    case Repo.get_by(ArchitecturePattern, pattern_id: attrs.pattern_id, version: attrs.version) do
      nil ->
        # Insert new
        %ArchitecturePattern{}
        |> ArchitecturePattern.changeset(attrs)
        |> Repo.insert()

      existing ->
        # Update existing
        existing
        |> ArchitecturePattern.changeset(attrs)
        |> Repo.update()
    end
  end
end
