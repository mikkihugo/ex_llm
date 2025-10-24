#!/usr/bin/env bash
#
# Generate AI Metadata Template for Ecto Schema
#
# Usage: ./generate_schema_metadata_template.sh path/to/schema.ex
#
# Analyzes an Ecto schema file and generates a pre-filled AI metadata template
# that you can paste into the @moduledoc.

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 path/to/schema.ex"
    echo ""
    echo "Example: $0 lib/singularity/schemas/execution/rule.ex"
    exit 1
fi

SCHEMA_FILE="$1"

if [ ! -f "$SCHEMA_FILE" ]; then
    echo "Error: File not found: $SCHEMA_FILE"
    exit 1
fi

# Extract information from schema file
MODULE_NAME=$(grep -E "^defmodule " "$SCHEMA_FILE" | head -1 | sed -E 's/defmodule ([^ ]+) do/\1/')
TABLE_NAME=$(grep -E 'schema "' "$SCHEMA_FILE" | head -1 | sed -E 's/.*schema "([^"]+)".*/\1/' || echo "UNKNOWN")
FIELDS=$(grep -E '^\s+field :' "$SCHEMA_FILE" | sed -E 's/.*field :([^,]+).*/\1/' | tr '\n' ' ')
BELONGS_TO=$(grep -E '^\s+belongs_to :' "$SCHEMA_FILE" | sed -E 's/.*belongs_to :([^,]+),.*/\1/' | tr '\n' ' ')
HAS_MANY=$(grep -E '^\s+has_many :' "$SCHEMA_FILE" | sed -E 's/.*has_many :([^,]+),.*/\1/' | tr '\n' ' ')

# Detect special features
HAS_PGVECTOR=$(grep -q "Pgvector.Ecto.Vector" "$SCHEMA_FILE" && echo "true" || echo "false")
HAS_JSONB=$(grep -qE 'field :.*:map' "$SCHEMA_FILE" && echo "true" || echo "false")
HAS_ENUM=$(grep -q "Ecto.Enum" "$SCHEMA_FILE" && echo "true" || echo "false")

# Determine layer from path
LAYER="domain_services"
if [[ "$SCHEMA_FILE" == *"/monitoring/"* ]]; then
    LAYER="monitoring"
elif [[ "$SCHEMA_FILE" == *"/tools/"* ]]; then
    LAYER="tools"
elif [[ "$SCHEMA_FILE" == *"/infrastructure/"* ]]; then
    LAYER="infrastructure"
elif [[ "$SCHEMA_FILE" == *"/access_control/"* ]]; then
    LAYER="infrastructure"
fi

echo "================================================"
echo "AI Metadata Template for: $MODULE_NAME"
echo "================================================"
echo ""
echo "Detected information:"
echo "  Module: $MODULE_NAME"
echo "  Table: $TABLE_NAME"
echo "  Layer: $LAYER"
echo "  Fields: $FIELDS"
echo "  Belongs to: ${BELONGS_TO:-none}"
echo "  Has many: ${HAS_MANY:-none}"
echo "  Has pgvector: $HAS_PGVECTOR"
echo "  Has JSONB: $HAS_JSONB"
echo "  Has Enum: $HAS_ENUM"
echo ""
echo "================================================"
echo "PASTE THIS INTO @moduledoc:"
echo "================================================"
echo ""

cat <<EOF
  ## AI Navigation Metadata

  ### Module Identity (JSON)

  \`\`\`json
  {
    "module": "$MODULE_NAME",
    "purpose": "TODO: One-line purpose (what data does this store?)",
    "role": "schema",
    "layer": "$LAYER",
    "table": "$TABLE_NAME",
    "relationships": {
      TODO: Add parent/child relationships
    },
    "alternatives": {
      "SimilarSchema": "TODO: When to use this vs SimilarSchema"
    },
    "disambiguation": {
      "vs_similar": "TODO: Key difference from SimilarSchema"
    }
  }
  \`\`\`

  ### Schema Structure (YAML)

  \`\`\`yaml
  table: $TABLE_NAME
  primary_key: :id (binary_id)

  fields:
    # TODO: Document each field with type and purpose
EOF

# Generate field templates
for field in $FIELDS; do
    echo "    - name: $field"
    echo "      type: TODO"
    echo "      required: TODO"
    echo "      purpose: TODO"
    echo ""
done

if [ -n "$BELONGS_TO" ]; then
    echo ""
    echo "  relationships:"
    echo "    belongs_to:"
    for rel in $BELONGS_TO; do
        echo "      - schema: TODO_${rel}_Schema"
        echo "        field: ${rel}_id"
        echo "        required: TODO"
        echo ""
    done
fi

if [ -n "$HAS_MANY" ]; then
    echo ""
    echo "    has_many:"
    for rel in $HAS_MANY; do
        echo "      - schema: TODO_${rel}_Schema"
        echo "        foreign_key: TODO"
        echo "        purpose: TODO"
        echo ""
    done
fi

cat <<EOF
  indexes:
    # TODO: Document indexes from migration
EOF

if [ "$HAS_PGVECTOR" = "true" ]; then
    echo "    - type: hnsw"
    echo "      fields: [embedding]"
    echo "      purpose: Vector similarity search"
    echo ""
fi

if [ "$HAS_JSONB" = "true" ]; then
    echo "    - type: gin"
    echo "      fields: [metadata_or_jsonb_field]"
    echo "      purpose: JSONB queries"
    echo ""
fi

cat <<EOF
  constraints:
    # TODO: Document constraints from migration
  \`\`\`

  ### Data Flow (Mermaid)

  \`\`\`mermaid
  graph TB
      Source[TODO: Data Source] -->|1. create/update| Schema[$MODULE_NAME]
      Schema -->|2. changeset| Validation[Validations]
      Validation -->|3. valid| DB[PostgreSQL: $TABLE_NAME]

      Query[Queries] -->|4. read| DB
      DB -->|5. results| Schema

      style Schema fill:#90EE90
      style DB fill:#FFD700
  \`\`\`

  ### Call Graph (YAML)

  \`\`\`yaml
  calls_out:
    - module: Ecto.Schema
      function: schema/2
      purpose: Define table structure
      critical: true

    - module: Ecto.Changeset
      function: cast/3, validate_*/2
      purpose: Data validation
      critical: true

EOF

if [ "$HAS_PGVECTOR" = "true" ]; then
    echo "    - module: Pgvector.Ecto.Vector"
    echo "      function: type definition"
    echo "      purpose: Store vector embeddings"
    echo "      critical: true"
    echo ""
fi

if [ "$HAS_ENUM" = "true" ]; then
    echo "    - module: Ecto.Enum"
    echo "      function: type definition"
    echo "      purpose: Enum field validation"
    echo "      critical: true"
    echo ""
fi

cat <<EOF
  called_by:
    - module: TODO_ServiceThatUsesThis
      purpose: CRUD operations
      frequency: high

  depends_on:
    - PostgreSQL $TABLE_NAME table (MUST exist via migration)
    - Ecto.Repo (for all operations)
EOF

if [ "$HAS_PGVECTOR" = "true" ]; then
    echo "    - Pgvector extension (for embedding field)"
fi

cat <<EOF

  supervision:
    supervised: false
    reason: "Pure Ecto schema - not a process, no supervision needed"
  \`\`\`

  ### Anti-Patterns

  #### ❌ DO NOT create duplicate schemas for same table
  **Why:** One schema per table. Multiple schemas = confusion.
  \`\`\`elixir
  # ❌ WRONG - Duplicate schema
  defmodule ${MODULE_NAME}V2 do
    schema "$TABLE_NAME" do ...

  # ✅ CORRECT - Evolve existing schema
  # Add new fields/relationships to $MODULE_NAME
  \`\`\`

  #### ❌ DO NOT bypass changesets for validation
  \`\`\`elixir
  # ❌ WRONG - Direct struct insertion
  %${MODULE_NAME}{field: value} |> Repo.insert!()

  # ✅ CORRECT - Use changeset
  %${MODULE_NAME}{}
  |> ${MODULE_NAME}.changeset(%{field: value})
  |> Repo.insert()
  \`\`\`

  #### ❌ DO NOT use raw SQL instead of Ecto queries
  \`\`\`elixir
  # ❌ WRONG - Raw SQL bypasses schema
  Repo.query!("SELECT * FROM $TABLE_NAME WHERE id = \$1", [id])

  # ✅ CORRECT - Use Ecto query
  from(s in ${MODULE_NAME}, where: s.id == ^id) |> Repo.one()
  \`\`\`

EOF

if [ "$HAS_PGVECTOR" = "true" ]; then
    cat <<'PGVECTOR_ANTIPATTERN'
  #### ❌ DO NOT use wrong embedding dimensions
  **Why:** Index is optimized for specific dimension count.
  ```elixir
  # ❌ WRONG - Wrong dimension
  %YourSchema{embedding: wrong_size_vector}

  # ✅ CORRECT - Correct dimension (check schema)
  %YourSchema{embedding: correct_size_vector}
  ```

PGVECTOR_ANTIPATTERN
fi

if [ "$HAS_JSONB" = "true" ]; then
    cat <<'JSONB_ANTIPATTERN'
  #### ❌ DO NOT query JSONB without GIN index
  **Why:** Full table scans are slow for JSONB queries.
  ```elixir
  # ❌ WRONG - No index support
  from(s in Schema, where: fragment("metadata->>'key' = ?", "value"))

  # ✅ CORRECT - Ensure GIN index exists in migration
  # Then query with GIN-supported operators
  from(s in Schema, where: fragment("metadata @> ?", ^%{key: "value"}))
  ```

JSONB_ANTIPATTERN
fi

cat <<EOF
  ### Search Keywords

  TODO: schema name, $TABLE_NAME, main purpose, key features,
  domain, use cases, technologies
  (10-15 comma-separated keywords)
EOF

echo ""
echo "================================================"
echo "NEXT STEPS:"
echo "================================================"
echo "1. Replace all TODO items with actual values"
echo "2. Add 2-3 more schema-specific anti-patterns"
echo "3. Fill in search keywords (10-15 terms)"
echo "4. Test JSON/YAML syntax:"
echo "   python3 -m json.tool < module_identity.json"
echo "   yq < schema_structure.yaml"
echo "5. Preview Mermaid diagram in GitHub"
echo ""
echo "Estimated time: 30-60 minutes"
echo ""
