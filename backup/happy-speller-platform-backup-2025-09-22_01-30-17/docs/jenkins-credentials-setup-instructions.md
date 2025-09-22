# Jenkins Credentials Setup Instructions

## Method 1: Using Jenkins Script Console (Recommended)

1. **Access Jenkins Script Console:**
   - Go to `http://192.168.50.247:8080/script` (your Jenkins URL + /script)
   - Or navigate: Jenkins → Manage Jenkins → Script Console

2. **Run the Setup Script:**
   - Copy and paste the contents of `setup-jenkins-credentials.groovy`
   - Click "Run"
   - This will create the `gitea-token` and `minio-creds` credentials

## Method 2: Manual Setup via Jenkins UI

### 1. Gitea Token Credential

1. Go to: Jenkins → Manage Jenkins → Manage Credentials
2. Click on "Global" → "Add Credentials"
3. Select "Secret text"
4. Fill in:
   - **ID**: `gitea-token`
   - **Description**: `Gitea API token`
   - **Secret**: `9b407fc263328ce9f89b41721d80b48a306ece8d`
5. Click "Create"

### 2. MinIO Credentials

1. In the same credentials section, click "Add Credentials"
2. Select "Username with password"
3. Fill in:
   - **ID**: `minio-creds`
   - **Description**: `MinIO access credentials`
   - **Username**: `minioadmin`
   - **Password**: `FiXKggTsc4gnR`
4. Click "Create"

### 3. Kubeconfig File (Required for Kubernetes stages)

1. Click "Add Credentials" again
2. Select "Secret file"
3. Fill in:
   - **ID**: `kubeconfig`
   - **Description**: `Kubernetes config file`
   - **File**: Upload your kubeconfig file (usually found at `~/.kube/config`)
4. Click "Create"

## Verification

After setting up all credentials, you should see:
- ✅ `gitea-token` (Secret text)
- ✅ `minio-creds` (Username with password)
- ✅ `kubeconfig` (Secret file)

## Testing

Run your Jenkins pipeline again - it should now have access to all required credentials and the "Gitea API token" error should be resolved.

## Security Notes

- The credentials are now stored securely in Jenkins' credential store
- They are encrypted at rest
- Only authorized Jenkins jobs can access them via the credential IDs
- Never commit these credentials to version control