defmodule Centralcloud.FrameworkLearners.TemplateMatcherTest do
  @moduledoc """
  Tests for TemplateMatcher - Fast template-based framework detection.

  Tests the template matching learner's ability to:
  - Match packages against framework templates
  - Return :no_match when package not found
  - Return cached framework when already detected
  - Record successful matches to database
  - Implement FrameworkLearner behavior correctly
  """

  use ExUnit.Case, async: false

  import Mox
  import Centralcloud.TestHelper

  alias Centralcloud.FrameworkLearners.TemplateMatcher
  alias Centralcloud.Schemas.Package
  alias Centralcloud.Repo

  setup :verify_on_exit!

  setup do
    setup_test_db()
    on_exit(fn -> cleanup_test_db() end)
    :ok
  end

  describe "learner_type/0" do
    test "returns :template_matcher" do
      assert TemplateMatcher.learner_type() == :template_matcher
    end
  end

  describe "description/0" do
    test "returns description string" do
      description = TemplateMatcher.description()

      assert is_binary(description)
      assert description =~ "template"
      assert description =~ "framework"
    end
  end

  describe "capabilities/0" do
    test "returns list of capabilities" do
      capabilities = TemplateMatcher.capabilities()

      assert is_list(capabilities)
      assert "fast" in capabilities
      assert "offline" in capabilities
      assert "dependency_based" in capabilities
      assert "high_confidence" in capabilities
    end
  end

  describe "learn/2" do
    test "returns :no_match when package not found in database" do
      package_id = "npm:nonexistent-package"
      code_samples = []

      with_mock Centralcloud.Repo, [:passthrough],
        get: fn Package, ^package_id -> nil end do

        result = TemplateMatcher.learn(package_id, code_samples)

        assert {:error, :package_not_found} = result
      end
    end

    test "returns cached framework when already detected" do
      package_id = "npm:react"
      cached_framework = %{
        "name" => "React",
        "type" => "web_framework",
        "version" => "18.0.0"
      }

      mock_package = %Package{
        id: package_id,
        name: "react",
        ecosystem: "npm",
        version: "18.0.0",
        detected_framework: cached_framework
      }

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end do

        result = TemplateMatcher.learn(package_id, [])

        assert {:ok, framework} = result
        assert framework["name"] == "React"
        assert framework["type"] == "web_framework"
      end
    end

    test "matches package against framework templates successfully" do
      package_id = "npm:next-app"

      mock_package = %Package{
        id: package_id,
        name: "next-app",
        ecosystem: "npm",
        version: "1.0.0",
        dependencies: ["react", "next", "webpack"],
        detected_framework: %{}
      }

      framework_templates = [
        %{
          "name" => "Next.js",
          "type" => "web_framework",
          "ecosystem" => "npm",
          "latest_version" => "14.0.0",
          "detector_signatures" => %{
            "dependencies" => ["next", "react"]
          }
        }
      ]

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end do

        with_mock Centralcloud.NatsClient, [:passthrough],
          request: fn "central.template.search", _payload, _opts ->
            {:ok, %{"templates" => framework_templates}}
          end do

          result = TemplateMatcher.learn(package_id, [])

          assert {:ok, framework} = result
          assert framework["name"] == "Next.js"
          assert framework["type"] == "web_framework"
          assert framework["ecosystem"] == "npm"
          assert framework["confidence"] == 0.95
          assert framework["detected_by"] == "template_matcher"
        end
      end
    end

    test "returns :no_match when no templates match package dependencies" do
      package_id = "npm:custom-app"

      mock_package = %Package{
        id: package_id,
        name: "custom-app",
        ecosystem: "npm",
        version: "1.0.0",
        dependencies: ["lodash", "axios"],
        detected_framework: %{}
      }

      framework_templates = [
        %{
          "name" => "React",
          "detector_signatures" => %{
            "dependencies" => ["react", "react-dom"]
          }
        },
        %{
          "name" => "Vue",
          "detector_signatures" => %{
            "dependencies" => ["vue"]
          }
        }
      ]

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end do

        with_mock Centralcloud.NatsClient, [:passthrough],
          request: fn "central.template.search", _payload, _opts ->
            {:ok, %{"templates" => framework_templates}}
          end do

          result = TemplateMatcher.learn(package_id, [])

          assert result == :no_match
        end
      end
    end

    test "returns :no_match when template loading fails" do
      package_id = "npm:test-app"

      mock_package = %Package{
        id: package_id,
        name: "test-app",
        ecosystem: "npm",
        dependencies: ["react"],
        detected_framework: %{}
      }

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end do

        with_mock Centralcloud.NatsClient, [:passthrough],
          request: fn "central.template.search", _payload, _opts ->
            {:error, :nats_timeout}
          end do

          result = TemplateMatcher.learn(package_id, [])

          assert result == :no_match
        end
      end
    end

    test "handles empty templates list" do
      package_id = "npm:test-app"

      mock_package = %Package{
        id: package_id,
        name: "test-app",
        ecosystem: "npm",
        dependencies: ["react"],
        detected_framework: %{}
      }

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end do

        with_mock Centralcloud.NatsClient, [:passthrough],
          request: fn "central.template.search", _payload, _opts ->
            {:ok, %{"templates" => []}}
          end do

          result = TemplateMatcher.learn(package_id, [])

          assert result == :no_match
        end
      end
    end

    test "matches with partial dependency overlap" do
      package_id = "npm:react-app"

      mock_package = %Package{
        id: package_id,
        name: "react-app",
        ecosystem: "npm",
        dependencies: ["react", "react-dom", "lodash", "axios"],
        detected_framework: %{}
      }

      framework_templates = [
        %{
          "name" => "React",
          "type" => "web_framework",
          "ecosystem" => "npm",
          "latest_version" => "18.0.0",
          "detector_signatures" => %{
            "dependencies" => ["react"]
          }
        }
      ]

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end do

        with_mock Centralcloud.NatsClient, [:passthrough],
          request: fn "central.template.search", _payload, _opts ->
            {:ok, %{"templates" => framework_templates}}
          end do

          result = TemplateMatcher.learn(package_id, [])

          assert {:ok, framework} = result
          assert framework["name"] == "React"
        end
      end
    end
  end

  describe "record_success/2" do
    test "stores framework in database successfully" do
      package_id = "test-package-id"
      framework = %{
        "name" => "Express",
        "type" => "backend_framework",
        "version" => "4.18.0"
      }

      mock_package = %Package{
        id: package_id,
        name: "express-app",
        ecosystem: "npm",
        detected_framework: %{}
      }

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end,
        update: fn changeset ->
          # Verify the changeset has correct data
          changes = changeset.changes
          assert changes[:detected_framework] == framework
          assert changes[:last_updated] != nil

          {:ok, %{mock_package | detected_framework: framework}}
        end do

        result = TemplateMatcher.record_success(package_id, framework)

        assert result == :ok
        assert called(Repo.update(:_))
      end
    end

    test "returns error when package not found" do
      package_id = "nonexistent-package"
      framework = %{"name" => "React"}

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> nil end do

        result = TemplateMatcher.record_success(package_id, framework)

        assert {:error, :package_not_found} = result
      end
    end

    test "returns error when database update fails" do
      package_id = "test-package-id"
      framework = %{"name" => "Vue"}

      mock_package = %Package{
        id: package_id,
        name: "vue-app",
        ecosystem: "npm"
      }

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end,
        update: fn _changeset ->
          {:error, :database_error}
        end do

        result = TemplateMatcher.record_success(package_id, framework)

        assert {:error, :database_error} = result
      end
    end
  end

  describe "template matching logic" do
    test "matches when any required dependency is present" do
      package_id = "npm:multi-framework"

      mock_package = %Package{
        id: package_id,
        name: "multi-framework",
        ecosystem: "npm",
        dependencies: ["express", "koa", "fastify"],
        detected_framework: %{}
      }

      # Template with multiple possible dependencies (OR logic)
      framework_templates = [
        %{
          "name" => "Express",
          "type" => "backend_framework",
          "ecosystem" => "npm",
          "latest_version" => "4.18.0",
          "detector_signatures" => %{
            "dependencies" => ["express"]
          }
        }
      ]

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end do

        with_mock Centralcloud.NatsClient, [:passthrough],
          request: fn "central.template.search", _payload, _opts ->
            {:ok, %{"templates" => framework_templates}}
          end do

          result = TemplateMatcher.learn(package_id, [])

          assert {:ok, framework} = result
          assert framework["name"] == "Express"
        end
      end
    end

    test "returns first matching template" do
      package_id = "npm:react-next"

      mock_package = %Package{
        id: package_id,
        name: "react-next",
        ecosystem: "npm",
        dependencies: ["react", "next"],
        detected_framework: %{}
      }

      # Multiple templates that could match
      framework_templates = [
        %{
          "name" => "React",
          "type" => "web_framework",
          "ecosystem" => "npm",
          "latest_version" => "18.0.0",
          "detector_signatures" => %{
            "dependencies" => ["react"]
          }
        },
        %{
          "name" => "Next.js",
          "type" => "web_framework",
          "ecosystem" => "npm",
          "latest_version" => "14.0.0",
          "detector_signatures" => %{
            "dependencies" => ["next"]
          }
        }
      ]

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end do

        with_mock Centralcloud.NatsClient, [:passthrough],
          request: fn "central.template.search", _payload, _opts ->
            {:ok, %{"templates" => framework_templates}}
          end do

          result = TemplateMatcher.learn(package_id, [])

          assert {:ok, framework} = result
          # Should return first match (React)
          assert framework["name"] == "React"
        end
      end
    end

    test "handles templates without detector_signatures" do
      package_id = "npm:test-app"

      mock_package = %Package{
        id: package_id,
        name: "test-app",
        ecosystem: "npm",
        dependencies: ["react"],
        detected_framework: %{}
      }

      framework_templates = [
        %{
          "name" => "React",
          "type" => "web_framework"
          # No detector_signatures field
        }
      ]

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end do

        with_mock Centralcloud.NatsClient, [:passthrough],
          request: fn "central.template.search", _payload, _opts ->
            {:ok, %{"templates" => framework_templates}}
          end do

          result = TemplateMatcher.learn(package_id, [])

          # Should not match (no signatures to match against)
          assert result == :no_match
        end
      end
    end

    test "handles package with nil or empty dependencies" do
      package_id = "npm:no-deps"

      mock_package = %Package{
        id: package_id,
        name: "no-deps",
        ecosystem: "npm",
        dependencies: nil,
        detected_framework: %{}
      }

      framework_templates = [
        %{
          "name" => "React",
          "detector_signatures" => %{
            "dependencies" => ["react"]
          }
        }
      ]

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end do

        with_mock Centralcloud.NatsClient, [:passthrough],
          request: fn "central.template.search", _payload, _opts ->
            {:ok, %{"templates" => framework_templates}}
          end do

          result = TemplateMatcher.learn(package_id, [])

          assert result == :no_match
        end
      end
    end
  end

  describe "template loading" do
    test "always fetches latest templates (no caching)" do
      package_id = "npm:test"

      mock_package = %Package{
        id: package_id,
        name: "test",
        ecosystem: "npm",
        dependencies: ["react"],
        detected_framework: %{}
      }

      # Track how many times templates are fetched
      call_count = Agent.start_link(fn -> 0 end)
      {:ok, pid} = call_count

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end do

        with_mock Centralcloud.NatsClient, [:passthrough],
          request: fn "central.template.search", _payload, _opts ->
            Agent.update(pid, &(&1 + 1))
            {:ok, %{"templates" => []}}
          end do

          # Call learn twice
          TemplateMatcher.learn(package_id, [])
          TemplateMatcher.learn(package_id, [])

          # Should fetch templates both times (no caching)
          count = Agent.get(pid, & &1)
          assert count == 2
        end
      end
    end

    test "passes correct request parameters to NATS" do
      package_id = "npm:test"

      mock_package = %Package{
        id: package_id,
        name: "test",
        ecosystem: "npm",
        dependencies: [],
        detected_framework: %{}
      }

      with_mock Repo, [:passthrough],
        get: fn Package, ^package_id -> mock_package end do

        with_mock Centralcloud.NatsClient, [:passthrough],
          request: fn subject, payload, opts ->
            # Verify request parameters
            assert subject == "central.template.search"
            assert payload[:artifact_type] == "framework"
            assert payload[:limit] == 100
            assert opts[:timeout] == 10_000

            {:ok, %{"templates" => []}}
          end do

          TemplateMatcher.learn(package_id, [])
        end
      end
    end
  end
end
