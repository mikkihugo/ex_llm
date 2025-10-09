defmodule CentralCloud.Repo do
  @moduledoc """
  Central Services Ecto repository for package data, code snippets, 
  security advisories, and analysis results.
  
  This is completely separate from Singularity's Ecto setup.
  """
  use Ecto.Repo,
    otp_app: :central_services,
    adapter: Ecto.Adapters.Postgres
end
