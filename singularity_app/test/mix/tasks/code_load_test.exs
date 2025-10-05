defmodule Mix.Tasks.Code.LoadTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @task "code.load"

  setup do
    tmp_root =
      System.tmp_dir!()
      |> Path.join("code_load_test_" <> Integer.to_string(System.unique_integer([:positive])))

    System.put_env("CODE_ROOT", tmp_root)

    on_exit(fn ->
      System.delete_env("CODE_ROOT")
      File.rm_rf(tmp_root)
      Application.stop(:singularity)
    end)

    Application.stop(:singularity)
    {:ok, _} = Application.ensure_all_started(:singularity)

    %{code_root: tmp_root}
  end

  test "stages code from file" do
    paths = Singularity.CodeStore.paths()
    versions_dir = paths.versions

    code_file = Path.join(paths.root, "snippet.exs")
    File.write!(code_file, "IO.puts(:hello)\n")

    output =
      capture_io(fn ->
        Mix.Task.rerun(@task, ["--agent", "cli-agent", "--code", code_file, "--version", "v1"]) 
      end)

    assert output =~ "Staged"

    staged_files = File.ls!(versions_dir)
    assert Enum.any?(staged_files, &String.contains?(&1, "cli-agent"))
  end

  test "reads code from stdin" do
    output =
      capture_io("defmodule FromStdin do\nend\n", fn ->
        Mix.Task.rerun(@task, ["--agent", "stdin-agent", "--version", "stdin"])
      end)

    assert output =~ "Staged"

    versions_dir = Singularity.CodeStore.paths().versions
    assert Enum.any?(File.ls!(versions_dir), &String.contains?(&1, "stdin-agent"))
  end
end
