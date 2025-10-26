#!/usr/bin/env elixir

# Simple script to test pgflow.add_step function
Mix.install([
  {:ecto_sql, "~> 3.10"},
  {:postgrex, "~> 0.17"}
])

defmodule TestDb do
  use Ecto.Repo,
    otp_app: :test,
    adapter: Ecto.Adapters.Postgrex

  def init(_type, config) do
    config = Keyword.merge(config, [
      hostname: "localhost",
      port: 5432,
      database: "ex_pgflow",
      username: "postgres",
      password: "",
      pool_size: 1
    ])
    {:ok, config}
  end
end

# Start the repo
{:ok, _} = TestDb.start_link()

# Test the function
try do
  result = TestDb.query!("""
    SELECT * FROM pgflow.create_flow('test_workflow', 3, 60)
  """)

  IO.puts("create_flow result: #{inspect(result.rows)}")

  result = TestDb.query!("""
    SELECT * FROM pgflow.add_step('test_workflow', 'step1', '{}', 'single', NULL, NULL, NULL)
  """)

  IO.puts("add_step result: #{inspect(result.rows)}")
  IO.puts("SUCCESS: Function works!")
rescue
  e ->
    IO.puts("ERROR: #{inspect(e)}")
end