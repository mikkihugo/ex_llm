#!/usr/bin/env bash
# One-time setup: Generate encryption key and store in fly.io
set -e

APP_NAME="${1:-singularity}"

echo "🔐 Setting up credential encryption for fly.io..."
echo ""

# Check if age is installed
if ! command -v age &> /dev/null; then
    echo "Installing age..."
    if command -v nix-env &> /dev/null; then
        nix-env -iA nixpkgs.age
    elif command -v brew &> /dev/null; then
        brew install age
    else
        echo "❌ Please install age: https://github.com/FiloSottile/age#installation"
        exit 1
    fi
fi

# Check flyctl
if ! command -v flyctl &> /dev/null; then
    echo "❌ flyctl not found. Install: https://fly.io/docs/hands-on/install-flyctl/"
    exit 1
fi

# Generate key if it doesn't exist
KEY_FILE=".age-key.txt"
if [ -f "$KEY_FILE" ]; then
    echo "✓ Using existing key: $KEY_FILE"
else
    echo "📝 Generating new encryption key..."
    age-keygen -o "$KEY_FILE"
    echo "✓ Key generated: $KEY_FILE"
fi

# Get the secret key content
SECRET_KEY=$(cat "$KEY_FILE")

echo ""
echo "🚀 Setting fly.io secret..."
flyctl secrets set AGE_SECRET_KEY="$SECRET_KEY" --app "$APP_NAME"

echo ""
echo "✅ Fly.io secret set!"
echo ""
echo "📋 Now add to GitHub Secrets:"
echo "  1. Go to: https://github.com/YOUR_ORG/YOUR_REPO/settings/secrets/actions"
echo "  2. Click 'New repository secret'"
echo "  3. Name: AGE_SECRET_KEY"
echo "  4. Value:"
echo ""
echo "──────────────────────────────────────"
cat "$KEY_FILE"
echo "──────────────────────────────────────"
echo ""
echo "⚠️  Security notes:"
echo "  ✓ Key in fly.io: AGE_SECRET_KEY (for runtime decryption)"
echo "  ✓ Key in GitHub: AGE_SECRET_KEY (for CI/CD)"
echo "  ✓ Local key: $KEY_FILE (keep safe, add to .gitignore)"
echo ""
echo "Next steps:"
echo "  1. Add to GitHub secrets (copy key above)"
echo "  2. Encrypt credentials: ./scripts/encrypt-credentials.sh"
echo "  3. Commit encrypted .age files: git add .credentials.encrypted/*.age"
echo "  4. Deploy - credentials auto-decrypt"
echo ""
