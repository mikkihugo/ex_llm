defmodule Singularity.TechnologyDetectorTest do
  use Singularity.DataCase, async: true

  alias Singularity.{TechnologyDetector, TechnologyTemplateStore}

  setup do
    TechnologyTemplateStore.truncate!()

    tmp_dir =
      System.tmp_dir!()
      |> Path.join("tech_detector_test_" <> Integer.to_string(System.unique_integer([:positive])))

    File.mkdir_p!(tmp_dir)

    on_exit(fn ->
      File.rm_rf(tmp_dir)
    end)

    %{tmp_dir: tmp_dir}
  end

  test "detects phoenix framework via template patterns", %{tmp_dir: tmp_dir} do
    analysis = %{
      files: [
        %{
          path: "lib/my_app_web/router.ex",
          content: "use Phoenix.Router\nuse Phoenix.Controller"
        },
        %{path: "lib/my_app_web/endpoint.ex", content: "use Phoenix.Endpoint, otp_app: :my_app"}
      ],
      metadata: %{}
    }

    {:ok, %{technologies: technologies}} =
      TechnologyDetector.detect_technologies_elixir(tmp_dir,
        analysis: analysis,
        persist_snapshot: false
      )

    assert :phoenix in technologies.frameworks
  end

  test "detects nats messaging when patterns match", %{tmp_dir: tmp_dir} do
    analysis = %{
      files: [
        %{
          path: "lib/singularity/nats/consumer.ex",
          content: "defmodule Consumer do\n  Gnat.sub(conn, self(), \"events.*\")\nend"
        }
      ],
      metadata: %{}
    }

    {:ok, %{technologies: technologies}} =
      TechnologyDetector.detect_technologies_elixir(tmp_dir,
        analysis: analysis,
        persist_snapshot: false
      )

    assert :nats in technologies.messaging
  end

  test "category detection uses injected analysis", %{tmp_dir: tmp_dir} do
    analysis = %{
      files: [
        %{
          path: "lib/singularity/metrics/prom_ex.ex",
          content: "defmodule Metrics do\n  use PromEx.Plugins.Phoenix\nend"
        }
      ],
      metadata: %{}
    }

    {:ok, monitoring} =
      TechnologyDetector.detect_technology_category(tmp_dir, :monitoring,
        analysis: analysis,
        persist_snapshot: false
      )

    assert :prometheus in monitoring
  end

  test "persists snapshot when enabled", %{tmp_dir: tmp_dir} do
    analysis = %{
      files: [
        %{
          path: "lib/singularity/nats/consumer.ex",
          content: "defmodule Consumer do\n  Gnat.sub(conn, self(), \"events.*\")\nend"
        }
      ],
      metadata: %{}
    }

    {:ok, snapshot} =
      TechnologyDetector.detect_technologies_elixir(tmp_dir,
        analysis: analysis,
        persist_snapshot: true,
        codebase_id: "test_repo",
        snapshot_id: 42
      )

    assert snapshot.snapshot_id == 42

    assert %Singularity.CodebaseSnapshots{} =
             Repo.get_by(Singularity.CodebaseSnapshots,
               codebase_id: "test_repo",
               snapshot_id: 42
             )
  end
end
