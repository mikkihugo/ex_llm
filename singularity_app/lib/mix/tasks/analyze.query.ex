defmodule Mix.Tasks.Analyze.Query do
  @moduledoc """
  Query the codebase analysis database for insights from Rust tooling analysis.

  Displays structured information about the codebase including security issues,
  module structure, licenses, outdated dependencies, and binary size analysis.

  ## Examples

      # Show all analysis results
      mix analyze.query

      # Show only security issues
      mix analyze.query security

      # Show only module structure
      mix analyze.query modules
  """

  use Mix.Task
  import Ecto.Query

  @impl Mix.Task
  def run(args) do
    # Start the application
    Mix.Task.run("app.start", [])

    filter = List.first(args)

    IO.puts("🔍 Codebase Analysis Database")
    IO.puts(String.duplicate("=", 50))

    case filter do
      "security" -> show_security_analysis()
      "modules" -> show_module_analysis()
      "licenses" -> show_license_analysis()
      "outdated" -> show_outdated_analysis()
      "binary" -> show_binary_analysis()
      _ -> show_all_analysis()
    end
  end

  defp show_all_analysis do
    show_module_analysis()
    IO.puts("")
    show_security_analysis()
    IO.puts("")
    show_license_analysis()
    IO.puts("")
    show_outdated_analysis()
    IO.puts("")
    show_binary_analysis()
  end

  defp show_module_analysis do
    IO.puts("📦 Module Structure:")

    # This assumes you have an Embeddings schema
    # Adjust according to your actual schema
    query_modules()
    |> Enum.each(fn embedding ->
      IO.puts("  • #{embedding.path} - #{embedding.label}")
    end)

    if query_modules() == [] do
      IO.puts("  No module analysis data found. Run: mix analyze.rust")
    end
  end

  defp show_security_analysis do
    IO.puts("🔒 Security Issues:")

    query_security()
    |> Enum.each(fn embedding ->
      severity = get_in(embedding.metadata, ["severity"]) || "unknown"
      IO.puts("  • #{severity}: #{embedding.label}")
    end)

    if query_security() == [] do
      IO.puts("  No security analysis data found. Run: mix analyze.rust")
    end
  end

  defp show_license_analysis do
    IO.puts("📄 License Overview:")

    # Group by license type
    license_counts =
      query_licenses()
      |> Enum.group_by(fn embedding ->
        get_in(embedding.metadata, ["license"])
      end)
      |> Enum.map(fn {license, items} ->
        {license || "unknown", length(items)}
      end)
      |> Enum.sort_by(fn {_, count} -> count end, :desc)

    license_counts
    |> Enum.each(fn {license, count} ->
      IO.puts("  • #{license}: #{count} dependencies")
    end)

    if license_counts == [] do
      IO.puts("  No license analysis data found. Run: mix analyze.rust")
    end
  end

  defp show_outdated_analysis do
    IO.puts("⏰ Outdated Dependencies:")

    query_outdated()
    |> Enum.each(fn embedding ->
      IO.puts("  • #{embedding.label}")
    end)

    if query_outdated() == [] do
      IO.puts("  No outdated dependency data found. Run: mix analyze.rust")
    end
  end

  defp show_binary_analysis do
    IO.puts("📏 Largest Binary Components:")

    query_binary()
    |> Enum.take(10)
    |> Enum.each(fn embedding ->
      size = get_in(embedding.metadata, ["size"]) || 0
      IO.puts("  • #{embedding.label}")
    end)

    if query_binary() == [] do
      IO.puts("  No binary size analysis data found. Run: mix analyze.rust")
    end
  end

  # Database query functions
  # These assume you have an Embeddings schema - adjust as needed

  defp query_modules do
    # Replace with your actual Ecto query
    # from(e in Embeddings,
    #   where: fragment("?->>'type' = ?", e.metadata, "module"),
    #   order_by: e.path
    # ) |> Repo.all()
    []
  end

  defp query_security do
    # from(e in Embeddings,
    #   where: fragment("?->>'type' = ?", e.metadata, "security"),
    #   order_by: [
    #     asc: fragment("CASE ?->>'severity' WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END", e.metadata)
    #   ]
    # ) |> Repo.all()
    []
  end

  defp query_licenses do
    # from(e in Embeddings,
    #   where: fragment("?->>'type' = ?", e.metadata, "license")
    # ) |> Repo.all()
    []
  end

  defp query_outdated do
    # from(e in Embeddings,
    #   where: fragment("?->>'type' = ?", e.metadata, "outdated"),
    #   order_by: e.path
    # ) |> Repo.all()
    []
  end

  defp query_binary do
    # from(e in Embeddings,
    #   where: fragment("?->>'type' = ?", e.metadata, "binary_size"),
    #   order_by: [desc: fragment("(?->>'size')::bigint", e.metadata)]
    # ) |> Repo.all()
    []
  end
end