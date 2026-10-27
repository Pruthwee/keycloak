#!/bin/bash
set -e

# Build and push script for Keycloak on AWS ECR
# Usage: ./scripts/build-push.sh

PROJECT_NAME="keycloak"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s-*$//')

echo "=== Keycloak Build and Push Script ==="
echo "Project: $PROJECT_NAME"
echo "Image: $IMAGE_NAME"
echo ""

# Ask for AWS region
read -p "Enter AWS region (e.g., us-east-1): " AWS_REGION
export AWS_REGION

# Ask for ECR registry URL
read -p "Enter ECR registry URL (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com): " REGISTRY_URL
export REGISTRY_URL

# Ask for ECR repository name
read -p "Enter ECR repository name (or press Enter for '$IMAGE_NAME'): " ECR_REPO
ECR_REPO=${ECR_REPO:-$IMAGE_NAME}
export ECR_REPO

# Ask for image tag
read -p "Enter image tag (or press Enter for 'latest'): " IMAGE_TAG
IMAGE_TAG=${IMAGE_TAG:-latest}

# Sanitize tag
IMAGE_TAG=$(echo "$IMAGE_TAG" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s-*$//')
if [ -z "$IMAGE_TAG" ]; then
    IMAGE_TAG="latest"
fi

# Build full image name
FULL_IMAGE_NAME="${REGISTRY_URL}/${ECR_REPO}:${IMAGE_TAG}"

echo ""
echo "=== Configuration ==="
echo "AWS Region: $AWS_REGION"
echo "Registry: $REGISTRY_URL"
echo "Repository: $ECR_REPO"
echo "Tag: $IMAGE_TAG"
echo "Full Image: $FULL_IMAGE_NAME"
echo ""

# Login to ECR
echo "=== Logging in to Amazon ECR ==="
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_URL"
echo "ECR login successful"

# Create repository if it doesn't exist
echo "=== Checking ECR repository ==="
aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"
echo "Repository ready: $ECR_REPO"

# Build the Docker image
echo "=== Building Docker image ==="
docker build -f Dockerfile -t "$FULL_IMAGE_NAME" .
echo "Docker build successful"

# Push the image
echo "=== Pushing Docker image ==="
docker push "$FULL_IMAGE_NAME"
echo "Docker push successful"

echo ""
echo "=== Done ==="
echo "Image pushed: $FULL_IMAGE_NAME"
echo ""
echo "To deploy to EKS, run: ./scripts/deploy-image.sh"
