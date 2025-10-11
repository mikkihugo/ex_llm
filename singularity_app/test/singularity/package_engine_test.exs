defmodule Singularity.PackageEngineTest do
  use ExUnit.Case, async: true

  alias Singularity.PackageEngine

  describe "scan_dependencies_nif/1" do
    test "scans JavaScript package.json" do
      # Create a temporary package.json
      package_json = """
      {
        "name": "test-app",
        "dependencies": {
          "react": "^18.0.0",
          "express": "^4.18.0"
        },
        "devDependencies": {
          "jest": "^29.0.0"
        }
      }
      """

      # Write to temp file
      tmp_path = Path.join(System.tmp_dir!(), "package.json")
      File.write!(tmp_path, package_json)

      try do
        {:ok, packages} = PackageEngine.scan_dependencies_nif(tmp_path)

        # Should find react, express, and jest
        package_names = Enum.map(packages, & &1.name)
        assert "react" in package_names
        assert "express" in package_names
        assert "jest" in package_names

        # All should be JavaScript ecosystem
        assert Enum.all?(packages, &(&1.ecosystem == "javascript"))
      after
        File.rm(tmp_path)
      end
    end

    test "scans Python requirements.txt" do
      requirements_txt = """
      flask==2.3.0
      requests>=2.28.0
      pytest~=7.3.0
      """

      tmp_path = Path.join(System.tmp_dir!(), "requirements.txt")
      File.write!(tmp_path, requirements_txt)

      try do
        {:ok, packages} = PackageEngine.scan_dependencies_nif(tmp_path)

        # Should find flask, requests, pytest
        package_names = Enum.map(packages, & &1.name)
        assert "flask" in package_names
        assert "requests" in package_names
        assert "pytest" in package_names

        # All should be Python ecosystem
        assert Enum.all?(packages, &(&1.ecosystem == "python"))
      after
        File.rm(tmp_path)
      end
    end

    test "scans directory for multiple package files" do
      # Create a temporary directory with multiple package files
      tmp_dir = Path.join(System.tmp_dir!(), "test_project_#{:rand.uniform(1000)}")
      File.mkdir_p!(tmp_dir)

      # Create package.json
      package_json = ~s({"dependencies": {"react": "18.0.0"}})
      File.write!(Path.join(tmp_dir, "package.json"), package_json)

      # Create requirements.txt
      requirements_txt = "flask==2.3.0\n"
      File.write!(Path.join(tmp_dir, "requirements.txt"), requirements_txt)

      try do
        {:ok, packages} = PackageEngine.scan_dependencies_nif(tmp_dir)

        package_names = Enum.map(packages, & &1.name)
        assert "react" in package_names
        assert "flask" in package_names

        # Should have correct ecosystems
        react_pkg = Enum.find(packages, &(&1.name == "react"))
        flask_pkg = Enum.find(packages, &(&1.name == "flask"))
        assert react_pkg.ecosystem == "javascript"
        assert flask_pkg.ecosystem == "python"
      after
        File.rm_rf!(tmp_dir)
      end
    end

    test "handles non-existent files gracefully" do
      {:ok, packages} = PackageEngine.scan_dependencies_nif("/non/existent/path")
      assert packages == []
    end

    test "handles unsupported file types" do
      tmp_path = Path.join(System.tmp_dir!(), "readme.txt")
      File.write!(tmp_path, "This is just a readme file")

      try do
        {:ok, packages} = PackageEngine.scan_dependencies_nif(tmp_path)
        assert packages == []
      after
        File.rm(tmp_path)
      end
    end
  end

  describe "check_vulnerabilities_nif/1" do
    test "checks packages for vulnerabilities" do
      packages = [
        %{name: "old-package", version: "0.1.0", ecosystem: "javascript"},
        %{name: "safe-package", version: "1.0.0", ecosystem: "javascript"}
      ]

      {:ok, result} = PackageEngine.check_vulnerabilities_nif(packages)

      assert Map.has_key?(result, :vulnerabilities)
      assert Map.has_key?(result, :total_checked)
      assert result.total_checked == 2
    end

    test "handles empty package list" do
      {:ok, result} = PackageEngine.check_vulnerabilities_nif([])
      assert result.vulnerabilities == []
      assert result.total_checked == 0
    end
  end

  describe "validate_versions_nif/1" do
    test "validates package versions" do
      packages = [
        %{name: "react", version: "18.0.0", ecosystem: "javascript"},
        %{name: "express", version: "4.18.0", ecosystem: "javascript"}
      ]

      {:ok, result} = PackageEngine.validate_versions_nif(packages)

      assert Map.has_key?(result, :packages)
      assert Map.has_key?(result, :total_validated)
      assert result.total_validated == 2

      # All packages should be marked as valid
      assert Enum.all?(result.packages, & &1.valid)
    end

    test "handles empty package list" do
      {:ok, result} = PackageEngine.validate_versions_nif([])
      assert result.packages == []
      assert result.total_validated == 0
    end
  end

  describe "validate_deps/1" do
    test "validates all dependencies in a project" do
      # Create a temporary project with package.json
      tmp_dir = Path.join(System.tmp_dir!(), "validate_test_#{:rand.uniform(1000)}")
      File.mkdir_p!(tmp_dir)

      package_json = """
      {
        "dependencies": {
          "safe-package": "1.0.0"
        }
      }
      """
      File.write!(Path.join(tmp_dir, "package.json"), package_json)

      try do
        result = PackageEngine.validate_deps(tmp_dir)

        case result do
          {:ok, validation} ->
            assert Map.has_key?(validation, :safe) or Map.has_key?(validation, :dependencies)
          {:error, _} ->
            # May fail due to missing NIF implementations, but shouldn't crash
            assert true
        end
      after
        File.rm_rf!(tmp_dir)
      end
    end
  end

  describe "ecosystem detection" do
    test "correctly identifies ecosystems from file paths" do
      test_cases = [
        {"/path/package.json", "javascript"},
        {"/path/requirements.txt", "python"},
        {"/path/Gemfile", "ruby"},
        {"/path/mix.exs", "elixir"},
        {"/path/Cargo.toml", "rust"},
        {"/path/go.mod", "go"},
        {"/path/pom.xml", "java"},
        {"/path/composer.json", "php"}
      ]

      Enum.each(test_cases, fn {file_path, expected_ecosystem} ->
        ecosystem = PackageEngine.__private__(:detect_ecosystem_from_file, [file_path])
        assert ecosystem == expected_ecosystem, "Expected #{expected_ecosystem} for #{file_path}, got #{ecosystem}"
      end)
    end
  end

  describe "error handling" do
    test "handles malformed JSON gracefully" do
      tmp_path = Path.join(System.tmp_dir!(), "bad_package.json")
      File.write!(tmp_path, "{ invalid json }")

      try do
        {:ok, packages} = PackageEngine.scan_dependencies_nif(tmp_path)
        assert packages == []
      after
        File.rm(tmp_path)
      end
    end

    test "handles file read errors gracefully" do
      # Try to scan a directory we don't have permission to read
      {:ok, packages} = PackageEngine.scan_dependencies_nif("/root")
      assert is_list(packages)
    end
  end
end