#!/bin/bash
# Dead Code Scan - Quick summary of #[allow(dead_code)] annotations
# Usage: ./scripts/scan_dead_code.sh

echo "=== Dead Code Scan ==="
echo ""
echo "Date: $(date)"
echo ""

total=0
for file in $(find ./rust -name "*.rs" -type f | \
              grep -v target | \
              grep -v ".cargo-build" | \
              xargs grep -l "#\[allow(dead_code)\]" 2>/dev/null); do
    count=$(grep -c "#\[allow(dead_code)\]" "$file")
    total=$((total + count))
    printf "%-70s %3d\n" "$file" "$count"
done

echo ""
echo "Total #[allow(dead_code)] annotations: $total"
echo ""
echo "Previous audit (Jan 2025): 35 annotations"
change=$((total - 35))
if [ $change -gt 0 ]; then
    echo "Change: +$change (INCREASED)"
elif [ $change -lt 0 ]; then
    echo "Change: $change (DECREASED)"
else
    echo "Change: 0 (UNCHANGED)"
fi
echo ""
echo "Run ./scripts/analyze_dead_code.sh for detailed analysis"
