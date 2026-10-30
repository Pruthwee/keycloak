#!/bin/bash
# Builds the Bedrock_keycloak_MM1 image and pushes it to AWS ECR or Docker Hub.
# Run from the repository root: ./scripts/build-push.sh
set -e
set -o pipefail

PROJECT_NAME="Bedrock_keycloak_MM1"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

echo "=== Build and push: $IMAGE_NAME ==="

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed or not in the PATH"
  exit 1
fi

echo "Select the registry:"
echo "  1. AWS ECR"
echo "  2. Docker Hub"
read -r -p "Enter 1 or 2: " REGISTRY_CHOICE

case "$REGISTRY_CHOICE" in
  1)
    if ! command -v aws >/dev/null 2>&1; then
      echo "ERROR: the AWS CLI is not installed or not in the PATH"
      exit 1
    fi
    read -r -p "Enter the AWS region (for example us-east-1): " AWS_REGION
    read -r -p "Enter the AWS account ID: " AWS_ACCOUNT_ID
    read -r -p "Enter the ECR repository name [$IMAGE_NAME]: " ECR_REPO
    ECR_REPO=${ECR_REPO:-$IMAGE_NAME}
    if [ -z "$AWS_REGION" ] || [ -z "$AWS_ACCOUNT_ID" ]; then
      echo "ERROR: the AWS region and the account ID are required"
      exit 1
    fi
    REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    REPO_PATH="$ECR_REPO"
    ;;
  2)
    read -r -p "Enter the Docker Hub username: " DOCKER_USERNAME
    read -r -s -p "Enter the Docker Hub password or access token: " DOCKER_PASSWORD
    echo ""
    read -r -p "Enter the repository name [$IMAGE_NAME]: " DOCKER_REPO
    DOCKER_REPO=${DOCKER_REPO:-$IMAGE_NAME}
    if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
      echo "ERROR: the Docker Hub username and password are required"
      exit 1
    fi
    REGISTRY_URL="docker.io"
    REPO_PATH="${DOCKER_USERNAME}/${DOCKER_REPO}"
    ;;
  *)
    echo "ERROR: invalid choice '$REGISTRY_CHOICE'"
    exit 1
    ;;
esac

read -r -p "Enter IMAGE_TAG [latest]: " IMAGE_TAG
IMAGE_TAG=$(echo "$IMAGE_TAG" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')
IMAGE_TAG=${IMAGE_TAG:-latest}

FULL_IMAGE_NAME="${REGISTRY_URL}/${REPO_PATH}:${IMAGE_TAG}"
echo "Image: $FULL_IMAGE_NAME"

echo "Step 1/3: building the image..."
docker build -f Dockerfile -t "$FULL_IMAGE_NAME" .
echo "Build finished."

echo "Step 2/3: logging in to the registry..."
if [ "$REGISTRY_CHOICE" = "1" ]; then
  aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_URL"
  echo "Checking the ECR repository..."
  aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 || aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"
else
  echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
fi
echo "Login succeeded."

echo "Step 3/3: pushing the image..."
docker push "$FULL_IMAGE_NAME"

echo "=== Done. Pushed: $FULL_IMAGE_NAME ==="
echo "Use this image URI with scripts/deploy-image.sh"
