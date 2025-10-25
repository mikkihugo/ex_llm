defmodule Nexus.IDTest do
  use ExUnit.Case, async: true
  doctest Nexus.ID

  describe "generate/0" do
    test "generates valid UUIDv7 string" do
      id = Nexus.ID.generate()

      assert is_binary(id)
      assert String.length(id) == 36
      assert String.match?(id, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
    end

    test "generates unique IDs" do
      id1 = Nexus.ID.generate()
      id2 = Nexus.ID.generate()

      assert id1 != id2
    end

    test "generates sortable IDs" do
      # Generate multiple IDs with small delays
      ids = for _ <- 1..5 do
        id = Nexus.ID.generate()
        Process.sleep(1)
        id
      end

      # UUIDv7 should be sortable by generation time
      assert Enum.sort(ids) == ids
    end
  end

  describe "generate_binary/0" do
    test "generates 16-byte binary" do
      id = Nexus.ID.generate_binary()

      assert is_binary(id)
      assert byte_size(id) == 16
    end
  end

  describe "extract_timestamp/1" do
    test "extracts timestamp from UUIDv7" do
      id = Nexus.ID.generate()

      assert {:ok, timestamp} = Nexus.ID.extract_timestamp(id)
      assert is_integer(timestamp)
      assert timestamp > 0

      # Timestamp should be recent (within last hour)
      now_ms = System.system_time(:millisecond)
      assert timestamp <= now_ms
      assert timestamp >= now_ms - 3_600_000
    end

    test "returns error for invalid UUID" do
      assert {:error, :invalid_uuid} = Nexus.ID.extract_timestamp("not-a-uuid")
    end
  end

  describe "valid?/1" do
    test "returns true for valid UUIDv7" do
      id = Nexus.ID.generate()
      assert Nexus.ID.valid?(id)
    end

    test "returns false for invalid UUID string" do
      refute Nexus.ID.valid?("not-a-uuid")
    end

    test "returns false for UUIDv4" do
      # UUIDv4 has version 4 in the third group
      uuid_v4 = "550e8400-e29b-41d4-a716-446655440000"
      refute Nexus.ID.valid?(uuid_v4)
    end
  end

  describe "timestamp ordering" do
    test "newer IDs have larger timestamps" do
      id1 = Nexus.ID.generate()
      Process.sleep(10)
      id2 = Nexus.ID.generate()

      {:ok, ts1} = Nexus.ID.extract_timestamp(id1)
      {:ok, ts2} = Nexus.ID.extract_timestamp(id2)

      assert ts2 >= ts1
    end
  end
end
