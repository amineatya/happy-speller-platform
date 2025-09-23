#!/bin/bash
# Simple automatic deployment script
set -e

echo "🚀 Starting automatic deployment..."

# Get build information
BUILD_NUMBER=${BUILD_NUMBER:-$(date +%Y%m%d%H%M%S)}
COMMIT_SHA=${GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo "local")}
NAMESPACE=${NAMESPACE:-demo}
APP_NAME=${APP_NAME:-happy-speller}

echo "📋 Deployment Info:"
echo "   Build: $BUILD_NUMBER"
echo "   Commit: $COMMIT_SHA"
echo "   Namespace: $NAMESPACE"
echo "   App: $APP_NAME"

# Simple approach: Just restart the deployment with new annotations
echo "🔄 Triggering deployment restart..."
kubectl -n $NAMESPACE patch deployment $APP_NAME -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"kubectl.kubernetes.io/restartedAt\":\"$(date -Iseconds)\",\"build.number\":\"$BUILD_NUMBER\",\"git.commit\":\"$COMMIT_SHA\"}}}}}"

# Wait for rollout
echo "⏳ Waiting for deployment rollout..."
kubectl -n $NAMESPACE rollout status deployment/$APP_NAME --timeout=300s

# Verify deployment
echo "✅ Verifying deployment..."
kubectl -n $NAMESPACE get pods -l app=$APP_NAME

echo "🎉 Automatic deployment completed!"
echo "📱 Your app is running at:"
echo "   - http://192.168.50.183:30080"
echo "   - http://192.168.50.226:30080"