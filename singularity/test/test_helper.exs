# ExUnit.start() will:
# 1. Load test config which sets pool: Ecto.Adapters.SQL.Sandbox
# 2. Start the application with the test config
# 3. Set up test database
ExUnit.start()

# The Repo pool should now be configured as SQL.Sandbox
# If needed, we can set manual mode for shared database access
try do
  Ecto.Adapters.SQL.Sandbox.mode(Singularity.Repo, :manual)
rescue
  RuntimeError -> :ok
end
