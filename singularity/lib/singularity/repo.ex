defmodule Singularity.Repo do
  @moduledoc """
  Primary Ecto repository for Singularity telemetry, quality signals, and analysis metadata.
  """
  use Ecto.Repo,
    otp_app: :singularity,
    adapter: Ecto.Adapters.Postgres
end
