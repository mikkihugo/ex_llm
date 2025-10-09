#!/bin/bash

cd /home/mhugo/code/singularity

find rust/package/templates/bits -type f -name "*.md" | while read file; do
    rel_path="${file#rust/package/templates/}"
    target="templates_data/code_generation/$rel_path"

    if [ -f "$target" ]; then
        hash1=$(md5sum "$file" | cut -d' ' -f1)
        hash2=$(md5sum "$target" | cut -d' ' -f1)

        if [ "$hash1" = "$hash2" ]; then
            echo "IDENTICAL: $rel_path"
        else
            echo "DIFFERENT: $rel_path"
        fi
    else
        echo "UNIQUE: $rel_path"
    fi
done
