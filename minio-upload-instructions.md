# 📤 Upload Files to MinIO

## 🎯 Your MinIO Setup
- **MinIO Console**: `http://192.168.50.177:9001`
- **MinIO API**: `http://192.168.50.177:9000`
- **Credentials**: `minioadmin` / `FiXKggTsc4gnR`

## 📦 Files Ready for Upload
- **Archive**: `backup/happy-speller-platform-backup-2025-09-22_01-30-17.tar.gz` (24KB)
- **Contains**: Jenkins files, Terraform files, Documentation, Kubeconfig

## 🖱️ Method 1: Manual Upload via Web Console

1. **Open MinIO Console**: `http://192.168.50.177:9001`
2. **Login** with credentials: `minioadmin` / `FiXKggTsc4gnR`
3. **Create bucket** (if needed): `happy-speller-platform`
4. **Upload files**:
   - Click "Upload" or drag & drop
   - Select: `backup/happy-speller-platform-backup-2025-09-22_01-30-17.tar.gz`

## 🔧 Method 2: Using MinIO Client (mc)

Install MinIO client if not available:
```bash
# macOS
brew install minio/stable/mc

# Or download directly
wget https://dl.min.io/client/mc/release/darwin-amd64/mc
chmod +x mc
```

Configure and upload:
```bash
# Configure MinIO alias
mc alias set myminro http://192.168.50.177:9000 minioadmin FiXKggTsc4gnR

# Create bucket
mc mb myminro/happy-speller-platform

# Upload archive
mc cp backup/happy-speller-platform-backup-2025-09-22_01-30-17.tar.gz myminro/happy-speller-platform/

# Upload individual files (optional)
mc cp Jenkinsfile myminro/happy-speller-platform/jenkins/
mc cp infra/terraform/*.tf myminro/happy-speller-platform/terraform/
mc cp kubeconfig-talos myminro/happy-speller-platform/config/
```

## 📋 What's in the Archive

```
jenkins/
├── Jenkinsfile
├── Jenkinsfile.non-k8s  
├── jenkins-credentials.groovy
├── setup-jenkins-credentials.groovy
└── simple-jenkins-credentials.groovy

terraform/
├── main.tf
├── variables.tf
└── outputs.tf

docs/
├── All *.md documentation files
└── Setup instructions

config/
└── kubeconfig-talos

backup-info.txt (metadata)
```

## 🎯 Recommended Approach

**Use Method 1 (Web Console)** - it's the fastest:
1. Go to `http://192.168.50.177:9001`
2. Login with `minioadmin` / `FiXKggTsc4gnR`
3. Create bucket: `happy-speller-platform` 
4. Upload: `backup/happy-speller-platform-backup-2025-09-22_01-30-17.tar.gz`

✅ **Done!** Your Terraform and Jenkins files will be safely stored in MinIO.