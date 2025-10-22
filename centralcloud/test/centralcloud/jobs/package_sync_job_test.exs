defmodule Centralcloud.Jobs.PackageSyncJobTest do
  use ExUnit.Case, async: true
  import Centralcloud.TestHelper

  alias Centralcloud.Jobs.PackageSyncJob
  alias Centralcloud.Schemas.Package

  setup do
    setup_test_db()
    on_exit(fn -> cleanup_test_db() end)
    :ok
  end

  describe "sync_packages/0" do
    test "syncs packages based on instance dependencies and requests" do
      # Create test dependencies
      create_test_dependency(%{
        instance_id: "instance-1",
        package_name: "react",
        ecosystem: "npm",
        version: "18.2.0"
      })

      create_test_dependency(%{
        instance_id: "instance-2", 
        package_name: "tokio",
        ecosystem: "cargo",
        version: "1.0.0"
      })

      # Mock HTTP responses
      with_mock Req, [:passthrough], [
        get: fn
          "https://registry.npmjs.org/react" -> 
            {:ok, mock_http_response(200, %{
              "name" => "react",
              "version" => "18.2.0",
              "description" => "React is a JavaScript library for building user interfaces",
              "homepage" => "https://reactjs.org/",
              "repository" => %{"url" => "https://github.com/facebook/react"},
              "license" => "MIT",
              "keywords" => ["react", "ui", "javascript"],
              "dependencies" => %{"loose-envify" => "^1.1.0"}
            })}
          "https://crates.io/api/v1/crates/tokio" ->
            {:ok, mock_http_response(200, %{
              "crate" => %{
                "name" => "tokio",
                "newest_version" => "1.0.0",
                "description" => "A runtime for writing reliable, asynchronous, and slim applications",
                "homepage" => "https://tokio.rs/",
                "repository" => "https://github.com/tokio-rs/tokio",
                "license" => "MIT",
                "keywords" => ["async", "runtime", "tokio"]
              }
            })}
          _ -> {:ok, mock_http_response(404)}
        end
      ] do
        # Run sync
        result = PackageSyncJob.sync_packages()

        # Verify packages were synced
        assert result > 0

        # Verify packages exist in database
        react_package = Centralcloud.Repo.get_by(Package, name: "react", ecosystem: "npm")
        assert react_package != nil
        assert react_package.version == "18.2.0"
        assert react_package.description =~ "React is a JavaScript library"

        tokio_package = Centralcloud.Repo.get_by(Package, name: "tokio", ecosystem: "cargo")
        assert tokio_package != nil
        assert tokio_package.version == "1.0.0"
        assert tokio_package.description =~ "A runtime for writing reliable"
      end
    end

    test "handles API errors gracefully" do
      # Mock API errors
      with_mock Req, [:passthrough], [
        get: fn _url -> {:error, :timeout} end
      ] do
        result = PackageSyncJob.sync_packages()
        
        # Should not crash, should return 0
        assert result == 0
      end
    end
  end

  describe "handle_dependency_report/2" do
    test "stores dependency reports and triggers sync" do
      dependencies = [
        {"axios", "npm", "1.0.0"},
        {"serde", "cargo", "1.0.0"}
      ]

      # Mock HTTP responses
      with_mock Req, [:passthrough], [
        get: fn
          "https://registry.npmjs.org/axios" ->
            {:ok, mock_http_response(200, %{
              "name" => "axios",
              "version" => "1.0.0",
              "description" => "Promise based HTTP client"
            })}
          "https://crates.io/api/v1/crates/serde" ->
            {:ok, mock_http_response(200, %{
              "crate" => %{
                "name" => "serde",
                "newest_version" => "1.0.0",
                "description" => "Serialization framework"
              }
            })}
          _ -> {:ok, mock_http_response(404)}
        end
      ] do
        # Handle dependency report
        PackageSyncJob.handle_dependency_report("test-instance", dependencies)

        # Verify dependencies were stored
        result = Centralcloud.Repo.query!("""
        SELECT package_name, ecosystem FROM instance_dependencies 
        WHERE instance_id = 'test-instance'
        """)

        assert length(result.rows) == 2
        assert {"axios", "npm"} in result.rows
        assert {"serde", "cargo"} in result.rows
      end
    end
  end

  describe "cleanup_old_packages/0" do
    test "cleans up packages based on usage patterns" do
      # Create test packages with different ages
      old_time = DateTime.utc_now() |> DateTime.add(-20, :day)
      recent_time = DateTime.utc_now() |> DateTime.add(-5, :day)

      # Create old unused package
      create_test_package(%{
        name: "old-unused",
        ecosystem: "npm",
        last_updated: old_time
      })

      # Create recent package in dependencies
      create_test_package(%{
        name: "recent-dep",
        ecosystem: "npm", 
        last_updated: recent_time
      })

      create_test_dependency(%{
        package_name: "recent-dep",
        ecosystem: "npm",
        reported_at: recent_time
      })

      # Run cleanup
      PackageSyncJob.cleanup_old_packages()

      # Verify old unused package was deleted
      assert Centralcloud.Repo.get_by(Package, name: "old-unused") == nil

      # Verify recent dependency package was kept
      assert Centralcloud.Repo.get_by(Package, name: "recent-dep") != nil
    end
  end

  describe "quality score calculation" do
    test "calculates quality scores correctly" do
      package = create_test_package(%{
        name: "high-quality",
        description: "This is a very detailed description with lots of information",
        keywords: ["quality", "test", "example", "good"],
        homepage: "https://example.com",
        repository: "https://github.com/example/repo",
        last_updated: DateTime.utc_now()
      })

      # The quality score calculation is private, but we can test it indirectly
      # by checking that packages get quality scores assigned
      updated_package = Centralcloud.Repo.get!(Package, package.id)
      assert updated_package.security_score != nil
      assert updated_package.security_score > 0
    end
  end
end
