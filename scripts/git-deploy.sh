#!/bin/bash
# Git-triggered automatic deployment
# Usage: ./scripts/git-deploy.sh [message]
set -e

echo "🚀 Git Deploy - Automatic Deployment Script"
echo "=========================================="

# Get deployment message or use default
DEPLOY_MSG=${1:-"Auto-deployment triggered by git-deploy script"}
echo "📝 Deploy message: $DEPLOY_MSG"

# Get current git info
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT_SHA=$(git rev-parse --short HEAD)
COMMIT_MSG=$(git log -1 --pretty=format:'%s')

echo "📋 Git Information:"
echo "   Branch: $CURRENT_BRANCH"
echo "   Commit: $COMMIT_SHA"
echo "   Message: $COMMIT_MSG"

# Ensure we're on main branch
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "⚠️  Warning: Not on main branch. Continuing with $CURRENT_BRANCH"
fi

# Check if there are uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "📝 Uncommitted changes detected. Committing..."
    git add .
    git commit -m "$DEPLOY_MSG" || echo "Nothing new to commit"
fi

# Push to origin
echo "📤 Pushing to repository..."
git push origin $CURRENT_BRANCH

# Trigger deployment
echo "🎯 Triggering Kubernetes deployment..."
BUILD_NUMBER=$(date +%Y%m%d%H%M%S)
export BUILD_NUMBER
export GIT_COMMIT=$COMMIT_SHA

# Run the deployment
./scripts/simple-auto-deploy.sh

# Verify deployment
echo "🩺 Checking deployment health..."
sleep 5
kubectl -n demo get pods -l app=happy-speller
echo ""

# Test the application
echo "🧪 Testing application endpoints..."
echo "Health check:"
curl -s http://192.168.50.183:30080/healthz | head -1 || echo "Health check failed"

echo ""
echo "🎉 Git Deploy Complete!"
echo "📱 Your application is live at:"
echo "   🔗 http://192.168.50.183:30080"
echo "   🔗 http://192.168.50.226:30080"
echo "   🩺 Health: http://192.168.50.183:30080/healthz"
echo ""
echo "🔨 Build: $BUILD_NUMBER"
echo "📝 Commit: $COMMIT_SHA"