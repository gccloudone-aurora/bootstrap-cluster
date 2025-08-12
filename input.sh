#!/bin/bash

# This script validates that required environment variables are set.

# Define an array of required environment variable names.
# Add or remove variables from this list as needed for your application.

REQUIRED_COMMON_VARS=(
    "CLUSTER_NAME"
    "AURORA_PLATFORM_CLUSTERS_REPOSITORY"
    "AURORA_PLATFORM_CLUSTERS_PATH"
    "AURORA_PLATFORM_NAMESPACE_PATH"
    "HELM_REGISTRY"
    "GIT_REPOSITORY_PAT"
    "ARGOCD_INSTANCE_HELM_CHART_VERSION"
    "AURORA_PLATFORM_HELM_CHART_VERSION"    
)
# "IMAGE_PULL_SECRET" is optional

REQUIRED_AZURE_VARS=(
    "CLUSTER_RESOURCE_GROUP"
    "AZURE_MSI_RESOURCE_ID"
)
# AZURE_MSI_CLIENT_ID is optional

REQUIRED_AWS_VARS=(
    "AWS_REGION"
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
)

echo "Fetching environment variables from .env.test"

# Before sourcing, enable auto-export
set -a
source .env
# After sourcing, disable auto-export if you don't want all subsequent variables exported
set +a


REQUIRED_VARS=()
case "$CSP" in
    "azure"|"AZURE")
        REQUIRED_VARS=("${REQUIRED_COMMON_VARS[@]}" "${REQUIRED_AZURE_VARS[@]}")
        echo "Azure vars"
        ;;
    "aws"|"AWS")
        REQUIRED_VARS=("${REQUIRED_COMMON_VARS[@]}" "${REQUIRED_AWS_VARS[@]}")
        echo "AWS vars"
        ;;
    *) # Default case for invalid input
        echo "Invalid CSP specified. The CSP environment varible must be set to 'azure' or 'aws'"
        exit 1 
        ;;
esac


echo "--- Validating Required Environment Variables ---"

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    else
        echo "✅ $var is set."
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo ""
    echo "❌ ERROR: The following required environment variables are NOT set:"
    for missing_var in "${MISSING_VARS[@]}"; do
        echo "   - $missing_var"
    done
    echo ""
    echo "Please set these variables before proceeding. You can often do this by:"
    echo "  - Exporting them in your shell (e.g., export MY_API_KEY=\"your_key\")"
    echo "  - Sourcing a configuration file (e.g., source .env)"
    exit 1 # Exit with an error code
else
    echo ""
    echo "🎉 All required environment variables are set!"
    echo ""
fi
