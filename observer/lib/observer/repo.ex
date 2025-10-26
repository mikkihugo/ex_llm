defmodule Observer.Repo do
  use Ecto.Repo,
    otp_app: :observer,
    adapter: Ecto.Adapters.Postgres
end
