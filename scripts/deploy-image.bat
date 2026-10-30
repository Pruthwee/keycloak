@echo off & setlocal enabledelayedexpansion
rem Deploys the pushed Bedrock_keycloak_MM1 image to AWS EKS with kubectl.
rem Run from the repository root - scripts\deploy-image.bat

set "APP_NAME=bedrock-keycloak-mm1"
set "NAMESPACE=bedrock-keycloak-mm1"

echo === Deploy !APP_NAME! to AWS EKS ===

where aws >nul 2>&1
if !ERRORLEVEL! neq 0 (echo The AWS CLI is not installed or not in the PATH & exit /b 1)
where kubectl >nul 2>&1
if !ERRORLEVEL! neq 0 (echo kubectl is not installed or not in the PATH & exit /b 1)

if not exist kubernetes\deployment.yaml (echo kubernetes\deployment.yaml not found - run this script from the repository root & exit /b 1)

set /p AWS_REGION="Enter the AWS region (for example us-east-1): "
set /p CLUSTER_NAME="Enter the EKS cluster name: "
set /p IMAGE_URI="Enter the image URI (registry/repository and tag): "
if "!AWS_REGION!"=="" (echo The AWS region is required & exit /b 1)
if "!CLUSTER_NAME!"=="" (echo The cluster name is required & exit /b 1)
if "!IMAGE_URI!"=="" (echo The image URI is required & exit /b 1)

echo Application settings - press Enter to skip a value
set /p KC_DB="Enter value for KC_DB (or press Enter to skip): "
set /p DB_HOST="Enter value for DB_HOST (or press Enter to skip): "
set /p DB_PORT="Enter value for DB_PORT (or press Enter to skip): "
set /p DB_NAME="Enter value for DB_NAME (or press Enter to skip): "
set /p DB_USERNAME="Enter value for DB_USERNAME (or press Enter to skip): "
set /p KC_HOSTNAME="Enter value for KC_HOSTNAME (or press Enter to skip): "
if "!KC_DB!"=="" set "KC_DB=postgres"
if "!DB_PORT!"=="" set "DB_PORT=5432"
if "!DB_NAME!"=="" set "DB_NAME=keycloak"

echo Credentials - the console shows what you type on Windows
set /p KC_DB_PASSWORD="Enter value for KC_DB_PASSWORD: "
set /p KC_BOOTSTRAP_ADMIN_USERNAME="Enter value for KC_BOOTSTRAP_ADMIN_USERNAME: "
set /p KC_BOOTSTRAP_ADMIN_PASSWORD="Enter value for KC_BOOTSTRAP_ADMIN_PASSWORD: "
set /p KC_JGROUPS_KEY_PASSWORD="Enter value for KC_JGROUPS_KEY_PASSWORD (or press Enter to generate one per pod): "
if "!KC_DB_PASSWORD!"=="" (echo KC_DB_PASSWORD is required & exit /b 1)
if "!KC_BOOTSTRAP_ADMIN_USERNAME!"=="" (echo KC_BOOTSTRAP_ADMIN_USERNAME is required & exit /b 1)
if "!KC_BOOTSTRAP_ADMIN_PASSWORD!"=="" (echo KC_BOOTSTRAP_ADMIN_PASSWORD is required & exit /b 1)

echo Step 1 of 6 - configuring kubectl for the EKS cluster
aws eks update-kubeconfig --region !AWS_REGION! --name !CLUSTER_NAME!
if !ERRORLEVEL! neq 0 (echo Could not configure kubectl - check the AWS credentials, the region and the cluster name & exit /b 1)
kubectl cluster-info
if !ERRORLEVEL! neq 0 (echo kubectl cannot reach the cluster & exit /b 1)

echo Step 2 of 6 - creating the namespace
kubectl apply -f kubernetes\namespace.yaml
if !ERRORLEVEL! neq 0 (echo Could not apply kubernetes\namespace.yaml & exit /b 1)

echo Step 3 of 6 - creating the Secret !APP_NAME!-secrets
kubectl create secret generic !APP_NAME!-secrets -n !NAMESPACE! --from-literal=KC_DB_PASSWORD="!KC_DB_PASSWORD!" --from-literal=KC_BOOTSTRAP_ADMIN_USERNAME="!KC_BOOTSTRAP_ADMIN_USERNAME!" --from-literal=KC_BOOTSTRAP_ADMIN_PASSWORD="!KC_BOOTSTRAP_ADMIN_PASSWORD!" --from-literal=KC_JGROUPS_KEY_PASSWORD="!KC_JGROUPS_KEY_PASSWORD!" --dry-run=client -o yaml | kubectl apply -f -
if !ERRORLEVEL! neq 0 (echo Could not create the Secret & exit /b 1)

echo Step 4 of 6 - filling in the placeholders of kubernetes\deployment.yaml
copy /Y kubernetes\deployment.yaml kubernetes\deployment.yaml.tpl >nul
powershell -NoProfile -Command "(Get-Content -Raw 'kubernetes\deployment.yaml.tpl').Replace('{{IMAGE_URI}}', $env:IMAGE_URI).Replace('{{NAMESPACE}}', $env:NAMESPACE).Replace('{{KC_DB}}', $env:KC_DB).Replace('{{DB_HOST}}', $env:DB_HOST).Replace('{{DB_PORT}}', $env:DB_PORT).Replace('{{DB_NAME}}', $env:DB_NAME).Replace('{{DB_USERNAME}}', $env:DB_USERNAME).Replace('{{KC_HOSTNAME}}', $env:KC_HOSTNAME) | Set-Content -NoNewline 'kubernetes\deployment.yaml'"
if !ERRORLEVEL! neq 0 (
  copy /Y kubernetes\deployment.yaml.tpl kubernetes\deployment.yaml >nul
  del kubernetes\deployment.yaml.tpl
  echo Could not fill in the placeholders
  exit /b 1
)

echo Step 5 of 6 - applying the manifests
kubectl apply -f kubernetes\deployment.yaml
set "APPLY_RESULT=!ERRORLEVEL!"
copy /Y kubernetes\deployment.yaml.tpl kubernetes\deployment.yaml >nul
del kubernetes\deployment.yaml.tpl
if !APPLY_RESULT! neq 0 (echo Could not apply kubernetes\deployment.yaml & echo Rollback with - kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE! & exit /b 1)
kubectl apply -f kubernetes\service.yaml
if !ERRORLEVEL! neq 0 (echo Could not apply kubernetes\service.yaml & exit /b 1)
kubectl apply -f kubernetes\ingress.yaml
if !ERRORLEVEL! neq 0 (echo Could not apply kubernetes\ingress.yaml & exit /b 1)

echo Step 6 of 6 - waiting for the rollout
kubectl rollout status deployment/!APP_NAME! -n !NAMESPACE! --timeout=600s
if !ERRORLEVEL! neq 0 (echo The rollout did not finish & echo Rollback with - kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE! & exit /b 1)

kubectl get pods,svc,ingress -n !NAMESPACE!

kubectl get ingress !APP_NAME!-ingress -n !NAMESPACE! -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
echo.
echo The line above is the load balancer address of the application. It may be empty until the ALB is ready.

echo === Deployment finished ===
echo To roll back - kubectl rollout undo deployment/!APP_NAME! -n !NAMESPACE!
endlocal
