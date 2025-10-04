defmodule SingularityWeb.ToolRouteTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Plug.Test

  alias Singularity.Tools.{Registry, Tool}
  alias SingularityWeb.Router

  @endpoint Router

  @defaults_key {:singularity, :tools, :defaults_loaded}

  setup do
    :persistent_term.erase(@defaults_key)
    Registry.clear(:claude_cli)
    :ok
  end

  test "executes registered tool" do
    tool = Tool.new!(%{name: "echo", function: fn %{"text" => text}, _ -> {:ok, text} end})
    Registry.register_tool(:claude_cli, tool)

    conn =
      conn(
        :post,
        "/api/tools/run",
        Jason.encode!(%{
          provider: "claude_cli",
          tool: "echo",
          arguments: %{text: "hi"}
        })
      )
      |> put_req_header("content-type", "application/json")
      |> @endpoint.call([])

    assert conn.status == 200
    assert %{"content" => "hi"} = Jason.decode!(conn.resp_body)
  end

  test "returns error for invalid payload" do
    conn =
      conn(:post, "/api/tools/run", "{}")
      |> put_req_header("content-type", "application/json")
      |> @endpoint.call([])

    assert conn.status == 400
  end
end
