#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SOURCE_DIR="/home/mhugo/code/singularity/rust/package/templates"
TARGET_DIR="/home/mhugo/code/singularity/templates_data"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Template Migration Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    print_error "Source directory not found: $SOURCE_DIR"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    print_error "Target directory not found: $TARGET_DIR"
    exit 1
fi

print_info "Source: $SOURCE_DIR"
print_info "Target: $TARGET_DIR"
echo ""

# Step 1: Create directories
print_info "Step 1: Creating directories..."
mkdir -p "$TARGET_DIR/code_generation/patterns/cloud"
mkdir -p "$TARGET_DIR/code_generation/patterns/ai"
mkdir -p "$TARGET_DIR/code_generation/patterns/messaging"
mkdir -p "$TARGET_DIR/code_generation/patterns/monitoring"
mkdir -p "$TARGET_DIR/code_generation/patterns/security"
mkdir -p "$TARGET_DIR/code_generation/patterns/languages/python/fastapi"
mkdir -p "$TARGET_DIR/code_generation/patterns/languages/rust"
mkdir -p "$TARGET_DIR/code_generation/patterns/languages/typescript"
print_status "Directories created"
echo ""

# Counters
COPIED=0
SKIPPED=0
ERRORS=0

# Step 2: Copy system prompts
print_info "Step 2: Copying system prompts (7 files)..."
for file in "$SOURCE_DIR/system"/*.json; do
    if [ -f "$file" ]; then
        basename=$(basename "$file")
        target="$TARGET_DIR/prompt_library/$basename"

        if [ -f "$target" ]; then
            print_warning "Already exists: $basename (skipping)"
            ((SKIPPED++))
        else
            cp "$file" "$target"
            print_status "Copied: $basename"
            ((COPIED++))
        fi
    fi
done
echo ""

# Step 3: Copy SPARC workflows
print_info "Step 3: Copying SPARC workflows (6 files)..."
for file in "$SOURCE_DIR/workflows/sparc"/{0-research,4-architecture,5-security,6-performance,7-refinement,8-implementation}.json; do
    if [ -f "$file" ]; then
        basename=$(basename "$file")
        target="$TARGET_DIR/workflows/sparc/$basename"

        if [ -f "$target" ]; then
            print_warning "Already exists: $basename (skipping)"
            ((SKIPPED++))
        else
            cp "$file" "$target"
            print_status "Copied: $basename"
            ((COPIED++))
        fi
    fi
done
echo ""

# Step 4: Copy cloud templates
print_info "Step 4: Copying cloud templates (3 files)..."
for file in "$SOURCE_DIR/cloud"/*.json; do
    if [ -f "$file" ]; then
        basename=$(basename "$file")
        target="$TARGET_DIR/code_generation/patterns/cloud/$basename"

        if [ -f "$target" ]; then
            print_warning "Already exists: $basename (skipping)"
            ((SKIPPED++))
        else
            cp "$file" "$target"
            print_status "Copied: $basename"
            ((COPIED++))
        fi
    fi
done
echo ""

# Step 5: Copy AI framework templates
print_info "Step 5: Copying AI framework templates (3 files)..."
for file in "$SOURCE_DIR/ai"/*.json; do
    if [ -f "$file" ]; then
        basename=$(basename "$file")
        target="$TARGET_DIR/code_generation/patterns/ai/$basename"

        if [ -f "$target" ]; then
            print_warning "Already exists: $basename (skipping)"
            ((SKIPPED++))
        else
            cp "$file" "$target"
            print_status "Copied: $basename"
            ((COPIED++))
        fi
    fi
done
echo ""

# Step 6: Copy messaging templates
print_info "Step 6: Copying messaging templates (4 files)..."
for file in "$SOURCE_DIR/messaging"/*.json; do
    if [ -f "$file" ]; then
        basename=$(basename "$file")
        target="$TARGET_DIR/code_generation/patterns/messaging/$basename"

        if [ -f "$target" ]; then
            print_warning "Already exists: $basename (skipping)"
            ((SKIPPED++))
        else
            cp "$file" "$target"
            print_status "Copied: $basename"
            ((COPIED++))
        fi
    fi
done
echo ""

# Step 7: Copy monitoring templates
print_info "Step 7: Copying monitoring templates (4 files)..."
for file in "$SOURCE_DIR/monitoring"/*.json; do
    if [ -f "$file" ]; then
        basename=$(basename "$file")
        target="$TARGET_DIR/code_generation/patterns/monitoring/$basename"

        if [ -f "$target" ]; then
            print_warning "Already exists: $basename (skipping)"
            ((SKIPPED++))
        else
            cp "$file" "$target"
            print_status "Copied: $basename"
            ((COPIED++))
        fi
    fi
done
echo ""

# Step 8: Copy security templates
print_info "Step 8: Copying security templates (2 files)..."
for file in "$SOURCE_DIR/security"/*.json; do
    if [ -f "$file" ]; then
        basename=$(basename "$file")
        target="$TARGET_DIR/code_generation/patterns/security/$basename"

        if [ -f "$target" ]; then
            print_warning "Already exists: $basename (skipping)"
            ((SKIPPED++))
        else
            cp "$file" "$target"
            print_status "Copied: $basename"
            ((COPIED++))
        fi
    fi
done
echo ""

# Step 9: Copy language templates (single files)
print_info "Step 9: Copying language templates - single files (6 files)..."
for file in "$SOURCE_DIR/language"/*.json; do
    if [ -f "$file" ]; then
        basename=$(basename "$file")
        target="$TARGET_DIR/code_generation/patterns/languages/$basename"

        if [ -f "$target" ]; then
            print_warning "Already exists: $basename (skipping)"
            ((SKIPPED++))
        else
            cp "$file" "$target"
            print_status "Copied: $basename"
            ((COPIED++))
        fi
    fi
done
echo ""

# Step 10: Copy language templates (structured)
print_info "Step 10: Copying language templates - structured (5 files)..."

# Python
if [ -f "$SOURCE_DIR/languages/python/_base.json" ]; then
    target="$TARGET_DIR/code_generation/patterns/languages/python/_base.json"
    if [ -f "$target" ]; then
        print_warning "Already exists: python/_base.json (skipping)"
        ((SKIPPED++))
    else
        cp "$SOURCE_DIR/languages/python/_base.json" "$target"
        print_status "Copied: python/_base.json"
        ((COPIED++))
    fi
fi

if [ -f "$SOURCE_DIR/languages/python/fastapi/crud.json" ]; then
    target="$TARGET_DIR/code_generation/patterns/languages/python/fastapi/crud.json"
    if [ -f "$target" ]; then
        print_warning "Already exists: python/fastapi/crud.json (skipping)"
        ((SKIPPED++))
    else
        cp "$SOURCE_DIR/languages/python/fastapi/crud.json" "$target"
        print_status "Copied: python/fastapi/crud.json"
        ((COPIED++))
    fi
fi

# Rust
if [ -f "$SOURCE_DIR/languages/rust/_base.json" ]; then
    target="$TARGET_DIR/code_generation/patterns/languages/rust/_base.json"
    if [ -f "$target" ]; then
        print_warning "Already exists: rust/_base.json (skipping)"
        ((SKIPPED++))
    else
        cp "$SOURCE_DIR/languages/rust/_base.json" "$target"
        print_status "Copied: rust/_base.json"
        ((COPIED++))
    fi
fi

if [ -f "$SOURCE_DIR/languages/rust/microservice.json" ]; then
    target="$TARGET_DIR/code_generation/patterns/languages/rust/microservice.json"
    if [ -f "$target" ]; then
        print_warning "Already exists: rust/microservice.json (skipping)"
        ((SKIPPED++))
    else
        cp "$SOURCE_DIR/languages/rust/microservice.json" "$target"
        print_status "Copied: rust/microservice.json"
        ((COPIED++))
    fi
fi

# TypeScript
if [ -f "$SOURCE_DIR/languages/typescript/_base.json" ]; then
    target="$TARGET_DIR/code_generation/patterns/languages/typescript/_base.json"
    if [ -f "$target" ]; then
        print_warning "Already exists: typescript/_base.json (skipping)"
        ((SKIPPED++))
    else
        cp "$SOURCE_DIR/languages/typescript/_base.json" "$target"
        print_status "Copied: typescript/_base.json"
        ((COPIED++))
    fi
fi

echo ""

# Step 11: Copy root level templates
print_info "Step 11: Copying root level templates (10 files)..."

ROOT_FILES=(
    "UNIFIED_SCHEMA.json"
    "gleam-nats-consumer.json"
    "python-django.json"
    "python-fastapi.json"
    "rust-api-endpoint.json"
    "rust-microservice.json"
    "rust-nats-consumer.json"
    "sparc-implementation.json"
    "typescript-api-endpoint.json"
    "typescript-microservice.json"
)

for filename in "${ROOT_FILES[@]}"; do
    file="$SOURCE_DIR/$filename"
    if [ -f "$file" ]; then
        target="$TARGET_DIR/code_generation/patterns/$filename"

        if [ -f "$target" ]; then
            print_warning "Already exists: $filename (skipping)"
            ((SKIPPED++))
        else
            cp "$file" "$target"
            print_status "Copied: $filename"
            ((COPIED++))
        fi
    else
        print_warning "Not found: $filename"
    fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Migration Summary${NC}"
echo -e "${BLUE}========================================${NC}"
print_status "Files copied: $COPIED"
print_warning "Files skipped: $SKIPPED"
if [ $ERRORS -gt 0 ]; then
    print_error "Errors: $ERRORS"
fi
echo ""

# Step 12: List files that need manual review
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Files Requiring Manual Review${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
print_warning "1. elixir-nats-consumer.json"
echo "   Source: rust/package/templates/elixir-nats-consumer.json (6,307 bytes)"
echo "   Target: templates_data/code_generation/patterns/messaging/elixir-nats-consumer.json (6,619 bytes)"
echo "   Recommendation: KEEP TARGET (newer schema)"
echo ""
print_warning "2. schema.json"
echo "   Source: rust/package/templates/schema.json (4,900 bytes - Technology Detection)"
echo "   Target: templates_data/schema.json (6,192 bytes - Unified Schema)"
echo "   Recommendation: RENAME source to 'technology_detection_schema.json'"
echo ""
print_warning "3. workflows/sparc/3-architecture.json"
echo "   Source: rust/package/templates/workflows/sparc/3-architecture.json (2,117 bytes - v1.0.0)"
echo "   Target: templates_data/workflows/sparc/3-architecture.json (653 bytes - v2.0.0)"
echo "   Recommendation: KEEP TARGET (newer version)"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Next Steps${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "1. Review the 3 files listed above manually"
echo "2. Validate templates: moon run templates_data:validate"
echo "3. Sync to database: moon run templates_data:sync-to-db"
echo "4. Generate embeddings: moon run templates_data:embed-all"
echo "5. Archive source: mv rust/package/templates rust/package/templates.archived"
echo ""
print_status "Migration complete!"
