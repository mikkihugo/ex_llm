#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Resolving Template Conflicts${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

SOURCE_DIR="/home/mhugo/code/singularity/rust/package/templates"
TARGET_DIR="/home/mhugo/code/singularity/templates_data"

# File 1: elixir-nats-consumer.json
echo -e "${YELLOW}[1/3]${NC} Resolving elixir-nats-consumer.json"
echo "      Action: Remove source (keep target with unified schema)"
if [ -f "$SOURCE_DIR/elixir-nats-consumer.json" ]; then
    rm "$SOURCE_DIR/elixir-nats-consumer.json"
    echo -e "${GREEN}      ✓ Removed source version${NC}"
else
    echo -e "${YELLOW}      ! Source already removed${NC}"
fi
echo ""

# File 2: schema.json
echo -e "${YELLOW}[2/3]${NC} Resolving schema.json"
echo "      Action: Rename source (keep both - different purposes)"
if [ -f "$SOURCE_DIR/schema.json" ]; then
    mv "$SOURCE_DIR/schema.json" "$SOURCE_DIR/technology_detection_schema.json"
    echo -e "${GREEN}      ✓ Renamed to technology_detection_schema.json${NC}"
else
    echo -e "${YELLOW}      ! Source already renamed or missing${NC}"
fi
echo ""

# File 3: workflows/sparc/3-architecture.json
echo -e "${YELLOW}[3/3]${NC} Resolving workflows/sparc/3-architecture.json"
echo "      Action: Remove source (keep target v2.0.0 with composition)"
if [ -f "$SOURCE_DIR/workflows/sparc/3-architecture.json" ]; then
    rm "$SOURCE_DIR/workflows/sparc/3-architecture.json"
    echo -e "${GREEN}      ✓ Removed source version${NC}"
else
    echo -e "${YELLOW}      ! Source already removed${NC}"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}All conflicts resolved!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Summary:"
echo "  • elixir-nats-consumer.json: Kept target (unified schema)"
echo "  • schema.json: Kept both (renamed source to technology_detection_schema.json)"
echo "  • 3-architecture.json: Kept target (v2.0.0)"
echo ""
echo "Next steps:"
echo "  1. Run: ./migrate_templates.sh"
echo "  2. Validate: moon run templates_data:validate"
echo "  3. Sync to DB: moon run templates_data:sync-to-db"
echo ""
