defmodule Singularity.TechnologyTemplateStoreTest do
  use Singularity.DataCase, async: false

  alias Singularity.TechnologyTemplateStore

  setup do
    TechnologyTemplateStore.truncate!()
    :ok
  end

  test "imports templates from filesystem directories" do
    result = TechnologyTemplateStore.import_from_directories()

    assert result.upserted > 0
    assert result.errors == []
    assert %{} = TechnologyTemplateStore.get({:database, :postgresql})
  end

  test "upserts templates with checksum tracking" do
    template = %{"patterns" => [%{"regex" => "custom"}], "version" => "1.0"}
    {:ok, record} = TechnologyTemplateStore.upsert({:ai, :custom}, template, source: "test")

    assert record.checksum != nil

    {:ok, updated} =
      TechnologyTemplateStore.upsert({:ai, :custom}, Map.put(template, "version", "1.1"), source: "test")

    refute updated.checksum == record.checksum
  end
end
