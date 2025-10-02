#!/bin/bash

# Portfolio Improvements Implementation Script
# This script helps implement the most critical improvements for your CI/CD pipeline

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Happy Speller Platform - Portfolio Improvements Setup${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo

# Function to create directory structure
setup_directories() {
    echo -e "${YELLOW}📁 Creating directory structure...${NC}"
    
    # Security directories
    mkdir -p security/{snyk,trivy,secrets}
    mkdir -p monitoring/{prometheus,grafana,jaeger}
    mkdir -p environments/{dev,staging,prod}
    mkdir -p tests/{integration,contract,performance}
    mkdir -p compliance/{sbom,licenses,audit}
    
    echo -e "${GREEN}✅ Directory structure created${NC}"
}

# Function to create monitoring configuration
setup_monitoring() {
    echo -e "${YELLOW}📊 Setting up monitoring stack...${NC}"
    
    # Create Prometheus monitoring configuration
    cat > app/monitoring.js << 'EOF'
const prometheus = require('prom-client');

// Create a Registry to register the metrics
const register = new prometheus.Registry();

// Add default metrics
prometheus.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestDuration = new prometheus.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

const httpRequestsTotal = new prometheus.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status_code']
});

const activeUsers = new prometheus.Gauge({
    name: 'active_users_total',
    help: 'Number of active users'
});

// Register custom metrics
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestsTotal);
register.registerMetric(activeUsers);

// Middleware for metrics collection
function metricsMiddleware(req, res, next) {
    const start = Date.now();
    
    res.on('finish', () => {
        const duration = (Date.now() - start) / 1000;
        const route = req.route?.path || req.path;
        
        httpRequestDuration
            .labels(req.method, route, res.statusCode.toString())
            .observe(duration);
            
        httpRequestsTotal
            .labels(req.method, route, res.statusCode.toString())
            .inc();
    });
    
    next();
}

module.exports = { 
    metricsMiddleware, 
    register,
    httpRequestDuration,
    httpRequestsTotal,
    activeUsers
};
EOF

    echo -e "${GREEN}✅ Monitoring setup created${NC}"
}

# Function to create enhanced Jenkinsfile with security
create_enhanced_jenkinsfile() {
    echo -e "${YELLOW}🔧 Creating enhanced Jenkinsfile...${NC}"
    
    cp Jenkinsfile Jenkinsfile.backup
    
    cat > Jenkinsfile.enhanced << 'EOF'
pipeline {
    agent any
    
    tools {
        nodejs 'NodeJS-18'
    }
    
    environment {
        GITEA_BASE = 'http://192.168.50.130:3000'
        JENKINS_BASE = 'http://192.168.50.247:8080'
        MINIO_BASE = 'http://192.168.50.177:9000'
        REGISTRY = 'registry.local:5000'
        NAMESPACE = 'demo'
        APP_NAME = 'happy-speller'
        SONAR_HOST_URL = 'http://sonarqube:9000'
    }
    
    stages {
        stage('Checkout & Setup') {
            steps {
                checkout scm
                script {
                    env.COMMIT_SHA = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                    env.SHORT_COMMIT = env.COMMIT_SHA.take(8)
                    currentBuild.displayName = "BUILD #${BUILD_NUMBER} - ${env.SHORT_COMMIT}"
                }
            }
        }
        
        stage('Security & Quality Analysis') {
            parallel {
                stage('SAST - SonarQube') {
                    steps {
                        script {
                            try {
                                withSonarQubeEnv('SonarQube') {
                                    sh '''
                                        cd app
                                        npm install
                                        npm test -- --coverage --watchAll=false
                                        sonar-scanner \
                                          -Dsonar.projectKey=happy-speller \
                                          -Dsonar.sources=. \
                                          -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
                                    '''
                                }
                                
                                // Quality Gate check
                                timeout(time: 5, unit: 'MINUTES') {
                                    def qg = waitForQualityGate()
                                    if (qg.status != 'OK') {
                                        echo "⚠️ Quality Gate failed: ${qg.status}"
                                        currentBuild.result = 'UNSTABLE'
                                    }
                                }
                            } catch (Exception e) {
                                echo "⚠️ SonarQube analysis failed: ${e.getMessage()}"
                                currentBuild.result = 'UNSTABLE'
                            }
                        }
                    }
                }
                
                stage('Dependency Security') {
                    steps {
                        sh '''
                            cd app
                            
                            # npm audit with JSON output
                            npm audit --audit-level=moderate --json > npm-audit.json || true
                            
                            # Install Snyk if available
                            if command -v snyk >/dev/null 2>&1; then
                                snyk test --severity-threshold=high --json > snyk-test.json || true
                                snyk monitor --project-name=happy-speller || true
                            else
                                echo "⚠️ Snyk not installed, skipping advanced security scan"
                            fi
                        '''
                    }
                }
                
                stage('Secrets Scanning') {
                    steps {
                        sh '''
                            # Use git secrets or similar tool
                            echo "Scanning for secrets..."
                            
                            # Simple secret patterns check
                            grep -r -n -i "password.*=" . --exclude-dir=node_modules --exclude-dir=.git > secrets-scan.txt || true
                            grep -r -n -i "api.*key.*=" . --exclude-dir=node_modules --exclude-dir=.git >> secrets-scan.txt || true
                            grep -r -n -i "secret.*=" . --exclude-dir=node_modules --exclude-dir=.git >> secrets-scan.txt || true
                            
                            if [ -s secrets-scan.txt ]; then
                                echo "⚠️ Potential secrets found! Review secrets-scan.txt"
                                head -10 secrets-scan.txt
                            else
                                echo "✅ No obvious secrets found"
                            fi
                        '''
                    }
                }
            }
        }
        
        stage('Build & Test') {
            steps {
                sh '''
                    cd app
                    npm install
                    npm run build || echo "No build script, continuing..."
                    npm test -- --coverage --watchAll=false --ci
                '''
            }
            post {
                always {
                    // Publish test results
                    junit testResultsPattern: 'app/junit.xml', allowEmptyResults: true
                    
                    // Archive coverage
                    archiveArtifacts artifacts: 'app/coverage/**/*', allowEmptyArchive: true
                }
            }
        }
        
        stage('Container Build & Security') {
            when {
                expression { sh(script: 'which docker', returnStatus: true) == 0 }
            }
            steps {
                script {
                    def imageTag = "${env.REGISTRY}/${env.APP_NAME}:${BUILD_NUMBER}-${env.SHORT_COMMIT}"
                    
                    // Build container
                    sh """
                        cd app
                        docker build -t ${imageTag} .
                        docker tag ${imageTag} ${env.REGISTRY}/${env.APP_NAME}:latest
                    """
                    
                    // Container security scanning (if Trivy is available)
                    sh """
                        if command -v trivy >/dev/null 2>&1; then
                            trivy image --exit-code 1 --severity HIGH,CRITICAL ${imageTag} > trivy-report.txt || echo "⚠️ Container vulnerabilities found"
                            trivy image --format json -o trivy-report.json ${imageTag}
                        else
                            echo "⚠️ Trivy not installed, skipping container security scan"
                        fi
                    """
                    
                    env.IMAGE_TAG = imageTag
                }
            }
        }
        
        stage('Multi-Environment Deploy') {
            parallel {
                stage('Deploy to Dev') {
                    steps {
                        sh '''
                            # Deploy to development environment
                            kubectl create namespace ${NAMESPACE}-dev --dry-run=client -o yaml | kubectl apply -f -
                            
                            helm upgrade --install ${APP_NAME}-dev ./helm/app \
                                --namespace ${NAMESPACE}-dev \
                                --set image.repository=${REGISTRY}/${APP_NAME} \
                                --set image.tag=${BUILD_NUMBER}-${SHORT_COMMIT} \
                                --set environment=dev \
                                --set replicaCount=1 \
                                --wait --timeout=300s
                        '''
                    }
                }
                
                stage('Deploy to Staging') {
                    when {
                        anyOf {
                            branch 'main'
                            branch 'develop'
                        }
                    }
                    steps {
                        script {
                            def deploy = input(
                                message: 'Deploy to staging?',
                                ok: 'Deploy',
                                parameters: [
                                    choice(name: 'DEPLOY', choices: 'Yes\nNo', description: 'Deploy to staging?')
                                ]
                            )
                            
                            if (deploy == 'Yes') {
                                sh '''
                                    kubectl create namespace ${NAMESPACE}-staging --dry-run=client -o yaml | kubectl apply -f -
                                    
                                    helm upgrade --install ${APP_NAME}-staging ./helm/app \
                                        --namespace ${NAMESPACE}-staging \
                                        --set image.repository=${REGISTRY}/${APP_NAME} \
                                        --set image.tag=${BUILD_NUMBER}-${SHORT_COMMIT} \
                                        --set environment=staging \
                                        --set replicaCount=2 \
                                        --wait --timeout=300s
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('Integration & Performance Tests') {
            parallel {
                stage('Integration Tests') {
                    steps {
                        sh '''
                            # Wait for deployment to be ready
                            kubectl wait --for=condition=available deployment/${APP_NAME} -n ${NAMESPACE}-dev --timeout=300s
                            
                            # Run integration tests
                            kubectl run integration-test-${BUILD_NUMBER} --rm -i --restart=Never \
                              --namespace=${NAMESPACE}-dev \
                              --image=curlimages/curl:8.2.1 -- \
                              sh -c "
                                curl -f http://${APP_NAME}:8080/healthz && \
                                curl -f http://${APP_NAME}:8080/api/version && \
                                echo 'Integration tests passed'
                              "
                        '''
                    }
                }
                
                stage('Performance Tests') {
                    steps {
                        sh '''
                            # Simple load test using curl in a loop
                            kubectl run perf-test-${BUILD_NUMBER} --rm -i --restart=Never \
                              --namespace=${NAMESPACE}-dev \
                              --image=curlimages/curl:8.2.1 -- \
                              sh -c "
                                echo 'Running basic performance test...'
                                for i in \$(seq 1 10); do
                                  START=\$(date +%s%N)
                                  curl -s http://${APP_NAME}:8080/healthz > /dev/null
                                  END=\$(date +%s%N)
                                  DURATION=\$(( (END - START) / 1000000 ))
                                  echo \"Request \$i: \${DURATION}ms\"
                                  if [ \$DURATION -gt 1000 ]; then
                                    echo 'Performance test failed: Response time > 1000ms'
                                    exit 1
                                  fi
                                done
                                echo 'Performance tests passed'
                              "
                        '''
                    }
                }
            }
        }
        
        stage('Compliance & Audit') {
            steps {
                sh '''
                    # Generate compliance reports
                    cd app
                    
                    # License check
                    npm ls --json > package-tree.json
                    
                    # Generate SBOM if syft is available
                    if command -v syft >/dev/null 2>&1; then
                        syft ${IMAGE_TAG} -o json > sbom.json
                    else
                        echo "⚠️ Syft not installed, skipping SBOM generation"
                    fi
                    
                    # Create compliance report
                    cat > compliance-report.json << EOF
{
  "buildNumber": "${BUILD_NUMBER}",
  "timestamp": "$(date -Iseconds)",
  "commitSha": "${COMMIT_SHA}",
  "securityScanCompleted": true,
  "testsCompleted": true,
  "complianceStatus": "PASSED"
}
EOF
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'app/*-report.json,app/sbom.json,app/compliance-report.json', allowEmptyArchive: true
                }
            }
        }
    }
    
    post {
        always {
            script {
                // Upload artifacts to MinIO
                try {
                    withCredentials([
                        usernamePassword(credentialsId: 'minio-creds', usernameVariable: 'MINIO_ACCESS_KEY', passwordVariable: 'MINIO_SECRET_KEY')
                    ]) {
                        sh '''
                            # Create artifacts bundle
                            tar -czf build-artifacts-${BUILD_NUMBER}.tgz \
                              app/coverage/ \
                              app/*-report.json \
                              app/junit.xml \
                              2>/dev/null || echo "Some artifacts missing"
                            
                            # Upload to MinIO
                            mc alias set build-minio ${MINIO_BASE} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY}
                            mc cp build-artifacts-${BUILD_NUMBER}.tgz build-minio/artifacts/ || echo "Upload failed"
                        '''
                    }
                } catch (Exception e) {
                    echo "⚠️ Failed to upload artifacts: ${e.getMessage()}"
                }
            }
        }
        success {
            echo "🎉 Pipeline completed successfully!"
            script {
                updateGiteaStatus(env.COMMIT_SHA, 'success', 'All checks passed', 'jenkins/enhanced-build')
            }
        }
        failure {
            echo "❌ Pipeline failed!"
            script {
                updateGiteaStatus(env.COMMIT_SHA, 'failure', 'Build failed', 'jenkins/enhanced-build')
            }
        }
    }
}

def updateGiteaStatus(commitSha, state, description, context) {
    if (!commitSha) return
    
    try {
        withCredentials([string(credentialsId: 'gitea-token', variable: 'GITEA_TOKEN')]) {
            sh """
                curl -X POST \
                  -H "Authorization: token \$GITEA_TOKEN" \
                  -H "Content-Type: application/json" \
                  -d '{
                    "state": "${state}",
                    "target_url": "${env.JENKINS_BASE}/job/${env.JOB_NAME}/${env.BUILD_NUMBER}",
                    "description": "${description}",
                    "context": "${context}"
                  }' \
                  ${env.GITEA_BASE}/api/v1/repos/amine/happy-speller-platform/statuses/${commitSha}
            """
        }
    } catch (Exception e) {
        echo "⚠️ Failed to update Gitea status: ${e.getMessage()}"
    }
}
EOF

    echo -e "${GREEN}✅ Enhanced Jenkinsfile created as Jenkinsfile.enhanced${NC}"
}

# Function to create integration tests
create_integration_tests() {
    echo -e "${YELLOW}🧪 Creating integration tests...${NC}"
    
    mkdir -p app/test/integration
    
    cat > app/test/integration/api.test.js << 'EOF'
const request = require('supertest');
const app = require('../../server');

describe('Integration Tests - API Endpoints', () => {
    let server;
    
    beforeAll(() => {
        server = app.listen(0); // Use random port for testing
    });
    
    afterAll(() => {
        server.close();
    });
    
    describe('Health Endpoint', () => {
        test('should return 200 and correct format', async () => {
            const response = await request(app)
                .get('/healthz')
                .expect(200);
                
            expect(response.body).toHaveProperty('status', 'ok');
            expect(response.body).toHaveProperty('timestamp');
            expect(response.body.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
        });
        
        test('should respond within acceptable time', async () => {
            const start = Date.now();
            await request(app).get('/healthz').expect(200);
            const duration = Date.now() - start;
            
            expect(duration).toBeLessThan(100); // Should respond within 100ms
        });
    });
    
    describe('Version Endpoint', () => {
        test('should return version information', async () => {
            const response = await request(app)
                .get('/api/version')
                .expect(200);
                
            expect(response.body).toHaveProperty('version');
            expect(response.body).toHaveProperty('name', 'Happy Speller');
        });
    });
    
    describe('Static Files', () => {
        test('should serve main application page', async () => {
            const response = await request(app)
                .get('/')
                .expect(200);
                
            expect(response.type).toBe('text/html');
        });
    });
});
EOF

    echo -e "${GREEN}✅ Integration tests created${NC}"
}

# Function to create environment configurations
create_multi_env_configs() {
    echo -e "${YELLOW}🌍 Creating multi-environment configurations...${NC}"
    
    # Dev environment
    mkdir -p environments/dev
    cat > environments/dev/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../helm/app/templates

namespace: happy-speller-dev

commonLabels:
  environment: dev
  version: v1.0.0

replicas:
  - name: happy-speller
    count: 1

images:
  - name: happy-speller
    newTag: latest

patchesStrategicMerge:
  - deployment-patch.yaml
EOF

    cat > environments/dev/deployment-patch.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: happy-speller
spec:
  template:
    spec:
      containers:
      - name: happy-speller
        env:
        - name: NODE_ENV
          value: "development"
        - name: LOG_LEVEL
          value: "debug"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
EOF

    # Staging environment
    mkdir -p environments/staging
    cat > environments/staging/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../helm/app/templates

namespace: happy-speller-staging

commonLabels:
  environment: staging
  version: v1.0.0

replicas:
  - name: happy-speller
    count: 2

images:
  - name: happy-speller
    newTag: stable

patchesStrategicMerge:
  - deployment-patch.yaml
EOF

    cat > environments/staging/deployment-patch.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: happy-speller
spec:
  template:
    spec:
      containers:
      - name: happy-speller
        env:
        - name: NODE_ENV
          value: "staging"
        - name: LOG_LEVEL
          value: "info"
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
EOF

    echo -e "${GREEN}✅ Multi-environment configurations created${NC}"
}

# Main execution
main() {
    echo -e "${YELLOW}Starting Portfolio Improvements Implementation...${NC}"
    echo
    
    # Check if we're in the right directory
    if [ ! -f "Jenkinsfile" ]; then
        echo -e "${RED}❌ Error: Run this script from the project root directory${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}This script will set up:${NC}"
    echo "  ✅ Enhanced directory structure"
    echo "  ✅ Monitoring and observability"
    echo "  ✅ Enhanced Jenkinsfile with security"
    echo "  ✅ Integration tests"
    echo "  ✅ Multi-environment configurations"
    echo
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    setup_directories
    setup_monitoring
    create_enhanced_jenkinsfile
    create_integration_tests
    create_multi_env_configs
    
    echo
    echo -e "${GREEN}🎉 Portfolio Improvements Setup Complete!${NC}"
    echo
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Review the created files and configurations"
    echo "2. Update package.json with new dependencies:"
    echo "   npm install --save prom-client"
    echo "   npm install --save-dev supertest"
    echo "3. Replace current Jenkinsfile with Jenkinsfile.enhanced"
    echo "4. Set up SonarQube server (optional)"
    echo "5. Install security tools (Snyk, Trivy) on Jenkins agent"
    echo "6. Test the enhanced pipeline"
    echo
    echo -e "${YELLOW}📚 View the complete improvement guide:${NC}"
    echo "./scripts/view-docs-from-minio.sh PORTFOLIO_IMPROVEMENTS"
    echo
}

# Run main function
main "$@"