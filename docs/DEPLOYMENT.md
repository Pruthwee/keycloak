# Bedrock_keycloak_MM1 - Deployment Guide (AWS EKS)

Bedrock_keycloak_MM1 is the Keycloak identity and access management server (Quarkus distribution, Maven multi-module build, Java 17).
This guide describes how to run it locally with Docker Compose, build and push its image, and deploy it to AWS EKS with kubectl.

## 1. Prerequisites and system requirements

| Tool | Use |
|---|---|
| Docker 24+ | build and run the image locally |
| AWS CLI v2 | ECR login, `aws eks update-kubeconfig` |
| kubectl (within one minor version of the cluster) | apply the manifests |
| eksctl | create and manage the EKS cluster |
| Bash (Linux/macOS) or Windows `cmd` | run the scripts under `scripts/` |

* Build machine: 4 GB RAM or more for the Maven build inside Docker (the whole multi-module project is compiled), about 10 GB of disk.
* Runtime: each pod requests 250m CPU / 512Mi memory and is limited to 500m CPU / 1Gi memory.
* An external PostgreSQL database (for example Amazon RDS). No database is part of this project's container files: it is reached through environment variables.
* IAM permissions of the user or role that deploys: `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:PutImage`, `ecr:CreateRepository`, `ecr:DescribeRepositories`, `eks:DescribeCluster`, and Kubernetes RBAC rights (cluster-admin or equivalent in the namespace) on the cluster.

## 2. Local setup with Docker Compose

`docker-compose.yml` starts only the application (service `bedrock-keycloak-mm1`). The database is an external service.

```bash
export DB_HOST=my-postgres.example.com
export DB_USERNAME=keycloak
export DB_PASSWORD='...'                         # never written in a file
export KC_BOOTSTRAP_ADMIN_USERNAME=admin
export KC_BOOTSTRAP_ADMIN_PASSWORD='...'
docker compose up --build
```

* HTTP on `http://localhost:8080`, management interface on `http://localhost:9000` (`/health/live`, `/health/ready`).
* Compose stops with a message (`set DB_PASSWORD`) when a required variable is missing.
* The configuration folder `quarkus/dist/src/main/content/conf` is mounted read-only on `/opt/keycloak/conf`; data and logs are kept in the volume `bedrock-keycloak-mm1-data`.

## 3. Build and push the image

Run from the repository root.

```bash
./scripts/build-push.sh        # Linux / macOS
scripts\build-push.bat         # Windows
```

The script asks for the registry (1 = AWS ECR, 2 = Docker Hub), then only that registry's details (ECR: region, account ID, repository; Docker Hub: user name, password, repository), then `IMAGE_TAG` (empty = `latest`).
It builds with `docker build -f Dockerfile -t <registry>/<repo>:<tag> .`, logs in (`aws ecr get-login-password ... | docker login --username AWS --password-stdin`), creates the ECR repository when it is missing, and pushes.
The image name is the project name lower-cased: `bedrock-keycloak-mm1`.

### What the Dockerfile does

1. Build stage `maven:3.9.4-eclipse-temurin-17`: copies the whole project (several modules), installs the parent POM (`mvn clean install -N -DskipTests`), builds the distribution module with the modules it needs (`mvn clean package -DskipTests -pl quarkus/dist -am`), unpacks `keycloak-<version>.tar.gz` and runs `kc.sh build` with the build-time options `KC_DB` (default `postgres`, build argument) and `KC_HEALTH_ENABLED=true`.
2. Runtime stage `amazoncorretto:17`: copies `/opt/keycloak`, runs as the non-root user `1000:0`, exposes 8080, 8443 and 9000, and starts `java ... io.quarkus.bootstrap.runner.QuarkusEntryPoint start --optimized` through `sh -c "exec java ..."`, so java is the first process and receives SIGTERM for a graceful shutdown.

Keycloak is not a single runnable jar: the Quarkus build produces the `quarkus-run.jar` layout with its `lib/` folder inside the distribution, so the whole distribution is copied. Another database vendor needs another build: `docker build --build-arg KC_DB=mysql ...`.

## 4. AWS EKS

### 4.1 Cluster setup and kubectl configuration

```bash
eksctl create cluster --name my-cluster --region us-east-1 --nodes 2 --node-type t3.large
aws eks update-kubeconfig --region us-east-1 --name my-cluster
kubectl cluster-info
```

The Ingress needs the **AWS Load Balancer Controller** in the cluster (IAM OIDC provider, IAM policy and service account, then the Helm chart `eks/aws-load-balancer-controller`). Without it the Ingress gets no address.
The RDS security group must allow the nodes (or pods) to reach the database port.

### 4.2 Deploy

```bash
./scripts/deploy-image.sh      # Linux / macOS
scripts\deploy-image.bat       # Windows
```

The script asks for the AWS region, the EKS cluster name and the image URI (full path with registry and tag), then for each variable (`Enter value for <variable> (or press Enter to skip)`): `KC_DB`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `KC_HOSTNAME`; and for each credential (not echoed on Linux/macOS): `KC_DB_PASSWORD`, `KC_BOOTSTRAP_ADMIN_USERNAME`, `KC_BOOTSTRAP_ADMIN_PASSWORD`, `KC_JGROUPS_KEY_PASSWORD`.
It then: configures kubectl (`aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME`), checks `kubectl cluster-info`, applies `namespace.yaml`, creates the Secret with `kubectl create secret generic bedrock-keycloak-mm1-secrets -n bedrock-keycloak-mm1 --from-literal=... --dry-run=client -o yaml | kubectl apply -f -`, replaces the `"{{...}}"` placeholders of `deployment.yaml` (the template is restored when the script ends), applies deployment, service and ingress in that order, waits with `kubectl rollout status deployment/bedrock-keycloak-mm1 -n bedrock-keycloak-mm1`, shows `kubectl get pods,svc,ingress -n bedrock-keycloak-mm1` and the application's URL from the Ingress.

### 4.3 The manifests

| File | Object | Content |
|---|---|---|
| `kubernetes/namespace.yaml` | Namespace `bedrock-keycloak-mm1` | label `name: bedrock-keycloak-mm1` |
| `kubernetes/deployment.yaml` | Deployment `bedrock-keycloak-mm1` | 2 replicas, container `bedrock-keycloak-mm1`, image `"{{IMAGE_URI}}"`, ports 8080 (http) and 9000 (management), environment from placeholders (database host, port, name, user, hostname), credentials from the Secret `bedrock-keycloak-mm1-secrets`, requests 250m/512Mi, limits 500m/1Gi, liveness probe `/health/live` and readiness probe `/health/ready` on port 9000 |
| `kubernetes/service.yaml` | Service `bedrock-keycloak-mm1-service` | ClusterIP, port 80 to container port 8080, selector `app: bedrock-keycloak-mm1` |
| `kubernetes/ingress.yaml` | Ingress `bedrock-keycloak-mm1-ingress` | AWS Load Balancer Controller annotations (`kubernetes.io/ingress.class: alb`, `alb.ingress.kubernetes.io/scheme: internet-facing`), host `bedrock-keycloak-mm1.example.com`, path `/` (Prefix) to the service on port 80; the ALB health check uses `/health/ready` on port 9000 |

Replace the host `bedrock-keycloak-mm1.example.com` with your DNS name (and set `KC_HOSTNAME` to the same name). For HTTPS add the ALB annotations `alb.ingress.kubernetes.io/certificate-arn` and `alb.ingress.kubernetes.io/listen-ports`.

### 4.4 Rollback

```bash
kubectl rollout undo deployment/bedrock-keycloak-mm1 -n bedrock-keycloak-mm1
kubectl rollout history deployment/bedrock-keycloak-mm1 -n bedrock-keycloak-mm1
```

### 4.5 Troubleshooting

**Pod failures**
* `kubectl get pods -n bedrock-keycloak-mm1`, `kubectl describe pod <pod> -n bedrock-keycloak-mm1`, `kubectl logs <pod> -n bedrock-keycloak-mm1`.
* `ImagePullBackOff`: wrong image URI, or the node role lacks `AmazonEC2ContainerRegistryReadOnly`.
* `CrashLoopBackOff` with database errors: check `DB_HOST`, the security group of the database and the Secret values (`kubectl get secret bedrock-keycloak-mm1-secrets -n bedrock-keycloak-mm1`).
* `OOMKilled`: raise the memory limit and `-Xmx` together (section 6).
* Probes failing: Keycloak needs about 30-60 s to start; raise `initialDelaySeconds`. The health endpoints are on the management port 9000, not on 8080.

**Service issues**
* `kubectl get endpoints bedrock-keycloak-mm1-service -n bedrock-keycloak-mm1` must list the pod IPs; empty means the readiness probe fails or the selector does not match.
* `kubectl port-forward svc/bedrock-keycloak-mm1-service 8080:80 -n bedrock-keycloak-mm1` tests the service.

**Ingress problems**
* No ADDRESS: the AWS Load Balancer Controller is not installed or lacks IAM permissions (`kubectl logs -n kube-system deployment/aws-load-balancer-controller`).
* 502/503: the target group is unhealthy; check the health-check path and port annotations and the security groups.
* Redirect loops or wrong URLs: set `KC_HOSTNAME`, `KC_PROXY_HEADERS=xforwarded` and `KC_HTTP_ENABLED=true` (TLS ends at the ALB).

**EKS**
* `aws eks update-kubeconfig` fails: check `aws sts get-caller-identity` and the cluster access entry / `aws-auth` mapping of your IAM identity.
* Pods pending: not enough node capacity (`kubectl describe pod`), scale the node group.

### 4.6 Scaling and management

* Manual: `kubectl scale deployment/bedrock-keycloak-mm1 --replicas=3 -n bedrock-keycloak-mm1`.
* HPA (needs the metrics server): `kubectl autoscale deployment bedrock-keycloak-mm1 --cpu-percent=70 --min=2 --max=6 -n bedrock-keycloak-mm1`.
* Rolling updates: deploy a new image tag with the deploy script, or `kubectl set image deployment/bedrock-keycloak-mm1 bedrock-keycloak-mm1=<new image> -n bedrock-keycloak-mm1`; follow with `kubectl rollout status`.
* Node group: `eksctl scale nodegroup --cluster my-cluster --name <group> --nodes 3`.
* Several replicas form a Keycloak cluster (Infinispan, JGroups). The default JDBC_PING discovery uses the shared database; keep the replicas on the same image.

## 5. Configuration management and environment variables

| Variable | Where | Purpose |
|---|---|---|
| `KC_DB` | build argument and env | database vendor (build-time option, default `postgres`) |
| `KC_DB_URL_HOST` (`DB_HOST`) | env / deployment placeholder | database host |
| `KC_DB_URL_PORT` (`DB_PORT`) | env | database port, default 5432 |
| `KC_DB_URL_DATABASE` (`DB_NAME`) | env | database name |
| `KC_DB_USERNAME` (`DB_USERNAME`) | env | database user |
| `KC_DB_PASSWORD` | Secret | database password |
| `KC_BOOTSTRAP_ADMIN_USERNAME`, `KC_BOOTSTRAP_ADMIN_PASSWORD` | Secret | first administrator |
| `KC_JGROUPS_KEY_PASSWORD` | Secret (optional) | password of the in-memory JGroups key store; a random one is generated per process when empty |
| `KC_HOSTNAME`, `KC_HTTP_ENABLED`, `KC_PROXY_HEADERS` | env | public host name and reverse-proxy mode |
| `KC_HEALTH_ENABLED` | build and env | health endpoints (enabled in the image) |
| `JAVA_OPTS`, `JAVA_ADD_OPENS` | env | JVM settings |

Paths and ports that were hard-coded in the code can now be overridden by environment variables (defaults unchanged): `KC_OPERATOR_CERTIFICATES_FOLDER`, `KC_OPERATOR_CONFIG_FOLDER`, `KC_OPERATOR_REALM_IMPORT_MOUNT_PATH`, `KC_OPERATOR_UPDATE_JOB_MOUNT_BASE`, `KUBERNETES_SERVICE_ACCOUNT_TOKEN_PATH`, `KUBERNETES_CA_PATH`, `KUBERNETES_SERVICE_CA_PATH`, `KC_JTA_TRANSACTION_MANAGER_JNDI_NAME`, `KC_POLICY_EVALUATION_IP_ADDRESS`, and for test tooling `KC_TEST_TMP_DIR`, `KC_TEST_REQUEST_PORT`, `KC_TEST_MANAGEMENT_PORT`, `EDB_DB_PORT`, `CRL_RESPONDER_PORT`, `OCSP_RESPONDER_PORT`, `TEST_CLASS_SERVER_PORT`, `NGINX_CERTIFICATE_PATH`, `TRIVY_LOGS_DIR`.

## 6. Java notes

* **JVM settings** (`JAVA_OPTS`): `-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:MetaspaceSize=96M -XX:MaxMetaspaceSize=256m -XX:+ExitOnOutOfMemoryError`, charset UTF-8, `TZ=UTC`. An explicit `-Xmx` wins over `MaxRAMPercentage`. With the 1Gi pod limit, a 512m heap plus 256m metaspace and thread/native memory fits; when you raise the memory limit, raise `-Xmx` (or remove `-Xmx/-Xms` so `MaxRAMPercentage=75.0` is used) and keep at least 25% of the limit free for non-heap memory.
* **Spring profiles**: Keycloak is a Quarkus application, so `SPRING_PROFILES_ACTIVE` does not apply. Use `KC_*` variables, `conf/keycloak.conf` and Quarkus profiles (`QUARKUS_PROFILE`) instead; the log level is `KC_LOG_LEVEL`.
* **Health endpoints**: the application already has them (Quarkus SmallRye Health, enabled with `health-enabled=true`, set at build time in the image). They answer on the management interface, port 9000: `/health/live` (liveness probe), `/health/ready` (readiness probe) and `/health`. No endpoint was added by this containerization and no `HEALTHCHECK` instruction is used: the platform probes them.
* **Graceful shutdown**: java runs as the container's first process (`exec`), so it receives SIGTERM from Kubernetes.

## 7. Security considerations and best practices

* Credentials live only in the Kubernetes Secret `bedrock-keycloak-mm1-secrets` and in the shell of whoever runs Compose or the deploy script; they are never in the image, the manifests or the code. Prefer AWS Secrets Manager with the Secrets Store CSI driver or External Secrets for production, and encrypt Kubernetes Secrets with a KMS key.
* The container runs as a non-root user (`1000:0`); the runtime image has no package manager steps and no extra tools.
* Terminate TLS at the ALB (ACM certificate) and restrict the management port 9000: the Ingress does not route it, so `/health` is reachable only inside the cluster.
* Use private ECR repositories with image scanning, immutable tags (not `latest`) and least-privilege IAM roles (IRSA) for pods.
* Use an Amazon RDS instance with encryption, backups and a security group that only admits the cluster.
* Add NetworkPolicies, Pod Security Standards (`restricted`) and resource quotas for the namespace.

## 8. Known limits of this containerization

* The application's own work does not end after start-up: the Keycloak server keeps running and serves the health endpoints.
* Several analysis blockers (distributed locks, Redis/ElastiCache sessions and caches, microservice decomposition) ask for new infrastructure or a re-architecture of Keycloak and were not applied; they are listed as failed in the transformation report. Keycloak keeps its sessions and caches in its own embedded Infinispan cluster.
