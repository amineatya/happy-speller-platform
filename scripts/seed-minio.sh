#!/bin/bash

# Script to create MinIO buckets and upload sample content
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info "Starting MinIO setup and seeding..."

# Load credentials from environment or use defaults
MINIO_ENDPOINT=${MINIO_BASE:-http://192.168.68.58:9000}
ACCESS_KEY=${MINIO_ACCESS_KEY:-minioadmin}
SECRET_KEY=${MINIO_SECRET_KEY:-minioadmin}

print_info "Using MinIO endpoint: $MINIO_ENDPOINT"

# Check if mc (MinIO client) is available
if command -v mc &> /dev/null; then
    print_info "Using mc client for MinIO setup..."
    
    # Configure mc alias
    print_info "Configuring MinIO client..."
    mc alias set local-minio ${MINIO_ENDPOINT} ${ACCESS_KEY} ${SECRET_KEY} --api S3v4
    
    # Test connection
    if ! mc admin info local-minio &> /dev/null; then
        print_error "Cannot connect to MinIO at ${MINIO_ENDPOINT}"
        print_error "Please ensure MinIO is running and accessible"
        exit 1
    fi
    print_success "Connected to MinIO successfully"
    
    # Create buckets
    for bucket in artifacts logs docs backups reports; do
        if mc ls local-minio/${bucket} > /dev/null 2>&1; then
            print_warning "Bucket ${bucket} already exists"
        else
            mc mb local-minio/${bucket}
            print_success "Created bucket ${bucket}"
            
            # Set bucket policy to allow read access for artifacts and docs
            if [ "$bucket" = "artifacts" ] || [ "$bucket" = "docs" ]; then
                mc anonymous set download local-minio/${bucket}
                print_info "Set public read access for bucket ${bucket}"
            fi
        fi
    done
    
    # Upload sample documentation
    print_info "Creating and uploading sample documentation..."
    
    # Create temporary directory for sample files
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Create README.md
    cat > $TEMP_DIR/README.md << 'EOL'
# Happy Speller Application Documentation

This is a learning application for children to practice spelling and math skills.

## CI/CD Pipeline

This application is built and deployed using a comprehensive CI/CD pipeline with:

- **Gitea**: Source code management at `http://192.168.50.130:3000`
- **Jenkins**: CI/CD automation at `http://192.168.50.247:8080`
- **Talos Linux**: Kubernetes cluster with control plane and worker nodes
- **MinIO**: Artifact storage at `http://192.168.68.58:9000`
- **Grafana**: Monitoring and dashboards

## Application Features

- **Word Spelling Practice**: Multiple difficulty levels with phonics support
- **Math Activities**: Kindergarten level counting, addition, subtraction, and geometry
- **Audio Feedback**: Text-to-speech for word pronunciation and phonics
- **Progress Tracking**: Star system to track learning achievements
- **Responsive Design**: Optimized for tablets and computers
- **Offline Support**: Works without internet connection
- **Accessibility**: Dyslexia-friendly fonts and keyboard navigation

## Architecture

- **Frontend**: Single-page application with HTML5, CSS3, and JavaScript
- **Backend**: Node.js Express server with health checks and API endpoints
- **Containerization**: Docker with multi-stage builds for optimization
- **Orchestration**: Kubernetes with Helm charts for deployment
- **Security**: Helmet.js middleware, CORS, and security contexts
- **Monitoring**: Health checks and metrics collection

## Deployment

The application is automatically deployed through the Jenkins pipeline:

1. **Source Control**: Code changes trigger builds
2. **Testing**: Automated unit and integration tests
3. **Security Scanning**: Vulnerability assessment
4. **Build**: Docker image creation and tagging
5. **Artifact Storage**: Test results and reports stored in MinIO
6. **Deploy**: Helm-based deployment to Kubernetes
7. **Verification**: Smoke tests and health checks

## Usage

Access the application after deployment:

```bash
# Port forward to access locally
kubectl -n demo port-forward svc/happy-speller 8080:8080
```

Then open http://localhost:8080 in your browser.

## Educational Content

### Word Lists

- **Level 1**: Sight words (preprimer)
- **Level 2**: CVC words with short vowels  
- **Level 3**: Digraphs (sh, th, ch, wh)
- **Level 4**: Simple blends (fl, sp, dr, etc.)
- **Custom**: User-defined word lists

### Math Activities

- **Count & Compare**: Object counting and set comparison
- **Add & Subtract**: Story problems and visual math
- **Teen Numbers**: Understanding 10 + n patterns
- **Measure & Data**: Comparison and sorting
- **Geometry**: Shape recognition and positions

## Support

For technical support or questions about the CI/CD pipeline, please refer to:

- Jenkins build logs
- Kubernetes pod logs: `kubectl logs -n demo -l app=happy-speller`
- MinIO artifacts in the `logs` bucket
- Application health: `GET /healthz`
EOL

    # Create API documentation
    cat > $TEMP_DIR/api-docs.md << 'EOL'
# Happy Speller API Documentation

## Health Check

**GET /healthz**

Returns the current health status of the application.

### Response

```json
{
  "status": "ok",
  "timestamp": "2023-12-07T10:30:00.000Z"
}
```

### Status Codes

- `200 OK` - Application is healthy
- `503 Service Unavailable` - Application is unhealthy

## Version Information

**GET /api/version**

Returns application version and name.

### Response

```json
{
  "name": "Happy Speller",
  "version": "1.0.0"
}
```

## Static Files

**GET /**

Serves the main single-page application. All routes not matching API endpoints will serve the main HTML file to support client-side routing.

## Error Handling

The application includes comprehensive error handling:

- Malformed requests return appropriate HTTP status codes
- Large payloads (>10MB) return `413 Payload Too Large`
- Unknown API routes serve the main application (SPA routing)
- All errors are logged for debugging
EOL

    # Create deployment guide
    cat > $TEMP_DIR/deployment-guide.md << 'EOL'
# Happy Speller Deployment Guide

## Prerequisites

- Kubernetes cluster (tested with Talos Linux)
- Helm 3.x
- Docker registry access
- MinIO instance for artifacts
- Jenkins for CI/CD

## Quick Deployment

### 1. Clone Repository

```bash
git clone http://192.168.50.130:3000/amine/happy-speller-platform.git
cd happy-speller-platform
```

### 2. Set Environment Variables

```bash
export MINIO_ACCESS_KEY="your-minio-access-key"
export MINIO_SECRET_KEY="your-minio-secret-key"
export JENKINS_TOKEN="your-jenkins-api-token"
export GITEA_TOKEN="your-gitea-api-token"
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
cd infra/terraform
terraform init
terraform apply

# Setup Jenkins
cd ../ansible
ansible-playbook jenkins-setup.yaml
```

### 4. Deploy Application

```bash
# Using Helm directly
helm upgrade --install happy-speller ./helm/app \
  --namespace demo \
  --set image.repository=registry.local:5000/happy-speller \
  --set image.tag=latest

# Or using the deployment script
./scripts/deploy.sh
```

### 5. Verify Deployment

```bash
# Check pods
kubectl -n demo get pods -l app=happy-speller

# Check service
kubectl -n demo get svc happy-speller

# Test health endpoint
kubectl -n demo port-forward svc/happy-speller 8080:8080 &
curl http://localhost:8080/healthz
```

## Configuration Options

### Helm Values

Key configuration options in `helm/app/values.yaml`:

```yaml
replicaCount: 2
image:
  repository: registry.local:5000/happy-speller
  tag: latest
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

### Environment Variables

- `NODE_ENV`: Runtime environment (production/development)
- `PORT`: Application port (default: 8080)
- `APP_VERSION`: Application version for tracking

## CI/CD Pipeline

The Jenkins pipeline automatically:

1. Builds and tests the application
2. Creates Docker images
3. Stores artifacts in MinIO
4. Deploys to Kubernetes
5. Runs smoke tests

### Triggering Builds

- **Automatic**: Push to main branch in Gitea
- **Manual**: Trigger from Jenkins UI
- **API**: Use Jenkins API with authentication token

## Monitoring

### Health Checks

```bash
# Application health
curl http://happy-speller.demo.svc.cluster.local:8080/healthz

# Version check
curl http://happy-speller.demo.svc.cluster.local:8080/api/version
```

### Logs

```bash
# Application logs
kubectl logs -n demo -l app=happy-speller -f

# Deployment events
kubectl get events -n demo --sort-by='.lastTimestamp'
```

### Metrics

```bash
# Resource usage
kubectl top pods -n demo -l app=happy-speller

# Pod details
kubectl describe pods -n demo -l app=happy-speller
```

## Troubleshooting

### Common Issues

1. **Image Pull Errors**
   - Check registry credentials
   - Verify image tag exists
   - Check network connectivity

2. **Health Check Failures**
   - Review application logs
   - Check resource limits
   - Verify port configuration

3. **MinIO Connection Issues**
   - Verify credentials
   - Check network policies
   - Test connectivity from pods

### Debug Commands

```bash
# Get pod shell
kubectl exec -it -n demo deployment/happy-speller -- sh

# Check DNS resolution
kubectl exec -it -n demo deployment/happy-speller -- nslookup kubernetes.default

# Test internal connectivity
kubectl exec -it -n demo deployment/happy-speller -- curl http://localhost:8080/healthz
```
EOL

    # Upload documentation files
    mc cp $TEMP_DIR/README.md local-minio/docs/
    mc cp $TEMP_DIR/api-docs.md local-minio/docs/
    mc cp $TEMP_DIR/deployment-guide.md local-minio/docs/
    print_success "Uploaded documentation files"
    
    # Create sample build artifact structure
    print_info "Creating sample build artifacts..."
    BUILD_DIR=$TEMP_DIR/build-123
    mkdir -p $BUILD_DIR/{coverage,test-results,security-scan}
    
    # Sample test results
    cat > $BUILD_DIR/test-results/junit.xml << 'EOL'
<?xml version="1.0" encoding="UTF-8" ?>
<testsuites id="jest-tests" name="Happy Speller Tests" tests="25" failures="0" time="2.541">
  <testsuite id="server-tests" name="Happy Speller Server" tests="15" failures="0" time="1.234">
    <testcase classname="Happy Speller Server GET /healthz" name="should return status 200 and JSON with status ok" time="0.123"/>
    <testcase classname="Happy Speller Server GET /api/version" name="should return application version and name" time="0.089"/>
    <testcase classname="Happy Speller Server GET /" name="should serve the main application HTML" time="0.156"/>
  </testsuite>
  <testsuite id="integration-tests" name="Happy Speller Integration Tests" tests="10" failures="0" time="1.307">
    <testcase classname="Integration Tests Application Flow" name="should serve the complete application workflow" time="0.234"/>
    <testcase classname="Integration Tests Content Validation" name="should serve application with all required word sets" time="0.178"/>
  </testsuite>
</testsuites>
EOL

    # Sample coverage report
    cat > $BUILD_DIR/coverage/lcov.info << 'EOL'
TN:
SF:server.js
FN:15,handler
FN:25,healthCheck
FNF:2
FNH:2
FNDA:5,handler
FNDA:3,healthCheck
DA:1,1
DA:15,1
DA:25,1
LF:3
LH:3
BRF:0
BRH:0
end_of_record
EOL

    # Security scan results
    cat > $BUILD_DIR/security-scan/audit.json << 'EOL'
{
  "auditReportVersion": 2,
  "vulnerabilities": {},
  "metadata": {
    "vulnerabilities": {
      "info": 0,
      "low": 0,
      "moderate": 0,
      "high": 0,
      "critical": 0
    },
    "dependencies": 15,
    "devDependencies": 8,
    "optionalDependencies": 0,
    "totalDependencies": 23
  }
}
EOL

    # Upload build artifacts
    mc cp --recursive $BUILD_DIR/ local-minio/artifacts/
    print_success "Uploaded sample build artifacts"
    
    # Create versioned backup
    BACKUP_DIR=$TEMP_DIR/backup-$(date +%Y%m%d-%H%M%S)
    mkdir -p $BACKUP_DIR
    echo "Application backup created at $(date)" > $BACKUP_DIR/backup.log
    mc cp $BACKUP_DIR/backup.log local-minio/backups/
    print_success "Created sample backup"
    
    # List all buckets and their contents
    print_info "MinIO bucket contents:"
    for bucket in artifacts logs docs backups reports; do
        echo -e "${BLUE}Bucket: ${bucket}${NC}"
        mc ls local-minio/${bucket} | head -10
        echo ""
    done
    
else
    print_warning "mc client not found, using curl for basic MinIO setup..."
    
    # Function to make authenticated requests to MinIO
    make_request() {
        local method=$1
        local bucket=$2
        local object=$3
        local content_type=${4:-"application/octet-stream"}
        
        local date=$(date -R)
        local string_to_sign="${method}\n\n${content_type}\n${date}\n/${bucket}${object:+/}${object}"
        local signature=$(echo -n "$string_to_sign" | openssl sha1 -hmac "${SECRET_KEY}" -binary | base64)
        
        curl -X "${method}" \
            -H "Date: ${date}" \
            -H "Authorization: AWS ${ACCESS_KEY}:${signature}" \
            -H "Content-Type: ${content_type}" \
            "${MINIO_ENDPOINT}/${bucket}${object:+/}${object}"
    }
    
    # Test connection
    if ! curl -s --connect-timeout 5 "${MINIO_ENDPOINT}/minio/health/live" > /dev/null; then
        print_error "Cannot connect to MinIO at ${MINIO_ENDPOINT}"
        print_error "Please ensure MinIO is running and accessible"
        exit 1
    fi
    print_success "Connected to MinIO successfully"
    
    # Create buckets using curl
    for bucket in artifacts logs docs backups reports; do
        # Check if bucket exists
        response=$(curl -s -o /dev/null -w "%{http_code}" -X HEAD "${MINIO_ENDPOINT}/${bucket}")
        
        if [ "$response" = "200" ]; then
            print_warning "Bucket ${bucket} already exists"
        else
            # Create bucket
            make_request "PUT" "$bucket"
            if [ $? -eq 0 ]; then
                print_success "Created bucket ${bucket}"
            else
                print_error "Failed to create bucket ${bucket}"
            fi
        fi
    done
    
    print_info "Basic MinIO setup completed using curl"
    print_warning "Install mc client for full functionality: https://docs.min.io/minio/baremetal/reference/minio-mc.html"
fi

print_success "MinIO setup and seeding completed successfully!"

# Print summary
echo -e "\n${GREEN}=== MinIO Setup Summary ===${NC}"
echo -e "${BLUE}Endpoint:${NC} $MINIO_ENDPOINT"
echo -e "${BLUE}Buckets created:${NC}"
echo -e "  - artifacts (for build artifacts and test results)"
echo -e "  - logs (for application and pipeline logs)"
echo -e "  - docs (for documentation and guides)"
echo -e "  - backups (for application backups)"
echo -e "  - reports (for monitoring and analysis reports)"

if command -v mc &> /dev/null; then
    echo -e "\n${BLUE}Access documentation:${NC}"
    echo -e "  mc cat local-minio/docs/README.md"
    echo -e "  mc cat local-minio/docs/api-docs.md"
    echo -e "  mc cat local-minio/docs/deployment-guide.md"
    
    echo -e "\n${BLUE}View artifacts:${NC}"
    echo -e "  mc ls local-minio/artifacts/"
    echo -e "  mc ls local-minio/logs/"
fi

echo -e "\n${GREEN}Ready for CI/CD pipeline integration!${NC}"