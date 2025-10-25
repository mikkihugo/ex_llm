defmodule Singularity.Jobs.TemplatesDataLoadWorker do
  @moduledoc """
  Load templates_data/ (Git) into PostgreSQL JSONB (one-time setup)

  Runs on application startup to ensure template database is loaded.
  Idempotent - safe to run multiple times (updates existing templates).

  Previously manual: `mix templates_data.load all`
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Loading templates_data/ into PostgreSQL...")

    case Singularity.TemplateStore.load_all() do
      {:ok, count} ->
        Logger.info("✅ Loaded #{count} templates from templates_data/")
        :ok

      {:error, reason} ->
        Logger.error("❌ Templates data load failed: #{reason}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Exception during templates data load: #{inspect(e)}")
      {:error, "Exception: #{inspect(e)}"}
  end
end
