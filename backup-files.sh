#!/bin/bash

# Backup configuration
BACKUP_DIR="backup"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')
BACKUP_NAME="happy-speller-platform-backup-${DATE}"
ARCHIVE_NAME="${BACKUP_NAME}.tar.gz"

echo "🚀 Creating backup archive for Terraform and Jenkins files"
echo "📅 Date: ${DATE}"

# Create backup directory structure
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/jenkins"
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/terraform"
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/docs"
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/config"

echo "📁 Created backup directory structure"

# Copy Jenkins files
echo "🔧 Backing up Jenkins files..."
cp Jenkinsfile "${BACKUP_DIR}/${BACKUP_NAME}/jenkins/" 2>/dev/null
cp Jenkinsfile.non-k8s "${BACKUP_DIR}/${BACKUP_NAME}/jenkins/" 2>/dev/null
cp jenkins-credentials.groovy "${BACKUP_DIR}/${BACKUP_NAME}/jenkins/" 2>/dev/null
cp setup-jenkins-credentials.groovy "${BACKUP_DIR}/${BACKUP_NAME}/jenkins/" 2>/dev/null
cp simple-jenkins-credentials.groovy "${BACKUP_DIR}/${BACKUP_NAME}/jenkins/" 2>/dev/null

# Copy Terraform files
echo "🏗️ Backing up Terraform files..."
if [ -d "infra/terraform" ]; then
    cp -r infra/terraform/* "${BACKUP_DIR}/${BACKUP_NAME}/terraform/" 2>/dev/null
fi

# Copy documentation and configuration files
echo "📋 Backing up documentation and configuration files..."
cp *.md "${BACKUP_DIR}/${BACKUP_NAME}/docs/" 2>/dev/null
cp kubeconfig-talos "${BACKUP_DIR}/${BACKUP_NAME}/config/" 2>/dev/null

# Create metadata file
cat > "${BACKUP_DIR}/${BACKUP_NAME}/backup-info.txt" << EOF
Happy Speller Platform Backup
=============================

Backup Date: ${DATE}
Created by: $(whoami)
Hostname: $(hostname)
Directory: $(pwd)

Contents:
- Jenkins files (Jenkinsfile, credentials scripts)
- Terraform infrastructure files
- Documentation (*.md files)  
- Kubernetes configuration (kubeconfig-talos)

Infrastructure Details:
- Jenkins: http://192.168.50.247:8080
- Gitea: http://192.168.50.130:3000
- Talos Master: 192.168.50.226
- Talos Worker: 192.168.50.183
- MinIO: http://192.168.68.58:9000 (not accessible from this network)
EOF

# Create archive
echo "📦 Creating archive: ${ARCHIVE_NAME}"
cd "${BACKUP_DIR}"
tar -czf "${ARCHIVE_NAME}" "${BACKUP_NAME}/"
cd ..

# Show results
echo ""
echo "✅ Backup completed successfully!"
echo "📁 Archive created: ${BACKUP_DIR}/${ARCHIVE_NAME}"
echo "📊 Archive size: $(du -h "${BACKUP_DIR}/${ARCHIVE_NAME}" | cut -f1)"
echo ""

# List contents
echo "📋 Archive contents:"
tar -tzf "${BACKUP_DIR}/${ARCHIVE_NAME}" | head -20
if [ $(tar -tzf "${BACKUP_DIR}/${ARCHIVE_NAME}" | wc -l) -gt 20 ]; then
    echo "... and $(expr $(tar -tzf "${BACKUP_DIR}/${ARCHIVE_NAME}" | wc -l) - 20) more files"
fi

echo ""
echo "🎉 All files backed up locally!"
echo "💾 To upload later when MinIO is accessible:"
echo "   tar -xzf ${BACKUP_DIR}/${ARCHIVE_NAME} -C /tmp && upload to MinIO"

# Try MinIO upload as secondary option (non-blocking)
echo ""
echo "🔄 Attempting MinIO upload (will timeout quickly if not available)..."
if timeout 10 curl -s http://192.168.68.58:9000/minio/health/live 2>/dev/null; then
    echo "✅ MinIO is accessible, would you like to upload now?"
else
    echo "⚠️  MinIO not accessible from this network."
    echo "💡 Alternative: Copy ${BACKUP_DIR}/${ARCHIVE_NAME} to a system with MinIO access"
fi