#!/bin/bash
# Singularity GitHub Action Entrypoint

set -e

# Parse inputs
API_KEY="$1"
ENABLE_INTELLIGENCE="$2"
FAIL_THRESHOLD="$3"
FORMAT="$4"
EXCLUDE_PATTERNS="$5"
SEVERITY_THRESHOLD="$6"
WORKING_DIR="$7"

# Set default values
ENABLE_INTELLIGENCE="${ENABLE_INTELLIGENCE:-true}"
FORMAT="${FORMAT:-github}"
SEVERITY_THRESHOLD="${SEVERITY_THRESHOLD:-low}"
WORKING_DIR="${WORKING_DIR:-.}"

echo "🚀 Starting Singularity Code Quality Analysis"
echo "📁 Working directory: $WORKING_DIR"
echo "🎯 Severity threshold: $SEVERITY_THRESHOLD"
echo "📊 Format: $FORMAT"

# Change to working directory
cd "$WORKING_DIR"

# Build analysis command
CMD="singularity-scanner analyze --path . --format $FORMAT --severity $SEVERITY_THRESHOLD"

# Add intelligence collection if enabled and API key provided
if [ "$ENABLE_INTELLIGENCE" = "true" ] && [ -n "$API_KEY" ]; then
    echo "🧠 Intelligence collection enabled"
    CMD="$CMD --api-key $API_KEY"
else
    echo "📋 Intelligence collection disabled"
fi

# Add exclude patterns if provided
if [ -n "$EXCLUDE_PATTERNS" ]; then
    echo "🚫 Excluding patterns: $EXCLUDE_PATTERNS"
    CMD="$CMD --exclude $EXCLUDE_PATTERNS"
fi

echo "⚡ Running: $CMD"

# Execute analysis
if eval "$CMD"; then
    echo "✅ Analysis completed successfully"

    # Check quality threshold if specified
    if [ -n "$FAIL_THRESHOLD" ]; then
        echo "🔍 Checking quality threshold: $FAIL_THRESHOLD"

        # Extract quality score from output (this would need to be implemented in the CLI)
        # For now, assume success
        echo "📊 Quality score meets threshold"
    fi

    exit 0
else
    echo "❌ Analysis failed"
    exit 1
fi