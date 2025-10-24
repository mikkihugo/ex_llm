#!/usr/bin/env bash
#
# Validate AI Metadata in Ecto Schema
#
# Usage: ./validate_schema_metadata.sh path/to/schema.ex
#
# Checks that AI metadata is complete and valid (JSON, YAML, Mermaid)

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 path/to/schema.ex [--fix]"
    echo ""
    echo "Options:"
    echo "  --fix    Attempt to auto-fix common issues"
    echo ""
    echo "Examples:"
    echo "  $0 lib/singularity/schemas/execution/rule.ex"
    echo "  $0 lib/singularity/schemas/**/*.ex  # Validate all"
    exit 1
fi

SCHEMA_FILE="$1"
FIX_MODE="${2:-}"
ERRORS=0
WARNINGS=0

if [ ! -f "$SCHEMA_FILE" ]; then
    echo "❌ Error: File not found: $SCHEMA_FILE"
    exit 1
fi

echo "================================================"
echo "Validating: $SCHEMA_FILE"
echo "================================================"
echo ""

# Check 1: Has AI Navigation Metadata section
echo "✓ Checking for AI Navigation Metadata section..."
if ! grep -q "## AI Navigation Metadata" "$SCHEMA_FILE"; then
    echo "  ❌ MISSING: ## AI Navigation Metadata section"
    ((ERRORS++))
else
    echo "  ✓ Found"
fi

# Check 2: Module Identity JSON
echo ""
echo "✓ Checking Module Identity JSON..."
if ! grep -q "### Module Identity (JSON)" "$SCHEMA_FILE"; then
    echo "  ❌ MISSING: Module Identity section"
    ((ERRORS++))
else
    # Extract JSON and validate
    JSON_CONTENT=$(sed -n '/### Module Identity/,/```$/p' "$SCHEMA_FILE" | sed -n '/```json/,/```/p' | sed '1d;$d')

    if [ -z "$JSON_CONTENT" ]; then
        echo "  ❌ MISSING: JSON content"
        ((ERRORS++))
    else
        echo "$JSON_CONTENT" | python3 -m json.tool > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "  ✓ Valid JSON syntax"

            # Check required fields
            for field in module purpose role layer table; do
                if ! echo "$JSON_CONTENT" | grep -q "\"$field\""; then
                    echo "  ⚠️  WARNING: Missing field '$field'"
                    ((WARNINGS++))
                fi
            done
        else
            echo "  ❌ INVALID: JSON syntax error"
            ((ERRORS++))
            if [ -n "$FIX_MODE" ]; then
                echo "  → Attempting to fix..."
                # Could add auto-fix logic here
            fi
        fi
    fi
fi

# Check 3: Schema Structure YAML
echo ""
echo "✓ Checking Schema Structure YAML..."
if ! grep -q "### Schema Structure (YAML)" "$SCHEMA_FILE"; then
    echo "  ❌ MISSING: Schema Structure section"
    ((ERRORS++))
else
    # Extract YAML and validate
    YAML_CONTENT=$(sed -n '/### Schema Structure/,/```$/p' "$SCHEMA_FILE" | sed -n '/```yaml/,/```/p' | sed '1d;$d')

    if [ -z "$YAML_CONTENT" ]; then
        echo "  ❌ MISSING: YAML content"
        ((ERRORS++))
    else
        if command -v yq &> /dev/null; then
            echo "$YAML_CONTENT" | yq '.' > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "  ✓ Valid YAML syntax"

                # Check required fields
                for field in table fields; do
                    if ! echo "$YAML_CONTENT" | grep -q "^$field:"; then
                        echo "  ⚠️  WARNING: Missing field '$field'"
                        ((WARNINGS++))
                    fi
                done
            else
                echo "  ❌ INVALID: YAML syntax error"
                ((ERRORS++))
            fi
        else
            echo "  ⚠️  WARNING: yq not installed, skipping YAML validation"
            echo "  Install: brew install yq"
            ((WARNINGS++))
        fi
    fi
fi

# Check 4: Data Flow Mermaid
echo ""
echo "✓ Checking Data Flow Mermaid..."
if ! grep -q "### Data Flow (Mermaid)" "$SCHEMA_FILE"; then
    echo "  ⚠️  WARNING: Data Flow diagram missing (optional)"
    ((WARNINGS++))
else
    # Basic Mermaid syntax check
    MERMAID_CONTENT=$(sed -n '/### Data Flow/,/```$/p' "$SCHEMA_FILE" | sed -n '/```mermaid/,/```/p' | sed '1d;$d')

    if [ -z "$MERMAID_CONTENT" ]; then
        echo "  ❌ MISSING: Mermaid content"
        ((ERRORS++))
    else
        if echo "$MERMAID_CONTENT" | grep -q "graph \(TB\|LR\|TD\)"; then
            echo "  ✓ Valid Mermaid graph syntax"

            # Check for highlight
            if ! echo "$MERMAID_CONTENT" | grep -q "fill:#90EE90"; then
                echo "  ⚠️  WARNING: Missing schema highlight (fill:#90EE90)"
                ((WARNINGS++))
            fi
        else
            echo "  ❌ INVALID: Missing graph declaration (graph TB/LR/TD)"
            ((ERRORS++))
        fi
    fi
fi

# Check 5: Call Graph YAML
echo ""
echo "✓ Checking Call Graph YAML..."
if ! grep -q "### Call Graph (YAML)" "$SCHEMA_FILE"; then
    echo "  ❌ MISSING: Call Graph section"
    ((ERRORS++))
else
    CALL_GRAPH=$(sed -n '/### Call Graph/,/```$/p' "$SCHEMA_FILE" | sed -n '/```yaml/,/```/p' | sed '1d;$d')

    if [ -z "$CALL_GRAPH" ]; then
        echo "  ❌ MISSING: YAML content"
        ((ERRORS++))
    else
        if command -v yq &> /dev/null; then
            echo "$CALL_GRAPH" | yq '.' > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "  ✓ Valid YAML syntax"

                # Check required sections
                for section in calls_out called_by depends_on supervision; do
                    if ! echo "$CALL_GRAPH" | grep -q "^$section:"; then
                        echo "  ⚠️  WARNING: Missing section '$section'"
                        ((WARNINGS++))
                    fi
                done

                # Check supervision is false
                if ! echo "$CALL_GRAPH" | grep -q "supervised: false"; then
                    echo "  ⚠️  WARNING: supervision should be 'false' for schemas"
                    ((WARNINGS++))
                fi
            else
                echo "  ❌ INVALID: YAML syntax error"
                ((ERRORS++))
            fi
        fi
    fi
fi

# Check 6: Anti-Patterns
echo ""
echo "✓ Checking Anti-Patterns..."
if ! grep -q "### Anti-Patterns" "$SCHEMA_FILE"; then
    echo "  ❌ MISSING: Anti-Patterns section"
    ((ERRORS++))
else
    ANTIPATTERN_COUNT=$(grep -c "#### ❌" "$SCHEMA_FILE" || echo 0)

    if [ "$ANTIPATTERN_COUNT" -lt 3 ]; then
        echo "  ⚠️  WARNING: Only $ANTIPATTERN_COUNT anti-patterns (recommend 3+)"
        ((WARNINGS++))
    else
        echo "  ✓ Found $ANTIPATTERN_COUNT anti-patterns"
    fi

    # Check for common anti-patterns
    if ! grep -q "DO NOT create duplicate" "$SCHEMA_FILE"; then
        echo "  ⚠️  WARNING: Missing 'duplicate schema' anti-pattern"
        ((WARNINGS++))
    fi

    if ! grep -q "DO NOT bypass changeset" "$SCHEMA_FILE"; then
        echo "  ⚠️  WARNING: Missing 'bypass changeset' anti-pattern"
        ((WARNINGS++))
    fi
fi

# Check 7: Search Keywords
echo ""
echo "✓ Checking Search Keywords..."
if ! grep -q "### Search Keywords" "$SCHEMA_FILE"; then
    echo "  ❌ MISSING: Search Keywords section"
    ((ERRORS++))
else
    # Count comma-separated keywords after the section
    KEYWORDS=$(sed -n '/### Search Keywords/,/"""/p' "$SCHEMA_FILE" | tail -n +2 | head -n -1)
    KEYWORD_COUNT=$(echo "$KEYWORDS" | tr ',' '\n' | grep -v '^[[:space:]]*$' | wc -l | tr -d ' ')

    if [ "$KEYWORD_COUNT" -lt 10 ]; then
        echo "  ⚠️  WARNING: Only $KEYWORD_COUNT keywords (recommend 10-15)"
        ((WARNINGS++))
    else
        echo "  ✓ Found $KEYWORD_COUNT keywords"
    fi
fi

# Check 8: Code block closure
echo ""
echo "✓ Checking code block closure..."
JSON_BLOCKS=$(grep -c '```json' "$SCHEMA_FILE" || echo 0)
JSON_CLOSES=$(grep -c '^  ```$' "$SCHEMA_FILE" | head -1 || echo 0)

if [ "$JSON_BLOCKS" -gt "$JSON_CLOSES" ]; then
    echo "  ⚠️  WARNING: Possible unclosed code blocks"
    ((WARNINGS++))
else
    echo "  ✓ Code blocks appear closed"
fi

# Summary
echo ""
echo "================================================"
echo "VALIDATION SUMMARY"
echo "================================================"
echo ""
echo "File: $SCHEMA_FILE"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ ALL CHECKS PASSED!"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  PASSED with $WARNINGS warning(s)"
    exit 0
else
    echo "❌ FAILED with $ERRORS error(s) and $WARNINGS warning(s)"
    echo ""
    echo "Recommended fixes:"
    [ $ERRORS -gt 0 ] && echo "  1. Add missing required sections"
    [ $WARNINGS -gt 0 ] && echo "  2. Address warnings for completeness"
    echo "  3. Validate JSON: python3 -m json.tool < your.json"
    echo "  4. Validate YAML: yq < your.yaml"
    echo ""
    exit 1
fi
