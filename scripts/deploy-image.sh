#!/bin/bash
set -e
set -o pipefail

# Deploy script for Keycloak on AWS EKS
# Usage: ./scripts/deploy-image.sh

PROJECT_NAME="keycloak"
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s-*$//')

echo "=== Keycloak Deploy to AWS EKS ==="
echo "Project: $PROJECT_NAME"
echo "Image: $IMAGE_NAME"
echo ""

# Ask for AWS region
read -p "Enter AWS region (e.g., us-east-1): " AWS_REGION

# Ask for EKS cluster name
read -p "Enter EKS cluster name: " CLUSTER_NAME

# Ask for image URI
read -p "Enter full image URI (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/keycloak:latest): " IMAGE_URI

# Ask for environment variables
echo ""
echo "=== Environment Variables ==="
echo "Enter values for environment variables (or press Enter to skip)."
echo ""

read -p "Enter value for DB_HOST (or press Enter to skip): " DB_HOST
read -p "Enter value for DB_PORT (or press Enter to skip): " DB_PORT
read -p "Enter value for DB_DATABASE (or press Enter to skip): " DB_DATABASE
read -p "Enter value for DB_USER (or press Enter to skip): " DB_USER
read -sp "Enter value for DB_PASSWORD (or press Enter to skip): " DB_PASSWORD
echo ""

# Configure kubectl for the EKS cluster
echo ""
echo "=== Configuring kubectl for EKS ==="
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
echo "kubectl configured for cluster: $CLUSTER_NAME"

# Verify cluster connectivity
kubectl cluster-info || exit 1
echo "Cluster connectivity verified"

# Apply namespace
echo ""
echo "=== Applying namespace ==="
kubectl apply -f kubernetes/namespace.yaml
echo "Namespace applied"

# Create secrets if DB_USER and DB_PASSWORD are provided
if [ -n "$DB_USER" ] && [ -n "$DB_PASSWORD" ]; then
    echo ""
    echo "=== Creating Kubernetes Secret ==="
    kubectl create secret generic keycloak-secrets -n keycloak \
        --from-literal=db-user="$DB_USER" \
        --from-literal=db-password="$DB_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
    echo "Secret created: keycloak-secrets"
fi

# Apply deployment with placeholder replacements
echo ""
echo "=== Applying deployment ==="
cp kubernetes/deployment.yaml /tmp/deployment.yaml.bak
sed -i.bak 's|{{IMAGE_URI}}|'$IMAGE_URI'|g' kubernetes/deployment.yaml
sed -i.bak 's|{{DB_HOST}}|'"${DB_HOST:-localhost}"'|g' kubernetes/deployment.yaml
sed -i.bak 's|{{DB_PORT}}|'"${DB_PORT:-5432}"'|g' kubernetes/deployment.yaml
sed -i.bak 's|{{DB_DATABASE}}|'"${DB_DATABASE:-keycloak}"'|g' kubernetes/deployment.yaml
rm -f kubernetes/deployment.yaml.bak
kubectl apply -f kubernetes/deployment.yaml
echo "Deployment applied"

# Apply service
echo ""
echo "=== Applying service ==="
kubectl apply -f kubernetes/service.yaml
echo "Service applied"

# Apply ingress
echo ""
echo "=== Applying ingress ==="
kubectl apply -f kubernetes/ingress.yaml
echo "Ingress applied"

# Wait for deployment to be ready
echo ""
echo "=== Waiting for deployment rollout ==="
kubectl rollout status deployment/keycloak -n keycloak
echo "Deployment is ready"

# Show resources
echo ""
echo "=== Resources ==="
kubectl get pods,svc,ingress -n keycloak

# Show application URL
echo ""
echo "=== Application URL ==="
echo "https://keycloak.example.com"
echo ""
echo "=== Deployment complete ==="
echo "If the deployment fails, rollback with:"
echo "  kubectl rollout undo deployment/keycloak -n keycloak"
