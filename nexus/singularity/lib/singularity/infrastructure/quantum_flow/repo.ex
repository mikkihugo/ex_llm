defmodule Singularity.Infrastructure.QuantumFlow.Repo do
  @moduledoc """
  Dedicated Ecto repo for QuantumFlow-backed workflow metadata.
  """
  use Ecto.Repo,
    otp_app: :singularity,
    adapter: Ecto.Adapters.Postgres
end
