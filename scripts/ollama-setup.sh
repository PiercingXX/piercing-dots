#!/bin/bash

# Ollama Install and Migration Script
# Installs Ollama (if needed) and moves models directory to a custom location

set -e  # Exit on any error

SOURCE="/usr/share/ollama/.ollama/models"
TARGET="/media/Working-Storage/.ollama-models"
SERVICE="ollama"

echo "=== Ollama Install & Migration Script ==="
echo "Target models directory: $TARGET"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run with sudo"
   exit 1
fi

# Check and install rsync if necessary
if ! command -v rsync &> /dev/null; then
    echo "📦 rsync not found. Installing..."
    
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y rsync
    elif command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm rsync
    elif command -v dnf &> /dev/null; then
        dnf install -y rsync
    elif command -v yum &> /dev/null; then
        yum install -y rsync
    else
        echo "❌ Could not determine package manager. Please install rsync manually:"
        echo "   apt: sudo apt-get install rsync"
        echo "   arch: sudo pacman -S rsync"
        echo "   fedora: sudo dnf install rsync"
        echo "   centos: sudo yum install rsync"
        exit 1
    fi
    echo "✅ rsync installed successfully"
else
    echo "✅ rsync is already installed"
fi

# Check and install Ollama if necessary
if ! command -v ollama &> /dev/null; then
    echo ""
    echo "📦 Ollama not found. Installing from official source..."
    curl -fsSL https://ollama.com/install.sh | sh
    echo "✅ Ollama installed successfully"
    sleep 2
else
    echo "✅ Ollama is already installed"
fi

# Ollama model pulling (optional - uncomment to pull specific models)
    # Tiny models for testing and low VRAM:
        #ollama pull kimi-k2.5:cloud
        #ollama pull mistral:7b
        #ollama pull gemma3:12b
        #ollama pull gpt-oss:20b
        #ollama pull gemma3:27b-it-qat
        #ollama pull codellama:34b
    # Better Models, more vram usage:
        #ollama pull qwen3-coder:30b
        #ollama pull qwq:32b
        #ollama pull deepseek-r1:70b
        #ollama pull llama3.3:70b
        #ollama pull llama3.2-vision:90b
        #ollama pull command-r-plus:104b
        #ollama pull gpt-oss:120b
        #ollama pull qwen3.5:122b
        #ollama pull milkey/deepseek-v2.5-1210-UD:IQ1_M
        #ollama pull qwen3-coder-next:q4_K_M
        #ollama pull qwen3-coder-next:q8_0


# Check if target already has models (indicates migration was already done)
if [ -d "$TARGET" ] && [ "$(ls -A $TARGET 2>/dev/null)" ]; then
    echo ""
    echo "=== Models Already Migrated ==="
    echo "✅ Target directory already has models: $TARGET"
    echo "ℹ️  Skipping migration (already completed)"
    MIGRATION_NEEDED=false
else
    MIGRATION_NEEDED=true
fi

if [ "$MIGRATION_NEEDED" = true ]; then
    # Check if source exists (it should after install)
    if [ ! -d "$SOURCE" ]; then
        echo "❌ Source directory does not exist: $SOURCE"
        echo "   Ollama may not have initialized yet. Please try again after starting Ollama."
        exit 1
    fi

    echo ""
    echo "=== Beginning Model Migration ==="
    echo "Source: $SOURCE"
    echo "Target: $TARGET"
    echo ""

    # Check if service is running
    if systemctl is-active --quiet $SERVICE; then
        echo "⏹️  Stopping ollama service..."
        systemctl stop $SERVICE
        sleep 2
    else
        echo "ℹ️  ollama service is not running"
    fi

    # Create target parent directory if it doesn't exist
    echo "📁 Creating target directory..."
    mkdir -p "$TARGET"

    # Copy models (only if there are models to copy)
    if [ "$(ls -A $SOURCE)" ]; then
        echo "📋 Copying models (this may take a while)..."
        rsync -av --progress "$SOURCE/" "$TARGET/"
        echo "✅ Models copied successfully"
        
        # Remove original models directory after successful copy
        echo "🗑️  Removing original model files..."
        rm -rf "$SOURCE"
        echo "✅ Original directory removed"
    else
        echo "ℹ️  No existing models to copy"
        echo "📁 Target directory ready for new models"
    fi
fi

# Fix permissions
echo "🔐 Setting permissions for ollama user..."
chown -R ollama:ollama "$TARGET"
chmod -R u+rwX,g+rX,o-rwx "$TARGET"

# Create systemd override directory
echo "⚙️  Configuring systemd service..."
mkdir -p /etc/systemd/system/${SERVICE}.service.d

# Write the override file
cat > /etc/systemd/system/${SERVICE}.service.d/override.conf <<EOF
[Service]
Environment="OLLAMA_MODELS=$TARGET"
EOF

echo "📝 Created systemd override at /etc/systemd/system/${SERVICE}.service.d/override.conf"

# Reload systemd
echo "🔄 Reloading systemd daemon..."
systemctl daemon-reload

# Start the service
echo "▶️  Starting ollama service..."
systemctl start $SERVICE
sleep 3

echo ""
echo "=== Verification ==="

# Check systemd environment
echo "Checking systemd configuration..."
systemctl show $SERVICE -p Environment | grep OLLAMA_MODELS || echo "⚠️  Environment var not found"

# Check journal for errors
echo ""
echo "Checking service logs (last 20 lines)..."
journalctl -u $SERVICE -n 20 --no-pager | grep -i error || echo "✅ No errors in logs"

# Check if models are accessible
echo ""
echo "✅ Installation & Migration Complete!"
echo ""
echo "All model files have been successfully moved to: $TARGET"
echo ""
echo "Next steps:"
echo "1. Verify models are accessible: ollama list"
echo "2. Test with a model: ollama pull <model-name>"
echo "3. Confirm new models are stored in: $TARGET"