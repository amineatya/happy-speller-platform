# Happy Speller Platform

A comprehensive CI/CD pipeline for the Happy Speller educational application, designed for kindergarten students to learn spelling and basic math skills.

## 🎯 Overview

Happy Speller is an interactive learning application that helps young children practice:
- **Spelling**: Multiple difficulty levels with phonics support
- **Math**: Basic counting, addition, subtraction, and geometry
- **Accessibility**: Dyslexia-friendly fonts and audio support

## 🏗️ Architecture

The platform consists of:

- **Frontend**: HTML5/CSS3/JavaScript application with offline support
- **Backend**: Node.js Express server with health checks
- **Containerization**: Docker with multi-stage builds
- **Orchestration**: Kubernetes with Helm charts
- **CI/CD**: Jenkins pipeline with automated testing and deployment
- **Infrastructure**: Terraform for infrastructure as code
- **Configuration**: Ansible for configuration management
- **Monitoring**: Health checks and logging integration

## 📁 Project Structure

```
happy-speller-platform/
├── app/                          # Node.js application
│   ├── public/                   # Static web files
│   │   └── index.html           # Main application
│   ├── test/                    # Test files
│   ├── server.js                # Express server
│   ├── package.json             # Dependencies
│   └── Dockerfile               # Container definition
├── helm/app/                    # Helm charts
│   ├── templates/               # Kubernetes templates
│   ├── Chart.yaml              # Chart metadata
│   └── values.yaml             # Default values
├── infra/                       # Infrastructure code
│   ├── terraform/              # Terraform configurations
│   └── ansible/                # Ansible playbooks
├── scripts/                     # Deployment scripts
│   ├── deploy.sh               # Main deployment script
│   ├── setup-infrastructure.sh # Infrastructure setup
│   └── health-check.sh         # Health monitoring
├── Jenkinsfile                 # CI/CD pipeline
└── README.md                   # This file
```

## 🚀 Quick Start

### Prerequisites

- Docker
- Kubernetes cluster (kubectl configured)
- Helm 3.x
- Terraform
- Ansible
- Jenkins (optional, for CI/CD)

### 1. Infrastructure Setup

```bash
# Set environment variables
export JENKINS_TOKEN="your-jenkins-token"
export GITEA_TOKEN="your-gitea-token"
export MINIO_ACCESS_KEY="your-minio-key"
export MINIO_SECRET_KEY="your-minio-secret"
export KUBECONFIG="~/.kube/config"

# Run infrastructure setup
./scripts/setup-infrastructure.sh
```

### 2. Deploy Application

```bash
# Deploy to Kubernetes
./scripts/deploy.sh

# Or build only
./scripts/deploy.sh --build-only
```

### 3. Health Check

```bash
# Run comprehensive health checks
./scripts/health-check.sh

# Generate health report
./scripts/health-check.sh --report-only
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Application port | `8080` |
| `NODE_ENV` | Node environment | `production` |
| `APP_VERSION` | Application version | `1.0.0` |

### Kubernetes Configuration

The application is deployed with:
- **Namespace**: `demo`
- **Replicas**: 2
- **Resources**: 250m CPU, 256Mi memory (requests)
- **Health Checks**: Liveness and readiness probes

### Helm Values

Key configurable values in `helm/app/values.yaml`:

```yaml
replicaCount: 2
image:
  repository: registry.local:5000/happy-speller
  tag: latest
service:
  type: ClusterIP
  port: 8080
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

## 🧪 Testing

### Unit Tests

```bash
cd app
npm test
```

### Integration Tests

```bash
# Run health checks
./scripts/health-check.sh

# Test specific endpoints
curl http://localhost:8080/healthz
curl http://localhost:8080/api/version
```

### Load Testing

```bash
# Using Apache Bench
ab -n 1000 -c 10 http://localhost:8080/healthz
```

## 📊 Monitoring

### Health Endpoints

- **Health Check**: `GET /healthz`
- **Version Info**: `GET /api/version`

### Logs

```bash
# View application logs
kubectl logs -n demo -l app=happy-speller

# Follow logs
kubectl logs -n demo -l app=happy-speller -f
```

### Metrics

```bash
# Resource usage
kubectl top pods -n demo -l app=happy-speller

# Pod details
kubectl describe pods -n demo -l app=happy-speller
```

## 🔄 CI/CD Pipeline

The Jenkins pipeline includes:

1. **Checkout**: Git repository checkout
2. **Build**: Install dependencies and lint code
3. **Test**: Run unit tests with coverage
4. **Security**: Audit dependencies
5. **Build Image**: Create Docker image
6. **Upload Artifacts**: Store test results in MinIO
7. **Deploy**: Deploy to Kubernetes using Helm
8. **Smoke Test**: Verify deployment health

### Pipeline Triggers

- **Manual**: Triggered manually
- **SCM**: Triggered on code changes (every 5 minutes)
- **Webhook**: Triggered by Gitea webhooks

## 🛠️ Development

### Local Development

```bash
# Install dependencies
cd app
npm install

# Start development server
npm run dev

# Run tests
npm test

# Lint code
npm run lint
```

### Docker Development

```bash
# Build image
docker build -t happy-speller:dev ./app

# Run container
docker run -p 8080:8080 happy-speller:dev
```

## 🔒 Security

### Container Security

- **Base Image**: Alpine Linux (minimal attack surface)
- **User**: Non-root user execution
- **Multi-stage Build**: Reduced image size
- **Security Scanning**: npm audit in pipeline

### Kubernetes Security

- **Network Policies**: Restricted pod communication
- **Service Accounts**: Least privilege access
- **Resource Limits**: Prevent resource exhaustion
- **Health Checks**: Automatic failure detection

## 📈 Scaling

### Horizontal Scaling

```bash
# Scale deployment
kubectl scale deployment happy-speller -n demo --replicas=5

# Or using Helm
helm upgrade happy-speller ./helm/app --set replicaCount=5
```

### Vertical Scaling

Update resource limits in `helm/app/values.yaml`:

```yaml
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

## 🐛 Troubleshooting

### Common Issues

1. **Pod Not Starting**
   ```bash
   kubectl describe pod -n demo -l app=happy-speller
   kubectl logs -n demo -l app=happy-speller
   ```

2. **Health Check Failing**
   ```bash
   kubectl get pods -n demo -l app=happy-speller
   kubectl port-forward -n demo service/happy-speller 8080:8080
   curl http://localhost:8080/healthz
   ```

3. **Image Pull Errors**
   ```bash
   kubectl get events -n demo --sort-by='.lastTimestamp'
   ```

### Debug Commands

```bash
# Check pod status
kubectl get pods -n demo -l app=happy-speller -o wide

# Check service endpoints
kubectl get endpoints -n demo -l app=happy-speller

# Check ingress
kubectl get ingress -n demo -l app=happy-speller

# Check persistent volumes
kubectl get pv,pvc -n demo
```

## 📚 Documentation

- [Application Features](docs/features.md)
- [API Documentation](docs/api.md)
- [Deployment Guide](docs/deployment.md)
- [Troubleshooting Guide](docs/troubleshooting.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Educational content designed for kindergarten students
- Accessibility features for learners with dyslexia
- Offline-first design for reliable learning experience
# Test automatic deployment - Tue Sep 23 01:50:34 EDT 2025
