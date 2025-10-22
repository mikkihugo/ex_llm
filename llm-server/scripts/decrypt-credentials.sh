#!/usr/bin/env bash
# Decrypt credentials at runtime using AGE_SECRET_KEY from fly.io secrets
# This runs automatically at startup on fly.io

set -e

ENCRYPTED_DIR="${1:-.credentials.encrypted}"

echo "🔓 Decrypting credentials..."

# Check if age is available
if ! command -v age &> /dev/null; then
    echo "⚠️  age not found, installing..."
    # Install age from nixpkgs (available in Nix environment)
    nix-env -iA nixpkgs.age 2>/dev/null || {
        echo "❌ Failed to install age"
        exit 1
    }
fi

# Check for secret key in environment
if [ -z "$AGE_SECRET_KEY" ]; then
    echo "❌ AGE_SECRET_KEY not found in environment"
    echo "   Set it with: flyctl secrets set AGE_SECRET_KEY=<key> --app singularity"
    exit 1
fi

# Create temporary key file
KEY_FILE=$(mktemp)
echo "$AGE_SECRET_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

# Ensure directories exist
mkdir -p ~/.config/gcloud
mkdir -p ~/.config/cursor
mkdir -p ~/.claude

# Decrypt Gemini ADC
if [ -f "$ENCRYPTED_DIR/gcloud-adc.json.age" ]; then
    age -d -i "$KEY_FILE" -o ~/.config/gcloud/application_default_credentials.json \
        "$ENCRYPTED_DIR/gcloud-adc.json.age"
    chmod 600 ~/.config/gcloud/application_default_credentials.json
    echo "✓ Decrypted: Gemini ADC credentials"
fi

# Decrypt Claude credentials
if [ -f "$ENCRYPTED_DIR/claude-credentials.json.age" ]; then
    age -d -i "$KEY_FILE" -o ~/.claude/.credentials.json \
        "$ENCRYPTED_DIR/claude-credentials.json.age"
    chmod 600 ~/.claude/.credentials.json
    echo "✓ Decrypted: Claude credentials"
fi

# Decrypt Cursor auth
if [ -f "$ENCRYPTED_DIR/cursor-auth.json.age" ]; then
    age -d -i "$KEY_FILE" -o ~/.config/cursor/auth.json \
        "$ENCRYPTED_DIR/cursor-auth.json.age"
    chmod 600 ~/.config/cursor/auth.json
    echo "✓ Decrypted: Cursor credentials"
fi

# Clean up key file
rm -f "$KEY_FILE"

echo "✅ Credentials decrypted and ready"
echo ""
