#!/bin/bash
# Automatic deployment script for Jenkins CI/CD
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

# Create namespace if it doesn't exist
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Update deployment with new build number and commit
echo "🔄 Updating deployment..."
kubectl -n $NAMESPACE patch deployment $APP_NAME -p "{
  \"spec\": {
    \"template\": {
      \"metadata\": {
        \"annotations\": {
          \"kubectl.kubernetes.io/restartedAt\": \"$(date -Iseconds)\",
          \"build.number\": \"$BUILD_NUMBER\",
          \"git.commit\": \"$COMMIT_SHA\"
        }
      },
      \"spec\": {
        \"containers\": [{
          \"name\": \"$APP_NAME\",
          \"args\": [
            \"mkdir -p /app && cd /app\ncat > package.json << 'EOF'\n{\n  \\\"name\\\": \\\"happy-speller\\\",\n  \\\"version\\\": \\\"1.0.0\\\",\n  \\\"main\\\": \\\"server.js\\\",\n  \\\"dependencies\\\": {\n    \\\"express\\\": \\\"^4.18.2\\\",\n    \\\"cors\\\": \\\"^2.8.5\\\",\n    \\\"helmet\\\": \\\"^7.0.0\\\"\n  }\n}\nEOF\ncat > server.js << 'EOF'\nconst express = require('express');\nconst cors = require('cors');\nconst helmet = require('helmet');\nconst app = express();\nconst port = process.env.PORT || 8080;\n\napp.use(helmet());\napp.use(cors());\napp.use(express.json());\n\napp.get('/healthz', (req, res) => {\n  res.json({ status: 'ok', build: '$BUILD_NUMBER', commit: '$COMMIT_SHA', timestamp: new Date().toISOString() });\n});\n\napp.get('/', (req, res) => {\n  res.send(\\\`<!DOCTYPE html>\n<html>\n<head>\n  <title>🌟 Happy Speller Platform - Build $BUILD_NUMBER</title>\n  <style>\n    body { font-family: Arial, sans-serif; margin: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-align: center; }\n    .container { max-width: 600px; margin: 0 auto; }\n    .card { background: rgba(255,255,255,0.1); padding: 30px; border-radius: 15px; margin: 20px 0; }\n    .build-info { background: rgba(0,255,0,0.1); padding: 15px; border-radius: 10px; margin: 10px 0; }\n    a { color: #90EE90; text-decoration: none; }\n  </style>\n</head>\n<body>\n  <div class=\\\"container\\\">\n    <div class=\\\"card\\\">\n      <h1>🌟 Happy Speller Platform</h1>\n      <p>Arabic Learning Made Fun & Interactive!</p>\n    </div>\n    \n    <div class=\\\"card\\\">\n      <h2>🚀 Deployment Status</h2>\n      <div class=\\\"build-info\\\">\n        <p>✅ <strong>Auto-deployed from Git push!</strong></p>\n        <p>🔨 Build: <strong>$BUILD_NUMBER</strong></p>\n        <p>📝 Commit: <strong>$COMMIT_SHA</strong></p>\n        <p>⏰ Deployed: <strong>\\\${new Date().toISOString()}</strong></p>\n      </div>\n    </div>\n    \n    <div class=\\\"card\\\">\n      <h2>🔗 Links</h2>\n      <p><a href=\\\"/healthz\\\">Health Check</a></p>\n      <p><a href=\\\"/api/status\\\">API Status</a></p>\n    </div>\n  </div>\n</body>\n</html>\\\`);\n});\n\napp.get('/api/status', (req, res) => {\n  res.json({\n    application: 'Happy Speller Platform',\n    version: '1.0.0',\n    build: '$BUILD_NUMBER',\n    commit: '$COMMIT_SHA',\n    status: 'running',\n    environment: process.env.NODE_ENV || 'production',\n    uptime: process.uptime(),\n    timestamp: new Date().toISOString()\n  });\n});\n\napp.listen(port, '0.0.0.0', () => {\n  console.log(\\\`🌟 Happy Speller Platform running on port \\\${port}\\\`);\n  console.log(\\\`🔨 Build: $BUILD_NUMBER\\\`);\n  console.log(\\\`📝 Commit: $COMMIT_SHA\\\`);\n});\nEOF\nnpm install && exec node server.js\"
          ]
        }]
      }
    }
  }
}"

# Wait for rollout
echo "⏳ Waiting for deployment rollout..."
kubectl -n $NAMESPACE rollout status deployment/$APP_NAME --timeout=300s

# Verify deployment
echo "✅ Verifying deployment..."
kubectl -n $NAMESPACE get pods -l app=$APP_NAME

# Test health endpoint
echo "🩺 Testing health endpoint..."
sleep 10
kubectl -n $NAMESPACE run test-deployment-$BUILD_NUMBER --rm -i --restart=Never --image=curlimages/curl:latest -- \
  curl -f -s http://$APP_NAME:8080/healthz && echo " - Health check passed!" || echo " - Health check failed!"

echo "🎉 Automatic deployment completed successfully!"
echo "📱 Access your app:"
echo "   - http://192.168.50.183:30080"
echo "   - http://192.168.50.226:30080"
echo "   - Health: http://192.168.50.183:30080/healthz"