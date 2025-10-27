{:ok, _} = Application.ensure_all_started(:genesis)
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Genesis.Repo, :manual)
