defmodule Singularity.Jobs.TemplateEmbedWorker do
  @moduledoc """
  Regenerate embeddings for templates (Oban scheduled job)

  Scheduled: Weekly on Sundays at 3:00 AM UTC

  Regenerates Qodo-Embed-1 embeddings for all templates.
  Run after model updates or periodic maintenance.

  Previously manual: `mix templates.embed --missing`
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Regenerating template embeddings...")

    case Singularity.TemplateStore.embed_all() do
      {:ok, count} ->
        Logger.info("✅ Regenerated embeddings for #{count} templates")
        :ok

      {:error, reason} ->
        Logger.error("❌ Template embedding failed: #{reason}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Exception during template embedding: #{inspect(e)}")
      {:error, "Exception: #{inspect(e)}"}
  end
end
