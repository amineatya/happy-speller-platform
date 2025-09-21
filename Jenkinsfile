pipeline {
    agent {
        kubernetes {
            label 'jenkins-agent-nodejs'
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: node
    image: node:20-alpine
    command: ['cat']
    tty: true
    volumeMounts:
    - name: docker
      mountPath: /var/run/docker.sock
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ['cat']
    tty: true
  - name: helm
    image: alpine/helm:3.12.0
    command: ['cat']
    tty: true
  volumes:
  - name: docker
    hostPath:
      path: /var/run/docker.sock
"""
        }
    }
    
    environment {
        GITEA_BASE = 'http://192.168.50.130:3000'
        JENKINS_BASE = 'http://192.168.50.247:8080'
        MINIO_BASE = 'http://192.168.68.58:9000'
        REGISTRY = 'registry.local:5000'
        NAMESPACE = 'demo'
        APP_NAME = 'happy-speller'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    currentBuild.displayName = "BUILD #${BUILD_NUMBER} - ${env.GIT_COMMIT.take(8)}"
                    currentBuild.description = "Branch: ${env.BRANCH_NAME}"
                }
            }
        }
        
        stage('Notify Gitea - PENDING') {
            steps {
                script {
                    def commitSha = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                    updateGiteaStatus(commitSha, 'pending', 'Build started', 'jenkins/build')
                }
            }
        }
        
        stage('Build') {
            steps {
                container('node') {
                    sh '''
                        echo "Building application..."
                        cd app
                        npm install
                        npm run lint || { echo "Linting failed but continuing"; }
                    '''
                }
            }
        }
        
        stage('Test') {
            steps {
                container('node') {
                    sh '''
                        echo "Running tests..."
                        cd app
                        npm test -- --ci --coverage --reporters=default --reporters=jest-junit
                    '''
                }
            }
            post {
                always {
                    junit 'app/junit.xml'
                    publishHTML(target: [
                        allowMissing: false,
                        alwaysLinkToLastBuild: false,
                        keepAll: true,
                        reportDir: 'app/coverage',
                        reportFiles: 'lcov-report/index.html',
                        reportName: 'Jest Coverage Report',
                        reportTitles: ''
                    ])
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                container('node') {
                    sh '''
                        echo "Running security scan..."
                        cd app
                        npm audit --audit-level=moderate || true
                    '''
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                container('node') {
                    script {
                        def shortCommit = env.GIT_COMMIT.take(8)
                        def imageTag = "${env.REGISTRY}/${APP_NAME}:${BUILD_NUMBER}-${shortCommit}"
                        def imageTagLatest = "${env.REGISTRY}/${APP_NAME}:latest"
                        
                        sh """
                            cd app
                            docker build -t ${imageTag} -t ${imageTagLatest} .
                        """
                        
                        // In a real scenario, you would push to a registry here
                        // docker push ${imageTag}
                        // docker push ${imageTagLatest}
                    }
                }
            }
        }
        
        stage('Upload Artifacts to MinIO') {
            steps {
                script {
                    try {
                        withCredentials([[
                            $class: 'UsernamePasswordMultiBinding',
                            credentialsId: 'minio-creds',
                            usernameVariable: 'MINIO_ACCESS_KEY',
                            passwordVariable: 'MINIO_SECRET_KEY'
                        ]]) {
                            sh '''
                                # Create tarball of artifacts
                                tar -czf artifacts-${BUILD_NUMBER}.tgz app/coverage/ app/junit.xml app/package-lock.json
                                
                                # Upload to MinIO using curl (assuming no mc client)
                                curl -X PUT -T artifacts-${BUILD_NUMBER}.tgz \
                                  -H "X-Amz-Date: $(date -R)" \
                                  -H "Authorization: AWS ${MINIO_ACCESS_KEY}:$(echo -n "PUT\n\n\n$(date -R)\n/artifacts/artifacts-${BUILD_NUMBER}.tgz" | openssl sha1 -hmac ${MINIO_SECRET_KEY} -binary | base64)" \
                                  ${MINIO_BASE}/artifacts/artifacts-${BUILD_NUMBER}.tgz
                            '''
                        }
                    } catch (Exception e) {
                        echo "MinIO upload failed: ${e.getMessage()}. Continuing..."
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                container('helm') {
                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                        script {
                            def shortCommit = env.GIT_COMMIT.take(8)
                            sh """
                                # Create namespace if it doesn't exist
                                kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                                
                                # Deploy with Helm
                                helm upgrade --install ${APP_NAME} ./helm/app \
                                  --namespace ${NAMESPACE} \
                                  --set image.repository=${REGISTRY}/${APP_NAME} \
                                  --set image.tag=${BUILD_NUMBER}-${shortCommit} \
                                  --set replicaCount=2
                            """
                        }
                    }
                }
            }
        }
        
        stage('Smoke Test') {
            steps {
                container('kubectl') {
                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                        retry(3) {
                            sleep 10  // Wait for deployment to be ready
                            sh """
                                # Test the health endpoint
                                kubectl run smoke-test --rm -i --restart=Never --namespace ${NAMESPACE} \
                                  --image=curlimages/curl:8.2.1 -- \
                                  curl -s http://${APP_NAME}:8080/healthz | grep '"status":"ok"' || exit 1
                            """
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            script {
                def commitSha = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                updateGiteaStatus(commitSha, 'success', 'Build successful', 'jenkins/build')
            }
        }
        failure {
            script {
                def commitSha = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                updateGiteaStatus(commitSha, 'failure', 'Build failed', 'jenkins/build')
            }
        }
        always {
            cleanWs()
        }
    }
}

// Function to update Gitea commit status
def updateGiteaStatus(commitSha, state, description, context) {
    withCredentials([string(credentialsId: 'gitea-token', variable: 'GITEA_TOKEN')]) {
        sh """
            curl -X POST \
              -H "Authorization: token ${GITEA_TOKEN}" \
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
}
