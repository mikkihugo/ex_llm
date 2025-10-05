Application.ensure_all_started(:singularity)
Ecto.Adapters.SQL.Sandbox.mode(Singularity.Repo, :manual)
ExUnit.start()
