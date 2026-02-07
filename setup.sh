#!/bin/bash
set -euo pipefail
 
# Install Go (latest), Claude Code, and OpenCode on Ubuntu 
 
echo "==> Installing dependencies..."
sudo apt-get update
sudo apt-get install -y curl wget git
 
# Install latest Go
echo "==> Installing Go (latest)..." 
GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -1)
wget -q "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz 
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz 
rm /tmp/go.tar.gz
 
# Add Go and local bin to PATH if not already present
if ! grep -q '/usr/local/go/bin' ~/.bashrc; then 
echo 'export PATH="$HOME/.local/bin:$PATH:/usr/local/go/bin:$HOME/go/bin"' >> ~/.bashrc
fi 
export PATH="$HOME/.local/bin:$PATH:/usr/local/go/bin:$HOME/go/bin"
 
echo "==> Go installed: $(/usr/local/go/bin/go version)" 
 
# Install Claude Code (native installer - recommended) 
echo "==> Installing Claude Code..." 
curl -fsSL https://claude.ai/install.sh | bash 
 
echo "==> Claude Code installed" 
 
# Install OpenCode via curl installer
echo "==> Installing OpenCode..."
curl -fsSL https://opencode.ai/install | bash
 
echo "==> OpenCode installed"
 
echo ""
echo "==> Installation complete!"
echo "Run 'source ~/.bashrc' or open a new terminal to update PATH"
echo "Then run 'claude' to start Claude Code"
echo "Or run 'opencode' to start OpenCode"