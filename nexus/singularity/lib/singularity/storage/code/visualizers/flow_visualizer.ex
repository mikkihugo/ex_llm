defmodule Singularity.FlowVisualizer do
  @moduledoc """
  Visualize code flows using existing graph data

  Generates Mermaid diagrams from:
  - Existing graph_nodes table
  - Existing graph_edges table
  - Existing code_function_control_flow_graphs table

  NO new infrastructure needed - uses what you have!
  """

  alias Singularity.Repo

  @doc """
  Generate Mermaid flowchart from function name

  Uses existing graph tables!
  """
  def generate_mermaid_diagram(function_name, codebase_name \\ "singularity") do
    # Load from existing tables
    {:ok, cfg} = load_cfg_from_db(function_name, codebase_name)

    """
    flowchart TD
      #{render_nodes(cfg.nodes, cfg.dead_ends)}
      #{render_edges(cfg.edges)}

      %% Legend
      classDef deadEnd fill:#ff6b6b,stroke:#c92a2a
      classDef unreachable fill:#ffd43b,stroke:#fab005
      classDef normal fill:#51cf66,stroke:#2f9e44
    """
  end

  @doc """
  Generate interactive D3.js data from function

  Returns JSON for D3 force-directed graph
  """
  def generate_d3_data(function_name, codebase_name \\ "singularity") do
    {:ok, cfg} = load_cfg_from_db(function_name, codebase_name)

    %{
      nodes:
        Enum.map(cfg.nodes, fn node ->
          %{
            id: node["id"],
            label: node["label"],
            type: node["type"],
            is_dead_end: Enum.any?(cfg.dead_ends, &(&1["node_id"] == node["id"]))
          }
        end),
      edges:
        Enum.map(cfg.edges, fn edge ->
          %{
            source: edge["from"],
            target: edge["to"],
            type: edge["type"]
          }
        end)
    }
  end

  ## Private Functions

  defp load_cfg_from_db(function_name, codebase_name) do
    query = """
    SELECT cfg_nodes, cfg_edges, has_dead_ends, has_unreachable_code
    FROM code_function_control_flow_graphs
    WHERE codebase_name = $1
      AND function_name = $2
    LIMIT 1
    """

    case Repo.query(query, [codebase_name, function_name]) do
      {:ok, %{rows: [[nodes_json, edges_json, has_dead_ends, has_unreachable]]}} ->
        nodes = Jason.decode!(nodes_json)
        edges = Jason.decode!(edges_json)

        # Find dead end nodes
        dead_ends =
          if has_dead_ends do
            Enum.filter(nodes, fn node ->
              # Nodes with no outgoing edges
              outgoing = Enum.filter(edges, &(&1["from"] == node["id"]))
              Enum.empty?(outgoing) and node["type"] != "return"
            end)
          else
            []
          end

        {:ok,
         %{
           nodes: nodes,
           edges: edges,
           dead_ends: dead_ends,
           has_unreachable: has_unreachable
         }}

      {:ok, %{rows: []}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp render_nodes(nodes, dead_ends) do
    dead_end_ids = MapSet.new(dead_ends, & &1["id"])

    Enum.map_join(nodes, "\n", fn node ->
      node_id = safe_id(node["id"])
      label = node["label"] || node["name"] || node["id"]

      # Choose shape based on type
      {shape_start, shape_end} =
        case node["type"] do
          "entry" -> {"{", "}"}
          "return" -> {"([", "])"}
          "case_branch" -> {"{", "}"}
          _ -> {"[", "]"}
        end

      # Add class for styling
      class =
        cond do
          MapSet.member?(dead_end_ids, node["id"]) -> ":::deadEnd"
          node["type"] == "unreachable" -> ":::unreachable"
          true -> ":::normal"
        end

      "  #{node_id}#{shape_start}#{label}#{shape_end}#{class}"
    end)
  end

  defp render_edges(edges) do
    Enum.map_join(edges, "\n", fn edge ->
      from_id = safe_id(edge["from"])
      to_id = safe_id(edge["to"])

      # Edge style based on type
      arrow =
        cond do
          edge["is_error_path"] -> "-.->|error|"
          edge["condition"] -> "-->|#{edge["condition"]}|"
          true -> "-->"
        end

      "  #{from_id} #{arrow} #{to_id}"
    end)
  end

  defp safe_id(id) when is_binary(id) do
    # Make ID safe for Mermaid
    id
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
  end

  defp safe_id(id), do: "node_#{id}"
end
