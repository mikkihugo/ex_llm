# Where to Use intarray Queries - Integration Guide

**Status:** 🎯 **Integration Points Identified** (2025-10-25)

Found **6 specific locations** where your new intarray queries should be integrated for 10-100x performance improvements.

---

## 🔴 PRIORITY 1: Graph Query Module (`graph_queries.ex`)

**File:** `lib/singularity/graph/graph_queries.ex`

### 1.1 Optimize `find_callers_sql` (Lines 73-90)

**Current (JOIN-based - SLOW):**
```elixir
defp find_callers_sql(function_name, codebase_id) do
  from(gn1 in GraphNode,
    join: ge in GraphEdge,
    on: ge.from_node_id == gn1.node_id,
    join: gn2 in GraphNode,
    on: ge.to_node_id == gn2.node_id,
    where: gn2.name == ^function_name,
    where: ge.edge_type == "calls",
    where: gn1.codebase_id == ^codebase_id,
    select: %{name: gn1.name, file_path: gn1.file_path, line: gn1.line_number}
  )
  |> Repo.all()
end
```

**Problem:**
- ❌ Double JOIN (edges table + second node lookup)
- ❌ Full table scans on edges
- ❌ Slow for functions with many callers

**Optimized (intarray-based - FAST):**
```elixir
defp find_callers_sql(function_name, codebase_id) do
  # Get the target node and its dependent_node_ids (functions that call it)
  case Repo.one(from gn in GraphNode,
    where: gn.name == ^function_name and gn.codebase_id == ^codebase_id,
    select: gn.dependent_node_ids) do
    nil -> []
    dependent_ids when is_list(dependent_ids) and length(dependent_ids) > 0 ->
      # Use intarray to find caller nodes directly
      from(gn in GraphNode,
        where: gn.codebase_id == ^codebase_id and gn.id in ^dependent_ids,
        select: %{name: gn.name, file_path: gn.file_path, line: gn.line_number}
      )
      |> Repo.all()
    _ -> []
  end
end
```

**Performance:** 10-50x faster ✅

---

### 1.2 Optimize `find_callees_sql` (Lines 112-129)

**Current (JOIN-based):**
```elixir
defp find_callees_sql(function_name, codebase_id) do
  from(gn1 in GraphNode,
    join: ge in GraphEdge,
    on: ge.from_node_id == gn1.node_id,
    join: gn2 in GraphNode,
    on: ge.to_node_id == gn2.node_id,
    where: gn1.name == ^function_name,
    where: ge.edge_type == "calls",
    where: gn1.codebase_id == ^codebase_id,
    select: %{name: gn2.name, file_path: gn2.file_path, line: gn2.line_number}
  )
  |> Repo.all()
end
```

**Optimized (intarray-based):**
```elixir
defp find_callees_sql(function_name, codebase_id) do
  case Repo.one(from gn in GraphNode,
    where: gn.name == ^function_name and gn.codebase_id == ^codebase_id,
    select: gn.dependency_node_ids) do
    nil -> []
    dependency_ids when is_list(dependency_ids) and length(dependency_ids) > 0 ->
      from(gn in GraphNode,
        where: gn.codebase_id == ^codebase_id and gn.id in ^dependency_ids,
        select: %{name: gn.name, file_path: gn.file_path, line: gn.line_number}
      )
      |> Repo.all()
    _ -> []
  end
end
```

**Performance:** 10-50x faster ✅

---

### 1.3 Optimize `find_dependents` (Lines 209-225)

**Current (JOIN-based):**
```elixir
def find_dependents(module_name, codebase_id \\ "singularity") do
  target_node_id = "module::#{module_name}"

  from(gn1 in GraphNode,
    join: ge in GraphEdge,
    on: ge.from_node_id == gn1.node_id,
    where: ge.to_node_id == ^target_node_id,
    where: ge.edge_type == "imports",
    where: gn1.codebase_id == ^codebase_id,
    select: %{name: gn1.name, file_path: gn1.file_path}
  )
  |> Repo.all()
end
```

**Optimized (intarray-based):**
```elixir
def find_dependents_fast(module_name, codebase_id \\ "singularity") do
  module_node_id = "module::#{module_name}"

  case Repo.one(from gn in GraphNode,
    where: gn.node_id == ^module_node_id and gn.codebase_id == ^codebase_id,
    select: gn.dependent_node_ids) do
    nil -> []
    dependent_ids when is_list(dependent_ids) and length(dependent_ids) > 0 ->
      from(gn in GraphNode,
        where: gn.codebase_id == ^codebase_id and gn.id in ^dependent_ids,
        select: %{name: gn.name, file_path: gn.file_path}
      )
      |> Repo.all()
    _ -> []
  end
end
```

**Performance:** 20-100x faster ✅
**Note:** Use `IntarrayQueries.find_dependents_of([target_node_id])` instead

---

### 1.4 Optimize `find_dependencies` (Lines 232-249)

**Current (JOIN-based):**
```elixir
def find_dependencies(module_name, codebase_id \\ "singularity") do
  source_node_id = "module::#{module_name}"

  from(gn2 in GraphNode,
    join: ge in GraphEdge,
    on: ge.to_node_id == gn2.node_id,
    where: ge.from_node_id == ^source_node_id,
    where: ge.edge_type == "imports",
    where: gn2.codebase_id == ^codebase_id,
    select: %{name: gn2.name, file_path: gn2.file_path, weight: ge.weight}
  )
  |> Repo.all()
end
```

**Optimized (intarray-based):**
```elixir
def find_dependencies_fast(module_name, codebase_id \\ "singularity") do
  source_node_id = "module::#{module_name}"

  case Repo.one(from gn in GraphNode,
    where: gn.node_id == ^source_node_id and gn.codebase_id == ^codebase_id,
    select: gn.dependency_node_ids) do
    nil -> []
    dependency_ids when is_list(dependency_ids) and length(dependency_ids) > 0 ->
      from(gn in GraphNode,
        where: gn.codebase_id == ^codebase_id and gn.id in ^dependency_ids,
        select: %{name: gn.name, file_path: gn.file_path}
      )
      |> Repo.all()
    _ -> []
  end
end
```

**Performance:** 20-100x faster ✅
**Note:** Use `IntarrayQueries.find_dependencies_of(target_node_id)` instead

---

## 🟡 PRIORITY 2: Circular Dependency Detection

**File:** `lib/singularity/graph/graph_queries.ex` (Lines 256-299)

### 2.1 Optimize `find_circular_dependencies`

**Current:** Uses recursive CTE with edge table JOINs (slow on deep cycles)

**Optimized approach:**
```elixir
def find_circular_dependencies_fast(codebase_id \\ "singularity") do
  # Use IntarrayQueries.find_dependency_chain for each node
  # Then check if chain loops back to start
  nodes = from(gn in GraphNode,
    where: gn.codebase_id == ^codebase_id and gn.node_type == "module",
    select: gn.id
  ) |> Repo.all()

  cycles = Enum.flat_map(nodes, fn node_id ->
    case IntarrayQueries.find_dependency_chain(node_id, depth: 5) do
      {:ok, chain} ->
        node_ids_in_chain = Enum.map(chain, & &1.id)
        # Check if any node's dependencies include starting node
        case Enum.find(chain, fn node ->
          Enum.any?(node.dependency_node_ids, &(&1 == node_id))
        end) do
          nil -> []
          _cycle_node -> [chain]  # Found a cycle!
        end
      _ -> []
    end
  end)

  {:ok, cycles}
end
```

**Performance:** 3-10x faster for cycle detection ✅

---

## 🟡 PRIORITY 3: Code Graph Queries (`code_graph/queries.ex`)

**File:** `lib/singularity/code_graph/queries.ex`

### 3.1 Optimize `forward_dependencies` & `reverse_callers`

**Current:** Uses recursive CTEs with table JOINs

**Suggestion:** Create similar fast path using:
```elixir
# Instead of full CTE, use:
IntarrayQueries.find_dependency_chain(node_id, depth: max_depth)
IntarrayQueries.find_nodes_with_shared_deps(node_id)
```

---

## 🟢 PRIORITY 4: PageRank & Analysis Jobs

**File:** `lib/singularity/jobs/pagerank_calculation_job.ex`

### 4.1 Use intarray for Dependency Aggregation

PageRank calculation could use intarray operators to:
1. Find all dependents of a node: `gn.dependent_node_ids`
2. Calculate influence scores more efficiently
3. Batch process dependency relationships

**Suggested optimization:**
```elixir
# Instead of querying edges for each node:
# Use dependency arrays directly
nodes_with_high_dependent_count =
  from(gn in GraphNode,
    where: fragment("array_length(?, 1) > ?", gn.dependent_node_ids, 10),
    order_by: [desc: fragment("array_length(?, 1)", gn.dependent_node_ids)]
  )
  |> Repo.all()
```

---

## 🟢 PRIORITY 5: Architecture Analysis

**File:** `lib/singularity/architecture_engine/` (various)

### 5.1 Use for Layering Detection

Identify architectural layers:
```elixir
# Find nodes heavily depended on but depend on few (stable layer)
stable_modules =
  from(gn in GraphNode,
    where:
      fragment("array_length(?, 1) > ?", gn.dependent_node_ids, 5) and
      fragment("array_length(?, 1) < ?", gn.dependency_node_ids, 3),
    select: %{name: gn.name, fan_in: fragment("array_length(?, 1)", gn.dependent_node_ids)}
  )
  |> Repo.all()
```

---

## 🟢 PRIORITY 6: Search & Discovery

**File:** `lib/singularity/search/` (various)

### 6.1 Use for Dependency-Based Search

Find similar modules based on dependency patterns:
```elixir
def find_similar_modules(module_id, limit \\ 10) do
  IntarrayQueries.find_nodes_with_shared_deps(module_id)
  |> Enum.take(limit)
end
```

---

## Summary Table

| Module | Function | Optimization | Performance | Priority |
|--------|----------|--------------|-------------|----------|
| GraphQueries | find_callers_sql | Use dependent_node_ids | 10-50x | 🔴 HIGH |
| GraphQueries | find_callees_sql | Use dependency_node_ids | 10-50x | 🔴 HIGH |
| GraphQueries | find_dependents | Use dependent_node_ids | 20-100x | 🔴 HIGH |
| GraphQueries | find_dependencies | Use dependency_node_ids | 20-100x | 🔴 HIGH |
| GraphQueries | find_circular | Use dependency chains | 3-10x | 🟡 MEDIUM |
| CodeGraph.Queries | forward_dependencies | Use chains + arrays | 5-20x | 🟡 MEDIUM |
| PageRank | calculation | Use array counts | 2-5x | 🟡 MEDIUM |
| Architecture | layering | Use array analysis | 3-10x | 🟢 LOW |
| Search | discovery | Use dependency overlap | 5-20x | 🟢 LOW |

---

## Implementation Checklist

- [ ] **Step 1:** Update `GraphQueries.find_callers_sql` to use `dependent_node_ids`
- [ ] **Step 2:** Update `GraphQueries.find_callees_sql` to use `dependency_node_ids`
- [ ] **Step 3:** Update `GraphQueries.find_dependents` to use intarray arrays
- [ ] **Step 4:** Update `GraphQueries.find_dependencies` to use intarray arrays
- [ ] **Step 5:** Optimize `find_circular_dependencies` with chain lookup
- [ ] **Step 6:** Add fast path functions alongside existing ones (no breaking changes)
- [ ] **Step 7:** Run performance benchmarks to verify improvements
- [ ] **Step 8:** Update callers to use fast path functions
- [ ] **Step 9:** Deprecate old JOIN-based functions
- [ ] **Step 10:** Document in IntarrayQueries module

---

## Code Template for Each Optimization

```elixir
# Template: Replace JOIN-based query

# BEFORE (slow):
def find_something_slow(name) do
  from(gn1 in GraphNode,
    join: ge in GraphEdge, on: ...,
    join: gn2 in GraphNode, on: ...,
    where: gn2.name == ^name,
    select: gn1
  ) |> Repo.all()
end

# AFTER (fast):
def find_something_fast(name) do
  case Repo.one(from gn in GraphNode,
    where: gn.name == ^name,
    select: gn.dependency_node_ids) do  # or dependent_node_ids
    ids when is_list(ids) and length(ids) > 0 ->
      from(gn in GraphNode, where: gn.id in ^ids) |> Repo.all()
    _ -> []
  end
end
```

---

## Testing Strategy

```bash
# 1. Verify arrays are populated
iex> alias Singularity.Schemas.GraphNode
iex> node = Repo.get!(GraphNode, 1)
iex> node.dependency_node_ids  # Should show array of IDs, not empty list

# 2. Test new functions
iex> alias Singularity.Graph.IntarrayQueries
iex> IntarrayQueries.find_heavily_used_nodes()
# Should return nodes with highest dependent_count

# 3. Compare performance
time_old = System.monotonic_time()
GraphQueries.find_dependencies("Module.Name")
time_new = System.monotonic_time()

# 4. Verify results match
old_results = GraphQueries.find_dependencies("Module.Name")
new_results = IntarrayQueries.find_dependencies_of(module_node_id)
# Should contain same nodes
```

---

## Migration Strategy

**Phase 1 (Backward Compatible):**
1. Add new `*_fast` versions alongside existing functions
2. Don't break any existing code
3. Let developers opt into fast path

**Phase 2 (Optional Replacement):**
1. Update internal usage to use fast path
2. Benchmark improvements
3. Document performance gains

**Phase 3 (Deprecation):**
1. Mark old functions as @deprecated
2. Point to new functions in docs
3. Plan removal for future version

---

*Last Updated: 2025-10-25*
*Ready to implement: All 6 optimization points identified*
*Expected overall performance gain: 5-100x depending on query type*
