defmodule Singularity.Graph.AgeQueries do
  @moduledoc """
  Apache AGE Cypher Query Helpers - Graph queries using Cypher syntax.

  Provides simple, declarative graph queries using Apache AGE's Cypher support.
  Requires AGE extension to be enabled (run `mix ecto.migrate` after adding AGE).

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "Singularity.Graph.AgeQueries",
    "purpose": "Cypher query helpers for Apache AGE graph database",
    "type": "Query service (AGE-specific)",
    "operates_on": "AGE graph 'singularity_code'",
    "storage": "PostgreSQL with AGE extension",
    "dependencies": ["Repo", "Apache AGE extension"]
  }
  ```

  ## Architecture (Mermaid)

  ```mermaid
  graph TD
      A[AgeQueries] -->|Cypher queries| B[Apache AGE]
      B -->|Graph ops| C[(PostgreSQL)]
      A -->|Fallback| D[GraphQueries]
      D -->|SQL queries| C
  ```

  ## Call Graph (YAML)

  ```yaml
  AgeQueries:
    calls:
      - Repo.query/1  # Execute Cypher queries via AGE
    called_by:
      - Controllers/Services  # When Cypher syntax is preferred
    alternative:
      - GraphQueries  # SQL-based queries (no AGE required)
  ```

  ## Anti-Patterns

  **DO NOT create these duplicates:**
  - ❌ `CypherQueries` - This IS the Cypher query module
  - ❌ `Neo4jQueries` - AGE uses Cypher but it's PostgreSQL, not Neo4j

  **Use this module when:**
  - ✅ AGE extension is enabled
  - ✅ Need graph algorithms (shortest path, etc.)
  - ✅ Prefer Cypher syntax over SQL

  **Use GraphQueries when:**
  - ✅ AGE not installed (SQL-only)
  - ✅ Simple queries (no graph algorithms)

  ## Search Keywords

  cypher, apache-age, graph-database, neo4j-syntax, pattern-matching,
  graph-algorithms, shortest-path, circular-dependencies, call-graph,
  import-graph, postgresql-graph-extension

  ## Benefits Over SQL (GraphQueries)

  **Find callers:**

  SQL (GraphQueries):
  ```sql
  SELECT gn1.name, gn1.file_path
  FROM graph_nodes gn1
  JOIN graph_edges ge ON ge.from_node_id = gn1.node_id
  JOIN graph_nodes gn2 ON ge.to_node_id = gn2.node_id
  WHERE gn2.name = 'my_function/2'
    AND ge.edge_type = 'calls';
  ```

  Cypher (AgeQueries):
  ```cypher
  MATCH (caller:Function)-[:CALLS]->(callee:Function {name: 'my_function/2'})
  RETURN caller.name, caller.file_path
  ```

  **Find circular dependencies:**

  SQL (GraphQueries - complex recursive CTE):
  ```sql
  WITH RECURSIVE dep_path AS (
    SELECT node_id as start_node, node_id as current_node,
           ARRAY[name] as path, 0 as depth
    FROM graph_nodes WHERE node_type = 'module'

    UNION ALL

    SELECT dp.start_node, gn.node_id, dp.path || gn.name, dp.depth + 1
    FROM dep_path dp
    JOIN graph_edges ge ON ge.from_node_id = dp.current_node
    JOIN graph_nodes gn ON ge.to_node_id = gn.node_id
    WHERE dp.depth < 10 AND NOT (gn.name = ANY(dp.path))
  )
  SELECT path FROM dep_path WHERE current_node = start_node AND depth > 0;
  ```

  Cypher (AgeQueries - elegant!):
  ```cypher
  MATCH path = (a:Module)-[:IMPORTS*]->(a)
  RETURN [node IN nodes(path) | node.name]
  ```
  """

  alias Singularity.Repo
  require Logger

  @doc """
  Find all functions that call the given function using Cypher.

  ## Examples

      iex> AgeQueries.find_callers_cypher("persist_module_to_db/2")
      {:ok, [
        %{name: "persist_learned_codebase/1", file_path: "lib/.../startup_code_ingestion.ex", line: 486}
      ]}

  ## Cypher Query

  ```cypher
  MATCH (caller:Function)-[:CALLS]->(callee:Function {name: 'my_function/2'})
  RETURN caller.name, caller.file_path, caller.line
  ```
  """
  def find_callers_cypher(function_name) do
    query = """
    SELECT * FROM ag_catalog.cypher('singularity_code', $$
      MATCH (caller:Function)-[:CALLS]->(callee:Function {name: '#{escape_cypher(function_name)}'})
      RETURN caller.name, caller.file_path, caller.line
    $$) as (name ag_catalog.agtype, file_path ag_catalog.agtype, line ag_catalog.agtype);
    """

    case Repo.query(query) do
      {:ok, result} ->
        callers =
          Enum.map(result.rows, fn [name, file_path, line] ->
            %{
              name: parse_agtype(name),
              file_path: parse_agtype(file_path),
              line: parse_agtype(line)
            }
          end)

        {:ok, callers}

      {:error, %Postgrex.Error{postgres: %{code: :undefined_file}}} ->
        {:error,
         "AGE extension not installed. Run 'mix ecto.migrate' or use GraphQueries (SQL) instead."}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Find all functions that the given function calls using Cypher.

  ## Examples

      iex> AgeQueries.find_callees_cypher("main/0")
      {:ok, [
        %{name: "Repo.insert/2", file_path: "lib/singularity/repo.ex", line: 10}
      ]}

  ## Cypher Query

  ```cypher
  MATCH (caller:Function {name: 'main/0'})-[:CALLS]->(callee:Function)
  RETURN callee.name, callee.file_path, callee.line
  ```
  """
  def find_callees_cypher(function_name) do
    query = """
    SELECT * FROM ag_catalog.cypher('singularity_code', $$
      MATCH (caller:Function {name: '#{escape_cypher(function_name)}'})-[:CALLS]->(callee:Function)
      RETURN callee.name, callee.file_path, callee.line
    $$) as (name ag_catalog.agtype, file_path ag_catalog.agtype, line ag_catalog.agtype);
    """

    case Repo.query(query) do
      {:ok, result} ->
        callees =
          Enum.map(result.rows, fn [name, file_path, line] ->
            %{
              name: parse_agtype(name),
              file_path: parse_agtype(file_path),
              line: parse_agtype(line)
            }
          end)

        {:ok, callees}

      {:error, %Postgrex.Error{postgres: %{code: :undefined_file}}} ->
        {:error,
         "AGE extension not installed. Run 'mix ecto.migrate' or use GraphQueries (SQL) instead."}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Find circular dependencies (import cycles) using Cypher.

  Returns list of cycles where each cycle is a list of module names.

  ## Examples

      iex> AgeQueries.find_circular_dependencies_cypher()
      {:ok, [
        ["ModuleA", "ModuleB", "ModuleC", "ModuleA"]
      ]}

  ## Cypher Query

  ```cypher
  MATCH path = (a:Module)-[:IMPORTS*]->(a)
  RETURN [node IN nodes(path) | node.name]
  ```
  """
  def find_circular_dependencies_cypher do
    query = """
    SELECT * FROM ag_catalog.cypher('singularity_code', $$
      MATCH path = (a:Module)-[:IMPORTS*]->(a)
      RETURN [node IN nodes(path) | node.name] as cycle
    $$) as (cycle ag_catalog.agtype);
    """

    case Repo.query(query) do
      {:ok, result} ->
        cycles = Enum.map(result.rows, fn [cycle] -> parse_agtype(cycle) end)
        {:ok, cycles}

      {:error, %Postgrex.Error{postgres: %{code: :undefined_file}}} ->
        {:error,
         "AGE extension not installed. Run 'mix ecto.migrate' or use GraphQueries (SQL) instead."}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Find shortest path between two functions using Cypher.

  Returns path as list of function names and hop count.

  ## Examples

      iex> AgeQueries.shortest_path_cypher("main/0", "persist_module_to_db/2")
      {:ok, %{
        path: ["main/0", "run/1", "persist_learned_codebase/1", "persist_module_to_db/2"],
        hops: 3
      }}

      iex> AgeQueries.shortest_path_cypher("main/0", "nonexistent/0")
      {:ok, nil}  # No path found

  ## Cypher Query

  ```cypher
  MATCH path = shortestPath((a:Function {name: 'main/0'})-[:CALLS*]->(b:Function {name: 'target/2'}))
  RETURN [node IN nodes(path) | node.name], length(path)
  ```
  """
  def shortest_path_cypher(from_func, to_func) do
    query = """
    SELECT * FROM ag_catalog.cypher('singularity_code', $$
      MATCH path = shortestPath((a:Function {name: '#{escape_cypher(from_func)}'})-[:CALLS*]->(b:Function {name: '#{escape_cypher(to_func)}'}))
      RETURN [node IN nodes(path) | node.name] as path, length(path) as hops
    $$) as (path ag_catalog.agtype, hops ag_catalog.agtype);
    """

    case Repo.query(query) do
      {:ok, result} ->
        case result.rows do
          [[path, hops] | _] ->
            {:ok, %{path: parse_agtype(path), hops: parse_agtype(hops)}}

          [] ->
            {:ok, nil}
        end

      {:error, %Postgrex.Error{postgres: %{code: :undefined_file}}} ->
        {:error,
         "AGE extension not installed. Run 'mix ecto.migrate' or use GraphQueries (SQL) instead."}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Find all modules that depend on the given module using Cypher.

  ## Examples

      iex> AgeQueries.find_module_dependencies_cypher("Singularity.SystemStatusMonitor")
      {:ok, [
        %{name: "Singularity.Runner", dependency_type: "internal"},
        %{name: "Ecto.Query", dependency_type: "external"}
      ]}

  ## Cypher Query

  ```cypher
  MATCH (module:Module {name: 'Singularity.SystemStatusMonitor'})-[:IMPORTS]->(dep:Module)
  RETURN dep.name, dep.dependency_type
  ```
  """
  def find_module_dependencies_cypher(module_name) do
    query = """
    SELECT * FROM ag_catalog.cypher('singularity_code', $$
      MATCH (module:Module {name: '#{escape_cypher(module_name)}'})-[:IMPORTS]->(dep:Module)
      RETURN dep.name, dep.dependency_type
    $$) as (name ag_catalog.agtype, dependency_type ag_catalog.agtype);
    """

    case Repo.query(query) do
      {:ok, result} ->
        deps =
          Enum.map(result.rows, fn [name, dependency_type] ->
            %{
              name: parse_agtype(name),
              dependency_type: parse_agtype(dependency_type)
            }
          end)

        {:ok, deps}

      {:error, %Postgrex.Error{postgres: %{code: :undefined_file}}} ->
        {:error,
         "AGE extension not installed. Run 'mix ecto.migrate' or use GraphQueries (SQL) instead."}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Find all call chains from start function to end function using Cypher.

  Returns all possible paths (not just shortest).

  ## Examples

      iex> AgeQueries.find_all_paths_cypher("main/0", "persist_module_to_db/2", max_hops: 5)
      {:ok, [
        %{path: ["main/0", "run/1", "persist_module_to_db/2"], hops: 2},
        %{path: ["main/0", "run/1", "persist_learned_codebase/1", "persist_module_to_db/2"], hops: 3}
      ]}

  ## Cypher Query

  ```cypher
  MATCH path = (a:Function {name: 'main/0'})-[:CALLS*1..5]->(b:Function {name: 'target/2'})
  RETURN [node IN nodes(path) | node.name], length(path)
  ```
  """
  def find_all_paths_cypher(from_func, to_func, _opts \\ []) do
    max_hops = Keyword.get(_opts, :max_hops, 5)

    query = """
    SELECT * FROM ag_catalog.cypher('singularity_code', $$
      MATCH path = (a:Function {name: '#{escape_cypher(from_func)}'})-[:CALLS*1..#{max_hops}]->(b:Function {name: '#{escape_cypher(to_func)}'})
      RETURN [node IN nodes(path) | node.name] as path, length(path) as hops
    $$) as (path ag_catalog.agtype, hops ag_catalog.agtype);
    """

    case Repo.query(query) do
      {:ok, result} ->
        paths =
          Enum.map(result.rows, fn [path, hops] ->
            %{path: parse_agtype(path), hops: parse_agtype(hops)}
          end)

        {:ok, paths}

      {:error, %Postgrex.Error{postgres: %{code: :undefined_file}}} ->
        {:error,
         "AGE extension not installed. Run 'mix ecto.migrate' or use GraphQueries (SQL) instead."}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Find most called functions using Cypher.

  Returns functions with highest in-degree (most callers).

  ## Examples

      iex> AgeQueries.most_called_functions_cypher(5)
      {:ok, [
        %{name: "Repo.insert/2", caller_count: 45},
        %{name: "Logger.info/1", caller_count: 38}
      ]}

  ## Cypher Query

  ```cypher
  MATCH (caller:Function)-[:CALLS]->(callee:Function)
  RETURN callee.name, count(caller) as caller_count
  ORDER BY caller_count DESC
  LIMIT 5
  ```
  """
  def most_called_functions_cypher(limit \\ 10) do
    query = """
    SELECT * FROM ag_catalog.cypher('singularity_code', $$
      MATCH (caller:Function)-[:CALLS]->(callee:Function)
      RETURN callee.name, count(caller) as caller_count
      ORDER BY caller_count DESC
      LIMIT #{limit}
    $$) as (name ag_catalog.agtype, caller_count ag_catalog.agtype);
    """

    case Repo.query(query) do
      {:ok, result} ->
        functions =
          Enum.map(result.rows, fn [name, caller_count] ->
            %{
              name: parse_agtype(name),
              caller_count: parse_agtype(caller_count)
            }
          end)

        {:ok, functions}

      {:error, %Postgrex.Error{postgres: %{code: :undefined_file}}} ->
        {:error,
         "AGE extension not installed. Run 'mix ecto.migrate' or use GraphQueries (SQL) instead."}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ------------------------------------------------------------------------------
  # Private Functions
  # ------------------------------------------------------------------------------

  # Parse AGE agtype format to Elixir terms.
  # AGE returns JSON-like strings that need to be decoded.
  defp parse_agtype(agtype_string) when is_binary(agtype_string) do
    case Jason.decode(agtype_string) do
      {:ok, parsed} -> parsed
      {:error, _} -> agtype_string
    end
  end

  defp parse_agtype(value), do: value

  # Escape single quotes in Cypher queries to prevent injection.
  defp escape_cypher(string) when is_binary(string) do
    String.replace(string, "'", "\\'")
  end
end
