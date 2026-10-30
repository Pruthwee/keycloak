@echo off & setlocal enabledelayedexpansion
rem Builds the Bedrock_keycloak_MM1 image and pushes it to AWS ECR or Docker Hub.
rem Run from the repository root - scripts\build-push.bat

set "PROJECT_NAME=Bedrock_keycloak_MM1"
set "TMP_NAME_FILE=%TEMP%\bedrock_image_name.txt"
powershell -NoProfile -Command "('%PROJECT_NAME%'.ToLower() -replace '[^a-z0-9]+','-').Trim('-')" > "!TMP_NAME_FILE!"
set /p IMAGE_NAME=<"!TMP_NAME_FILE!"
del "!TMP_NAME_FILE!" >nul 2>&1

echo === Build and push for !IMAGE_NAME! ===

where docker >nul 2>&1
if !ERRORLEVEL! neq 0 (echo Docker is not installed or not in the PATH & exit /b 1)

echo Select the registry
echo   1. AWS ECR
echo   2. Docker Hub
set /p REGISTRY_CHOICE="Enter 1 or 2: "

if "!REGISTRY_CHOICE!"=="1" (
  where aws >nul 2>&1
  if !ERRORLEVEL! neq 0 (echo The AWS CLI is not installed or not in the PATH & exit /b 1)
  set /p AWS_REGION="Enter the AWS region (for example us-east-1): "
  set /p AWS_ACCOUNT_ID="Enter the AWS account ID: "
  set /p ECR_REPO="Enter the ECR repository name (Enter for !IMAGE_NAME!): "
  if "!ECR_REPO!"=="" set "ECR_REPO=!IMAGE_NAME!"
  if "!AWS_REGION!"=="" (echo The AWS region is required & exit /b 1)
  if "!AWS_ACCOUNT_ID!"=="" (echo The AWS account ID is required & exit /b 1)
  set "REGISTRY_URL=!AWS_ACCOUNT_ID!.dkr.ecr.!AWS_REGION!.amazonaws.com"
  set "REPO_PATH=!ECR_REPO!"
) else if "!REGISTRY_CHOICE!"=="2" (
  set /p DOCKER_USERNAME="Enter the Docker Hub username: "
  set /p DOCKER_PASSWORD="Enter the Docker Hub password or access token: "
  set /p DOCKER_REPO="Enter the repository name (Enter for !IMAGE_NAME!): "
  if "!DOCKER_REPO!"=="" set "DOCKER_REPO=!IMAGE_NAME!"
  if "!DOCKER_USERNAME!"=="" (echo The Docker Hub username is required & exit /b 1)
  if "!DOCKER_PASSWORD!"=="" (echo The Docker Hub password is required & exit /b 1)
  set "REGISTRY_URL=docker.io"
  set "REPO_PATH=!DOCKER_USERNAME!/!DOCKER_REPO!"
) else (
  echo Invalid choice
  exit /b 1
)

set /p IMAGE_TAG="Enter IMAGE_TAG (Enter for latest): "
set "TMP_TAG_FILE=%TEMP%\bedrock_image_tag.txt"
powershell -NoProfile -Command "$t='!IMAGE_TAG!'.ToLower() -replace '[^a-z0-9._-]+','-'; $t.Trim('-')" > "!TMP_TAG_FILE!"
set "IMAGE_TAG="
set /p IMAGE_TAG=<"!TMP_TAG_FILE!"
del "!TMP_TAG_FILE!" >nul 2>&1
if "!IMAGE_TAG!"=="" set "IMAGE_TAG=latest"

set "FULL_IMAGE_NAME=!REGISTRY_URL!/!REPO_PATH!:!IMAGE_TAG!"
echo Image name is !FULL_IMAGE_NAME!

echo Step 1 of 3 - building the image
docker build -f Dockerfile -t !FULL_IMAGE_NAME! .
if !ERRORLEVEL! neq 0 (echo Docker build failed & exit /b 1)
echo Build finished

echo Step 2 of 3 - logging in to the registry
if "!REGISTRY_CHOICE!"=="1" (
  aws ecr get-login-password --region !AWS_REGION! | docker login --username AWS --password-stdin !REGISTRY_URL!
  if !ERRORLEVEL! neq 0 (echo ECR login failed & exit /b 1)
  aws ecr describe-repositories --repository-names !ECR_REPO! --region !AWS_REGION! >nul 2>&1
  if !ERRORLEVEL! neq 0 (echo Creating ECR repository... & aws ecr create-repository --repository-name !ECR_REPO! --region !AWS_REGION!)
) else (
  echo !DOCKER_PASSWORD! | docker login --username !DOCKER_USERNAME! --password-stdin
  if !ERRORLEVEL! neq 0 (echo Docker Hub login failed & exit /b 1)
)
echo Login succeeded

echo Step 3 of 3 - pushing the image
docker push !FULL_IMAGE_NAME!
if !ERRORLEVEL! neq 0 (echo Docker push failed & exit /b 1)

echo === Done - pushed !FULL_IMAGE_NAME! ===
echo Use this image URI with scripts\deploy-image.bat
endlocal
