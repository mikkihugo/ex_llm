ExUnit.start()

# Test helper for Centralcloud
defmodule Centralcloud.TestHelper do
  @moduledoc """
  Test helper functions for Centralcloud tests.
  """

  def setup_test_db do
    # Start the repo for tests
    {:ok, _} = Centralcloud.Repo.start_link()
    
    # Run migrations
    Ecto.Migrator.up(Centralcloud.Repo, :all)
    
    :ok
  end

  def cleanup_test_db do
    # Clean up test data
    Centralcloud.Repo.delete_all(Centralcloud.Schemas.Package)
    Centralcloud.Repo.delete_all("instance_dependencies")
    Centralcloud.Repo.delete_all("usage_analytics")
  end

  def create_test_package(attrs \\ %{}) do
    default_attrs = %{
      name: "test-package",
      ecosystem: "npm",
      version: "1.0.0",
      description: "A test package",
      source: "test"
    }
    
    attrs = Map.merge(default_attrs, attrs)
    
    %Centralcloud.Schemas.Package{}
    |> Centralcloud.Schemas.Package.changeset(attrs)
    |> Centralcloud.Repo.insert!()
  end

  def create_test_dependency(attrs \\ %{}) do
    default_attrs = %{
      instance_id: "test-instance-1",
      package_name: "test-package",
      ecosystem: "npm",
      version: "1.0.0",
      reported_at: DateTime.utc_now()
    }
    
    attrs = Map.merge(default_attrs, attrs)
    
    # Insert directly into database since we don't have a schema yet
    Centralcloud.Repo.query!("""
    INSERT INTO instance_dependencies (instance_id, package_name, ecosystem, version, reported_at, inserted_at, updated_at)
    VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
    """, [
      attrs.instance_id,
      attrs.package_name,
      attrs.ecosystem,
      attrs.version,
      attrs.reported_at
    ])
  end

  def mock_nats_client do
    # Mock NATS client for testing
    %{
      request: fn _subject, _payload, _opts -> {:ok, %{"status" => "ok"}} end,
      publish: fn _subject, _payload -> :ok end,
      subscribe: fn _subject, _callback -> :ok end,
      kv_get: fn _bucket, _key -> {:error, :not_found} end,
      kv_put: fn _bucket, _key, _value -> :ok end
    }
  end

  def mock_http_response(status \\ 200, body \\ %{}) do
    %Req.Response{
      status: status,
      body: Jason.encode!(body)
    }
  end
end
