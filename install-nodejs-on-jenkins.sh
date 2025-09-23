#!/bin/bash
# Run this script on your Jenkins server/agent

echo "Installing Node.js 18.x on Jenkins agent..."

# Update system
sudo apt-get update

# Install Node.js via NodeSource
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

# Set permissions for jenkins user
sudo chown -R jenkins:jenkins /usr/lib/node_modules/ 2>/dev/null || echo "Could not change node_modules ownership"

# Add to jenkins PATH (add to ~/.bashrc or /etc/environment)
echo 'export PATH=/usr/bin:$PATH' | sudo tee -a /var/lib/jenkins/.bashrc

echo "✅ Node.js installation completed!"
