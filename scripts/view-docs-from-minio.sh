#!/bin/bash

# Script to view documentation from MinIO
# Usage: ./view-docs-from-minio.sh [document-name]

MINIO_ALIAS="myminio"
DOCS_BUCKET="docs"

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Happy Speller Documentation Viewer ===${NC}"
echo

# Check if MinIO client is available
if ! command -v mc &> /dev/null; then
    echo -e "${YELLOW}MinIO client 'mc' not found. Please install it first.${NC}"
    exit 1
fi

# Function to list available documents
list_docs() {
    echo -e "${BLUE}Available Documentation in MinIO:${NC}"
    echo -e "${BLUE}Server: http://192.168.50.177:9001${NC}"
    echo -e "${BLUE}Bucket: ${DOCS_BUCKET}${NC}"
    echo
    
    if mc ls ${MINIO_ALIAS}/${DOCS_BUCKET}/ &>/dev/null; then
        mc ls ${MINIO_ALIAS}/${DOCS_BUCKET}/ | while read line; do
            if [[ $line == *".md" ]]; then
                filename=$(echo $line | awk '{print $NF}')
                size=$(echo $line | awk '{print $(NF-2)}')
                echo -e "  📄 ${GREEN}$filename${NC} ($size)"
            fi
        done
    else
        echo -e "${YELLOW}Could not connect to MinIO or bucket does not exist${NC}"
        return 1
    fi
}

# Function to view a specific document
view_doc() {
    local doc_name="$1"
    
    # Add .md extension if not present
    if [[ ! "$doc_name" == *.md ]]; then
        doc_name="${doc_name}.md"
    fi
    
    echo -e "${BLUE}Retrieving: ${GREEN}$doc_name${NC}"
    
    if mc cat ${MINIO_ALIAS}/${DOCS_BUCKET}/$doc_name 2>/dev/null; then
        echo
        echo -e "${GREEN}✓ Document retrieved successfully from MinIO${NC}"
    else
        echo -e "${YELLOW}Document '$doc_name' not found in MinIO bucket${NC}"
        echo
        list_docs
        return 1
    fi
}

# Function to download a document
download_doc() {
    local doc_name="$1"
    local local_path="${2:-.}"
    
    # Add .md extension if not present
    if [[ ! "$doc_name" == *.md ]]; then
        doc_name="${doc_name}.md"
    fi
    
    echo -e "${BLUE}Downloading: ${GREEN}$doc_name${NC} to ${local_path}"
    
    if mc cp ${MINIO_ALIAS}/${DOCS_BUCKET}/$doc_name $local_path/ 2>/dev/null; then
        echo -e "${GREEN}✓ Document downloaded successfully${NC}"
    else
        echo -e "${YELLOW}Failed to download '$doc_name'${NC}"
        return 1
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS] [DOCUMENT_NAME]"
    echo
    echo "Options:"
    echo "  -l, --list              List all available documents"
    echo "  -d, --download DOC      Download document to current directory"
    echo "  -o, --output PATH       Specify output directory for download"
    echo "  -h, --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0                                    # List all documents"
    echo "  $0 ARCHITECTURE_DIAGRAM               # View architecture diagram"
    echo "  $0 README                             # View main README"
    echo "  $0 -d ARCHITECTURE_DIAGRAM            # Download architecture diagram"
    echo "  $0 -d README -o /tmp                  # Download README to /tmp"
    echo
    echo "Available documents:"
    echo "  - ARCHITECTURE_DIAGRAM    : Complete system architecture"
    echo "  - README                  : Project overview and quick start"
    echo "  - CI_CD_PIPELINE_SUMMARY  : Comprehensive pipeline details"
    echo "  - GITOPS_GUIDE           : GitOps implementation guide"
    echo "  - README-minio-backend   : MinIO backend setup"
    echo "  - DOCS_INDEX             : Documentation index"
}

# Parse command line arguments
DOWNLOAD_MODE=false
OUTPUT_PATH="."

while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--list)
            list_docs
            exit 0
            ;;
        -d|--download)
            DOWNLOAD_MODE=true
            shift
            ;;
        -o|--output)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo -e "${YELLOW}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
        *)
            DOC_NAME="$1"
            shift
            ;;
    esac
done

# Main logic
if [[ -z "$DOC_NAME" ]]; then
    list_docs
elif [[ "$DOWNLOAD_MODE" == true ]]; then
    download_doc "$DOC_NAME" "$OUTPUT_PATH"
else
    view_doc "$DOC_NAME"
fi