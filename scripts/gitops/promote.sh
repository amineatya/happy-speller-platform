#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SOURCE_ENV=""
TARGET_ENV=""
IMAGE_TAG=""
DRY_RUN=false
AUTO_APPROVE=false
GITOPS_REPO="https://github.com/amineatya/happy-speller-platform.git"  # Update with your actual repo
GITOPS_BRANCH="main"

# Usage function
usage() {
    echo -e "${BLUE}Happy Speller Platform - GitOps Promotion Script${NC}"
    echo ""
    echo "Usage: $0 <source-env> <target-env> [image-tag] [options]"
    echo ""
    echo "Arguments:"
    echo "  source-env    Source environment (dev, staging, prod)"
    echo "  target-env    Target environment (staging, prod)"
    echo "  image-tag     Specific image tag to promote (optional - will auto-detect if not provided)"
    echo ""
    echo "Options:"
    echo "  --dry-run     Show what would be changed without making changes"
    echo "  --auto-approve Automatically approve the promotion without confirmation"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dev staging                    # Promote current dev image to staging"
    echo "  $0 dev staging v1.2.3             # Promote specific image tag to staging"
    echo "  $0 staging prod --dry-run          # Preview promotion from staging to prod"
    echo "  $0 dev staging --auto-approve      # Auto-approve promotion"
    echo ""
}

# Parse command line arguments
parse_args() {
    if [ $# -lt 2 ]; then
        usage
        exit 1
    fi
    
    SOURCE_ENV=$1
    TARGET_ENV=$2
    shift 2
    
    # Check for image tag as third argument
    if [ $# -gt 0 ] && [[ ! "$1" =~ ^-- ]]; then
        IMAGE_TAG=$1
        shift
    fi
    
    # Parse options
    while [ $# -gt 0 ]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --auto-approve)
                AUTO_APPROVE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option $1${NC}"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate environments
    case $SOURCE_ENV in
        dev|staging|prod)
            ;;
        *)
            echo -e "${RED}Error: Invalid source environment '$SOURCE_ENV'. Must be dev, staging, or prod${NC}"
            exit 1
            ;;
    esac
    
    case $TARGET_ENV in
        staging|prod)
            ;;
        *)
            echo -e "${RED}Error: Invalid target environment '$TARGET_ENV'. Must be staging or prod${NC}"
            exit 1
            ;;
    esac
    
    # Validate promotion path
    if [[ "$SOURCE_ENV" == "prod" ]]; then
        echo -e "${RED}Error: Cannot promote from production environment${NC}"
        exit 1
    fi
    
    if [[ "$SOURCE_ENV" == "staging" && "$TARGET_ENV" == "dev" ]]; then
        echo -e "${RED}Error: Cannot promote from staging to dev${NC}"
        exit 1
    fi
}

# Get current image tag from environment
get_current_image_tag() {
    local env=$1
    local kustomization_file="gitops/environments/$env/kustomization.yaml"
    
    if [ ! -f "$kustomization_file" ]; then
        echo -e "${RED}Error: Kustomization file not found: $kustomization_file${NC}"
        exit 1
    fi
    
    local current_tag=$(grep "newTag:" "$kustomization_file" | sed 's/.*newTag: *//')
    if [ -z "$current_tag" ]; then
        echo -e "${RED}Error: Could not find current image tag in $kustomization_file${NC}"
        exit 1
    fi
    
    echo "$current_tag"
}

# Update image tag in environment
update_image_tag() {
    local env=$1
    local new_tag=$2
    local kustomization_file="gitops/environments/$env/kustomization.yaml"
    
    echo -e "${BLUE}[INFO]${NC} Updating $env environment to image tag: $new_tag"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would update $kustomization_file with newTag: $new_tag"
        return
    fi
    
    # Create backup
    cp "$kustomization_file" "${kustomization_file}.backup"
    
    # Update the image tag
    sed -i.tmp "s/newTag: .*/newTag: $new_tag/" "$kustomization_file"
    rm "${kustomization_file}.tmp" 2>/dev/null || true
    
    echo -e "${GREEN}[SUCCESS]${NC} Updated $kustomization_file"
}

# Verify ArgoCD application exists and is healthy
verify_argocd_app() {
    local env=$1
    local app_name="happy-speller-$env"
    
    echo -e "${BLUE}[INFO]${NC} Verifying ArgoCD application: $app_name"
    
    if command -v argocd >/dev/null 2>&1; then
        # Check if logged in to ArgoCD
        if argocd app get "$app_name" >/dev/null 2>&1; then
            echo -e "${GREEN}[SUCCESS]${NC} ArgoCD application $app_name is accessible"
            
            # Get app health
            local health=$(argocd app get "$app_name" -o json | jq -r '.status.health.status')
            echo -e "${BLUE}[INFO]${NC} Application health: $health"
            
            if [ "$health" != "Healthy" ]; then
                echo -e "${YELLOW}[WARNING]${NC} Application is not healthy. Current status: $health"
                if [ "$AUTO_APPROVE" = false ]; then
                    read -p "Continue with promotion? [y/N]: " -r
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        echo -e "${BLUE}[INFO]${NC} Promotion cancelled by user"
                        exit 0
                    fi
                fi
            fi
        else
            echo -e "${YELLOW}[WARNING]${NC} ArgoCD application $app_name not found or not accessible"
        fi
    else
        echo -e "${YELLOW}[WARNING]${NC} ArgoCD CLI not available, skipping application verification"
        # Fallback: check if namespace exists
        if kubectl get namespace "happy-speller-$env" >/dev/null 2>&1; then
            echo -e "${GREEN}[SUCCESS]${NC} Kubernetes namespace happy-speller-$env exists"
        else
            echo -e "${YELLOW}[WARNING]${NC} Kubernetes namespace happy-speller-$env does not exist"
        fi
    fi
}

# Show promotion summary
show_promotion_summary() {
    local source_tag=$1
    local target_tag=$2
    
    echo ""
    echo -e "${BLUE}=== PROMOTION SUMMARY ===${NC}"
    echo -e "Source Environment: ${GREEN}$SOURCE_ENV${NC}"
    echo -e "Target Environment: ${GREEN}$TARGET_ENV${NC}"
    echo -e "Current $SOURCE_ENV image: ${YELLOW}$source_tag${NC}"
    echo -e "New $TARGET_ENV image: ${GREEN}$target_tag${NC}"
    echo -e "Dry Run: ${YELLOW}$DRY_RUN${NC}"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} This is a dry run - no changes will be made"
        return
    fi
    
    if [ "$AUTO_APPROVE" = false ]; then
        echo -e "${YELLOW}Are you sure you want to proceed with this promotion?${NC}"
        read -p "Type 'yes' to continue: " -r
        if [ "$REPLY" != "yes" ]; then
            echo -e "${BLUE}[INFO]${NC} Promotion cancelled by user"
            exit 0
        fi
    fi
}

# Commit and push changes
commit_and_push() {
    local source_tag=$1
    local target_tag=$2
    local commit_message="Promote $SOURCE_ENV to $TARGET_ENV: $source_tag -> $target_tag"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would commit and push changes with message: $commit_message"
        return
    fi
    
    echo -e "${BLUE}[INFO]${NC} Committing and pushing changes..."
    
    # Configure git if not already configured
    if ! git config user.name >/dev/null 2>&1; then
        git config user.name "GitOps Promotion Bot"
        git config user.email "gitops@happy-speller.com"
    fi
    
    # Add, commit, and push
    git add "gitops/environments/$TARGET_ENV/kustomization.yaml"
    
    if git diff --staged --quiet; then
        echo -e "${YELLOW}[WARNING]${NC} No changes to commit"
        return
    fi
    
    git commit -m "$commit_message"
    git push origin "$GITOPS_BRANCH"
    
    echo -e "${GREEN}[SUCCESS]${NC} Changes committed and pushed"
}

# Wait for ArgoCD sync
wait_for_sync() {
    local app_name="happy-speller-$TARGET_ENV"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would wait for ArgoCD sync of $app_name"
        return
    fi
    
    echo -e "${BLUE}[INFO]${NC} Waiting for ArgoCD to sync $app_name..."
    
    if command -v argocd >/dev/null 2>&1; then
        # Wait for sync with timeout
        if timeout 300 argocd app wait "$app_name" --sync --health; then
            echo -e "${GREEN}[SUCCESS]${NC} ArgoCD sync completed successfully"
        else
            echo -e "${YELLOW}[WARNING]${NC} ArgoCD sync timed out or failed"
        fi
    else
        echo -e "${YELLOW}[WARNING]${NC} ArgoCD CLI not available, manual sync verification required"
        echo -e "${BLUE}[INFO]${NC} Check ArgoCD UI for sync status: http://localhost:30080"
    fi
}

# Main function
main() {
    parse_args "$@"
    
    echo -e "${BLUE}Happy Speller Platform - GitOps Promotion${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo ""
    
    # Change to repository root
    if [ ! -f "gitops/README.md" ]; then
        echo -e "${RED}Error: Must run from repository root (gitops/README.md not found)${NC}"
        exit 1
    fi
    
    # Get current image tag from source environment if not provided
    if [ -z "$IMAGE_TAG" ]; then
        SOURCE_TAG=$(get_current_image_tag "$SOURCE_ENV")
        echo -e "${BLUE}[INFO]${NC} Auto-detected image tag from $SOURCE_ENV: $SOURCE_TAG"
        TARGET_TAG="$SOURCE_TAG"
    else
        SOURCE_TAG=$(get_current_image_tag "$SOURCE_ENV")
        TARGET_TAG="$IMAGE_TAG"
    fi
    
    # Verify ArgoCD applications
    verify_argocd_app "$SOURCE_ENV"
    verify_argocd_app "$TARGET_ENV"
    
    # Show promotion summary and get confirmation
    show_promotion_summary "$SOURCE_TAG" "$TARGET_TAG"
    
    # Update target environment
    update_image_tag "$TARGET_ENV" "$TARGET_TAG"
    
    # Commit and push changes (unless dry run)
    commit_and_push "$SOURCE_TAG" "$TARGET_TAG"
    
    # Wait for ArgoCD sync
    wait_for_sync
    
    echo ""
    echo -e "${GREEN}🎉 Promotion completed successfully! 🎉${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Verify deployment in ArgoCD UI: http://localhost:30080"
    echo "2. Check application health in $TARGET_ENV environment"
    echo "3. Run smoke tests against the $TARGET_ENV environment"
    echo ""
}

# Run main function with all arguments
main "$@"