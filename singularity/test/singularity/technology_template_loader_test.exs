defmodule Singularity.TechnologyTemplateLoaderTest do
  use Singularity.DataCase, async: true

  alias Singularity.{TechnologyTemplateLoader, TechnologyTemplateStore}

  setup do
    TechnologyTemplateStore.truncate!()
    :ok
  end

  test "loads compiled regex patterns for phoenix framework and persists" do
    regexes = TechnologyTemplateLoader.patterns({:framework, :phoenix}, field: :patterns)

    assert Enum.any?(regexes, &Regex.match?(&1, "use Phoenix.Controller"))
    assert %{} = TechnologyTemplateStore.get({:framework, :phoenix})
  end

  test "returns detector signatures map" do
    signatures = TechnologyTemplateLoader.detector_signatures({:framework, :phoenix})
    assert Map.has_key?(signatures, "dependencies")
  end

  test "supports top-level pattern field" do
    regexes = TechnologyTemplateLoader.patterns({:database, :postgresql})
    assert Enum.any?(regexes, &Regex.match?(&1, "pgvector"))
  end

  test "prefers database template when available" do
    template = %{"patterns" => [%{"regex" => "custom-nats"}]}
    {:ok, _} = TechnologyTemplateStore.upsert({:messaging, :nats}, template, source: "test")

    assert TechnologyTemplateLoader.template({:messaging, :nats}, persist: false) == template
  end
end
