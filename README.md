# TaskFlow K8s (Deploy Repo)

This repository holds Kubernetes deployment assets for TaskFlow, supporting both Kustomize and Helm deployment methods.

## Directory Structure

```
.
├── kustomize/                 # Kustomize YAML manifests (legacy)
│   ├── kustomization.yaml
│   ├── backend-*.yaml
│   ├── frontend-*.yaml
│   ├── postgres-*.yaml
│   └── ingress.yaml
├── charts/                    # Helm charts
│   └── taskflow/             # Umbrella chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── charts/
│           ├── frontend/     # Frontend sub-chart
│           ├── backend/      # Backend sub-chart
│           └── postgres/     # PostgreSQL sub-chart
├── values/                   # Environment-specific values
│   ├── kind.yaml            # KIND cluster (local development)
│   └── prod.yaml            # Production
├── scripts/                 # Deployment automation
│   ├── helpers.ps1
│   ├── deploy-kind.ps1
│   ├── create-kind-cluster.ps1
│   ├── uninstall.ps1
│   └── deploy-all.ps1
└── README.md
```

## Quick Start

### Option 1: Kustomize (Simple)

```powershell
# Apply all manifests
kubectl apply -k .\kustomize

# Delete all manifests
kubectl delete -k .\kustomize
```

### Option 2: Helm (Recommended)

#### Prerequisites

- [Helm 3.x](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [KIND](https://kind.sigs.k8s.io/docs/user/quick-start) (optional, for local development)

#### One-Command Deployment to KIND

```powershell
# Create KIND cluster + Deploy TaskFlow (all in one)
.\scripts\deploy-all.ps1 -CreateCluster -WaitForReady

# Or just deploy to existing cluster
.\scripts\deploy-kind.ps1 -WaitForReady
```

#### Manual Helm Deployment

```powershell
# Deploy to local KIND cluster
helm install taskflow ./charts/taskflow \
  -f ./values/kind.yaml \
  --namespace default \
  --create-namespace

# Deploy to production
helm install taskflow ./charts/taskflow \
  -f ./values/prod.yaml \
  --namespace production \
  --create-namespace
```

#### Helm Management

```powershell
# List releases
helm list -n default

# Update release
helm upgrade taskflow ./charts/taskflow \
  -f ./values/kind.yaml \
  -n default

# Uninstall release
.\scripts\uninstall.ps1 -ReleaseName taskflow -Namespace default

# Dry run (preview changes)
helm install taskflow ./charts/taskflow \
  -f ./values/kind.yaml \
  -n default \
  --dry-run \
  --debug
```

## Deployment Scripts

### `deploy-all.ps1` - Complete Setup
```powershell
.\scripts\deploy-all.ps1 -CreateCluster -WaitForReady

# Parameters:
#   -CreateCluster   : Create KIND cluster first
#   -WaitForReady    : Wait for deployments to be ready
#   -Namespace       : Target namespace (default: default)
#   -ClusterName     : KIND cluster name (default: taskflow)
```

### `deploy-kind.ps1` - Deploy to KIND
```powershell
.\scripts\deploy-kind.ps1 -WaitForReady

# Parameters:
#   -WaitForReady    : Wait for deployments to be ready
#   -DryRun          : Simulate deployment (no changes)
#   -ReleaseName     : Helm release name
#   -Namespace       : Target namespace
```

### `create-kind-cluster.ps1` - Create KIND Cluster
```powershell
.\scripts\create-kind-cluster.ps1 -ClusterName taskflow -Workers 2

# Parameters:
#   -ClusterName     : Cluster name
#   -NodeImage       : KIND node image
#   -Workers         : Number of worker nodes
```

### `uninstall.ps1` - Uninstall Release
```powershell
.\scripts\uninstall.ps1 -ReleaseName taskflow -Namespace default -Force
```

## Environment-Specific Values

### KIND (Local Development)
- File: `./values/kind.yaml`
- Frontend replicas: 1
- Backend replicas: 1
- PostgreSQL: No persistence (ephemeral storage)
- Resources: Minimal (development sizing)

### Production
- File: `./values/prod.yaml`
- Frontend replicas: 3
- Backend replicas: 3
- PostgreSQL: Persistent storage (50Gi)
- Resources: Full allocation (production sizing)

## Accessing the Application

### Local KIND Cluster

1. Add to `/etc/hosts`:
```
127.0.0.1  taskflow.local
```

2. Access frontend:
```
http://taskflow.local
```

### Port Forwarding (Alternative)

```powershell
# Frontend
kubectl port-forward svc/taskflow-frontend 3000:3000

# Backend
kubectl port-forward svc/taskflow-backend 3001:3001

# Database
kubectl port-forward svc/taskflow-postgres 5432:5432
```

## Helm Chart Structure

### Umbrella Chart (taskflow)
Main chart that depends on three sub-charts:
- **frontend**: Next.js frontend application
- **backend**: Node.js/Express backend API
- **postgres**: PostgreSQL database

All sub-charts are defined as dependencies in the umbrella chart's `Chart.yaml`.

### Sub-charts

Each sub-chart includes:
- **Deployment/StatefulSet**: Application workload
- **Service**: Internal Kubernetes service
- **Secret**: Sensitive configuration data
- **Ingress** (frontend only): HTTP ingress routing

## Configuration Management

### Overriding Values

```powershell
# Override specific values
helm install taskflow ./charts/taskflow \
  -f ./values/kind.yaml \
  --set frontend.replicaCount=2 \
  --set backend.image.tag=v1.1.0

# Use multiple values files
helm install taskflow ./charts/taskflow \
  -f ./values/kind.yaml \
  -f ./values/local-overrides.yaml
```

### Secrets Management

Database credentials are stored in Kubernetes Secrets:
```powershell
# View secrets
kubectl get secrets -n default

# Show secret values (be careful!)
kubectl get secret taskflow-postgres-secret -o jsonpath='{.data.password}' | base64 -d

# Update secret
kubectl patch secret taskflow-backend-secret -p '{"data":{"db-password":"'$(echo -n "newpassword" | base64)'"}}'
```

## Monitoring & Debugging

```powershell
# Check resource status
kubectl get all -n default
kubectl get pods -n default
kubectl get svc -n default
kubectl get ingress -n default

# View logs
kubectl logs deployment/taskflow-frontend -n default
kubectl logs deployment/taskflow-backend -n default
kubectl logs statefulset/taskflow-postgres -n default

# Describe pod (for events/errors)
kubectl describe pod <pod-name> -n default

# Execute command in container
kubectl exec -it <pod-name> -n default -- /bin/bash
```

## Troubleshooting

### Ingress Not Working
1. Ensure ingress-nginx is installed:
   ```powershell
   kubectl get pods -n ingress-nginx
   ```
2. Check ingress configuration:
   ```powershell
   kubectl describe ingress taskflow-frontend -n default
   ```
3. Update `/etc/hosts` for local access

### Pods Not Starting
1. Check pod status:
   ```powershell
   kubectl describe pod <pod-name> -n default
   ```
2. View logs:
   ```powershell
   kubectl logs <pod-name> -n default
   ```

### Database Connection Issues
1. Verify PostgreSQL is running:
   ```powershell
   kubectl exec <postgres-pod> -- pg_isready
   ```
2. Check credentials in secrets:
   ```powershell
   kubectl get secret taskflow-postgres-secret -o yaml
   ```

## Architecture Notes

- `frontend` is configured to call same-origin `/api/*` and relies on the frontend server to proxy to `backend`.
- Ingress requires an ingress controller (e.g., `ingress-nginx`) installed in the cluster.
- Services use internal DNS names (e.g., `taskflow-postgres:5432`).
- StatefulSet is used for PostgreSQL to maintain identity across restarts.
- All resources are namespace-scoped for better isolation.

## Next Steps

- Customize `values/` files for your environment
- Modify sub-chart templates for your application
- Set up CI/CD to automatically deploy on changes
- Configure TLS certificates for production ingress
- Set up persistent storage for production databases
