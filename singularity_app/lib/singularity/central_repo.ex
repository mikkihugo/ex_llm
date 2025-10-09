defmodule Singularity.CentralRepo do
  @moduledoc """
  Central Services Ecto repository for package data, code snippets, 
  security advisories, and analysis results.
  
  This is separate from the main Singularity.Repo and serves
  the central package servers and services.
  """
  use Ecto.Repo,
    otp_app: :singularity,
    adapter: Ecto.Adapters.Postgres
end
