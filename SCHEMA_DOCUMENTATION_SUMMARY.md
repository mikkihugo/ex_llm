# Schema AI Documentation - Complete Package

**Status**: Ready to use
**Created**: 2025-01-25
**Target**: 67 Ecto schemas in Singularity codebase

---

## 📦 What You Have

### 1. **Main Guide** - `ECTO_SCHEMA_AI_DOCUMENTATION_GUIDE.md`

**Size**: ~1,200 lines
**Purpose**: Complete template and examples for AI metadata

**Contents**:
- Why AI metadata for schemas
- Schema-specific template (15-30 min per schema)
- 3 real examples (CodeChunk, Rule, Event)
- Quick start workflow (7 steps)
- Schema type categories (5 types)
- Content generation tips
- Validation checklist
- Batch processing strategy

**Use for**: Reference while documenting each schema

---

### 2. **Checklist** - `SCHEMA_AI_METADATA_CHECKLIST.md`

**Size**: ~500 lines
**Purpose**: Print and track progress

**Contents**:
- Per-schema checklist (7 steps)
- Validation before commit
- 67 schemas organized in 4 phases
- Time tracking table
- Common issues & solutions
- Commit template
- Daily goals & milestones

**Use for**: Daily tracking, ensure nothing is missed

---

### 3. **Template Generator** - `scripts/generate_schema_metadata_template.sh`

**Purpose**: Auto-generate metadata template from schema file

**Usage**:
```bash
./scripts/generate_schema_metadata_template.sh lib/singularity/schemas/execution/rule.ex
```

**Output**: Pre-filled template with:
- Module name
- Table name
- Detected fields
- Relationships (belongs_to, has_many)
- Special features (pgvector, JSONB, Enum)
- Auto-detected layer (monitoring/tools/domain)

**Saves**: 10-15 minutes per schema (auto-fills boilerplate)

---

### 4. **Validator** - `scripts/validate_schema_metadata.sh`

**Purpose**: Validate metadata completeness and syntax

**Usage**:
```bash
# Single file
./scripts/validate_schema_metadata.sh lib/singularity/schemas/execution/rule.ex

# All schemas
for f in lib/singularity/schemas/**/*.ex; do
  ./scripts/validate_schema_metadata.sh "$f"
done
```

**Checks**:
- ✅ Has AI Navigation Metadata section
- ✅ Valid JSON syntax (Module Identity)
- ✅ Valid YAML syntax (Schema Structure, Call Graph)
- ✅ Valid Mermaid syntax (Data Flow)
- ✅ Anti-Patterns section (3+ patterns)
- ✅ Search Keywords (10+ keywords)
- ✅ Code blocks properly closed

**Output**: Pass/Fail with error/warning count

---

## 🚀 Quick Start

### Step 1: Read the Guide (30 min)

```bash
# Open in your editor
code ECTO_SCHEMA_AI_DOCUMENTATION_GUIDE.md

# Or view in terminal
less ECTO_SCHEMA_AI_DOCUMENTATION_GUIDE.md
```

**Focus on**:
- "Why AI Metadata for Schemas?" section
- "Real Examples" (CodeChunk, Rule, Event)
- "Quick Start Workflow" (7 steps)

### Step 2: Print the Checklist

```bash
# Print to PDF or paper
open SCHEMA_AI_METADATA_CHECKLIST.md
```

Keep it next to your keyboard. Check boxes as you complete each schema.

### Step 3: Test the Tools

```bash
# Generate template for first schema
./scripts/generate_schema_metadata_template.sh \
  singularity/lib/singularity/schemas/execution/rule.ex

# Copy output to clipboard, paste into @moduledoc
# Replace all TODO items with actual values

# Validate when done
./scripts/validate_schema_metadata.sh \
  singularity/lib/singularity/schemas/execution/rule.ex
```

### Step 4: Document First Schema (60 min)

Pick an easy one to start:
- **Event** - Simple monitoring schema
- **CodeChunk** - Storage with pgvector
- **Todo** - Core domain with relationships

Follow the 7-step workflow from the guide.

### Step 5: Batch Process (45 hours total)

Follow the phased approach from the checklist:

**Phase 1**: 10 core domain schemas (7 hours)
**Phase 2**: 15 storage schemas (10 hours)
**Phase 3**: 15 monitoring/analysis schemas (10 hours)
**Phase 4**: 27 infrastructure/misc schemas (18 hours)

---

## 📋 The 7-Step Workflow

### Step 1: Identify Schema Type (5 min)

Run generator to auto-detect:
```bash
./scripts/generate_schema_metadata_template.sh path/to/schema.ex
```

### Step 2: Module Identity JSON (10 min)

Answer:
- What data does this store?
- What table?
- What relationships?
- Similar schemas?
- Key differences?

### Step 3: Schema Structure YAML (15 min)

Document:
- All fields (name, type, purpose)
- Relationships (belongs_to, has_many)
- Indexes (HNSW for vectors, GIN for JSONB)
- Constraints

### Step 4: Data Flow Mermaid (10 min)

Diagram:
- Where data comes from
- Validation step
- Storage
- Query patterns

### Step 5: Call Graph YAML (10 min)

List:
- calls_out (Ecto.Schema, Ecto.Changeset, etc.)
- called_by (services using this schema)
- depends_on (table, extensions, other schemas)
- supervision (always false for schemas)

### Step 6: Anti-Patterns (10 min)

Include:
- Don't create duplicate schemas
- Don't bypass changesets
- Don't use raw SQL
- Schema-specific (2+ patterns)

### Step 7: Search Keywords (5 min)

10-15 keywords:
- Schema name
- Table name
- Purpose
- Technologies (pgvector, JSONB, TimescaleDB)
- Use cases

**Total**: ~65 minutes (40 min minimum viable)

---

## 🎯 Schema Categories

### 1. Core Domain (10 schemas)

**Examples**: Rule, Task, Todo, ExecutionRecord

**Features**:
- Complex relationships
- Versioning (parent_id)
- Workflow state (status enum)
- Business logic validation

**Template time**: 60-90 min (complex relationships)

---

### 2. Storage (15 schemas)

**Examples**: CodeChunk, KnowledgeArtifact, Template

**Features**:
- pgvector embeddings
- JSONB metadata
- Dual storage (raw + parsed)
- Deduplication (content_hash)

**Template time**: 45-60 min (special indexes)

---

### 3. Monitoring (15 schemas)

**Examples**: Event, AggregatedData, SearchMetric

**Features**:
- TimescaleDB hypertables
- Time-series optimization
- Measurement validation
- Tag-based filtering

**Template time**: 30-45 min (simpler structure)

---

### 4. Infrastructure (15 schemas)

**Examples**: GitStateStore, CodebaseMetadata, UserPreferences

**Features**:
- System configuration
- State persistence
- Access control
- Caching

**Template time**: 30-45 min

---

### 5. Tools (12 schemas)

**Examples**: Tool, ToolParam, ToolCall, ToolResult

**Features**:
- Embedded schemas (no table)
- Virtual fields
- Parameter schemas
- Execution tracking

**Template time**: 30-45 min

---

## 🛠️ Helper Scripts

### Generate Template

```bash
# Generate for one schema
./scripts/generate_schema_metadata_template.sh \
  singularity/lib/singularity/schemas/execution/rule.ex > /tmp/template.txt

# Copy to clipboard (macOS)
./scripts/generate_schema_metadata_template.sh \
  singularity/lib/singularity/schemas/execution/rule.ex | pbcopy

# Batch generate for all schemas in directory
for f in singularity/lib/singularity/schemas/execution/*.ex; do
  echo "=== $f ==="
  ./scripts/generate_schema_metadata_template.sh "$f"
  echo ""
done
```

### Validate Metadata

```bash
# Validate one schema
./scripts/validate_schema_metadata.sh \
  singularity/lib/singularity/schemas/execution/rule.ex

# Validate all schemas (summary)
for f in singularity/lib/singularity/schemas/**/*.ex; do
  if ./scripts/validate_schema_metadata.sh "$f" > /dev/null 2>&1; then
    echo "✅ $f"
  else
    echo "❌ $f"
  fi
done

# Count schemas with metadata
echo "Schemas with AI metadata:"
rg -c "## AI Navigation Metadata" singularity/lib/singularity/schemas/ | wc -l

# List schemas WITHOUT metadata
echo "Schemas missing AI metadata:"
for f in singularity/lib/singularity/schemas/**/*.ex; do
  if ! grep -q "## AI Navigation Metadata" "$f"; then
    echo "  - $f"
  fi
done
```

### Extract Metadata for Analysis

```bash
# Extract all Module Identity JSON
rg -U '@moduledoc.*```json.*?```' --multiline singularity/lib/singularity/schemas/ | \
  sed -n '/```json/,/```/p' | \
  python3 -m json.tool

# Extract all Call Graphs
rg -U '### Call Graph.*?```yaml.*?```' --multiline singularity/lib/singularity/schemas/ | \
  sed -n '/```yaml/,/```/p' | \
  yq

# Count anti-patterns
echo "Total anti-patterns documented:"
rg "#### ❌" singularity/lib/singularity/schemas/ | wc -l

# List schemas by layer
echo "Schemas by layer:"
rg '"layer": "' singularity/lib/singularity/schemas/ | \
  sed -E 's/.*"layer": "([^"]+)".*/\1/' | \
  sort | uniq -c
```

---

## 📊 Progress Tracking

### Current Status

```bash
# Run this to check progress
echo "Total schemas: 67"
echo "Documented: $(rg -c '## AI Navigation Metadata' singularity/lib/singularity/schemas/ | wc -l | tr -d ' ')"
echo "Remaining: $((67 - $(rg -c '## AI Navigation Metadata' singularity/lib/singularity/schemas/ | wc -l | tr -d ' ')))"
```

### Phase Completion

| Phase | Schemas | Hours | Status |
|-------|---------|-------|--------|
| Phase 1: Core Domain | 10 | 7h | ☐ Not started |
| Phase 2: Storage | 15 | 10h | ☐ Not started |
| Phase 3: Monitoring | 15 | 10h | ☐ Not started |
| Phase 4: Infrastructure | 27 | 18h | ☐ Not started |
| **Total** | **67** | **45h** | **0% complete** |

Update this table in `SCHEMA_AI_METADATA_CHECKLIST.md` as you go.

---

## 🎓 Learning Resources

### Before You Start

**Read these schemas first** (already documented):
1. `singularity/lib/singularity/schemas/execution/rule.ex` - Complex with relationships
2. `singularity/lib/singularity/schemas/code_chunk.ex` - Storage with pgvector
3. `singularity/lib/singularity/schemas/monitoring/event.ex` - Simple monitoring

**Study these examples**:
- `templates_data/code_generation/examples/elixir_ai_optimized_example.ex` - Full pattern
- `templates_data/code_generation/examples/AI_METADATA_QUICK_REFERENCE.md` - Quick ref

### While Documenting

**For Module Identity JSON**:
- Purpose: "Stores [what data] with [key feature]"
- Layer: domain_services (most), infrastructure, tools, monitoring
- Relationships: List parent/child schemas

**For Schema Structure YAML**:
- Copy field list from schema `def` block
- Check migration for indexes and constraints
- Note special types: Pgvector.Ecto.Vector, :map (JSONB), Ecto.Enum

**For Anti-Patterns**:
- Always include: duplicate schemas, bypass changeset, raw SQL
- Add 2+ schema-specific patterns (wrong dimensions, no index, etc.)

### Validation

**Test syntax**:
```bash
# JSON
echo 'YOUR_JSON_HERE' | python3 -m json.tool

# YAML
echo 'YOUR_YAML_HERE' | yq

# Mermaid (install mermaid-cli)
echo 'YOUR_MERMAID_HERE' > /tmp/test.mmd
mmdc -i /tmp/test.mmd -o /tmp/test.png
```

---

## 🎯 Daily Goals

**Goal**: Complete 67 schemas in 8 days (6 hours/day)

### Day 1 (6h): Phase 1 schemas 1-8
- Rule, RuleExecution, RuleEvolutionProposal
- Task, TaskExecutionStrategy
- Todo, ExecutionRecord, Tool

### Day 2 (6h): Phase 1-2 schemas 9-16
- ToolParam, ToolCall
- ToolResult, KnowledgeArtifact, CodeChunk
- Template, TemplateCache, TechnologyTemplate

### Day 3 (6h): Phase 2 schemas 17-25
- TechnologyPattern, TechnologyDetection
- PackageCodeExample, PackageUsagePattern, PackageDependency
- DependencyCatalog, CodeFile, CodeLocationIndex, CodeEmbeddingCache

### Day 4 (6h): Phase 3 schemas 26-33
- Event, AggregatedData, SearchMetric, UsageEvent
- AgentMetric, CodebaseSnapshot, Finding, Run

### Day 5 (6h): Phase 3 schemas 34-40
- CodeAnalysisResult, FileArchitecturePattern, FileNamingViolation
- DeadCodeHistory, ExperimentResult, T5EvaluationResult, T5TrainingSession

### Day 6 (6h): Phase 4 schemas 41-50
- T5TrainingExample, T5ModelVersion
- GitStateStore, CodebaseMetadata, CodebaseRegistry
- UserPreferences, UserCodebasePermission, ApprovalQueue
- VectorSimilarityCache, VectorSearch

### Day 7 (6h): Phase 4 schemas 51-60
- TemplateGeneration, LLMCall, LocalLearning
- GraphNode, GraphEdge, GraphType
- PackagePromptUsage, InstructorSchemas
- StrategicTheme, Epic

### Day 8 (3h): Phase 4 schemas 61-67 + validation
- Feature, Capability, CapabilityDependency
- Remaining schemas
- Run full validation on all 67 schemas

---

## 💡 Pro Tips

### Speed Up Documentation

1. **Batch similar schemas** - Do all Event-like schemas together
2. **Reuse YAML structure** - Copy field list, update values
3. **Template anti-patterns** - Most schemas have same 3 core patterns
4. **Group keywords** - Schemas in same domain share keywords
5. **Use generator** - Saves 10-15 min per schema

### Ensure Quality

1. **Validate after each 5 schemas** - Catch errors early
2. **Test Mermaid in GitHub** - Push to branch, check preview
3. **Read related schemas** - See how others documented similar patterns
4. **Ask "Would AI understand this?"** - If unclear to you, unclear to AI

### Stay Motivated

1. **Track progress visibly** - Update checklist after each schema
2. **Celebrate milestones** - 10, 25, 40, 67 schemas
3. **Take breaks** - 50 min work, 10 min break
4. **Batch commit** - Commit 5-10 schemas at once for satisfaction

---

## 🚨 Common Issues

### "JSON syntax error"

**Cause**: Missing comma, trailing comma, unescaped quotes

**Fix**:
```bash
# Extract and test JSON
grep -A 20 "Module Identity" your_schema.ex | python3 -m json.tool
```

### "YAML indentation error"

**Cause**: Tabs instead of spaces, misaligned nesting

**Fix**:
```bash
# Use 2 spaces (not tabs)
# Align list items
grep -A 30 "Schema Structure" your_schema.ex | yq
```

### "Mermaid doesn't render"

**Cause**: Invalid syntax, special characters in node names

**Fix**:
```mermaid
# ✅ CORRECT
graph TB
    Source --> Schema
    Schema --> DB

# ❌ WRONG
graph TB
    Source[Source-Name] --> Schema
    # Hyphens in node names break rendering
```

### "Can't find relationships"

**Cause**: Relationships defined in schema file

**Fix**:
```bash
# Search schema file
grep "belongs_to\|has_many" singularity/lib/singularity/schemas/your_schema.ex
```

---

## 📝 Commit Strategy

### Commit in Batches (5-10 schemas)

```bash
# Stage schemas
git add singularity/lib/singularity/schemas/execution/rule.ex
git add singularity/lib/singularity/schemas/execution/task.ex
# ... (5-10 files)

# Commit with template
git commit -m "docs: Add AI metadata to 8 core execution schemas

Schemas documented:
- Rule - Evolvable agent rules with Lua and consensus
- RuleExecution - Rule execution tracking
- RuleEvolutionProposal - Rule evolution proposals
- Task - Agent work item definitions
- TaskExecutionStrategy - Task execution strategies
- Todo - Todo items with dependencies
- ExecutionRecord - Execution history tracking
- Tool - Callable tool definitions

Complete Module Identity, Schema Structure, Data Flow,
Call Graph, Anti-Patterns, and Search Keywords for each.

Enables AI assistants and graph/vector DBs to navigate
schemas and prevent duplicates at billion-line scale.

Estimated time: 7 hours
Phase: 1/4 (Core Domain)"
```

### Push After Each Phase

```bash
# After Phase 1 (10 schemas)
git push origin feature/schema-ai-metadata-phase-1

# After Phase 2 (25 schemas total)
git push origin feature/schema-ai-metadata-phase-2

# etc.
```

---

## ✅ Final Checklist

Before considering the project complete:

- [ ] All 67 schemas have AI metadata
- [ ] All schemas pass validation script
- [ ] All JSON blocks are valid
- [ ] All YAML blocks are valid
- [ ] All Mermaid diagrams render in GitHub
- [ ] All schemas have 3+ anti-patterns
- [ ] All schemas have 10+ search keywords
- [ ] Progress tracked in checklist
- [ ] All changes committed
- [ ] Documentation reviewed by peer

---

## 🎉 Success Metrics

**When done, you'll have**:

1. **67 fully documented schemas** with AI-optimized metadata
2. **~4,500 lines of structured metadata** (JSON, YAML, Mermaid)
3. **200+ anti-patterns** preventing duplicate code
4. **670+ search keywords** for vector DB optimization
5. **67 visual diagrams** showing data flow
6. **Billion-line scale navigation** for AI assistants

**Benefits**:

- AI can find right schema instantly
- Graph DB can auto-index relationships
- Vector DB can optimize semantic search
- Developers can understand schema purpose at a glance
- Prevents duplicate schema creation
- Documents validation rules and constraints
- Shows data flow and relationships visually

---

## 📞 Need Help?

**Issues with tools**:
```bash
# Re-download scripts if corrupted
git checkout scripts/generate_schema_metadata_template.sh
git checkout scripts/validate_schema_metadata.sh

# Make executable
chmod +x scripts/*.sh
```

**Questions about template**:
- Read examples in guide: CodeChunk, Rule, Event
- Check quick reference: `templates_data/code_generation/examples/AI_METADATA_QUICK_REFERENCE.md`

**Validation failures**:
- Run validator with debug: `bash -x scripts/validate_schema_metadata.sh your_schema.ex`
- Check syntax manually: `python3 -m json.tool`, `yq`

---

## 🚀 Let's Go!

**Ready to start?**

1. ✅ Read the guide (30 min)
2. ✅ Print the checklist
3. ✅ Test the tools
4. ✅ Document first schema (60 min)
5. ✅ Batch process remaining 66 schemas (44 hours)

**Estimated completion**: 8 days at 6 hours/day

**You've got this!** 💪

---

**Files in this package**:
- `ECTO_SCHEMA_AI_DOCUMENTATION_GUIDE.md` - Main guide (1,200 lines)
- `SCHEMA_AI_METADATA_CHECKLIST.md` - Progress tracker (500 lines)
- `scripts/generate_schema_metadata_template.sh` - Template generator
- `scripts/validate_schema_metadata.sh` - Metadata validator
- `SCHEMA_DOCUMENTATION_SUMMARY.md` - This file (you are here)
