@echo off
setlocal enabledelayedexpansion

echo === Keycloak Build and Push Script ===

set PROJECT_NAME=keycloak
set IMAGE_NAME=keycloak

echo Project: %PROJECT_NAME%
echo Image: !IMAGE_NAME!
echo.

set /p AWS_REGION="Enter AWS region (e.g., us-east-1): "
set /p REGISTRY_URL="Enter ECR registry URL (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com): "
set /p ECR_REPO="Enter ECR repository name (or press Enter for 'keycloak'): "
if "!ECR_REPO!"=="" set ECR_REPO=keycloak

set /p IMAGE_TAG="Enter image tag (or press Enter for 'latest'): "
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest

REM Sanitize tag using PowerShell
for /f "delims=" %%i in ('powershell -command "^'!IMAGE_TAG!' -creplace '[^a-z0-9-]','-' -replace '^-+','' -replace '-+$',''"') do set IMAGE_TAG=%%i
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest

set FULL_IMAGE_NAME=!REGISTRY_URL!/!ECR_REPO!:!IMAGE_TAG!

echo.
echo === Configuration ===
echo AWS Region: !AWS_REGION!
echo Registry: !REGISTRY_URL!
echo Repository: !ECR_REPO!
echo Tag: !IMAGE_TAG!
echo Full Image: !FULL_IMAGE_NAME!
echo.

echo === Logging in to Amazon ECR ===
aws ecr get-login-password --region !AWS_REGION! | docker login --username AWS --password-stdin !REGISTRY_URL!
if !ERRORLEVEL! neq 0 (
    echo ECR login failed
    exit /b 1
)
echo ECR login successful

echo === Checking ECR repository ===
aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo Creating ECR repository...
    aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!
    if !ERRORLEVEL! neq 0 (
        echo Failed to create ECR repository
        exit /b 1
    )
)
echo Repository ready: !ECR_REPO!

echo === Building Docker image ===
docker build -f Dockerfile -t !FULL_IMAGE_NAME! .
if !ERRORLEVEL! neq 0 (
    echo Docker build failed
    exit /b 1
)
echo Docker build successful

echo === Pushing Docker image ===
docker push !FULL_IMAGE_NAME!
if !ERRORLEVEL! neq 0 (
    echo Docker push failed
    exit /b 1
)
echo Docker push successful

echo.
echo === Done ===
echo Image pushed: !FULL_IMAGE_NAME!
echo.
echo To deploy to EKS, run: scripts\deploy-image.bat

endlocal
