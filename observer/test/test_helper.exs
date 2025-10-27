ExUnit.start()
{:ok, _pid} = Observer.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Observer.Repo, :manual)
