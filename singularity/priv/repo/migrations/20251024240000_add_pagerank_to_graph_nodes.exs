defmodule Singularity.Repo.Migrations.AddPageRankToGraphNodes do
  use Ecto.Migration

  @moduledoc """
  Add PageRank scoring to graph_nodes table.

  PageRank identifies the most important/central nodes in the call graph.
  Used to answer: "Which modules are most frequently called?"

  ## Implementation

  Stores PageRank scores calculated by CodeSearch.Ecto.calculate_pagerank/2
  Includes index for efficient queries by importance.

  ## Usage

  ```elixir
  # Calculate PageRank scores
  scores = CodeSearch.Ecto.calculate_pagerank(20, 0.85)
  # => [%{node_id: "node1", pagerank_score: 3.14}, ...]

  # Store in database
  Enum.each(scores, fn %{node_id: id, pagerank_score: score} ->
    Repo.update_all(from(n in GraphNode, where: n.node_id == ^id),
      set: [pagerank_score: score])
  end)

  # Query most central modules
  from(n in GraphNode, where: n.pagerank_score > 5.0, order_by: [desc: :pagerank_score])
  ```

  ## Query Examples

  ```sql
  -- Find most important modules (top 10)
  SELECT name, file_path, pagerank_score
  FROM graph_nodes
  WHERE pagerank_score IS NOT NULL
  ORDER BY pagerank_score DESC
  LIMIT 10;

  -- Find nodes by importance tier
  SELECT name, pagerank_score,
    CASE
      WHEN pagerank_score > 5.0 THEN 'CRITICAL'
      WHEN pagerank_score > 2.0 THEN 'IMPORTANT'
      WHEN pagerank_score > 0.5 THEN 'MODERATE'
      ELSE 'LOW'
    END as importance
  FROM graph_nodes
  ORDER BY pagerank_score DESC;

  -- Average PageRank by module type
  SELECT node_type, AVG(pagerank_score) as avg_score, COUNT(*) as count
  FROM graph_nodes
  GROUP BY node_type
  ORDER BY avg_score DESC;
  ```
  """

  def up do
    # Add pagerank_score column if it doesn't exist
    alter table(:graph_nodes) do
      add :pagerank_score, :float, default: 0.0
    end

    # Create index for efficient queries by PageRank
    create index(:graph_nodes, [:pagerank_score], name: :graph_nodes_pagerank_idx)

    # Create index for composite queries (codebase + pagerank)
    create index(:graph_nodes, [:codebase_id, :pagerank_score],
      name: :graph_nodes_codebase_pagerank_idx
    )

    IO.puts("✅ Added pagerank_score column to graph_nodes")
    IO.puts("   • pagerank_score (float, default: 0.0)")
    IO.puts("   • Index: graph_nodes_pagerank_idx")
    IO.puts("   • Composite index: graph_nodes_codebase_pagerank_idx")
    IO.puts("")
    IO.puts("Next: Run PageRankCalculationJob to populate scores")
    IO.puts("  Singularity.Jobs.JobOrchestrator.enqueue(:pagerank_calculation, %{})")
  end

  def down do
    # Drop indexes
    drop_if_exists index(:graph_nodes, [:codebase_id, :pagerank_score],
      name: :graph_nodes_codebase_pagerank_idx
    )
    drop_if_exists index(:graph_nodes, [:pagerank_score], name: :graph_nodes_pagerank_idx)

    # Remove column
    alter table(:graph_nodes) do
      remove :pagerank_score
    end

    IO.puts("Reverted pagerank_score column")
  end
end
