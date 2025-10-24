# Singularity Orchestrator Systems - Quick Reference

## Overview Table

| System | Type | Config Key | Orchestrator | Behavior | Status | Implementations |
|--------|------|-----------|--------------|----------|--------|-----------------|
| Pattern Detection | Analysis | `:pattern_types` | PatternDetector | PatternType | ✅ | Framework, Technology, ServiceArchitecture |
| Code Analysis | Analysis | `:analyzer_types` | AnalysisOrchestrator | AnalyzerType | ✅ | Feedback, Quality, Refactoring, Microservice |
| Code Scanning | Analysis | `:scanner_types` | ScanOrchestrator | ScannerType | ✅ | Quality, Security |
| Code Generation | Generation | `:generator_types` | GenerationOrchestrator | GeneratorType | ✅ | Quality |
| Validation | Validation | `:validators` | ValidationOrchestrator | Validator | ✅ | TypeChecker, SchemaValidator, SecurityValidator |
| Search | Search | `:search_types` | SearchOrchestrator | SearchType | ✅ | Semantic, Hybrid, AST, Package |
| Job Management | Jobs | `:job_types` | JobOrchestrator | JobType | ✅ | 12 job types |
| Build Tools | Integration | `:build_tools` | BuildToolOrchestrator | BuildToolType | ✅ | Bazel, NX, Moon |
| Execution | Execution | N/A | ExecutionOrchestrator | N/A | ⚠️ | TaskDAG, SPARC, Methodology (hardcoded) |
| Execution Strategies | Execution | `:execution_strategies` | ExecutionStrategyOrchestrator | ExecutionStrategy | ✅ | TaskDag, SPARC, Methodology |
| Task Adapters | Execution | `:task_adapters` | TaskAdapterOrchestrator | TaskAdapter | ✅ | ObanAdapter, NatsAdapter, GenServerAdapter |
| Extraction | Analysis | `:extractor_types` | None | ExtractorType | ❌ | PatternExtractor (disabled) |
| Legacy Validation | Validation | `:validator_types` | None | ValidatorType | ❌ | TemplateValidator (disabled) |

## Orchestration Patterns

### Pattern 1: Parallel Execution (Run All)
Executes all enabled implementations in parallel and collects results.

```elixir
# Examples:
AnalysisOrchestrator.analyze(input)
ScanOrchestrator.scan(path)
GenerationOrchestrator.generate(spec)
SearchOrchestrator.search(query)
```

**Implementation Pattern:**
```elixir
def execute_all(input, opts) do
  enabled_items = ItemType.load_enabled_items()
  
  results = enabled_items
    |> Enum.map(fn {type, config} ->
      Task.async(fn -> run_item(type, config, input, opts) end)
    end)
    |> Enum.map(&Task.await/1)
    |> Enum.into(%{})
  
  {:ok, results}
end
```

### Pattern 2: Priority-Ordered First-Match (Stop on Success)
Tries implementations in priority order, stops on first success.

```elixir
# Examples:
BuildToolOrchestrator.run_build(path)
TaskAdapterOrchestrator.execute(task)
ExecutionStrategyOrchestrator.execute(goal)
```

**Implementation Pattern:**
```elixir
def try_implementations(input, opts) do
  items = ItemType.load_enabled_items()  # Returns sorted by priority
  
  case try_each(items, input, opts) do
    {:ok, result} -> {:ok, result}
    {:error, :no_item_found} -> {:error, :no_item_found}
    error -> error
  end
end

defp try_each([], _input, _opts), do: {:error, :no_item_found}

defp try_each([{type, _priority, config} | rest], input, opts) do
  try do
    module = config[:module]
    case module.execute(input, opts) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
      :no_match -> try_each(rest, input, opts)
    end
  rescue
    _ -> try_each(rest, input, opts)
  end
end
```

### Pattern 3: Sequential All-Run with Violations (All Must Pass)
Runs all implementations, collects violations, fails if any violations exist.

```elixir
# Examples:
ValidationOrchestrator.validate(input)
```

**Implementation Pattern:**
```elixir
def validate_all(input, opts) do
  validators = Validator.load_enabled_validators()
  
  case run_validators_recursive(validators, input, opts, []) do
    {:ok, []} -> :ok
    {:ok, violations} -> {:error, violations}
    {:error, reason} -> {:error, reason}
  end
end

defp run_validators_recursive([], _input, _opts, violations) do
  if Enum.empty?(violations) do
    {:ok, []}
  else
    {:error, violations}
  end
end

defp run_validators_recursive([{type, _priority, config} | rest], input, opts, violations) do
  module = config[:module]
  
  case module.validate(input, opts) do
    :ok -> run_validators_recursive(rest, input, opts, violations)
    {:error, new_violations} -> 
      run_validators_recursive(rest, input, opts, violations ++ new_violations)
  end
end
```

## Common Usage Examples

### Add a New Analyzer
1. Create analyzer in `lib/singularity/architecture_engine/analyzers/my_analyzer.ex`:
```elixir
defmodule Singularity.Architecture.Analyzers.MyAnalyzer do
  @behaviour Singularity.Architecture.AnalyzerType
  
  @impl true
  def analyzer_type, do: :my_analyzer
  
  @impl true
  def description, do: "Analyzes X aspect of code"
  
  @impl true
  def supported_types, do: ["issue_type_1", "issue_type_2"]
  
  @impl true
  def analyze(input, opts) do
    # Return list of analysis results
    [%{type: "issue_type_1", severity: "high", message: "..."}]
  end
  
  @impl true
  def learn_pattern(result), do: :ok
end
```

2. Add to config in `config/config.exs`:
```elixir
config :singularity, :analyzer_types,
  # ... existing analyzers ...
  my_analyzer: %{
    module: Singularity.Architecture.Analyzers.MyAnalyzer,
    enabled: true,
    description: "Analyzes X aspect of code"
  }
```

3. Use via orchestrator (no code changes needed!):
```elixir
AnalysisOrchestrator.analyze(input)
# Now automatically includes MyAnalyzer
```

### Add a New Scanner
Same pattern as analyzer, but:
1. File: `lib/singularity/code_analysis/scanners/my_scanner.ex`
2. Behavior: `@behaviour Singularity.CodeAnalysis.ScannerType`
3. Config key: `:scanner_types`
4. Orchestrator: `ScanOrchestrator.scan/2`

### Add a New Search Type
1. File: `lib/singularity/search/searchers/my_search.ex`
2. Behavior: `@behaviour Singularity.Search.SearchType`
3. Config key: `:search_types`
4. Orchestrator: `SearchOrchestrator.search/2`

### Add a New Validator
1. File: `lib/singularity/validators/my_validator.ex`
2. Behavior: `@behaviour Singularity.Validation.Validator`
3. Config key: `:validators` (note: not `:validator_types`)
4. Orchestrator: `ValidationOrchestrator.validate/2`

### Add a New Build Tool
1. File: `lib/singularity/build_tools/my_tool.ex`
2. Behavior: `@behaviour Singularity.Integration.BuildToolType`
3. Config key: `:build_tools`
4. Orchestrator: `BuildToolOrchestrator.run_build/2`

### Add a New Job Type
1. Create Oban worker in `lib/singularity/jobs/my_job.ex`:
```elixir
defmodule Singularity.Jobs.MyJob do
  use Oban.Worker, queue: :default
  
  @impl Oban.Worker
  def perform(%Job{args: args}) do
    # Do work
    :ok
  end
end
```

2. Add to config in `config/config.exs`:
```elixir
config :singularity, :job_types,
  my_job: %{
    module: Singularity.Jobs.MyJob,
    enabled: true,
    queue: :default,
    max_attempts: 2,
    description: "Description of what job does"
  }
```

3. Enqueue:
```elixir
JobOrchestrator.enqueue(:my_job, %{arg: "value"})
```

## File Organization

### Behavior Types (Define Contracts)
```
lib/singularity/
  ├── architecture_engine/
  │   ├── pattern_type.ex          # PatternType behavior
  │   ├── analyzer_type.ex         # AnalyzerType behavior
  │   ├── detectors/               # PatternType implementations
  │   │   ├── framework_detector.ex
  │   │   ├── technology_detector.ex
  │   │   └── service_architecture_detector.ex
  │   └── analyzers/               # AnalyzerType implementations
  │       ├── feedback_analyzer.ex
  │       ├── quality_analyzer.ex
  │       ├── refactoring_analyzer.ex
  │       └── microservice_analyzer.ex
  ├── code_analysis/
  │   ├── scanner_type.ex          # ScannerType behavior
  │   ├── scan_orchestrator.ex
  │   └── scanners/                # ScannerType implementations
  │       ├── quality_scanner.ex
  │       └── security_scanner.ex
  ├── code_generation/
  │   ├── generator_type.ex        # GeneratorType behavior
  │   ├── generation_orchestrator.ex
  │   └── generators/              # GeneratorType implementations
  │       └── quality_generator.ex
  ├── validation/
  │   ├── validator.ex             # Validator behavior
  │   ├── validator_type.ex        # Legacy ValidatorType behavior (disabled)
  │   ├── validation_orchestrator.ex
  │   └── validators/              # Validator implementations
  │       └── template_validator.ex
  ├── search/
  │   ├── search_type.ex           # SearchType behavior
  │   ├── search_orchestrator.ex
  │   └── searchers/               # SearchType implementations
  │       ├── semantic_search.ex
  │       ├── hybrid_search.ex
  │       ├── ast_search.ex
  │       └── package_search.ex
  ├── jobs/
  │   ├── job_type.ex              # JobType behavior
  │   ├── job_orchestrator.ex
  │   └── *.ex                     # Job implementations
  ├── integration/
  │   ├── build_tool_type.ex       # BuildToolType behavior
  │   ├── build_tool_orchestrator.ex
  │   └── (build_tools/            # BuildToolType implementations)
  │       ├── bazel_tool.ex
  │       ├── nx_tool.ex
  │       └── moon_tool.ex
  ├── execution/
  │   ├── task_adapter.ex          # TaskAdapter behavior
  │   ├── execution_strategy.ex    # ExecutionStrategy behavior
  │   ├── task_adapter_orchestrator.ex
  │   ├── execution_strategy_orchestrator.ex
  │   ├── execution_orchestrator.ex (partial - should use ExecutionStrategyOrchestrator)
  │   ├── adapters/                # TaskAdapter implementations
  │   │   ├── oban_adapter.ex
  │   │   ├── nats_adapter.ex
  │   │   └── genserver_adapter.ex
  │   └── ...
  └── analysis/
      ├── extractor_type.ex        # ExtractorType behavior (disabled)
      └── extractors/              # ExtractorType implementations
          └── pattern_extractor.ex
```

## Configuration Keys (config/config.exs)

### Lines 141-156: Pattern Detection
```elixir
config :singularity, :pattern_types,
  framework: %{...},
  technology: %{...},
  service_architecture: %{...}
```

### Lines 164-184: Code Analysis
```elixir
config :singularity, :analyzer_types,
  feedback: %{...},
  quality: %{...},
  refactoring: %{...},
  microservice: %{...}
```

### Lines 191-201: Code Scanning
```elixir
config :singularity, :scanner_types,
  quality: %{...},
  security: %{...}
```

### Lines 208-213: Code Generation
```elixir
config :singularity, :generator_types,
  quality: %{...}
```

### Lines 220-225: Legacy Validation (DISABLED)
```elixir
config :singularity, :validator_types,
  template: %{enabled: false, ...}
```

### Lines 232-237: Extraction (DISABLED)
```elixir
config :singularity, :extractor_types,
  pattern: %{enabled: false, ...}
```

### Lines 244-264: Search
```elixir
config :singularity, :search_types,
  semantic: %{...},
  hybrid: %{...},
  ast: %{...},
  package: %{...}
```

### Lines 271-384: Background Jobs
```elixir
config :singularity, :job_types,
  metrics_aggregation: %{...},
  pattern_miner: %{...},
  agent_evolution: %{...},
  # ... 9 more job types
```

### Lines 388-406: Validation (ACTIVE)
```elixir
config :singularity, :validators,
  type_checker: %{...},
  security_validator: %{...},
  schema_validator: %{...}
```

### Lines 410-428: Build Tools
```elixir
config :singularity, :build_tools,
  bazel: %{...},
  nx: %{...},
  moon: %{...}
```

### Lines 432-450: Execution Strategies
```elixir
config :singularity, :execution_strategies,
  task_dag: %{...},
  sparc: %{...},
  methodology: %{...}
```

### Lines 454-472: Task Adapters
```elixir
config :singularity, :task_adapters,
  oban_adapter: %{...},
  nats_adapter: %{...},
  genserver_adapter: %{...}
```

## Known Issues & Fixes

### Issue 1: ExecutionOrchestrator doesn't use config
**File**: `lib/singularity/execution/execution_orchestrator.ex` (lines 57-63)
**Fix**: Delegate to `ExecutionStrategyOrchestrator.execute/2` instead of hardcoding strategies

### Issue 2: Legacy ValidatorType in config
**File**: `singularity/config/config.exs` (lines 220-225)
**Fix**: Remove `:validator_types`, use `:validators` instead

### Issue 3: Orphaned ExtractorType
**File**: `singularity/config/config.exs` (lines 232-237)
**Fix**: Either implement `ExtractorOrchestrator` or remove from config

### Issue 4: Application.ex has disabled supervisors
**File**: `singularity/lib/singularity/application.ex` (lines 41-110)
**Fix**: Clean up disabled supervisors or re-enable with proper dependencies

---

*Last Updated: 2025-10-24*
*Scope: Complete Orchestrator and Behavior System Reference*
