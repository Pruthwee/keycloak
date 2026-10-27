# Keycloak Deployment Guide

## Overview

This document describes how to build, deploy, and manage the Keycloak identity and access management solution on AWS EKS (Elastic Kubernetes Service). Keycloak is built on the Quarkus framework and provides identity and access management capabilities for modern applications.

## Prerequisites

### System Requirements

- **Java**: JDK 17 (Eclipse Temurin 17)
- **Maven**: 3.9.x
- **Docker**: 20.10+
- **AWS CLI**: 2.x
- **kubectl**: 1.27+ (matching your EKS cluster version)
- **eksctl**: 0.150+ (optional, for cluster creation)

### AWS Requirements

- AWS account with permissions to:
  - Create and manage ECR repositories
  - Create and manage EKS clusters
  - Create IAM roles and policies
  - Create S3 buckets (for state storage, if needed)
  - Create RDS instances (for production database)
  - Create ElastiCache clusters (for Redis, if session externalization is needed)

### IAM Permissions

The deploying user/role needs the following AWS managed policies:
- `AmazonEC2ContainerRegistryFullAccess`
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryPowerUser`
- `AmazonRDSReadOnlyAccess` (or appropriate RDS permissions)

## Local Setup with Docker Compose

1. Ensure Docker is installed and running.

2. Build the Docker image locally (optional, for testing):
   ```bash
   docker build -f Dockerfile -t keycloak:latest .
   ```

3. Run with Docker Compose:
   ```bash
   docker-compose up -d
   ```

4. Access Keycloak at `http://localhost:8080`

5. Stop the services:
   ```bash
   docker-compose down
   ```

### Docker Compose Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KC_HTTP_PORT` | `8080` | HTTP port for the Keycloak server |
| `KC_HTTP_MANAGEMENT_PORT` | `9000` | Management interface port |
| `KC_HEALTH_ENABLED` | `true` | Enable health check endpoints |
| `KC_HTTP_HOST` | `0.0.0.0` | HTTP host binding |
| `KC_HTTP_MANAGEMENT_HOST` | `0.0.0.0` | Management host binding |
| `KC_DB` | `dev-file` | Database provider (dev-file for local testing) |
| `JAVA_OPTS` | `-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0` | JVM options |

## Building and Pushing the Image

### Using the Build Script (Linux/macOS)

1. Ensure you have the AWS CLI installed and configured with appropriate credentials.

2. Run the build and push script:
   ```bash
   ./scripts/build-push.sh
   ```

3. The script will prompt for:
   - AWS region
   - ECR registry URL
   - ECR repository name (defaults to `keycloak`)
   - Image tag (defaults to `latest`)

4. The script will:
   - Log in to Amazon ECR
   - Create the ECR repository if it doesn't exist
   - Build the Docker image
   - Push the image to ECR

### Using the Build Script (Windows)

1. Run the build and push script:
   ```cmd
   scripts\build-push.bat
   ```

2. Follow the prompts for AWS region, ECR registry, repository name, and image tag.

## Deploying to AWS EKS

### EKS Cluster Setup

1. Create an EKS cluster (if you don't have one):
   ```bash
   eksctl create cluster --name keycloak-cluster --region us-east-1 --nodegroup-name keycloak-nodes --node-type t3.medium --nodes 2 --nodes-max 4
   ```

2. Install the AWS Load Balancer Controller (required for Ingress):
   ```bash
   eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster keycloak-cluster --approve
   
   # Download and install the ALB Ingress Controller
   kubectl apply -k "github.com/aws/eks-lookup-for-alb-ingress-controller?ref=master"
   ```

3. Configure kubectl to use your EKS cluster:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name keycloak-cluster
   ```

### Deploying the Application

1. Run the deploy script:
   ```bash
   ./scripts/deploy-image.sh
   ```

2. The script will prompt for:
   - AWS region
   - EKS cluster name
   - Full image URI (from the build-push step)
   - Environment variables (DB_HOST, DB_PORT, DB_DATABASE, DB_USER, DB_PASSWORD)

3. The script will:
   - Configure kubectl for your EKS cluster
   - Create the namespace
   - Create Kubernetes secrets for credentials
   - Apply the deployment, service, and ingress manifests
   - Wait for the deployment to be ready
   - Display the application URL

### Manual Deployment

If you prefer to deploy manually:

1. Apply the namespace:
   ```bash
   kubectl apply -f kubernetes/namespace.yaml
   ```

2. Create secrets:
   ```bash
   kubectl create secret generic keycloak-secrets -n keycloak \
     --from-literal=db-user="your-db-user" \
     --from-literal=db-password="your-db-password"
   ```

3. Create a ConfigMap:
   ```bash
   kubectl create configmap keycloak-config -n keycloak \
     --from-literal=http_port="8080" \
     --from-literal=management_port="9000"
   ```

4. Apply the deployment (replace placeholders):
   ```bash
   sed 's|{{IMAGE_URI}}|123456789012.dkr.ecr.us-east-1.amazonaws.com/keycloak:latest|g' \
     kubernetes/deployment.yaml | kubectl apply -f -
   ```

5. Apply the service and ingress:
   ```bash
   kubectl apply -f kubernetes/service.yaml
   kubectl apply -f kubernetes/ingress.yaml
   ```

## Kubernetes Manifests

### Namespace (`kubernetes/namespace.yaml`)

Creates a dedicated `keycloak` namespace for the application.

### Deployment (`kubernetes/deployment.yaml`)

- **Replicas**: 2 (for high availability)
- **Container**: Keycloak Quarkus server
- **Image**: Configurable via `{{IMAGE_URI}}` placeholder
- **Ports**: 8080 (HTTP), 9000 (management)
- **Resources**: 250m CPU / 512Mi memory (requests), 500m CPU / 1Gi memory (limits)
- **Liveness Probe**: HTTP GET to `/health/live` on port 9000
- **Readiness Probe**: HTTP GET to `/health/ready` on port 9000
- **Environment Variables**: Injected from ConfigMap and Secrets

### Service (`kubernetes/service.yaml`)

- **Type**: ClusterIP
- **Port**: 80 (targeting container port 8080)
- **Selector**: `app: keycloak`

### Ingress (`kubernetes/ingress.yaml`)

- **Host**: `keycloak.example.com`
- **Annotations**: AWS Load Balancer Controller (ALB, internet-facing)
- **Path**: `/` (Prefix)

## Configuration Management

### Environment Variables

Keycloak reads configuration from environment variables prefixed with `KC_`. The following are the most important:

| Variable | Description | Default |
|----------|-------------|---------|
| `KC_HTTP_PORT` | HTTP server port | `8080` |
| `KC_HTTP_HOST` | HTTP server host | `0.0.0.0` |
| `KC_HTTP_MANAGEMENT_PORT` | Management interface port | `9000` |
| `KC_HTTP_MANAGEMENT_HOST` | Management interface host | `0.0.0.0` |
| `KC_HEALTH_ENABLED` | Enable health endpoints | `true` |
| `KC_DB` | Database provider | `dev-file` |
| `KC_DB_URL_HOST` | Database host | - |
| `KC_DB_URL_DATABASE` | Database name | - |
| `KC_DB_URL_PORT` | Database port | - |
| `KC_DB_USERNAME` | Database username | - |
| `KC_DB_PASSWORD` | Database password | - |
| `KC_HOSTNAME` | External hostname | - |
| `KC_HOSTNAME_STRICT` | Strict hostname | `true` |
| `KC_HTTP_RELATIVE_PATH` | HTTP context path | - |
| `KC_HTTPS_CERTIFICATE_FILE` | TLS certificate file | - |
| `KC_HTTPS_CERTIFICATE_KEY_FILE` | TLS key file | - |
| `KC_HTTPS_CERTIFICATE_KEY_FILE_PASSWORD` | TLS key password | - |
| `KC_HTTPS_TRUST_STORE_FILE` | Trust store file | - |
| `KC_HTTPS_TRUST_STORE_PASSWORD` | Trust store password | - |

### Kubernetes ConfigMaps and Secrets

- **ConfigMap** (`keycloak-config`): Non-sensitive configuration values
- **Secret** (`keycloak-secrets`): Database credentials and other sensitive values

## Health Checks

Keycloak provides health check endpoints via the SmallRye Health extension:

- **Liveness**: `http://<host>:9000/health/live` - Indicates if the server is running
- **Readiness**: `http://<host>:9000/health/ready` - Indicates if the server is ready to accept requests
- **General Health**: `http://<host>:9000/health` - Overall health status

These endpoints are used by the Kubernetes liveness and readiness probes defined in the deployment manifest.

## Security Considerations

### Container Security

- The container runs as a non-root user (`keycloak`)
- No package managers (apt-get, apk, yum) are installed in the runtime image
- The base image is `eclipse-temurin:17-jdk` (Alpine-based for smaller attack surface)
- `JAVA_OPTS` includes container-aware JVM settings:
  - `-XX:+UseContainerSupport` - Enables container-aware resource management
  - `-XX:MaxRAMPercentage=75.0` - Limits heap to 75% of container memory

### Network Security

- The application binds to `0.0.0.0` for both HTTP and management interfaces
- The Ingress is configured as internet-facing via AWS Load Balancer Controller
- Consider adding WAF (Web Application Firewall) for production deployments
- Use TLS termination at the ALB level or configure HTTPS directly

### Secret Management

- Database credentials are stored in Kubernetes Secrets, never in plain text
- The Helm chart or deployment script creates secrets from environment variables
- Consider using AWS Secrets Manager with the Secrets Store CSI Driver for production

### Database Security

- Use a managed database service (Amazon RDS) for production
- Enable encryption at rest and in transit
- Use IAM authentication or strong password policies
- Regularly rotate database credentials

## Java Notes

### JVM Settings

The container uses the following JVM settings optimized for containerized environments:

- **`-Xmx512m`**: Maximum heap size of 512MB
- **`-Xms256m`**: Initial heap size of 256MB
- **`-XX:+UseContainerSupport`**: Enables container-aware resource management (available since JDK 8u191)
- **`-XX:MaxRAMPercentage=75.0`**: Limits heap to 75% of the container's memory limit

These settings ensure the JVM respects container memory limits and doesn't cause OOM kills. The memory limits in the Kubernetes deployment (512Mi requests, 1Gi limits) are aligned with these JVM settings.

### Spring Profiles / Quarkus Profiles

Keycloak uses Quarkus profiles controlled by the `KC_PROFILE` environment variable:

- `dev`: Development mode (not recommended for production)
- `prod` (default): Production mode
- `test`: Test mode

For production deployments on EKS, the default `prod` profile is used.

### Health Endpoints

The platform's health checks use the following endpoints exposed by the Quarkus SmallRye Health extension:

- **Liveness**: `/health/live` - Returns `UP` when the application process is running
- **Readiness**: `/health/ready` - Returns `UP` when the application is ready to serve requests (includes database connectivity check)

These endpoints are available on the management port (9000) when `KC_HEALTH_ENABLED=true`.

### Signal Handling

The `ENTRYPOINT` uses JSON notation (`["sh", "-c", "exec java ..."]`) to ensure:
1. Java is the first process (PID 1) in the container
2. The `exec` command replaces the shell with the Java process
3. SIGTERM from Kubernetes is received directly by the JVM
4. Graceful shutdown is enabled via Quarkus' shutdown hooks

## Scaling and Management

### Horizontal Pod Autoscaler (HPA)

To enable auto-scaling based on CPU utilization:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: keycloak-hpa
  namespace: keycloak
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: keycloak
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### Rolling Updates

The deployment is configured for rolling updates. To update the application:

1. Build and push a new image
2. Update the deployment:
   ```bash
   kubectl set image deployment/keycloak keycloak=<new-image-uri> -n keycloak
   ```
3. Monitor the rollout:
   ```bash
   kubectl rollout status deployment/keycloak -n keycloak
   ```

### Rollback

To rollback to a previous version:

```bash
kubectl rollout undo deployment/keycloak -n keycloak
```

## Troubleshooting

### Pod Failures

1. **Check pod status**:
   ```bash
   kubectl get pods -n keycloak
   ```

2. **Check pod logs**:
   ```bash
   kubectl logs <pod-name> -n keycloak
   ```

3. **Check pod events**:
   ```bash
   kubectl describe pod <pod-name> -n keycloak
   ```

### Service Issues

1. **Check service status**:
   ```bash
   kubectl get svc -n keycloak
   ```

2. **Test service connectivity**:
   ```bash
   kubectl exec -it <pod-name> -n keycloak -- curl -v http://keycloak-service:8080
   ```

### Ingress Problems

1. **Check ingress status**:
   ```bash
   kubectl get ingress -n keycloak
   ```

2. **Check ingress controller logs**:
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```

3. **Verify DNS resolution**:
   ```bash
   nslookup keycloak.example.com
   ```

### Database Connection Issues

1. **Check database connectivity**:
   ```bash
   kubectl exec -it <pod-name> -n keycloak -- env | grep KC_DB
   ```

2. **Verify database credentials**:
   ```bash
   kubectl get secret keycloak-secrets -n keycloak -o yaml
   ```

3. **Check database health**:
   ```bash
   kubectl exec -it <pod-name> -n keycloak -- curl -v http://localhost:9000/health/ready
   ```

### Health Check Failures

1. **Check liveness probe**:
   ```bash
   kubectl exec -it <pod-name> -n keycloak -- curl -v http://localhost:9000/health/live
   ```

2. **Check readiness probe**:
   ```bash
   kubectl exec -it <pod-name> -n keycloak -- curl -v http://localhost:9000/health/ready
   ```

3. **Check general health**:
   ```bash
   kubectl exec -it <pod-name> -n keycloak -- curl -v http://localhost:9000/health
   ```

## EKS-Specific Considerations

### IRSA (IAM Roles for Service Accounts)

For production, configure IRSA to grant the Keycloak pods access to AWS resources:

```yaml
# In the deployment spec
serviceAccountName: keycloak-sa
```

```yaml
# service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: keycloak-sa
  namespace: keycloak
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/keycloak-role
```

### EBS Storage

For persistent data storage, use EBS-backed PersistentVolumes:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: keycloak-data-pvc
  namespace: keycloak
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 10Gi
```

### Networking

- Ensure the EKS cluster has proper VPC configuration
- Configure security groups to allow traffic on ports 8080 and 9000
- Use AWS PrivateLink for internal service communication if needed
- Configure network policies for pod-to-pod communication restrictions
