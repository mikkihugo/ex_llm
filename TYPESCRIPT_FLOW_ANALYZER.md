# TypeScript Flow Analyzer via Codex SDK

You **already have** TypeScript + NATS integration! Let's use it for flow analysis.

## Current Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ Elixir (singularity_app)                                     │
│  ├─ Agents                                                   │
│  ├─ NATS client                                              │
│  └─ Phoenix web                                              │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 │ NATS messaging (already connected!)
                 │
┌────────────────▼─────────────────────────────────────────────┐
│ TypeScript (ai-server via Bun)                               │
│  ├─ NATS handler                                             │
│  ├─ AI SDK providers (Claude, Gemini, Codex)                 │
│  └─ ElixirBridge (already exists!)                           │
└──────────────────────────────────────────────────────────────┘
```

## Add Flow Analysis to TypeScript Side

### 1. Install Flow Analysis Dependencies

```bash
cd ai-server

# Tree-sitter for AST parsing (like your Rust parser)
bun add @tree-sitter/tree-sitter
bun add tree-sitter-elixir
bun add tree-sitter-rust
bun add tree-sitter-typescript

# Codex for AI-powered analysis
# (Already have: "@openai/codex-sdk": "^0.45.0")

# Graph libraries
bun add graphology  # Graph data structure
bun add graphology-traversal  # BFS/DFS
```

### 2. Create Flow Analyzer Service

```typescript
// ai-server/src/flow-analyzer.ts

import Parser from '@tree-sitter/tree-sitter';
import Elixir from 'tree-sitter-elixir';
import { Graph } from 'graphology';
import { bfs } from 'graphology-traversal';
import { codex } from './codex-client'; // Your existing Codex client

export interface FlowNode {
  id: string;
  type: 'entry' | 'function_call' | 'case_branch' | 'return' | 'dead_end';
  label: string;
  line: number;
  mayRaise?: boolean;
}

export interface FlowEdge {
  from: string;
  to: string;
  condition?: string;
  isErrorPath?: boolean;
}

export interface ControlFlowGraph {
  nodes: FlowNode[];
  edges: FlowEdge[];
  issues: FlowIssue[];
  completeness: number;
}

export interface FlowIssue {
  type: 'dead_end' | 'unreachable_code' | 'incomplete_pattern' | 'missing_error_handling';
  severity: 'critical' | 'high' | 'medium' | 'low';
  line: number;
  description: string;
  recommendation: string;
  suggestedFix?: string;
}

export class FlowAnalyzer {
  private parser: Parser;

  constructor() {
    this.parser = new Parser();
    this.parser.setLanguage(Elixir);
  }

  /**
   * Analyze a file and build control flow graph
   */
  async analyzeFile(filePath: string, sourceCode: string): Promise<ControlFlowGraph> {
    console.log(`Analyzing flow for ${filePath}`);

    // 1. Parse code to AST
    const tree = this.parser.parse(sourceCode);

    // 2. Extract functions
    const functions = this.extractFunctions(tree.rootNode, sourceCode);

    // 3. Build CFG for each function
    const cfgs = functions.map(func => this.buildCFG(func, sourceCode));

    // 4. Detect issues
    const allIssues: FlowIssue[] = [];
    for (const cfg of cfgs) {
      const issues = this.detectIssues(cfg);
      allIssues.push(...issues);
    }

    // 5. Combine all function CFGs
    const combinedCFG = this.combineCFGs(cfgs);

    // 6. Calculate completeness
    const completeness = this.calculateCompleteness(combinedCFG);

    return {
      nodes: combinedCFG.nodes,
      edges: combinedCFG.edges,
      issues: allIssues,
      completeness,
    };
  }

  /**
   * Use Codex to suggest fixes for issues
   */
  async suggestFix(issue: FlowIssue, sourceCode: string): Promise<string> {
    const prompt = `
Fix this Elixir code issue:

**Issue**: ${issue.description}
**Type**: ${issue.type}
**Recommendation**: ${issue.recommendation}

**Current Code**:
\`\`\`elixir
${this.extractCodeSnippet(sourceCode, issue.line)}
\`\`\`

Generate ONLY the fixed code for the function. Add proper error handling.
`;

    const response = await codex.chat({
      messages: [{ role: 'user', content: prompt }],
      model: 'gpt-4-turbo-preview',
      temperature: 0.1,
    });

    return response.choices[0].message.content;
  }

  private buildCFG(func: FunctionNode, sourceCode: string): Graph {
    const cfg = new Graph({ type: 'directed' });

    // Entry node
    const entryId = `entry_${func.name}`;
    cfg.addNode(entryId, {
      type: 'entry',
      label: `Entry: ${func.name}`,
      line: func.startLine,
    });

    // Traverse function body
    this.traverseNode(func.bodyNode, cfg, entryId, sourceCode);

    return cfg;
  }

  private traverseNode(
    node: any,
    cfg: Graph,
    currentNodeId: string,
    sourceCode: string
  ): string {
    const nodeType = node.type;

    switch (nodeType) {
      case 'call': {
        const funcName = this.getFunctionName(node, sourceCode);
        const callNodeId = `call_${funcName}_${node.startPosition.row}`;

        cfg.addNode(callNodeId, {
          type: 'function_call',
          label: funcName,
          line: node.startPosition.row,
          mayRaise: this.mayRaiseError(funcName),
        });

        cfg.addEdge(currentNodeId, callNodeId);

        // If may raise, add error edge
        if (this.mayRaiseError(funcName)) {
          const deadEndId = `dead_end_${node.startPosition.row}`;
          if (!cfg.hasNode(deadEndId)) {
            cfg.addNode(deadEndId, {
              type: 'dead_end',
              label: 'Dead End (unhandled error)',
              line: node.startPosition.row,
            });
          }
          cfg.addEdge(callNodeId, deadEndId, { isErrorPath: true });
        }

        return callNodeId;
      }

      case 'case': {
        return this.analyzeCaseStatement(node, cfg, currentNodeId, sourceCode);
      }

      default: {
        // Traverse children
        let lastNodeId = currentNodeId;
        for (const child of node.children) {
          lastNodeId = this.traverseNode(child, cfg, lastNodeId, sourceCode);
        }
        return lastNodeId;
      }
    }
  }

  private detectIssues(cfg: Graph): FlowIssue[] {
    const issues: FlowIssue[] = [];

    // 1. Find dead ends
    cfg.forEachNode((nodeId, attrs) => {
      if (attrs.type === 'dead_end') {
        issues.push({
          type: 'dead_end',
          severity: 'critical',
          line: attrs.line,
          description: `Dead end: ${attrs.label}`,
          recommendation: 'Add error handling (try/rescue or case statement)',
        });
      }
    });

    // 2. Find unreachable code
    const reachable = new Set<string>();
    bfs(cfg, 'entry', (nodeId) => {
      reachable.add(nodeId);
    });

    cfg.forEachNode((nodeId, attrs) => {
      if (!reachable.has(nodeId) && attrs.type !== 'dead_end') {
        issues.push({
          type: 'unreachable_code',
          severity: 'medium',
          line: attrs.line,
          description: `Unreachable code at line ${attrs.line}`,
          recommendation: 'Remove dead code or fix control flow',
        });
      }
    });

    return issues;
  }

  private calculateCompleteness(cfg: Graph): number {
    const totalPaths = this.countAllPaths(cfg);
    const completePaths = this.countCompletePaths(cfg);

    return completePaths / totalPaths;
  }

  private mayRaiseError(funcName: string): boolean {
    // Known functions that may raise
    const raisingFunctions = [
      'String.to_integer',
      'File.read!',
      'Repo.get!',
      // ... add more
    ];

    return raisingFunctions.some(f => funcName.includes(f));
  }
}
```

### 3. Add NATS Handler for Flow Analysis

```typescript
// ai-server/src/nats-flow-handler.ts

import { NatsConnection, StringCodec } from 'nats';
import { FlowAnalyzer } from './flow-analyzer';
import fs from 'fs/promises';

const sc = StringCodec();
const analyzer = new FlowAnalyzer();

export async function setupFlowAnalysisHandlers(nc: NatsConnection) {
  console.log('Setting up flow analysis NATS handlers...');

  // Handle: flow.analyze (from Elixir)
  nc.subscribe('flow.analyze', {
    callback: async (err, msg) => {
      if (err) {
        console.error('Flow analysis error:', err);
        return;
      }

      try {
        const request = JSON.parse(sc.decode(msg.data));
        const { file_path, codebase_name } = request;

        // Read file
        const sourceCode = await fs.readFile(file_path, 'utf-8');

        // Analyze
        const cfg = await analyzer.analyzeFile(file_path, sourceCode);

        // Send response
        msg.respond(sc.encode(JSON.stringify({
          success: true,
          cfg: {
            nodes: cfg.nodes,
            edges: cfg.edges,
            issues: cfg.issues,
            completeness: cfg.completeness,
          }
        })));

        console.log(`✅ Analyzed ${file_path}: ${cfg.issues.length} issues, ${(cfg.completeness * 100).toFixed(1)}% complete`);
      } catch (error) {
        console.error('Flow analysis failed:', error);
        msg.respond(sc.encode(JSON.stringify({
          success: false,
          error: error.message,
        })));
      }
    }
  });

  // Handle: flow.suggest_fix (from Elixir)
  nc.subscribe('flow.suggest_fix', {
    callback: async (err, msg) => {
      if (err) return;

      try {
        const request = JSON.parse(sc.decode(msg.data));
        const { issue, source_code } = request;

        const suggestedFix = await analyzer.suggestFix(issue, source_code);

        msg.respond(sc.encode(JSON.stringify({
          success: true,
          suggested_fix: suggestedFix,
        })));
      } catch (error) {
        msg.respond(sc.encode(JSON.stringify({
          success: false,
          error: error.message,
        })));
      }
    }
  });

  console.log('✅ Flow analysis handlers ready');
}
```

### 4. Register Handlers in Server

```typescript
// ai-server/src/server.ts (add to existing)

import { setupFlowAnalysisHandlers } from './nats-flow-handler';

// In your main() function, after NATS connects:
await setupFlowAnalysisHandlers(nc);
```

## Elixir Side: Call TypeScript Flow Analyzer

```elixir
# lib/singularity/code_flow_analyzer.ex

defmodule Singularity.CodeFlowAnalyzer do
  @moduledoc """
  Analyze code flows using TypeScript flow analyzer via NATS
  """

  alias Singularity.NatsOrchestrator

  def analyze_file(file_path) do
    request = %{
      file_path: file_path,
      codebase_name: "singularity"
    }

    # Call TypeScript analyzer via NATS
    case NatsOrchestrator.request("flow.analyze", request, timeout: 30_000) do
      {:ok, %{"success" => true, "cfg" => cfg}} ->
        # Store in PostgreSQL
        store_cfg(file_path, cfg)

        {:ok, cfg}

      {:ok, %{"success" => false, "error" => error}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def suggest_fix(issue, source_code) do
    request = %{
      issue: issue,
      source_code: source_code
    }

    case NatsOrchestrator.request("flow.suggest_fix", request, timeout: 30_000) do
      {:ok, %{"success" => true, "suggested_fix" => fix}} ->
        {:ok, fix}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp store_cfg(file_path, cfg) do
    # Store in code_function_control_flow_graphs table
    # ... (use existing migration)
  end
end
```

## Why This Is Better Than Pure Rust

### TypeScript Advantages:

1. ✅ **Codex SDK** - Already integrated!
2. ✅ **AI-powered fixes** - Use Codex for suggestions
3. ✅ **tree-sitter** - Same as Rust, but easier to use
4. ✅ **npm ecosystem** - Tons of graph libraries
5. ✅ **Already running** - Bun server already there!

### Rust Advantages:

1. ✅ **Performance** - Faster for large codebases
2. ✅ **Type safety** - Better for complex analysis
3. ✅ **NIFs** - Can call directly from Elixir

## Hybrid Approach (BEST!)

```
TypeScript (ai-server):
- AST parsing (tree-sitter)
- CFG building
- AI-powered fix suggestions (Codex SDK)
- Graph analysis (graphology)

Rust (package_registry_indexer):
- Heavy parsing (entire codebase)
- Performance-critical analysis
- Complex graph algorithms

Elixir (singularity_app):
- Orchestration
- Database storage
- Web UI (Phoenix LiveView)
- NATS coordination
```

## Usage

```elixir
# Analyze file (calls TypeScript)
{:ok, cfg} = CodeFlowAnalyzer.analyze_file("lib/user.ex")

# Returns:
%{
  "nodes" => [...],
  "edges" => [...],
  "issues" => [
    %{
      "type" => "dead_end",
      "severity" => "critical",
      "line" => 42,
      "description" => "Dead end: validate_user may raise",
      "recommendation" => "Add error handling"
    }
  ],
  "completeness" => 0.75  # 75% complete
}

# Get AI fix suggestion (calls Codex via TypeScript)
{:ok, fix} = CodeFlowAnalyzer.suggest_fix(issue, source_code)
```

**You get the best of all worlds**: TypeScript + Codex SDK + Elixir orchestration! 🎯

Want me to implement this?
