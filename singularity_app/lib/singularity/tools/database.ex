defmodule Singularity.Tools.Database do
  @moduledoc """
  Database Tools - PostgreSQL operations for autonomous agents

  Provides safe database operations for agents to:
  - Query schema and metadata
  - Execute read-only queries
  - Check migration status
  - Analyze query performance
  - Monitor database statistics

  All operations are read-only by default, with explicit confirmation for destructive operations.
  """

  require Logger
  alias Singularity.Tools.{Tool, Catalog}

  def register(provider) do
    Catalog.add_tools(provider, [
      db_schema_tool(),
      db_query_tool(),
      db_migrations_tool(),
      db_explain_tool(),
      db_stats_tool(),
      db_indexes_tool(),
      db_connections_tool()
    ])
  end

  defp db_schema_tool do
    Tool.new!(%{
      name: "db_schema",
      description: "Show database schema information for tables, columns, and relationships",
      parameters: [
        %{
          name: "table",
          type: :string,
          required: false,
          description: "Specific table name to show schema for"
        },
        %{
          name: "include_indexes",
          type: :boolean,
          required: false,
          description: "Include index information (default: true)"
        },
        %{
          name: "include_constraints",
          type: :boolean,
          required: false,
          description: "Include constraint information (default: true)"
        }
      ],
      function: &db_schema/2
    })
  end

  defp db_query_tool do
    Tool.new!(%{
      name: "db_query",
      description: "Execute read-only SQL queries safely",
      parameters: [
        %{
          name: "sql",
          type: :string,
          required: true,
          description: "SQL query to execute (SELECT only)"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Maximum number of rows to return (default: 100)"
        },
        %{
          name: "timeout",
          type: :integer,
          required: false,
          description: "Query timeout in milliseconds (default: 5000)"
        }
      ],
      function: &db_query/2
    })
  end

  defp db_migrations_tool do
    Tool.new!(%{
      name: "db_migrations",
      description: "Show migration status and history",
      parameters: [
        %{
          name: "status",
          type: :string,
          required: false,
          description: "Filter by status: 'pending', 'ran', 'all' (default: 'all')"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Maximum number of migrations to show (default: 20)"
        }
      ],
      function: &db_migrations/2
    })
  end

  defp db_explain_tool do
    Tool.new!(%{
      name: "db_explain",
      description: "Explain query execution plan and performance",
      parameters: [
        %{name: "sql", type: :string, required: true, description: "SQL query to explain"},
        %{
          name: "format",
          type: :string,
          required: false,
          description: "Output format: 'text', 'json', 'xml' (default: 'text')"
        },
        %{
          name: "analyze",
          type: :boolean,
          required: false,
          description: "Execute query and analyze actual performance (default: false)"
        }
      ],
      function: &db_explain/2
    })
  end

  defp db_stats_tool do
    Tool.new!(%{
      name: "db_stats",
      description: "Show database statistics and performance metrics",
      parameters: [
        %{
          name: "type",
          type: :string,
          required: false,
          description: "Stats type: 'tables', 'indexes', 'connections', 'all' (default: 'all')"
        },
        %{
          name: "table",
          type: :string,
          required: false,
          description: "Specific table for table stats"
        }
      ],
      function: &db_stats/2
    })
  end

  defp db_indexes_tool do
    Tool.new!(%{
      name: "db_indexes",
      description: "Show index information and usage statistics",
      parameters: [
        %{
          name: "table",
          type: :string,
          required: false,
          description: "Specific table to show indexes for"
        },
        %{
          name: "unused",
          type: :boolean,
          required: false,
          description: "Show only unused indexes (default: false)"
        },
        %{
          name: "missing",
          type: :boolean,
          required: false,
          description: "Show potentially missing indexes (default: false)"
        }
      ],
      function: &db_indexes/2
    })
  end

  defp db_connections_tool do
    Tool.new!(%{
      name: "db_connections",
      description: "Show active database connections and their status",
      parameters: [
        %{
          name: "state",
          type: :string,
          required: false,
          description: "Filter by connection state: 'active', 'idle', 'all' (default: 'all')"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Maximum number of connections to show (default: 50)"
        }
      ],
      function: &db_connections/2
    })
  end

  # Implementation functions

  def db_schema(
        %{
          "table" => table,
          "include_indexes" => include_indexes,
          "include_constraints" => include_constraints
        },
        _ctx
      ) do
    db_schema_impl(table, include_indexes, include_constraints)
  end

  def db_schema(%{"table" => table, "include_indexes" => include_indexes}, _ctx) do
    db_schema_impl(table, include_indexes, true)
  end

  def db_schema(%{"table" => table}, _ctx) do
    db_schema_impl(table, true, true)
  end

  def db_schema(%{}, _ctx) do
    db_schema_impl(nil, true, true)
  end

  defp db_schema_impl(table, include_indexes, include_constraints) do
    try do
      # Get table information
      tables_query =
        if table do
          """
          SELECT 
            table_name,
            table_type,
            table_schema,
            table_comment
          FROM information_schema.tables 
          WHERE table_name = $1
          ORDER BY table_name
          """
        else
          """
          SELECT 
            table_name,
            table_type,
            table_schema,
            table_comment
          FROM information_schema.tables 
          WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
          ORDER BY table_name
          """
        end

      tables_params = if table, do: [table], else: []
      {:ok, tables} = execute_query(tables_query, tables_params)

      # Get columns for each table
      table_details =
        Enum.map(tables, fn table_info ->
          columns_query = """
          SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default,
            character_maximum_length,
            numeric_precision,
            numeric_scale,
            column_comment
          FROM information_schema.columns 
          WHERE table_name = $1
          ORDER BY ordinal_position
          """

          {:ok, columns} = execute_query(columns_query, [table_info["table_name"]])

          # Get indexes if requested
          indexes =
            if include_indexes do
              indexes_query = """
              SELECT 
                indexname,
                indexdef,
                indisunique,
                indisprimary
              FROM pg_indexes 
              WHERE tablename = $1
              ORDER BY indexname
              """

              case execute_query(indexes_query, [table_info["table_name"]]) do
                {:ok, idx} -> idx
                _ -> []
              end
            else
              []
            end

          # Get constraints if requested
          constraints =
            if include_constraints do
              constraints_query = """
              SELECT 
                constraint_name,
                constraint_type,
                column_name,
                foreign_table_name,
                foreign_column_name
              FROM information_schema.table_constraints tc
              LEFT JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
              LEFT JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
              WHERE tc.table_name = $1
              ORDER BY constraint_name
              """

              case execute_query(constraints_query, [table_info["table_name"]]) do
                {:ok, cons} -> cons
                _ -> []
              end
            else
              []
            end

          Map.merge(table_info, %{
            "columns" => columns,
            "indexes" => indexes,
            "constraints" => constraints,
            "column_count" => length(columns),
            "index_count" => length(indexes),
            "constraint_count" => length(constraints)
          })
        end)

      {:ok,
       %{
         table: table,
         include_indexes: include_indexes,
         include_constraints: include_constraints,
         tables: table_details,
         total_tables: length(table_details),
         total_columns: Enum.sum(Enum.map(table_details, & &1["column_count"])),
         total_indexes: Enum.sum(Enum.map(table_details, & &1["index_count"])),
         total_constraints: Enum.sum(Enum.map(table_details, & &1["constraint_count"]))
       }}
    rescue
      error -> {:error, "Database schema error: #{inspect(error)}"}
    end
  end

  def db_query(%{"sql" => sql, "limit" => limit, "timeout" => timeout}, _ctx) do
    db_query_impl(sql, limit, timeout)
  end

  def db_query(%{"sql" => sql, "limit" => limit}, _ctx) do
    db_query_impl(sql, limit, 5000)
  end

  def db_query(%{"sql" => sql, "timeout" => timeout}, _ctx) do
    db_query_impl(sql, 100, timeout)
  end

  def db_query(%{"sql" => sql}, _ctx) do
    db_query_impl(sql, 100, 5000)
  end

  defp db_query_impl(sql, limit, timeout) do
    try do
      # Validate SQL is read-only
      normalized_sql = String.downcase(String.trim(sql))

      if not String.starts_with?(normalized_sql, "select") and
           not String.starts_with?(normalized_sql, "with") and
           not String.starts_with?(normalized_sql, "explain") do
        {:error, "Only SELECT, WITH, and EXPLAIN queries are allowed"}
      else
        # Add limit if not present
        final_sql =
          if String.contains?(normalized_sql, "limit") do
            sql
          else
            "#{sql} LIMIT #{limit}"
          end

        # Execute query with timeout
        case execute_query_with_timeout(final_sql, [], timeout) do
          {:ok, results} ->
            {:ok,
             %{
               sql: sql,
               limit: limit,
               timeout: timeout,
               results: results,
               row_count: length(results),
               columns: if(length(results) > 0, do: Map.keys(hd(results)), else: [])
             }}

          {:error, reason} ->
            {:error, "Query execution failed: #{reason}"}
        end
      end
    rescue
      error -> {:error, "Database query error: #{inspect(error)}"}
    end
  end

  def db_migrations(%{"status" => status, "limit" => limit}, _ctx) do
    db_migrations_impl(status, limit)
  end

  def db_migrations(%{"status" => status}, _ctx) do
    db_migrations_impl(status, 20)
  end

  def db_migrations(%{"limit" => limit}, _ctx) do
    db_migrations_impl("all", limit)
  end

  def db_migrations(%{}, _ctx) do
    db_migrations_impl("all", 20)
  end

  defp db_migrations_impl(status, limit) do
    try do
      # Get migration status from schema_migrations table
      migrations_query = """
      SELECT 
        version,
        inserted_at,
        updated_at
      FROM schema_migrations 
      ORDER BY inserted_at DESC
      LIMIT $1
      """

      {:ok, ran_migrations} = execute_query(migrations_query, [limit])

      # Get pending migrations from filesystem
      pending_migrations = get_pending_migrations(ran_migrations)

      # Filter by status
      filtered_migrations =
        case status do
          "pending" -> pending_migrations
          "ran" -> ran_migrations
          "all" -> ran_migrations ++ pending_migrations
          _ -> ran_migrations ++ pending_migrations
        end

      {:ok,
       %{
         status: status,
         limit: limit,
         migrations: filtered_migrations,
         ran_count: length(ran_migrations),
         pending_count: length(pending_migrations),
         total_count: length(filtered_migrations)
       }}
    rescue
      error -> {:error, "Database migrations error: #{inspect(error)}"}
    end
  end

  def db_explain(%{"sql" => sql, "format" => format, "analyze" => analyze}, _ctx) do
    db_explain_impl(sql, format, analyze)
  end

  def db_explain(%{"sql" => sql, "format" => format}, _ctx) do
    db_explain_impl(sql, format, false)
  end

  def db_explain(%{"sql" => sql, "analyze" => analyze}, _ctx) do
    db_explain_impl(sql, "text", analyze)
  end

  def db_explain(%{"sql" => sql}, _ctx) do
    db_explain_impl(sql, "text", false)
  end

  defp db_explain_impl(sql, format, analyze) do
    try do
      # Build EXPLAIN query
      explain_sql =
        if analyze do
          "EXPLAIN (ANALYZE, BUFFERS, FORMAT #{String.upcase(format)}) #{sql}"
        else
          "EXPLAIN (FORMAT #{String.upcase(format)}) #{sql}"
        end

      case execute_query(explain_sql, []) do
        {:ok, results} ->
          plan_text =
            case format do
              "json" -> Jason.encode!(results)
              "xml" -> results |> Enum.map(& &1["QUERY PLAN"]) |> Enum.join("\n")
              _ -> results |> Enum.map(& &1["QUERY PLAN"]) |> Enum.join("\n")
            end

          {:ok,
           %{
             sql: sql,
             format: format,
             analyze: analyze,
             plan: plan_text,
             execution_time: extract_execution_time(plan_text),
             cost_estimate: extract_cost_estimate(plan_text)
           }}

        {:error, reason} ->
          {:error, "EXPLAIN query failed: #{reason}"}
      end
    rescue
      error -> {:error, "Database explain error: #{inspect(error)}"}
    end
  end

  def db_stats(%{"type" => type, "table" => table}, _ctx) do
    db_stats_impl(type, table)
  end

  def db_stats(%{"type" => type}, _ctx) do
    db_stats_impl(type, nil)
  end

  def db_stats(%{"table" => table}, _ctx) do
    db_stats_impl("tables", table)
  end

  def db_stats(%{}, _ctx) do
    db_stats_impl("all", nil)
  end

  defp db_stats_impl(type, table) do
    try do
      stats = %{}

      stats =
        if type == "all" or type == "tables" do
          table_stats = get_table_stats(table)
          Map.put(stats, :tables, table_stats)
        else
          stats
        end

      stats =
        if type == "all" or type == "indexes" do
          index_stats = get_index_stats(table)
          Map.put(stats, :indexes, index_stats)
        else
          stats
        end

      stats =
        if type == "all" or type == "connections" do
          connection_stats = get_connection_stats()
          Map.put(stats, :connections, connection_stats)
        else
          stats
        end

      {:ok,
       %{
         type: type,
         table: table,
         stats: stats,
         generated_at: DateTime.utc_now()
       }}
    rescue
      error -> {:error, "Database stats error: #{inspect(error)}"}
    end
  end

  def db_indexes(%{"table" => table, "unused" => unused, "missing" => missing}, _ctx) do
    db_indexes_impl(table, unused, missing)
  end

  def db_indexes(%{"table" => table, "unused" => unused}, _ctx) do
    db_indexes_impl(table, unused, false)
  end

  def db_indexes(%{"table" => table, "missing" => missing}, _ctx) do
    db_indexes_impl(table, false, missing)
  end

  def db_indexes(%{"table" => table}, _ctx) do
    db_indexes_impl(table, false, false)
  end

  def db_indexes(%{"unused" => unused}, _ctx) do
    db_indexes_impl(nil, unused, false)
  end

  def db_indexes(%{"missing" => missing}, _ctx) do
    db_indexes_impl(nil, false, missing)
  end

  def db_indexes(%{}, _ctx) do
    db_indexes_impl(nil, false, false)
  end

  defp db_indexes_impl(table, unused, missing) do
    try do
      indexes =
        if unused do
          get_unused_indexes(table)
        else
          get_all_indexes(table)
        end

      missing_indexes =
        if missing do
          get_missing_indexes()
        else
          []
        end

      {:ok,
       %{
         table: table,
         unused: unused,
         missing: missing,
         indexes: indexes,
         missing_indexes: missing_indexes,
         index_count: length(indexes),
         missing_count: length(missing_indexes)
       }}
    rescue
      error -> {:error, "Database indexes error: #{inspect(error)}"}
    end
  end

  def db_connections(%{"state" => state, "limit" => limit}, _ctx) do
    db_connections_impl(state, limit)
  end

  def db_connections(%{"state" => state}, _ctx) do
    db_connections_impl(state, 50)
  end

  def db_connections(%{"limit" => limit}, _ctx) do
    db_connections_impl("all", limit)
  end

  def db_connections(%{}, _ctx) do
    db_connections_impl("all", 50)
  end

  defp db_connections_impl(state, limit) do
    try do
      connections_query = """
      SELECT 
        pid,
        usename,
        application_name,
        client_addr,
        client_port,
        backend_start,
        state,
        query_start,
        query,
        state_change
      FROM pg_stat_activity 
      WHERE state != 'idle'
      ORDER BY backend_start DESC
      LIMIT $1
      """

      {:ok, connections} = execute_query(connections_query, [limit])

      # Filter by state if specified
      filtered_connections =
        case state do
          "active" -> Enum.filter(connections, &(&1["state"] == "active"))
          "idle" -> Enum.filter(connections, &(&1["state"] == "idle"))
          _ -> connections
        end

      {:ok,
       %{
         state: state,
         limit: limit,
         connections: filtered_connections,
         total_connections: length(filtered_connections),
         active_connections: Enum.count(filtered_connections, &(&1["state"] == "active")),
         idle_connections: Enum.count(filtered_connections, &(&1["state"] == "idle"))
       }}
    rescue
      error -> {:error, "Database connections error: #{inspect(error)}"}
    end
  end

  # Helper functions

  defp execute_query(sql, params) do
    case Singularity.Repo.query(sql, params) do
      {:ok, %{rows: rows, columns: columns}} ->
        results =
          Enum.map(rows, fn row ->
            Enum.zip(columns, row) |> Enum.into(%{})
          end)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_query_with_timeout(sql, params, timeout) do
    Task.async(fn -> execute_query(sql, params) end)
    |> Task.await(timeout)
  rescue
    :timeout -> {:error, "Query timeout after #{timeout}ms"}
  end

  defp get_pending_migrations(ran_migrations) do
    # Get migration files from filesystem
    migrations_dir = Path.join([File.cwd!(), "priv", "repo", "migrations"])

    case File.exists?(migrations_dir) do
      true ->
        # Read migration files
        migration_files =
          migrations_dir
          |> Path.join("*.exs")
          |> Path.wildcard()
          |> Enum.map(&Path.basename/1)
          |> Enum.sort()

        # Filter out already ran migrations
        ran_migration_names = Enum.map(ran_migrations, & &1.version)

        pending_migrations =
          migration_files
          |> Enum.reject(fn filename ->
            # Extract version from filename (e.g., "20240101000001_create_users.exs")
            case Regex.run(~r/^(\d{14})_/, filename) do
              [_, version] -> version in ran_migration_names
              _ -> false
            end
          end)
          |> Enum.map(fn filename ->
            %{
              filename: filename,
              status: "pending",
              version: extract_version_from_filename(filename)
            }
          end)

        Logger.debug("Found pending migrations",
          total_files: length(migration_files),
          ran_count: length(ran_migrations),
          pending_count: length(pending_migrations)
        )

        pending_migrations

      false ->
        Logger.warning("Migrations directory not found", path: migrations_dir)
        []
    end
  end

  defp extract_version_from_filename(filename) do
    case Regex.run(~r/^(\d{14})_/, filename) do
      [_, version] -> version
      _ -> "unknown"
    end
  end

  defp get_table_stats(table) do
    query =
      if table do
        """
        SELECT 
          schemaname,
          tablename,
          n_tup_ins as inserts,
          n_tup_upd as updates,
          n_tup_del as deletes,
          n_live_tup as live_tuples,
          n_dead_tup as dead_tuples,
          last_vacuum,
          last_autovacuum,
          last_analyze,
          last_autoanalyze
        FROM pg_stat_user_tables 
        WHERE tablename = $1
        """
      else
        """
        SELECT 
          schemaname,
          tablename,
          n_tup_ins as inserts,
          n_tup_upd as updates,
          n_tup_del as deletes,
          n_live_tup as live_tuples,
          n_dead_tup as dead_tuples,
          last_vacuum,
          last_autovacuum,
          last_analyze,
          last_autoanalyze
        FROM pg_stat_user_tables 
        ORDER BY n_live_tup DESC
        """
      end

    params = if table, do: [table], else: []

    case execute_query(query, params) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_index_stats(table) do
    query =
      if table do
        """
        SELECT 
          schemaname,
          tablename,
          indexname,
          idx_tup_read,
          idx_tup_fetch,
          idx_scan
        FROM pg_stat_user_indexes 
        WHERE tablename = $1
        ORDER BY idx_scan DESC
        """
      else
        """
        SELECT 
          schemaname,
          tablename,
          indexname,
          idx_tup_read,
          idx_tup_fetch,
          idx_scan
        FROM pg_stat_user_indexes 
        ORDER BY idx_scan DESC
        """
      end

    params = if table, do: [table], else: []

    case execute_query(query, params) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_connection_stats do
    query = """
    SELECT 
      count(*) as total_connections,
      count(*) FILTER (WHERE state = 'active') as active_connections,
      count(*) FILTER (WHERE state = 'idle') as idle_connections,
      count(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction
    FROM pg_stat_activity
    """

    case execute_query(query, []) do
      {:ok, [result]} -> result
      _ -> %{}
    end
  end

  defp get_all_indexes(table) do
    query =
      if table do
        """
        SELECT 
          schemaname,
          tablename,
          indexname,
          indexdef,
          idx_scan,
          idx_tup_read,
          idx_tup_fetch
        FROM pg_stat_user_indexes 
        WHERE tablename = $1
        ORDER BY idx_scan DESC
        """
      else
        """
        SELECT 
          schemaname,
          tablename,
          indexname,
          indexdef,
          idx_scan,
          idx_tup_read,
          idx_tup_fetch
        FROM pg_stat_user_indexes 
        ORDER BY idx_scan DESC
        """
      end

    params = if table, do: [table], else: []

    case execute_query(query, params) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_unused_indexes(table) do
    query =
      if table do
        """
        SELECT 
          schemaname,
          tablename,
          indexname,
          indexdef,
          idx_scan,
          idx_tup_read,
          idx_tup_fetch
        FROM pg_stat_user_indexes 
        WHERE tablename = $1 AND idx_scan = 0
        ORDER BY tablename, indexname
        """
      else
        """
        SELECT 
          schemaname,
          tablename,
          indexname,
          indexdef,
          idx_scan,
          idx_tup_read,
          idx_tup_fetch
        FROM pg_stat_user_indexes 
        WHERE idx_scan = 0
        ORDER BY tablename, indexname
        """
      end

    params = if table, do: [table], else: []

    case execute_query(query, params) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp get_missing_indexes do
    # This is a simplified version - in practice, you'd analyze query patterns
    # to suggest missing indexes based on WHERE clauses, JOIN conditions, etc.
    query = """
    SELECT 
      schemaname,
      tablename,
      attname as column_name,
      n_distinct,
      correlation
    FROM pg_stats 
    WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
    AND n_distinct > 100
    ORDER BY n_distinct DESC
    LIMIT 20
    """

    case execute_query(query, []) do
      {:ok, results} -> results
      _ -> []
    end
  end

  defp extract_execution_time(plan_text) do
    case Regex.run(~r/Execution Time: ([\d.]+) ms/, plan_text) do
      [_, time] -> String.to_float(time)
      _ -> nil
    end
  end

  defp extract_cost_estimate(plan_text) do
    case Regex.run(~r/cost=([\d.]+)\.\.([\d.]+)/, plan_text) do
      [_, start_cost, end_cost] ->
        %{start: String.to_float(start_cost), total: String.to_float(end_cost)}

      _ ->
        nil
    end
  end
end
