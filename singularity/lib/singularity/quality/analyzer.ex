defmodule Singularity.Quality.Analyzer do
  @moduledoc """
  Helpers for persisting and querying static analysis tool results (Sobelow, mix_audit).
  """

  import Ecto.Query

  alias Singularity.Repo
  alias Singularity.Schemas.Analysis.{Finding, Run}

  @type tool :: Run.tool()
  @type status :: Run.status()

  @doc "Persist a Sobelow run and its findings."
  def store_sobelow(%{
        output: json,
        exit_status: exit_status,
        started_at: started,
        finished_at: finished
      }) do
    with {:ok, findings} <- parse_sobelow(json) do
      warning_count = length(findings)
      status = status_from(exit_status, warning_count)

      Repo.transaction(fn ->
        {:ok, run} =
          %Run{}
          |> Run.changeset(%{
            tool: :sobelow,
            status: status,
            warning_count: warning_count,
            metadata: %{},
            started_at: started,
            finished_at: finished
          })
          |> Repo.insert()

        Enum.each(findings, fn finding ->
          %Finding{}
          |> Finding.changeset(Map.put(finding, :run_id, run.id))
          |> Repo.insert!()
        end)

        run
      end)
    end
  end

  @doc "Persist a mix_audit run."
  def store_mix_audit(%{
        output: json,
        exit_status: exit_status,
        started_at: started,
        finished_at: finished
      }) do
    with {:ok, findings} <- parse_mix_audit(json) do
      warning_count = length(findings)
      status = status_from(exit_status, warning_count)

      Repo.transaction(fn ->
        {:ok, run} =
          %Run{}
          |> Run.changeset(%{
            tool: :mix_audit,
            status: status,
            warning_count: warning_count,
            metadata: %{},
            started_at: started,
            finished_at: finished
          })
          |> Repo.insert()

        Enum.each(findings, fn finding ->
          %Finding{}
          |> Finding.changeset(Map.put(finding, :run_id, run.id))
          |> Repo.insert!()
        end)

        run
      end)
    end
  end

  @doc "Return the most recent run for a given tool."
  def latest(tool) do
    Run
    |> where([r], r.tool == ^tool)
    |> order_by([r], desc: r.inserted_at)
    |> preload(:findings)
    |> limit(1)
    |> Repo.one()
  end

  @doc "Enumerate findings for a tool, optionally filtering by severity."
  def findings_for(tool, opts \\ []) do
    severity = Keyword.get(opts, :severity)

    Finding
    |> join(:inner, [f], r in assoc(f, :run))
    |> where([f, r], r.tool == ^tool)
    |> maybe_filter_severity(severity)
    |> order_by([f, _], desc: f.inserted_at)
    |> Repo.all()
  end

  defp maybe_filter_severity(query, nil), do: query

  defp maybe_filter_severity(query, severity),
    do: where(query, [f, _], f.severity == ^to_string(severity))

  defp status_from(exit_status, warning_count) do
    cond do
      exit_status != 0 -> :error
      warning_count > 0 -> :warning
      true -> :ok
    end
  end

  defp parse_sobelow(json) do
    case Jason.decode(json) do
      {:ok, %{"findings" => list}} when is_list(list) ->
        findings =
          Enum.map(list, fn finding ->
            %{
              category: finding["type"],
              message: finding["description"] || finding["details"] || finding["message"] || "",
              file: finding["file"],
              line: finding["line"],
              severity: finding["confidence"],
              extra:
                Map.drop(finding, [
                  "type",
                  "description",
                  "details",
                  "message",
                  "file",
                  "line",
                  "confidence"
                ])
            }
          end)

        {:ok, findings}

      {:ok, list} when is_list(list) ->
        mapped =
          Enum.map(list, fn finding ->
            %{
              category: finding["type"],
              message: finding["details"] || finding["message"] || "",
              file: finding["file"],
              line: finding["line"],
              severity: finding["confidence"],
              extra:
                Map.drop(finding, ["type", "details", "message", "file", "line", "confidence"])
            }
          end)

        {:ok, mapped}

      {:ok, _} ->
        {:error, :invalid_json}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_mix_audit(json) do
    case Jason.decode(json) do
      {:ok, %{"vulnerable" => vulns}} when is_list(vulns) ->
        findings =
          Enum.map(vulns, fn vuln ->
            %{
              category: "dependency",
              message: vuln["title"] || vuln["description"] || "",
              file: vuln["name"],
              line: nil,
              severity: vuln["severity"],
              extra: vuln
            }
          end)

        {:ok, findings}

      {:ok, _} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
