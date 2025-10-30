defmodule Singularity.JobQueue.Worker do
  @moduledoc """
  Thin wrapper around Oban.Worker used by in-app jobs.

  Purpose: decouple app code from Oban so we can swap
  implementations later with minimal churn.
  """

  defmacro __using__(opts \\ []) do
    escaped = Macro.escape(opts)

    quote do
      use Oban.Worker, unquote(escaped)
    end
  end
end
