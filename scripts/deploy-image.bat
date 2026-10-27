@echo off
setlocal enabledelayedexpansion
set -e

echo === Keycloak Deploy to AWS EKS ===

set PROJECT_NAME=keycloak
set IMAGE_NAME=keycloak

echo Project: !PROJECT_NAME!
echo Image: !IMAGE_NAME!
echo.

set /p AWS_REGION="Enter AWS region (e.g., us-east-1): "
set /p CLUSTER_NAME="Enter EKS cluster name: "
set /p IMAGE_URI="Enter full image URI (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/keycloak:latest): "

echo.
echo === Environment Variables ===
echo Enter values for environment variables (or press Enter to skip).
echo.

set /p DB_HOST="Enter value for DB_HOST (or press Enter to skip): "
set /p DB_PORT="Enter value for DB_PORT (or press Enter to skip): "
set /p DB_DATABASE="Enter value for DB_DATABASE (or press Enter to skip): "
set /p DB_USER="Enter value for DB_USER (or press Enter to skip): "
set /p DB_PASSWORD="Enter value for DB_PASSWORD (or press Enter to skip): "

echo.
echo === Configuring kubectl for EKS ===
aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (
    echo Failed to update kubeconfig
    exit /b 1
)
echo kubectl configured for cluster: !CLUSTER_NAME!

kubectl cluster-info
if !ERRORLEVEL! neq 0 (
    echo Cluster connectivity check failed
    exit /b 1
)
echo Cluster connectivity verified

echo.
echo === Applying namespace ===
kubectl apply -f kubernetes/namespace.yaml
if !ERRORLEVEL! neq 0 (
    echo Failed to apply namespace
    exit /b 1
)
echo Namespace applied

REM Create secrets if DB_USER and DB_PASSWORD are provided
if not "!DB_USER!"=="" if not "!DB_PASSWORD!"=="" (
    echo.
    echo === Creating Kubernetes Secret ===
    kubectl create secret generic keycloak-secrets -n keycloak --from-literal=db-user="!DB_USER!" --from-literal=db-password="!DB_PASSWORD!" --dry-run=client -o yaml | kubectl apply -f -
    if !ERRORLEVEL! neq 0 (
        echo Failed to create secret
        exit /b 1
    )
    echo Secret created: keycloak-secrets
)

echo.
echo === Applying deployment ===
copy kubernetes\deployment.yaml kubernetes\deployment.yaml.bak >nul 2>&1
sed -i.bak "s|{{IMAGE_URI}}|!IMAGE_URI!|g" kubernetes/deployment.yaml
sed -i.bak "s|{{DB_HOST}}|!DB_HOST!|g" kubernetes/deployment.yaml
sed -i.bak "s|{{DB_PORT}}|!DB_PORT!|g" kubernetes/deployment.yaml
sed -i.bak "s|{{DB_DATABASE}}|!DB_DATABASE!|g" kubernetes/deployment.yaml
del kubernetes/deployment.yaml.bak >nul 2>&1
kubectl apply -f kubernetes/deployment.yaml
if !ERRORLEVEL! neq 0 (
    echo Failed to apply deployment
    exit /b 1
)
echo Deployment applied

echo.
echo === Applying service ===
kubectl apply -f kubernetes/service.yaml
if !ERRORLEVEL! neq 0 (
    echo Failed to apply service
    exit /b 1
)
echo Service applied

echo.
echo === Applying ingress ===
kubectl apply -f kubernetes/ingress.yaml
if !ERRORLEVEL! neq 0 (
    echo Failed to apply ingress
    exit /b 1
)
echo Ingress applied

echo.
echo === Waiting for deployment rollout ===
kubectl rollout status deployment/keycloak -n keycloak
if !ERRORLEVEL! neq 0 (
    echo Deployment rollout failed
    exit /b 1
)
echo Deployment is ready

echo.
echo === Resources ===
kubectl get pods,svc,ingress -n keycloak

echo.
echo === Application URL ===
echo https://keycloak.example.com
echo.
echo === Deployment complete ===
echo If the deployment fails, rollback with:
echo   kubectl rollout undo deployment/keycloak -n keycloak

endlocal
