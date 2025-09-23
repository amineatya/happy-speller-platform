# Happy Speller Platform - GitOps Repository

This directory contains the GitOps configuration for the Happy Speller Platform, implementing declarative deployments with ArgoCD.

## 📁 Repository Structure

```
gitops/
├── bootstrap/           # ArgoCD installation and initial setup
├── applications/        # ArgoCD Application definitions
├── environments/        # Environment-specific configurations
│   ├── dev/            # Development environment
│   ├── staging/        # Staging environment
│   └── prod/           # Production environment
└── README.md           # This file
```

## 🚀 GitOps Workflow

1. **Code Changes**: Developers push code changes to main repository
2. **CI Pipeline**: Jenkins builds, tests, and creates container images
3. **GitOps Update**: Jenkins updates image tags in this GitOps repository
4. **ArgoCD Sync**: ArgoCD detects changes and deploys to Kubernetes
5. **Monitoring**: ArgoCD provides deployment status and health monitoring

## 🔄 Deployment Flow

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Source Repo   │───▶│   Jenkins CI    │───▶│   GitOps Repo   │
│   (Code Changes)│    │   (Build & Test)│    │   (Config Update)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Container     │    │   ArgoCD        │
                       │   Registry      │◀───│   (Auto Deploy) │
                       └─────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Kubernetes    │    │   Application   │
                       │   Cluster       │───▶│   Running       │
                       └─────────────────┘    └─────────────────┘
```

## 🌍 Environments

### Development
- **Namespace**: `happy-speller-dev`
- **Image Policy**: Auto-deploy latest builds from `main` branch
- **Resources**: Minimal resource allocation
- **Monitoring**: Basic health checks

### Staging
- **Namespace**: `happy-speller-staging`
- **Image Policy**: Manual promotion from dev
- **Resources**: Production-like resource allocation
- **Monitoring**: Full monitoring stack enabled

### Production
- **Namespace**: `happy-speller-prod`
- **Image Policy**: Manual promotion with approval
- **Resources**: Full production resource allocation
- **Monitoring**: Complete observability stack

## 🔧 Configuration Management

Each environment contains:
- `kustomization.yaml`: Environment-specific customizations
- `values.yaml`: Helm chart values override
- `patches/`: Environment-specific patches
- `secrets/`: Encrypted secret configurations (using sealed-secrets)

## 📦 Application Components

- **happy-speller**: Main application deployment
- **monitoring**: Prometheus, Grafana stack
- **ingress**: Nginx ingress configuration
- **secrets**: Sealed secrets for sensitive data

## 🔐 Security

- **RBAC**: Fine-grained permissions for ArgoCD
- **Sealed Secrets**: Encrypted secrets in Git
- **Image Policies**: Controlled image deployment
- **Network Policies**: Pod-to-pod communication rules

## 🚀 Quick Start

1. **Bootstrap ArgoCD**:
   ```bash
   kubectl apply -f bootstrap/
   ```

2. **Deploy Applications**:
   ```bash
   kubectl apply -f applications/
   ```

3. **Access ArgoCD UI**:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

4. **Get ArgoCD Password**:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

## 📊 Monitoring

ArgoCD provides:
- Real-time deployment status
- Application health monitoring  
- Sync status and history
- Resource utilization views
- Alert notifications

## 🔄 Promotion Workflow

```bash
# Promote from dev to staging
./scripts/promote.sh dev staging v1.2.3

# Promote from staging to production
./scripts/promote.sh staging prod v1.2.3
```

## 📖 Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [Helm Documentation](https://helm.sh/docs/)