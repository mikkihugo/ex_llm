defmodule Singularity.Database.AgentGeospatialClustering do
  @moduledoc """
  Agent geospatial clustering via PostgreSQL h3 extension.

  Uses Uber's H3 hexagonal hierarchical geospatial indexing to cluster
  agents across distributed Singularity instances by geographic location.

  ## Features

  - Hexagonal grid indexing (H3 by Uber)
  - 15 resolution levels (0 = ~10,000 km, 15 = ~10 cm)
  - Efficient neighborhood queries (7-ring searches)
  - Cross-instance agent clustering
  - Location-based workload distribution

  ## Architecture

  ```
  Agent Location (lat, lon)
      ↓
  H3 Index (resolution 6 = ~1km cells)
      ↓
  Hexagonal Cell ID (alphanumeric)
      ↓
  Neighborhood Queries (same hex or adjacent)
      ↓
  Agent clustering and workload balancing
  ```

  ## Use Cases

  - Cluster agents by geographic region (for latency optimization)
  - Find agents in same location for local knowledge sharing
  - Balance workload across distributed instances
  - Detect and manage colocation (multiple agents same location)
  - Route requests to nearest agent

  ## H3 Resolution Levels

  - Level 0: ~10,000 km (continents)
  - Level 6: ~1.2 km (neighborhoods)
  - Level 8: ~462 m (city blocks)
  - Level 9: ~154 m (house-level precision)
  - Level 15: ~10 cm (precision measurement)

  ## Usage

  ```elixir
  # Add location to agent
  :ok = AgentGeospatialClustering.set_agent_location(agent_id, 37.7749, -122.4194)

  # Find nearby agents (same hex or neighbors)
  {:ok, nearby} = AgentGeospatialClustering.find_nearby_agents(agent_id, radius: :neighbors)

  # Get all agents in region
  {:ok, agents} = AgentGeospatialClustering.get_agents_in_hex("891e1000000ffff")

  # Cluster agents by region
  {:ok, clusters} = AgentGeospatialClustering.cluster_agents_by_region()

  # Get distance between agents (via H3)
  {:ok, distance} = AgentGeospatialClustering.get_h3_distance(agent_1_id, agent_2_id)
  ```
  """

  require Logger
  alias CentralCloud.Repo

  # H3 resolution for agent clustering (1.2 km cells)
  @default_resolution 6

  @doc """
  Set agent location (latitude, longitude).

  Automatically calculates H3 index cell at specified resolution.
  """
  def set_agent_location(agent_id, latitude, longitude, resolution \\ @default_resolution)
      when is_integer(agent_id) and is_float(latitude) and is_float(longitude) and
             is_integer(resolution) do
    case Repo.query(
           """
             UPDATE agents
             SET
               latitude = $1,
               longitude = $2,
               h3_cell = h3_latlng_to_cell($1, $2, $3),
               location_updated_at = NOW()
             WHERE id = $4
             RETURNING h3_cell
           """,
           [latitude, longitude, resolution, agent_id]
         ) do
      {:ok, %{rows: [[h3_cell]]}} ->
        Logger.info(
          "Agent #{agent_id} location set: #{latitude}, #{longitude} (cell: #{h3_cell})"
        )

        {:ok, h3_cell}

      {:ok, %{rows: []}} ->
        {:error, :agent_not_found}

      error ->
        error
    end
  end

  @doc """
  Find nearby agents (in same H3 cell or neighbors).

  ## Options

  - `:radius` - `:same` (same cell only) or `:neighbors` (neighbors included, default)
  - `:limit` - Max results (default: 50)
  """
  def find_nearby_agents(agent_id, _opts \\ []) when is_integer(agent_id) do
    radius = Keyword.get(opts, :radius, :neighbors)
    limit = Keyword.get(opts, :limit, 50)

    case Repo.query(
           "SELECT h3_cell FROM agents WHERE id = $1",
           [agent_id]
         ) do
      {:ok, %{rows: [[h3_cell]]}} when h3_cell != nil ->
        if radius == :same do
          # Same H3 cell only
          query_nearby_same_cell(h3_cell, agent_id, limit)
        else
          # H3 cell + neighbors (7-ring neighborhood)
          query_nearby_with_neighbors(h3_cell, agent_id, limit)
        end

      {:ok, %{rows: [[nil]]}} ->
        {:error, :agent_location_not_set}

      {:ok, %{rows: []}} ->
        {:error, :agent_not_found}

      error ->
        error
    end
  end

  @doc """
  Get all agents in a specific H3 cell.

  Useful for location-based queries and regional analysis.
  """
  def get_agents_in_hex(h3_cell, limit \\ 100) when is_binary(h3_cell) do
    case Repo.query(
           """
             SELECT id, agent_name, h3_cell, latitude, longitude, status
             FROM agents
             WHERE h3_cell = $1
             ORDER BY created_at DESC
             LIMIT $2
           """,
           [h3_cell, limit]
         ) do
      {:ok, %{rows: rows}} ->
        agents =
          Enum.map(rows, fn [id, name, cell, lat, lon, status] ->
            %{
              id: id,
              name: name,
              h3_cell: cell,
              latitude: lat,
              longitude: lon,
              status: status
            }
          end)

        {:ok, agents}

      error ->
        error
    end
  end

  @doc """
  Cluster all agents by H3 region.

  Returns agents grouped by their H3 cell.
  Useful for geographic distribution analysis.
  """
  def cluster_agents_by_region(resolution \\ @default_resolution) when is_integer(resolution) do
    case Repo.query("""
           SELECT
             h3_cell,
             COUNT(*) as agent_count,
             AVG(latitude) as avg_latitude,
             AVG(longitude) as avg_longitude,
             STRING_AGG(agent_name, ', ') as agent_names
           FROM agents
           WHERE h3_cell IS NOT NULL
           GROUP BY h3_cell
           ORDER BY agent_count DESC
         """) do
      {:ok, %{rows: rows}} ->
        clusters =
          Enum.map(rows, fn [cell, count, avg_lat, avg_lon, names] ->
            %{
              h3_cell: cell,
              agent_count: count,
              center_latitude: avg_lat,
              center_longitude: avg_lon,
              agent_names: String.split(names, ", ")
            }
          end)

        {:ok, clusters}

      error ->
        error
    end
  end

  @doc """
  Get H3 cell children (next resolution level).

  Useful for zooming into regions with many agents.
  """
  def get_cell_children(h3_cell, target_resolution \\ 8) when is_binary(h3_cell) do
    case Repo.query(
           """
             SELECT h3_cell_to_children($1, $2) as child_cells
           """,
           [h3_cell, target_resolution]
         ) do
      {:ok, %{rows: [[child_cells]]}} ->
        {:ok, child_cells}

      error ->
        error
    end
  end

  @doc """
  Get H3 cell parent (higher resolution level).

  Useful for zooming out to see broader regions.
  """
  def get_cell_parent(h3_cell, target_resolution \\ 5) when is_binary(h3_cell) do
    case Repo.query(
           """
             SELECT h3_cell_to_parent($1, $2) as parent_cell
           """,
           [h3_cell, target_resolution]
         ) do
      {:ok, %{rows: [[parent_cell]]}} ->
        {:ok, parent_cell}

      error ->
        error
    end
  end

  @doc """
  Get neighbors of an H3 cell (grid distance = 1).

  Returns cells directly adjacent to the given cell.
  """
  def get_cell_neighbors(h3_cell, ring_size \\ 1)
      when is_binary(h3_cell) and is_integer(ring_size) do
    case Repo.query(
           """
             SELECT h3_grid_ring($1, $2) as neighbor_cells
           """,
           [h3_cell, ring_size]
         ) do
      {:ok, %{rows: [[neighbor_cells]]}} ->
        {:ok, neighbor_cells}

      error ->
        error
    end
  end

  @doc """
  Get distance between two agents via H3.

  Returns grid distance (number of H3 steps between cells).
  Useful for routing and locality optimization.
  """
  def get_h3_distance(agent_1_id, agent_2_id)
      when is_integer(agent_1_id) and is_integer(agent_2_id) do
    case Repo.query(
           """
             SELECT
               h3_grid_distance(
                 (SELECT h3_cell FROM agents WHERE id = $1),
                 (SELECT h3_cell FROM agents WHERE id = $2)
               ) as distance
           """,
           [agent_1_id, agent_2_id]
         ) do
      {:ok, %{rows: [[distance]]}} when distance != nil ->
        {:ok, distance}

      {:ok, %{rows: [[nil]]}} ->
        {:error, :agent_location_not_set}

      error ->
        error
    end
  end

  @doc """
  Get regional statistics for H3 cells.

  Shows agent distribution and density by region.
  """
  def get_regional_stats do
    case Repo.query("""
           SELECT
             h3_cell,
             COUNT(*) as agent_count,
             (ARRAY_AGG(status))[1:5]::TEXT[] as sample_statuses,
             MAX(created_at) as newest_agent,
             MIN(created_at) as oldest_agent
           FROM agents
           WHERE h3_cell IS NOT NULL
           GROUP BY h3_cell
           ORDER BY agent_count DESC
         """) do
      {:ok, %{rows: rows}} ->
        stats =
          Enum.map(rows, fn [cell, count, statuses, newest, oldest] ->
            %{
              h3_cell: cell,
              agent_count: count,
              sample_statuses: statuses,
              newest_agent: newest,
              oldest_agent: oldest
            }
          end)

        {:ok, stats}

      error ->
        error
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp query_nearby_same_cell(h3_cell, agent_id, limit) do
    case Repo.query(
           """
             SELECT id, agent_name, h3_cell, status
             FROM agents
             WHERE h3_cell = $1 AND id != $2
             LIMIT $3
           """,
           [h3_cell, agent_id, limit]
         ) do
      {:ok, %{rows: rows}} ->
        agents =
          Enum.map(rows, fn [id, name, cell, status] ->
            %{id: id, name: name, h3_cell: cell, status: status}
          end)

        {:ok, agents}

      error ->
        error
    end
  end

  defp query_nearby_with_neighbors(h3_cell, agent_id, limit) do
    case Repo.query(
           """
             WITH neighbors AS (
               SELECT h3_grid_ring($1, 1) as neighbor_cell
             ),
             all_cells AS (
               SELECT $1::h3index as cell
               UNION ALL
               SELECT neighbor_cell FROM neighbors
             )
             SELECT id, agent_name, h3_cell, status
             FROM agents
             WHERE h3_cell = ANY(SELECT cell FROM all_cells)
               AND id != $2
             ORDER BY
               CASE WHEN h3_cell = $1 THEN 0 ELSE 1 END,
               created_at DESC
             LIMIT $3
           """,
           [h3_cell, agent_id, limit]
         ) do
      {:ok, %{rows: rows}} ->
        agents =
          Enum.map(rows, fn [id, name, cell, status] ->
            %{id: id, name: name, h3_cell: cell, status: status}
          end)

        {:ok, agents}

      error ->
        error
    end
  end
end
