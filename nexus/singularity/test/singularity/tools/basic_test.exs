defmodule Singularity.Tools.BasicTest do
  use ExUnit.Case, async: true

  alias Singularity.Tools.{Basic, Registry, Runner, ToolCall}

  @provider :gemini
  @tmp_dir Path.join(["tmp", "tools_basic_suite"])

  setup_all do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)

    on_exit(fn -> File.rm_rf!(@tmp_dir) end)
    :ok
  end

  setup do
    Basic.ensure_registered()
    :ok
  end

  test "registers baseline tools" do
    assert {:ok, tool} = Registry.fetch_tool(@provider, "fs_list_directory")
    assert tool.name == "fs_list_directory"

    assert {:ok, tool} = Registry.fetch_tool(@provider, "fs_search_content")
    assert tool.name == "fs_search_content"

    assert {:ok, tool} = Registry.fetch_tool(@provider, "fs_write_file")
    assert tool.name == "fs_write_file"

    assert {:ok, tool} = Registry.fetch_tool(@provider, "net_http_fetch")
    assert tool.name == "net_http_fetch"

    assert {:ok, tool} = Registry.fetch_tool(@provider, "gh_graphql_query")
    assert tool.name == "gh_graphql_query"
  end

  test "list_directory includes known files" do
    call =
      ToolCall.new!(%{
        status: :incomplete,
        call_id: "call:list",
        name: "fs_list_directory",
        arguments: %{"path" => "."}
      })

    assert {:ok, result} = Runner.execute(@provider, call)
    payload = Jason.decode!(result.content)

    assert is_list(payload["entries"])
    assert Enum.any?(payload["entries"], fn entry -> entry["name"] == "mix.exs" end)
  end

  test "write_file writes relative path" do
    path = Path.join(@tmp_dir, "basic_write.txt")

    call =
      ToolCall.new!(%{
        status: :incomplete,
        call_id: "call:write",
        name: "fs_write_file",
        arguments: %{"path" => path, "content" => "hello", "mode" => "overwrite"}
      })

    assert {:ok, result} = Runner.execute(@provider, call)
    info = Jason.decode!(result.content)

    assert info["bytes"] == 5
    assert info["mode"] == "overwrite"
    assert File.read!(Path.expand(path)) == "hello"
  end

  test "fs_search_content finds matches" do
    file_dir = Path.join(@tmp_dir, "search")
    File.mkdir_p!(file_dir)
    file_path = Path.join(file_dir, "sample.txt")
    File.write!(file_path, "needle here\nno match\nNeedle again")

    call =
      ToolCall.new!(%{
        status: :incomplete,
        call_id: "call:search",
        name: "fs_search_content",
        arguments: %{
          "pattern" => "needle",
          "path" => Path.join(["tmp", "tools_basic_suite", "search"]),
          "case_sensitive" => false
        }
      })

    assert {:ok, result} = Runner.execute(@provider, call)
    data = Jason.decode!(result.content)

    assert data["pattern"] == "needle"
    assert [%{"file" => file, "matches" => matches}] = data["results"]
    assert String.ends_with?(file, "sample.txt")
    assert Enum.any?(matches, fn m -> m["line"] == 1 end)
  end

  test "net_http_fetch retrieves remote content" do
    call =
      ToolCall.new!(%{
        status: :incomplete,
        call_id: "call:webfetch",
        name: "net_http_fetch",
        arguments: %{"url" => "https://example.com"}
      })

    assert {:ok, result} = Runner.execute(@provider, call)
    data = Jason.decode!(result.content)

    assert data["status"] in 200..299
    assert is_list(data["headers"])
    assert is_binary(data["body"])
    assert String.contains?(data["body"], "Example Domain")
  end

  test "gh_graphql_query errors when token missing" do
    if System.get_env("GITHUB_TOKEN") do
      call =
        ToolCall.new!(%{
          status: :incomplete,
          call_id: "call:github",
          name: "gh_graphql_query",
          arguments: %{"query" => "{ viewer { login } }"}
        })

      assert {:ok, result} = Runner.execute(@provider, call)
      body = Jason.decode!(result.content)
      assert Map.has_key?(body, "data")
    else
      call =
        ToolCall.new!(%{
          status: :incomplete,
          call_id: "call:github",
          name: "gh_graphql_query",
          arguments: %{"query" => "{ viewer { login } }"}
        })

      assert {:error, message} = Runner.execute(@provider, call)
      assert message =~ "GITHUB_TOKEN"
    end
  end
end
