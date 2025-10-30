defmodule Singularity.Infrastructure.PgFlow.Repo do
  @moduledoc """
  Ecto repo for PgFlow.
  """
  use Ecto.Repo,
    otp_app: :singularity,
    adapter: Ecto.Adapters.Postgres
end
