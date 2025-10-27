defmodule Genesis.Repo do
  @moduledoc """
  Genesis Ecto Repository - Isolated Database

  Connects to the separate `genesis` PostgreSQL database.
  This is completely isolated from the main `singularity` database.

  Genesis stores:
  - Experiment requests and metadata
  - Test results and metrics
  - Rollback history
  - Performance measurements
  """

  use Ecto.Repo,
    otp_app: :genesis,
    adapter: Ecto.Adapters.Postgres
end
