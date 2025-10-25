#!/usr/bin/env bash
# Encrypt credential files for safe distribution
# Uses age encryption (simple, secure, modern)

set -e

CREDENTIALS_DIR="${1:-.credentials}"
OUTPUT_DIR="${2:-.credentials.encrypted}"

echo "🔐 Encrypting credentials for safe distribution..."
echo ""

# Check if age is installed
if ! command -v age &> /dev/null; then
    echo "❌ age not found. Install with:"
    echo "   macOS: brew install age"
    echo "   Linux: apt install age / pacman -S age / nix-env -iA nixpkgs.age"
    echo "   Or download from: https://github.com/FiloSottile/age/releases"
    exit 1
fi

# Generate encryption key if it doesn't exist
KEY_FILE=".age-key.txt"
if [ ! -f "$KEY_FILE" ]; then
    echo "📝 Generating new age encryption key..."
    age-keygen -o "$KEY_FILE"
    echo ""
    echo "⚠️  IMPORTANT: Store this key securely!"
    echo "   Key saved to: $KEY_FILE"
    echo "   Add to .gitignore and fly.io secrets"
    echo ""
fi

# Get public key
PUBLIC_KEY=$(age-keygen -y "$KEY_FILE")
echo "Public key: $PUBLIC_KEY"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Encrypt each credential file
echo "Encrypting credential files..."

# Gemini ADC
if [ -f ~/.config/gcloud/application_default_credentials.json ]; then
    age -r "$PUBLIC_KEY" -o "$OUTPUT_DIR/gcloud-adc.json.age" \
        ~/.config/gcloud/application_default_credentials.json
    echo "✓ Encrypted: gcloud-adc.json.age"
fi

# Claude credentials
if [ -f ~/.claude/.credentials.json ]; then
    age -r "$PUBLIC_KEY" -o "$OUTPUT_DIR/claude-credentials.json.age" \
        ~/.claude/.credentials.json
    echo "✓ Encrypted: claude-credentials.json.age"
fi

# Cursor auth
if [ -f ~/.config/cursor/auth.json ]; then
    age -r "$PUBLIC_KEY" -o "$OUTPUT_DIR/cursor-auth.json.age" \
        ~/.config/cursor/auth.json
    echo "✓ Encrypted: cursor-auth.json.age"
fi

echo ""
echo "✅ Credentials encrypted!"
echo ""
echo "📦 Encrypted files in: $OUTPUT_DIR/"
echo "   These are SAFE to commit to git"
echo ""
echo "🔑 Encryption key: $KEY_FILE"
echo "   ⚠️  Keep this secret! Add to:"
echo "   1. .gitignore (local)"
echo "   2. fly.io secrets (deployment)"
echo ""
echo "To deploy:"
echo "  1. Add to .gitignore:"
echo "     echo '$KEY_FILE' >> .gitignore"
echo ""
echo "  2. Set fly.io secret:"
echo "     flyctl secrets set AGE_SECRET_KEY=\"\$(cat $KEY_FILE)\" --app singularity"
echo ""
echo "  3. Commit encrypted files:"
echo "     git add $OUTPUT_DIR/"
echo "     git commit -m 'Add encrypted credentials'"
echo ""
