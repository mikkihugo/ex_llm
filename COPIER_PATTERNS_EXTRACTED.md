# Copier Patterns Extracted

**Date:** 2025-01-10
**Source:** https://github.com/copier-org/copier (MIT License)
**Status:** ✅ Extracted and adapted for Singularity

## What Was Extracted

We extracted **7 valuable patterns** from Copier and adapted them for Singularity's AI-driven Living Knowledge Base:

| Pattern | File | Status |
|---------|------|--------|
| **1. Yield Extension** | `singularity/lib/singularity/templates/jinja_yield_extension.py` | ✅ Ready |
| **2. Dynamic Questions** | `singularity/lib/singularity/knowledge/template_question.ex` | ✅ Ready |
| **3. Answer Tracking** | `singularity/lib/singularity/knowledge/template_generation.ex` | ✅ Ready |
| **4. Template Migrations** | `singularity/lib/singularity/knowledge/template_migration.ex` | ✅ Ready |
| **5. Migration Mix Task** | `singularity/lib/mix/tasks/template.upgrade.ex` | ✅ Ready |
| **6. DB Migration** | `priv/repo/migrations/*_add_template_answer_tracking.exs` | ✅ Ready |
| **7. Example Template** | `templates_data/code_generation/examples/copier-patterns-example.json` | ✅ Ready |

## Pattern Details

### 1. Yield Extension - Bulk File Generation

**What:** Jinja2 extension for generating multiple files from one template.

**File:** `lib/singularity/templates/jinja_yield_extension.py`

**Example:**
```jinja
lib/singularity/agents/{% yield agent from agent_types %}{{ agent }}_agent.ex{% endyield %}
```

Generates:
- `lib/singularity/agents/self_improving_agent.ex`
- `lib/singularity/agents/cost_optimized_agent.ex`
- `lib/singularity/agents/refactoring_agent.ex`

**Usage:**
```python
from singularity.templates.jinja_yield_extension import YieldEnvironment, YieldExtension

env = YieldEnvironment(extensions=[YieldExtension])
template = env.from_string("{% yield item from items %}{{ item }}{% endyield %}")
template.render({"items": [1, 2, 3]})

# Check what to generate
env.yield_name      # => "item"
env.yield_iterable  # => [1, 2, 3]
```

### 2. Dynamic Questionnaire with Validation

**What:** Interactive questions for template parameters with type validation and conditional logic.

**File:** `lib/singularity/knowledge/template_question.ex`

**Features:**
- Dynamic choices based on previous answers
- Type validation (str, int, bool, yaml, json)
- Custom validators (Jinja templates)
- Conditional questions (`when` clause)
- Multiselect support
- Secret questions (hidden from answer file)

**Example:**
```elixir
questions = [
  %{
    var_name: "test_framework",
    type: "str",
    choices: ["ExUnit", "Wallaby"],
    when: "{{ include_tests }}",
    validator: "{% if test_framework == '' %}Required!{% endif %}"
  }
]

{:ok, answers} = TemplateQuestion.ask_via_llm(questions)
```

### 3. Answer File Tracking

**What:** Track what templates generated what code (like `.copier-answers.yml`).

**File:** `lib/singularity/knowledge/template_generation.ex`

**Benefits:**
- **Learning:** Track template success rates
- **Debugging:** "Why was this code generated?"
- **Updates:** Regenerate when template evolves
- **Analytics:** Template usage patterns

**Example:**
```elixir
# Record generation
TemplateGeneration.record(
  template_id: "quality_template:elixir-genserver",
  template_version: "2.1.0",
  file_path: "lib/my_app/worker.ex",
  answers: %{"otp_type" => "GenServer", "supervision" => true}
)

# Find what generated a file
{:ok, gen} = TemplateGeneration.find_by_file("lib/my_app/worker.ex")
gen.template_id      # => "quality_template:elixir-genserver"
gen.template_version # => "2.1.0"
gen.answers          # => %{"otp_type" => "GenServer", ...}

# Calculate success rate
TemplateGeneration.calculate_success_rate("quality_template:elixir-genserver")
# => 0.95 (95% success rate)

# Export answer file
{:ok, yaml} = TemplateGeneration.export_answer_file("lib/my_app/worker.ex")
# => "_template_id: quality_template:elixir-genserver\n_template_version: 2.1.0\n..."
```

### 4. Template Migration System

**What:** Upgrade code when templates evolve (like database migrations).

**File:** `lib/singularity/knowledge/template_migration.ex`

**Features:**
- Version-based migrations
- Before/after hooks
- Command execution with templated variables
- Working directory support
- Conditional execution

**Migration Schema:**
```json
{
  "migrations": [
    {
      "version": "2.0.0",
      "before": [
        "cp {{ _file_path }} {{ _file_path }}.backup"
      ],
      "after": [
        "mix format {{ _file_path }}",
        "mix test {{ _test_file }}"
      ]
    }
  ]
}
```

**Available Variables:**
- `{{ _file_path }}` - Path to generated file
- `{{ _test_file }}` - Path to test file
- `{{ _template_id }}` - Template identifier
- `{{ _version_from }}` - Old version
- `{{ _version_to }}` - New version
- `{{ _stage }}` - Current stage (before/after)
- All question answers

**Example:**
```elixir
# Upgrade all files from template v1.0 to v2.0
TemplateMigration.upgrade_template(
  template_id: "quality_template:elixir-genserver",
  from_version: "1.0.0",
  to_version: "2.0.0"
)

# Migrate single file
TemplateMigration.migrate_file(
  file_path: "lib/my_app/worker.ex",
  to_version: "2.0.0"
)
```

### 5. Mix Task for Easy Upgrades

**What:** CLI tool for upgrading generated code.

**File:** `lib/mix/tasks/template.upgrade.ex`

**Usage:**
```bash
# Upgrade all files from a template
mix template.upgrade quality_template:elixir-genserver --to 2.0.0

# Upgrade from specific version
mix template.upgrade quality_template:elixir-genserver --from 1.0.0 --to 2.0.0

# Upgrade single file
mix template.upgrade --file lib/my_app/worker.ex --to 2.0.0

# Dry run
mix template.upgrade quality_template:elixir-genserver --to 2.0.0 --dry-run
```

### 6. Database Schema

**What:** Track template generations in PostgreSQL.

**File:** `priv/repo/migrations/*_add_template_answer_tracking.exs`

**Schema:**
```sql
CREATE TABLE template_generations (
  id UUID PRIMARY KEY,
  template_id VARCHAR NOT NULL,
  template_version VARCHAR,
  file_path VARCHAR,
  answers JSONB NOT NULL,
  generated_at TIMESTAMP NOT NULL,
  success BOOLEAN DEFAULT TRUE,
  error_message TEXT,
  inserted_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE INDEX ON template_generations (template_id);
CREATE INDEX ON template_generations (file_path);
CREATE INDEX ON template_generations USING GIN (answers);
```

**Knowledge Artifacts Enhancement:**
```sql
ALTER TABLE knowledge_artifacts ADD COLUMN generation_metadata JSONB;
ALTER TABLE knowledge_artifacts ADD COLUMN answer_file JSONB;
```

### 7. Example Template

**What:** Full example showcasing all patterns.

**File:** `templates_data/code_generation/examples/copier-patterns-example.json`

**Features Demonstrated:**
- Questions with validation
- Dynamic choices
- Conditional questions
- Migrations with before/after hooks
- Bulk generation with `{% yield %}`
- Answer file tracking

## How to Use

### Setup

1. **Run migration:**
```bash
cd singularity
mix ecto.migrate
```

2. **Import example template:**
```bash
mix knowledge.migrate
```

### Generate Code with Questions

```elixir
# Load template
{:ok, template} = ArtifactStore.get("quality_template", "elixir-otp-advanced")

# Ask questions via LLM
{:ok, answers} = TemplateQuestion.ask_via_llm(template.content["questions"])

# Generate code
{:ok, code} = QualityCodeGenerator.generate(template, answers)

# Track generation
{:ok, _} = TemplateGeneration.record(
  template_id: template.artifact_type <> ":" <> template.identifier,
  template_version: template.version,
  file_path: "lib/my_app/worker.ex",
  answers: answers
)
```

### Upgrade When Template Evolves

```bash
# Template v1.0 -> v2.0 released
mix template.upgrade quality_template:elixir-otp-advanced --to 2.0.0
```

This will:
1. Find all files generated by v1.0
2. Run "before" migrations (backups, renames)
3. Regenerate code with v2.0
4. Run "after" migrations (format, test)
5. Track success/failure

### Track Template Performance

```elixir
# Get all generations from a template
gens = TemplateGeneration.list_by_template("quality_template:elixir-genserver")

# Calculate success rate
success_rate = TemplateGeneration.calculate_success_rate(gens)
# => 0.95

# Find poorly performing templates
ArtifactStore.list(artifact_type: "quality_template")
|> Enum.map(fn template ->
  success = TemplateGeneration.calculate_success_rate(template.identifier)
  {template.identifier, success}
end)
|> Enum.filter(fn {_, success} -> success < 0.8 end)
# => [{"elixir-bad-template", 0.42}]  # Needs improvement!
```

## Integration with Living Knowledge Base

These patterns enhance Singularity's Learning Knowledge Base:

1. **Track what works:**
   - Which templates have high success rates?
   - Which question combinations work best?
   - Which migrations fail most often?

2. **Auto-evolve templates:**
   - Low success rate → Improve template
   - High usage → Promote to curated
   - Failed migrations → Fix migration scripts

3. **Debugging:**
   - "Why did this code fail?" → Check generation record
   - "What answers were used?" → Export answer file
   - "Which template version?" → Check template_version

4. **Updates:**
   - Template improves → Auto-upgrade all generated code
   - Migration scripts ensure smooth transitions
   - Track which files upgraded successfully

## Differences from Copier

| Feature | Copier | Singularity |
|---------|--------|-------------|
| **Questions** | Human prompts | LLM-driven |
| **Generation** | Jinja templates | LLM + Templates |
| **Learning** | None | Track success rates |
| **Updates** | Manual | Auto-detect + upgrade |
| **Storage** | Git + YAML files | PostgreSQL + Git |
| **Analytics** | None | Success rates, usage patterns |

## Next Steps

1. **Integrate Jinja renderer:**
   - Connect `jinja_yield_extension.py` to Rust `prompt_engine`
   - Or add Python Jinja service via NATS

2. **Enhance TemplateQuestion:**
   - Add real Jinja validation rendering
   - Improve LLM question parsing

3. **Test migration system:**
   - Create real template with migrations
   - Test upgrade path v1.0 → v2.0

4. **Add to workflows:**
   - Agents use TemplateQuestion for interactive generation
   - QualityCodeGenerator records generations
   - Weekly job to upgrade stale templates

## License

Extracted code is based on Copier (MIT License):
https://github.com/copier-org/copier/blob/master/LICENSE

Adapted for Singularity under same MIT license.
