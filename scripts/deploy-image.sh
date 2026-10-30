#!/bin/bash
set -e
set -o pipefail

# Deploys the pushed Bedrock_keycloak_MM1 image to AWS EKS with kubectl.
# Run from the repository root: ./scripts/deploy-image.sh

APP_NAME="bedrock-keycloak-mm1"
NAMESPACE="bedrock-keycloak-mm1"

echo "=== Deploy $APP_NAME to AWS EKS ==="

for tool in aws kubectl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: $tool is not installed or not in the PATH"
    exit 1
  fi
done

for f in namespace deployment service ingress; do
  if [ ! -f "kubernetes/$f.yaml" ]; then
    echo "ERROR: kubernetes/$f.yaml not found. Run this script from the repository root."
    exit 1
  fi
done

read -r -p "Enter the AWS region (for example us-east-1): " AWS_REGION
read -r -p "Enter the EKS cluster name: " CLUSTER_NAME
read -r -p "Enter the image URI (registry/repository:tag): " IMAGE_URI
if [ -z "$AWS_REGION" ] || [ -z "$CLUSTER_NAME" ] || [ -z "$IMAGE_URI" ]; then
  echo "ERROR: the AWS region, the cluster name and the image URI are required"
  exit 1
fi

echo "Application settings (press Enter to skip a value)"
read -r -p "Enter value for KC_DB (or press Enter to skip) [postgres]: " KC_DB
read -r -p "Enter value for DB_HOST (or press Enter to skip): " DB_HOST
read -r -p "Enter value for DB_PORT (or press Enter to skip) [5432]: " DB_PORT
read -r -p "Enter value for DB_NAME (or press Enter to skip) [keycloak]: " DB_NAME
read -r -p "Enter value for DB_USERNAME (or press Enter to skip): " DB_USERNAME
read -r -p "Enter value for KC_HOSTNAME (or press Enter to skip): " KC_HOSTNAME
KC_DB=${KC_DB:-postgres}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-keycloak}

echo "Credentials (typed values are not shown)"
read -r -s -p "Enter value for KC_DB_PASSWORD: " KC_DB_PASSWORD; echo ""
read -r -s -p "Enter value for KC_BOOTSTRAP_ADMIN_USERNAME: " KC_BOOTSTRAP_ADMIN_USERNAME; echo ""
read -r -s -p "Enter value for KC_BOOTSTRAP_ADMIN_PASSWORD: " KC_BOOTSTRAP_ADMIN_PASSWORD; echo ""
read -r -s -p "Enter value for KC_JGROUPS_KEY_PASSWORD (or press Enter to generate one per pod): " KC_JGROUPS_KEY_PASSWORD; echo ""
if [ -z "$KC_DB_PASSWORD" ] || [ -z "$KC_BOOTSTRAP_ADMIN_USERNAME" ] || [ -z "$KC_BOOTSTRAP_ADMIN_PASSWORD" ]; then
  echo "ERROR: KC_DB_PASSWORD, KC_BOOTSTRAP_ADMIN_USERNAME and KC_BOOTSTRAP_ADMIN_PASSWORD are required"
  exit 1
fi

# Keep the template of deployment.yaml, to restore it when the script ends
TEMPLATE_COPY=$(mktemp)
cp kubernetes/deployment.yaml "$TEMPLATE_COPY"
cleanup() {
  cp "$TEMPLATE_COPY" kubernetes/deployment.yaml
  rm -f "$TEMPLATE_COPY" kubernetes/deployment.yaml.bak
}
trap cleanup EXIT

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

replace_placeholder() {
  local name="$1"
  local value
  value=$(escape_sed "$2")
  sed -i.bak 's|{{'"$name"'}}|'"$value"'|g' kubernetes/deployment.yaml
  rm -f kubernetes/deployment.yaml.bak
}

echo "Step 1/6: configuring kubectl for the EKS cluster..."
if ! aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"; then
  echo "ERROR: could not configure kubectl (check the AWS credentials, the region and the cluster name)"
  exit 1
fi
kubectl cluster-info || exit 1

echo "Step 2/6: creating the namespace..."
if ! kubectl apply -f kubernetes/namespace.yaml; then
  echo "ERROR: could not apply kubernetes/namespace.yaml"
  exit 1
fi

echo "Step 3/6: creating the Secret $APP_NAME-secrets..."
if ! kubectl create secret generic "$APP_NAME-secrets" -n "$NAMESPACE" \
  --from-literal=KC_DB_PASSWORD="$KC_DB_PASSWORD" \
  --from-literal=KC_BOOTSTRAP_ADMIN_USERNAME="$KC_BOOTSTRAP_ADMIN_USERNAME" \
  --from-literal=KC_BOOTSTRAP_ADMIN_PASSWORD="$KC_BOOTSTRAP_ADMIN_PASSWORD" \
  --from-literal=KC_JGROUPS_KEY_PASSWORD="$KC_JGROUPS_KEY_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -; then
  echo "ERROR: could not create the Secret"
  exit 1
fi

echo "Step 4/6: filling in the placeholders of kubernetes/deployment.yaml..."
replace_placeholder "IMAGE_URI" "$IMAGE_URI"
replace_placeholder "NAMESPACE" "$NAMESPACE"
replace_placeholder "KC_DB" "$KC_DB"
replace_placeholder "DB_HOST" "$DB_HOST"
replace_placeholder "DB_PORT" "$DB_PORT"
replace_placeholder "DB_NAME" "$DB_NAME"
replace_placeholder "DB_USERNAME" "$DB_USERNAME"
replace_placeholder "KC_HOSTNAME" "$KC_HOSTNAME"

echo "Step 5/6: applying the manifests..."
for f in deployment service ingress; do
  if ! kubectl apply -f "kubernetes/$f.yaml"; then
    echo "ERROR: could not apply kubernetes/$f.yaml"
    echo "Rollback: kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE"
    exit 1
  fi
done

echo "Step 6/6: waiting for the rollout..."
if ! kubectl rollout status deployment/"$APP_NAME" -n "$NAMESPACE" --timeout=600s; then
  echo "ERROR: the rollout did not finish"
  echo "Rollback: kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE"
  echo "Logs: kubectl logs -l app=$APP_NAME -n $NAMESPACE --tail=100"
  exit 1
fi

kubectl get pods,svc,ingress -n "$NAMESPACE"

INGRESS_HOST=$(kubectl get ingress "$APP_NAME-ingress" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
if [ -n "$INGRESS_HOST" ]; then
  echo "Application URL: http://$INGRESS_HOST (host rule: $APP_NAME.example.com)"
else
  echo "The load balancer address is not ready yet. Check later with: kubectl get ingress -n $NAMESPACE"
fi

echo "=== Deployment finished ==="
echo "To roll back: kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE"
