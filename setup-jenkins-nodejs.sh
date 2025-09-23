#!/bin/bash

echo "🔧 Jenkins Node.js Setup Guide"
echo "=============================="
echo ""

echo "🎯 This script will help you configure Node.js in Jenkins"
echo ""

JENKINS_URL="http://192.168.50.247:8080"
echo "Jenkins URL: $JENKINS_URL"
echo ""

echo "📋 Steps to configure Node.js in Jenkins:"
echo ""

echo "1️⃣ INSTALL NODEJS PLUGIN"
echo "------------------------"
echo "   • Go to: $JENKINS_URL/manage/pluginManager/"
echo "   • Search for 'NodeJS Plugin'"
echo "   • Install it (if not already installed)"
echo ""

echo "2️⃣ CONFIGURE NODEJS TOOL"
echo "------------------------"
echo "   • Go to: $JENKINS_URL/manage/configureTools/"
echo "   • Scroll to 'NodeJS' section"
echo "   • Click 'Add NodeJS'"
echo "   • Configuration:"
echo "     ✅ Name: NodeJS-18"
echo "     ✅ Install automatically: ✓ (checked)"
echo "     ✅ Version: NodeJS 18.x (latest LTS)"
echo "     ✅ Global npm packages to install: (leave empty for now)"
echo "   • Click 'Save'"
echo ""

echo "3️⃣ ALTERNATIVE: MANUAL NODEJS INSTALLATION"
echo "-------------------------------------------"
echo "If the Jenkins NodeJS plugin doesn't work, install Node.js directly on Jenkins agent:"
echo ""

cat > install-nodejs-on-jenkins.sh << 'EOF'
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
EOF

chmod +x install-nodejs-on-jenkins.sh

echo "   Script created: install-nodejs-on-jenkins.sh"
echo "   Copy this script to your Jenkins server and run it"
echo ""

echo "4️⃣ TEST THE CONFIGURATION"
echo "-------------------------"
echo "   Create a test pipeline with this content:"
echo ""

cat > test-pipeline.groovy << 'EOF'
pipeline {
  agent any
  tools {
    nodejs 'NodeJS-18' // This name must match your Jenkins configuration
  }
  stages {
    stage('Check Node') {
      steps {
        sh 'echo $PATH && which node && node -v && npm -v'
      }
    }
  }
}
EOF

echo "   Pipeline script created: test-pipeline.groovy"
echo ""

echo "5️⃣ TROUBLESHOOTING"
echo "------------------"
echo "   If Node.js is still not found:"
echo ""
echo "   A) Check Jenkins system configuration:"
echo "      • Go to: $JENKINS_URL/manage/systemInfo/"
echo "      • Look for PATH environment variable"
echo ""
echo "   B) Check Jenkins global configuration:"
echo "      • Go to: $JENKINS_URL/manage/configure/"
echo "      • Add to 'Environment variables':"
echo "        Name: PATH"
echo "        Value: /usr/bin:/usr/local/bin:\$PATH"
echo ""
echo "   C) SSH into Jenkins server and manually verify:"
echo "      • ssh into your Jenkins server"
echo "      • Run: sudo -u jenkins node -v"
echo "      • Run: sudo -u jenkins which node"
echo ""

echo "6️⃣ COMMIT YOUR UPDATED JENKINSFILE"
echo "----------------------------------"
echo "   Your Jenkinsfile has been updated with:"
echo "   ✅ NodeJS tool configuration"
echo "   ✅ Better Node.js detection"
echo "   ✅ Automatic Node.js installation fallback"
echo "   ✅ Improved error handling"
echo ""

echo "🚀 Next Steps:"
echo "1. Configure NodeJS tool in Jenkins UI (steps 1-2 above)"
echo "2. Commit the updated Jenkinsfile to your repo"
echo "3. Trigger a build to test the configuration"
echo ""

# Check if we can reach Jenkins
if curl -s --connect-timeout 5 "$JENKINS_URL" >/dev/null; then
    echo "✅ Jenkins is accessible at $JENKINS_URL"
    echo "🔗 Quick links:"
    echo "   • Plugin Manager: $JENKINS_URL/manage/pluginManager/"
    echo "   • Global Tool Configuration: $JENKINS_URL/manage/configureTools/"
    echo "   • System Information: $JENKINS_URL/manage/systemInfo/"
else
    echo "⚠️  Cannot reach Jenkins at $JENKINS_URL"
    echo "   Make sure Jenkins is running and accessible"
fi

echo ""
echo "🎊 Jenkins Node.js setup guide completed!"