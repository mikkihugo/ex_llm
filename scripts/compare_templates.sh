#!/bin/bash

# Script to compare templates between rust/package/templates and templates_data

SOURCE_DIR="/home/mhugo/code/singularity/rust/package/templates"
TARGET_DIR="/home/mhugo/code/singularity/templates_data"
REPORT_FILE="/home/mhugo/code/singularity/template_merge_report.md"

echo "# Template Merge Analysis Report" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Function to find matching file in target
find_matching_file() {
    local basename="$1"
    find "$TARGET_DIR" -type f -name "$basename" 2>/dev/null
}

# Function to compare files
compare_files() {
    local file1="$1"
    local file2="$2"

    if [ ! -f "$file2" ]; then
        echo "NO_MATCH"
        return
    fi

    local hash1=$(md5sum "$file1" | cut -d' ' -f1)
    local hash2=$(md5sum "$file2" | cut -d' ' -f1)

    if [ "$hash1" = "$hash2" ]; then
        echo "IDENTICAL"
    else
        echo "DIFFERENT"
    fi
}

# Arrays to track results
declare -a IDENTICAL_FILES=()
declare -a DIFFERENT_FILES=()
declare -a UNIQUE_FILES=()

# Process all JSON files in source
while IFS= read -r source_file; do
    # Get relative path and basename
    rel_path="${source_file#$SOURCE_DIR/}"
    basename=$(basename "$source_file")

    # Find matching files in target
    matching_files=$(find_matching_file "$basename")

    if [ -z "$matching_files" ]; then
        UNIQUE_FILES+=("$rel_path")
    else
        # Compare with first match
        target_file=$(echo "$matching_files" | head -n1)
        result=$(compare_files "$source_file" "$target_file")

        if [ "$result" = "IDENTICAL" ]; then
            IDENTICAL_FILES+=("$rel_path|$target_file")
        else
            DIFFERENT_FILES+=("$rel_path|$target_file")
        fi
    fi
done < <(find "$SOURCE_DIR" -type f -name "*.json" | sort)

# Write IDENTICAL files
echo "## 1. IDENTICAL Files (Skip - Already in templates_data/)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "These files are byte-for-byte identical and should NOT be copied:" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ ${#IDENTICAL_FILES[@]} -eq 0 ]; then
    echo "None found." >> "$REPORT_FILE"
else
    for entry in "${IDENTICAL_FILES[@]}"; do
        source_path="${entry%%|*}"
        target_path="${entry##*|}"
        target_rel="${target_path#$TARGET_DIR/}"
        echo "- **$source_path**" >> "$REPORT_FILE"
        echo "  - Exists at: \`$target_rel\`" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    done
fi

echo "" >> "$REPORT_FILE"
echo "**Total Identical:** ${#IDENTICAL_FILES[@]}" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Write DIFFERENT files
echo "## 2. DIFFERENT Files (Manual Review Required)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "These files exist in both locations but have different content:" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ ${#DIFFERENT_FILES[@]} -eq 0 ]; then
    echo "None found." >> "$REPORT_FILE"
else
    for entry in "${DIFFERENT_FILES[@]}"; do
        source_path="${entry%%|*}"
        target_path="${entry##*|}"
        target_rel="${target_path#$TARGET_DIR/}"

        source_full="$SOURCE_DIR/$source_path"

        echo "- **$source_path**" >> "$REPORT_FILE"
        echo "  - Exists at: \`$target_rel\`" >> "$REPORT_FILE"
        echo "  - Source size: $(wc -c < "$source_full") bytes" >> "$REPORT_FILE"
        echo "  - Target size: $(wc -c < "$target_path") bytes" >> "$REPORT_FILE"
        echo "  - **Action:** Manual review needed to determine which version to keep" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    done
fi

echo "" >> "$REPORT_FILE"
echo "**Total Different:** ${#DIFFERENT_FILES[@]}" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Write UNIQUE files
echo "## 3. UNIQUE Files (Need to Copy)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "These files are only in rust/package/templates/ and should be copied:" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ ${#UNIQUE_FILES[@]} -eq 0 ]; then
    echo "None found." >> "$REPORT_FILE"
else
    # Group by category
    declare -A CATEGORIES

    for file in "${UNIQUE_FILES[@]}"; do
        if [[ "$file" == system/* ]]; then
            CATEGORIES["System Prompts"]+="$file|"
        elif [[ "$file" == workflows/sparc/* ]]; then
            CATEGORIES["SPARC Workflows"]+="$file|"
        elif [[ "$file" == cloud/* ]]; then
            CATEGORIES["Cloud Templates"]+="$file|"
        elif [[ "$file" == ai/* ]]; then
            CATEGORIES["AI Framework Templates"]+="$file|"
        elif [[ "$file" == messaging/* ]]; then
            CATEGORIES["Messaging Templates"]+="$file|"
        elif [[ "$file" == monitoring/* ]]; then
            CATEGORIES["Monitoring Templates"]+="$file|"
        elif [[ "$file" == security/* ]]; then
            CATEGORIES["Security Templates"]+="$file|"
        elif [[ "$file" == language/* ]]; then
            CATEGORIES["Language Templates (Single)"]+="$file|"
        elif [[ "$file" == languages/* ]]; then
            CATEGORIES["Language Templates (Structured)"]+="$file|"
        elif [[ "$file" == bits/* ]]; then
            CATEGORIES["Reusable Bits"]+="$file|"
        else
            CATEGORIES["Root Level Templates"]+="$file|"
        fi
    done

    # Output by category
    for category in "${!CATEGORIES[@]}"; do
        echo "### $category" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"

        IFS='|' read -ra FILES <<< "${CATEGORIES[$category]}"
        for file in "${FILES[@]}"; do
            if [ -n "$file" ]; then
                source_full="$SOURCE_DIR/$file"
                size=$(wc -c < "$source_full")

                # Determine target location
                target_path=""
                if [[ "$file" == system/* ]]; then
                    target_path="templates_data/prompt_library/$(basename "$file")"
                elif [[ "$file" == workflows/sparc/* ]]; then
                    target_path="templates_data/workflows/sparc/$(basename "$file")"
                elif [[ "$file" == cloud/* ]]; then
                    target_path="templates_data/code_generation/patterns/cloud/$(basename "$file")"
                elif [[ "$file" == ai/* ]]; then
                    target_path="templates_data/code_generation/patterns/ai/$(basename "$file")"
                elif [[ "$file" == messaging/* ]]; then
                    target_path="templates_data/code_generation/patterns/messaging/$(basename "$file")"
                elif [[ "$file" == monitoring/* ]]; then
                    target_path="templates_data/code_generation/patterns/monitoring/$(basename "$file")"
                elif [[ "$file" == security/* ]]; then
                    target_path="templates_data/code_generation/patterns/security/$(basename "$file")"
                elif [[ "$file" == language/* ]]; then
                    target_path="templates_data/code_generation/patterns/languages/$(basename "$file")"
                elif [[ "$file" == languages/* ]]; then
                    # Keep structure
                    target_path="templates_data/code_generation/patterns/${file}"
                elif [[ "$file" == bits/* ]]; then
                    # Keep structure
                    target_path="templates_data/code_generation/${file}"
                else
                    # Root level - needs categorization
                    target_path="templates_data/code_generation/patterns/$(basename "$file")"
                fi

                echo "- **$file**" >> "$REPORT_FILE"
                echo "  - Size: $size bytes" >> "$REPORT_FILE"
                echo "  - Target: \`$target_path\`" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"
            fi
        done
        echo "" >> "$REPORT_FILE"
    done
fi

echo "" >> "$REPORT_FILE"
echo "**Total Unique:** ${#UNIQUE_FILES[@]}" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Summary
echo "## Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **Identical files (skip):** ${#IDENTICAL_FILES[@]}" >> "$REPORT_FILE"
echo "- **Different files (manual review):** ${#DIFFERENT_FILES[@]}" >> "$REPORT_FILE"
echo "- **Unique files (copy):** ${#UNIQUE_FILES[@]}" >> "$REPORT_FILE"
echo "- **Total files analyzed:** $((${#IDENTICAL_FILES[@]} + ${#DIFFERENT_FILES[@]} + ${#UNIQUE_FILES[@]}))" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "Report generated: $REPORT_FILE"
