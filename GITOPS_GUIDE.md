# Happy Speller Platform - GitOps Implementation Guide

## 🚀 Overview

This guide covers the complete GitOps implementation for the Happy Speller Platform using ArgoCD for declarative deployments and automated application lifecycle management.

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [GitOps Workflow](#gitops-workflow)
5. [Environment Management](#environment-management)
6. [Deployment Process](#deployment-process)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Features](#advanced-features)

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developer     │───▶│   Git Repository │───▶│   Jenkins CI    │
│   Code Changes  │    │   Source Code    │    │   Build & Test  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ArgoCD        │◀───│   Git Repository │◀───│   Container     │
│   Sync & Deploy │    │   GitOps Config  │    │   Registry      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Kubernetes    │    │   Environment   │    │   Monitoring &  │
│   Cluster       │    │   Configs       │    │   Notifications │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Key Components

- **Source Repository**: Application source code and build configurations
- **GitOps Repository**: Kubernetes manifests and environment configurations
- **ArgoCD**: GitOps controller for automated deployments
- **Jenkins CI**: Continuous integration pipeline
- **Image Updater**: Automated image tag updates
- **Notifications**: Deployment status and health alerts

## 🔧 Prerequisites

### Required Tools

```bash
# Kubernetes cluster access
kubectl version

# ArgoCD CLI (optional but recommended)
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64
chmod +x /usr/local/bin/argocd

# Kustomize (usually included with kubectl)
kustomize version

# jq for JSON parsing
brew install jq  # macOS
apt-get install jq  # Ubuntu
```

### Environment Setup

```bash
# Set required environment variables
export KUBECONFIG=~/.kube/config
export GITOPS_REPO="https://github.com/yourusername/happy-speller-platform.git"
export REGISTRY_URL="registry.local:5000"
```

## 🚀 Quick Start

### 1. Install ArgoCD

```bash
# Navigate to project root
cd /path/to/happy-speller-platform

# Install ArgoCD
./gitops/bootstrap/install-argocd.sh
```

### 2. Configure Git Repository

Update the repository URL in all GitOps files:

```bash
# Update repository URLs in application manifests
find gitops/applications -name "*.yaml" -exec sed -i 's|https://github.com/amineatya/happy-speller-platform.git|YOUR_REPO_URL|g' {} \;

# Update Jenkinsfile.gitops
sed -i 's|GITOPS_REPO = "https://github.com/amineatya/happy-speller-platform.git"|GITOPS_REPO = "YOUR_REPO_URL"|g' Jenkinsfile.gitops
```

### 3. Deploy Applications

```bash
# Deploy the app-of-apps pattern
kubectl apply -f gitops/applications/app-of-apps.yaml

# Or deploy individual applications
kubectl apply -f gitops/applications/
```

### 4. Access ArgoCD UI

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser to: https://localhost:8080
# Username: admin
# Password: (from above command)
```

## 🔄 GitOps Workflow

### Development Workflow

1. **Code Changes**: Developer pushes code to main/develop branch
2. **CI Pipeline**: Jenkins builds, tests, and creates container image
3. **GitOps Update**: Jenkins updates image tag in GitOps repository
4. **ArgoCD Sync**: ArgoCD detects changes and deploys to dev environment
5. **Validation**: Automated smoke tests verify deployment

### Promotion Workflow

```bash
# Promote from dev to staging
./scripts/gitops/promote.sh dev staging

# Promote from staging to production
./scripts/gitops/promote.sh staging prod

# Promote specific image version
./scripts/gitops/promote.sh dev staging v1.2.3

# Dry run to preview changes
./scripts/gitops/promote.sh dev staging --dry-run
```

## 🌍 Environment Management

### Environment Structure

- **Development** (`happy-speller-dev`)
  - Auto-sync enabled
  - Latest image tags
  - Minimal resources
  - Debug logging

- **Staging** (`happy-speller-staging`)
  - Manual sync for controlled deployments
  - Stable image tags
  - Production-like resources
  - Info logging

- **Production** (`happy-speller-prod`)
  - Manual sync with approval required
  - Release image tags
  - Full production resources
  - Warning-level logging

### Environment Configuration

Each environment has its own directory under `gitops/environments/`:

```
gitops/environments/
├── dev/
│   ├── kustomization.yaml    # Environment-specific customizations
│   ├── deployment-patch.yaml # Resource limits and environment vars
│   └── service-patch.yaml    # Service configuration
├── staging/
└── prod/
```

## 📦 Deployment Process

### Automated Deployment (Dev Environment)

1. Code pushed to main/develop branch
2. Jenkins pipeline executes:
   ```groovy
   stage('Update GitOps Repository - Dev') {
       updateGitOpsRepo('dev', env.IMAGE_TAG)
   }
   ```
3. ArgoCD detects Git changes within 3 minutes
4. ArgoCD syncs changes to dev environment
5. Health checks verify successful deployment

### Manual Deployment (Staging/Production)

1. Use promotion script:
   ```bash
   ./scripts/gitops/promote.sh dev staging
   ```
2. Review changes in ArgoCD UI
3. Manual sync in ArgoCD or auto-sync if configured
4. Monitor deployment progress

### Emergency Rollback

```bash
# Quick rollback using ArgoCD
argocd app rollback happy-speller-prod

# Or promote previous working version
./scripts/gitops/promote.sh prod prod previous-working-tag
```

## 📊 Monitoring and Status

### Check Deployment Status

```bash
# Check all environments
./scripts/gitops/status.sh

# Check specific environment
./scripts/gitops/status.sh dev

# Detailed status with health checks
./scripts/gitops/status.sh --all --detailed
```

### ArgoCD Application Status

```bash
# List all applications
argocd app list

# Get application details
argocd app get happy-speller-dev

# Sync application manually
argocd app sync happy-speller-dev

# View application logs
argocd app logs happy-speller-dev
```

### Kubernetes Status

```bash
# Check pods in all environments
kubectl get pods -n happy-speller-dev
kubectl get pods -n happy-speller-staging
kubectl get pods -n happy-speller-prod

# Check services
kubectl get svc -n happy-speller-dev

# View deployment status
kubectl rollout status deployment/happy-speller -n happy-speller-dev
```

## 🔧 Troubleshooting

### Common Issues

#### ArgoCD Application Out of Sync

```bash
# Check diff between Git and cluster
argocd app diff happy-speller-dev

# Force refresh
argocd app get happy-speller-dev --refresh

# Manual sync
argocd app sync happy-speller-dev
```

#### Image Pull Errors

```bash
# Check image tag in GitOps repo
grep "newTag:" gitops/environments/dev/kustomization.yaml

# Verify image exists in registry
curl -X GET http://registry.local:5000/v2/happy-speller/tags/list

# Check pod events
kubectl describe pod -n happy-speller-dev -l app=happy-speller
```

#### Deployment Stuck

```bash
# Check deployment status
kubectl describe deployment happy-speller -n happy-speller-dev

# Check replica sets
kubectl get rs -n happy-speller-dev

# View pod logs
kubectl logs -n happy-speller-dev -l app=happy-speller
```

### Health Checks

```bash
# Test application health endpoint
kubectl port-forward svc/happy-speller -n happy-speller-dev 8080:8080
curl http://localhost:8080/healthz

# Check ArgoCD health
kubectl get pods -n argocd

# Verify ArgoCD can reach Git repository
argocd repo list
```

## 🚀 Advanced Features

### Image Updater Configuration

ArgoCD Image Updater automatically updates image tags in the GitOps repository when new images are available:

```yaml
# Annotations on ArgoCD Application
annotations:
  argocd-image-updater.argoproj.io/image-list: happy-speller=registry.local:5000/happy-speller
  argocd-image-updater.argoproj.io/happy-speller.update-strategy: latest
  argocd-image-updater.argoproj.io/happy-speller.allow-tags: regexp:^[0-9]+-[a-f0-9]+$|^latest$
```

### Notifications Setup

ArgoCD sends notifications to Jenkins webhook for:
- Successful deployments
- Health degradation
- Sync failures

Configure webhooks in Jenkins to trigger downstream actions.

### Multi-Environment Promotion

```bash
# Automated promotion pipeline
./scripts/gitops/promote.sh dev staging --auto-approve
./scripts/gitops/promote.sh staging prod  # Requires manual confirmation
```

### Disaster Recovery

```bash
# Backup GitOps repository
git clone --mirror https://github.com/yourusername/happy-speller-platform.git

# Export ArgoCD applications
argocd app list -o yaml > argocd-apps-backup.yaml

# Restore from backup
kubectl apply -f argocd-apps-backup.yaml
```

## 📚 Best Practices

### Git Repository Management

- Keep source code and GitOps configurations in the same repository for simplicity
- Use separate branches for different environments if needed
- Implement proper Git branching strategy (GitFlow or similar)

### Security

- Use sealed secrets for sensitive data
- Implement RBAC for ArgoCD applications
- Regular security scanning of container images
- Network policies for pod-to-pod communication

### Performance

- Use resource limits and requests appropriately
- Implement horizontal pod autoscaling
- Monitor resource usage and optimize accordingly
- Use multi-stage Docker builds for smaller images

### Monitoring

- Set up comprehensive logging and monitoring
- Implement alerting for deployment failures
- Track deployment frequency and lead time metrics
- Monitor application performance and health

## 🤝 Support

For issues and questions:

1. Check the troubleshooting section above
2. Review ArgoCD documentation: https://argo-cd.readthedocs.io/
3. Check application logs and events in Kubernetes
4. Review Jenkins pipeline logs for CI/CD issues

## 🎉 Congratulations!

You now have a fully functional GitOps setup for the Happy Speller Platform! The system provides:

- ✅ Automated deployments to dev environment
- ✅ Controlled promotions to staging and production
- ✅ Health monitoring and notifications
- ✅ Easy rollback capabilities
- ✅ Complete audit trail of all changes
- ✅ Scalable multi-environment management

Happy deploying! 🚀