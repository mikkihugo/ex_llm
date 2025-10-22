#!/usr/bin/env bash
set -e

# Script to test Copilot setup steps without installing Nix
# This validates that the copilot-setup-steps.yml workflow is properly configured

echo "🧪 Testing Copilot Setup Steps"
echo "================================"
echo ""

ERRORS=0
WARNINGS=0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print success
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error
error() {
    echo -e "${RED}✗${NC} $1"
    ERRORS=$((ERRORS + 1))
}

# Function to print warning
warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

# Function to print info
info() {
    echo "ℹ $1"
}

echo "1. Checking YAML Syntax"
echo "-----------------------"

# Check if the workflow file exists
WORKFLOW_FILE=".github/workflows/copilot-setup-steps.yml"
if [ ! -f "$WORKFLOW_FILE" ]; then
    error "Workflow file not found: $WORKFLOW_FILE"
else
    success "Workflow file found"
    
    # Check for duplicate 'run:' keys using Python YAML parser
    if command -v python3 &> /dev/null; then
        if python3 -c "
import sys
import yaml
from collections import defaultdict
class DuplicateKeyDetector(yaml.SafeLoader):
    def construct_mapping(self, node, deep=False):
        mapping = {}
        keys = defaultdict(int)
        for key_node, value_node in node.value:
            key = self.construct_object(key_node, deep=deep)
            keys[key] += 1
            if keys[key] > 1 and key == 'run':
                raise yaml.YAMLError(f\"Duplicate 'run:' key detected at line {key_node.start_mark.line+1}\")
            value = self.construct_object(value_node, deep=deep)
            mapping[key] = value
        return mapping
try:
    with open('$WORKFLOW_FILE') as f:
        yaml.load(f, Loader=DuplicateKeyDetector)
except yaml.YAMLError as e:
    print(e)
    sys.exit(1)
" ; then
            success "No duplicate 'run:' keys found"
        else
            error "YAML syntax error detected: Multiple 'run:' keys on same level"
        fi
    else
        warning "Python3 not available for duplicate key validation"
    fi
    
    # Validate YAML structure (basic check)
    if command -v python3 &> /dev/null; then
        if python3 -c "import yaml" &>/dev/null; then
            if python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW_FILE'))" 2>/dev/null; then
                success "YAML syntax is valid"
            else
                error "YAML syntax validation failed"
            fi
        else
            warning "PyYAML not found, skipping YAML syntax validation. (pip install pyyaml)"
        fi
    else
        warning "Python3 not available for YAML validation"
    fi
fi

echo ""
echo "2. Checking Required Tool Availability"
echo "---------------------------------------"
info "Note: These tools will be installed by the workflow"

# Check for Elixir
if command -v elixir &> /dev/null; then
    VERSION=$(elixir --version | grep Elixir | awk '{print $2}')
    success "Elixir found: version $VERSION"
else
    info "Elixir not found (workflow will install via erlef/setup-beam@v1)"
fi

# Check for Erlang/OTP
if command -v erl &> /dev/null; then
    VERSION=$(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell 2>/dev/null || echo "unknown")
    success "Erlang/OTP found: version $VERSION"
else
    info "Erlang/OTP not found (workflow will install via erlef/setup-beam@v1)"
fi

# Check for Bun
if command -v bun &> /dev/null; then
    VERSION=$(bun --version)
    success "Bun found: version $VERSION"
else
    info "Bun not found (workflow will install via oven-sh/setup-bun@v2)"
fi

# Check for Mix (Elixir build tool)
if command -v mix &> /dev/null; then
    success "Mix (Elixir build tool) found"
else
    info "Mix not found (comes with Elixir installation)"
fi

echo ""
echo "3. Checking PostgreSQL Service"
echo "-------------------------------"

# Check if PostgreSQL is running
if command -v psql &> /dev/null; then
    VERSION=$(psql --version | awk '{print $3}')
    success "PostgreSQL client found: version $VERSION"
    
    # Try to connect to PostgreSQL (workflow uses port 5432 with password 'postgres')
    if PGPASSWORD=postgres psql -h localhost -U postgres -p 5432 -c "SELECT 1;" &> /dev/null; then
        success "PostgreSQL service is accessible on port 5432"
    else
        warning "PostgreSQL service not accessible (this is okay for local testing)"
        info "Workflow will start PostgreSQL service container"
    fi
else
    error "PostgreSQL client (psql) not found"
fi

echo ""
echo "4. Checking Project Structure"
echo "------------------------------"

# Check for singularity directory
if [ -d "singularity" ]; then
    success "singularity directory exists"
    
    # Check for mix.exs
    if [ -f "singularity/mix.exs" ]; then
        success "mix.exs found in singularity"
    else
        error "mix.exs not found in singularity"
    fi
    
    # Check for mix.lock
    if [ -f "singularity/mix.lock" ]; then
        success "mix.lock found (for dependency caching)"
    else
        warning "mix.lock not found (cache key will not work)"
    fi
else
    error "singularity directory not found"
fi

# Check for llm-server directory
if [ -d "llm-server" ]; then
    success "llm-server directory exists"
    
    # Check for package.json
    if [ -f "llm-server/package.json" ]; then
        success "package.json found in llm-server"
    else
        error "package.json not found in llm-server"
    fi
    
    # Check for bun.lockb
    if [ -f "llm-server/bun.lockb" ]; then
        success "bun.lockb found (for dependency management)"
    else
        warning "bun.lockb not found"
    fi
else
    error "llm-server directory not found"
fi

echo ""
echo "5. Testing Dependency Installation Steps"
echo "-----------------------------------------"

# Test mix deps.get (if Elixir is available)
if command -v mix &> /dev/null && [ -d "singularity" ]; then
    info "Testing 'mix deps.get' in singularity..."
    cd singularity
    
    timeout 60 mix deps.get 2>&1 | tee /tmp/mix-deps.log
    MIX_EXIT_CODE=${PIPESTATUS[0]}
    if [ "$MIX_EXIT_CODE" -eq 0 ]; then
        success "mix deps.get completed successfully"
    else
        if grep -qi "error" /tmp/mix-deps.log; then
            error "mix deps.get failed with errors"
            cat /tmp/mix-deps.log | tail -10
        else
            warning "mix deps.get failed but no explicit error found in output"
        fi
    fi
    cd ..
else
    warning "Skipping mix deps.get test (mix not available or singularity missing)"
fi

# Test bun install (if Bun is available)
if command -v bun &> /dev/null && [ -d "llm-server" ]; then
    info "Testing 'bun install' in llm-server..."
    cd llm-server
    
    timeout 60 bun install 2>&1 | tee /tmp/bun-install.log
    BUN_EXIT_CODE=${PIPESTATUS[0]}
    if [ "$BUN_EXIT_CODE" -eq 0 ]; then
        success "bun install completed"
    else
        error "bun install failed"
        cat /tmp/bun-install.log | tail -10
    fi
    cd ..
else
    warning "Skipping bun install test (bun not available or llm-server missing)"
fi

echo ""
echo "6. Checking Workflow File Completeness"
echo "---------------------------------------"

# Check if workflow has all necessary steps
REQUIRED_STEPS=("Set up Elixir" "Install Bun" "Checkout code" "Cache deps")

for step in "${REQUIRED_STEPS[@]}"; do
    if grep -q "name: $step" "$WORKFLOW_FILE"; then
        success "Workflow step found: $step"
    else
        error "Workflow step missing: $step"
    fi
done

# Check for PostgreSQL service configuration
if grep -q "services:" "$WORKFLOW_FILE" && grep -q "db:" "$WORKFLOW_FILE"; then
    success "PostgreSQL service configuration found"
else
    error "PostgreSQL service configuration missing"
fi

echo ""
echo "7. Checking for Nix Dependencies"
echo "---------------------------------"

# Verify we're NOT using Nix in the workflow
if grep -qE "\bnix\b|\bdirenv\b" "$WORKFLOW_FILE"; then
    warning "Workflow file contains references to Nix/direnv"
    info "This workflow should work without Nix installation"
else
    success "No Nix dependencies found in workflow (as expected)"
fi

# Check if .envrc exists (would require direnv)
if [ -f ".envrc" ]; then
    info ".envrc file exists (used for local Nix development)"
    success "But workflow doesn't require it"
else
    info "No .envrc file found"
fi

echo ""
echo "================================"
echo "📊 Test Summary"
echo "================================"
echo ""

# Critical errors are only structural issues with the workflow file itself
# Missing tools are expected since the workflow will install them

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "The copilot-setup-steps.yml workflow is properly configured."
    echo "It can run without Nix installation on GitHub Actions."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Tests completed with $WARNINGS warning(s)${NC}"
    echo ""
    echo "The workflow should work, but some optional features may not be available."
    exit 0
else
    echo -e "${RED}✗ Tests failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please fix the errors before using this workflow."
    echo ""
    echo "Note: Missing tools (Elixir, Bun, etc.) are expected and will be"
    echo "      installed by the workflow. Only structural errors are critical."
    exit 1
fi
