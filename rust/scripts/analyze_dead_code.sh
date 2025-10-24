#!/bin/bash
# Dead Code Analysis - Detailed context for each #[allow(dead_code)] annotation
# Usage: ./scripts/analyze_dead_code.sh

echo "=== Detailed Dead Code Analysis ==="
echo ""
echo "Date: $(date)"
echo ""

for file in $(find ./rust -name "*.rs" -type f | \
              grep -v target | \
              grep -v ".cargo-build" | \
              xargs grep -l "#\[allow(dead_code)\]" 2>/dev/null); do
    echo "FILE: $file"
    echo "---"

    # Get line numbers and context (3 lines after annotation)
    grep -n -A 3 "#\[allow(dead_code)\]" "$file" | head -30
    echo ""
done

echo ""
echo "=== Summary ==="
total=$(find ./rust -name "*.rs" -type f | \
        grep -v target | \
        grep -v ".cargo-build" | \
        xargs grep "#\[allow(dead_code)\]" 2>/dev/null | wc -l)
echo "Total annotations: $total"
echo ""
echo "Categorize each annotation using DEAD_CODE_QUICK_REFERENCE.md"
