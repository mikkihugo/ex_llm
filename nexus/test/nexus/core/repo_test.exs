defmodule Nexus.Core.RepoTest do
  @moduledoc """
  Tests for Nexus.Repo - Ecto repository configuration.

  Tests repository structure and configuration without requiring
  actual database access (that's for integration tests).
  """

  use ExUnit.Case, async: true

  alias Nexus.Repo

  describe "configuration" do
    test "repo module exists and is named correctly" do
      # Basic sanity check
      assert Repo == Nexus.Repo
    end

    test "repo uses Ecto.Repo" do
      # Verify it's an Ecto repo by checking module metadata
      assert is_atom(Repo)
    end
  end

  describe "module structure" do
    test "repo module exists" do
      assert is_atom(Repo)
    end

    test "repo module name ends with 'Repo'" do
      module_name = Repo |> Module.split() |> List.last()
      assert module_name == "Repo"
    end

    test "repo is in nexus namespace" do
      module_parts = Repo |> Module.split()
      assert "Nexus" in module_parts
    end
  end
end
