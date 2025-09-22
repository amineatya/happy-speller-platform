#!/bin/bash

# MinIO Configuration
MINIO_ENDPOINT="http://192.168.68.58:9000"
MINIO_ACCESS_KEY="minioadmin"
MINIO_SECRET_KEY="FiXKggTsc4gnR"
BUCKET_NAME="happy-speller-platform"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')

echo "🚀 Starting upload to MinIO bucket: ${BUCKET_NAME}"

# Function to upload file to MinIO using curl
upload_to_minio() {
    local file_path="$1"
    local object_name="$2"
    local content_type="$3"
    
    echo "📤 Uploading: ${file_path} -> ${object_name}"
    
    # Calculate content hash
    content_md5=$(openssl md5 -binary "${file_path}" | base64)
    content_length=$(stat -f%z "${file_path}" 2>/dev/null || stat -c%s "${file_path}")
    date_value=$(date -u "+%a, %d %b %Y %H:%M:%S GMT")
    
    # Create authorization string
    string_to_sign="PUT\n${content_md5}\n${content_type}\n${date_value}\n/${BUCKET_NAME}/${object_name}"
    signature=$(echo -n "${string_to_sign}" | openssl sha1 -hmac "${MINIO_SECRET_KEY}" -binary | base64)
    
    # Upload file
    curl -X PUT \
         -H "Host: $(echo ${MINIO_ENDPOINT} | sed 's|http://||')" \
         -H "Date: ${date_value}" \
         -H "Content-Type: ${content_type}" \
         -H "Content-MD5: ${content_md5}" \
         -H "Content-Length: ${content_length}" \
         -H "Authorization: AWS ${MINIO_ACCESS_KEY}:${signature}" \
         -T "${file_path}" \
         "${MINIO_ENDPOINT}/${BUCKET_NAME}/${object_name}"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully uploaded: ${object_name}"
    else
        echo "❌ Failed to upload: ${object_name}"
    fi
}

# Create bucket first (ignore if exists)
echo "🪣 Creating bucket: ${BUCKET_NAME}"
curl -X PUT "${MINIO_ENDPOINT}/${BUCKET_NAME}" \
     -H "Authorization: AWS ${MINIO_ACCESS_KEY}:$(echo -n "PUT\n\n\n$(date -u '+%a, %d %b %Y %H:%M:%S GMT')\n/${BUCKET_NAME}" | openssl sha1 -hmac "${MINIO_SECRET_KEY}" -binary | base64)" \
     -H "Date: $(date -u '+%a, %d %b %Y %H:%M:%S GMT')" 2>/dev/null

echo ""

# Upload Jenkins files
echo "🔧 Uploading Jenkins files..."
upload_to_minio "Jenkinsfile" "jenkins/${DATE}/Jenkinsfile" "text/plain"
upload_to_minio "Jenkinsfile.non-k8s" "jenkins/${DATE}/Jenkinsfile.non-k8s" "text/plain"
upload_to_minio "jenkins-credentials.groovy" "jenkins/${DATE}/jenkins-credentials.groovy" "text/plain"
upload_to_minio "setup-jenkins-credentials.groovy" "jenkins/${DATE}/setup-jenkins-credentials.groovy" "text/plain"
upload_to_minio "simple-jenkins-credentials.groovy" "jenkins/${DATE}/simple-jenkins-credentials.groovy" "text/plain"

echo ""

# Upload Terraform files
echo "🏗️ Uploading Terraform files..."
if [ -f "infra/terraform/main.tf" ]; then
    upload_to_minio "infra/terraform/main.tf" "terraform/${DATE}/main.tf" "text/plain"
fi

if [ -f "infra/terraform/variables.tf" ]; then
    upload_to_minio "infra/terraform/variables.tf" "terraform/${DATE}/variables.tf" "text/plain"
fi

if [ -f "infra/terraform/outputs.tf" ]; then
    upload_to_minio "infra/terraform/outputs.tf" "terraform/${DATE}/outputs.tf" "text/plain"
fi

# Upload documentation and config files
echo ""
echo "📋 Uploading documentation and configuration files..."
for file in *.md kubeconfig-talos; do
    if [ -f "$file" ]; then
        content_type="text/plain"
        if [[ "$file" == *.md ]]; then
            content_type="text/markdown"
        fi
        upload_to_minio "$file" "docs/${DATE}/${file}" "$content_type"
    fi
done

echo ""
echo "🎉 Upload completed!"
echo "📁 Files uploaded to MinIO bucket: ${BUCKET_NAME}"
echo "🌐 MinIO Console: ${MINIO_ENDPOINT}/minio"
echo "🗓️ Timestamp: ${DATE}"