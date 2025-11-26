# Service-Example GitOps Infrastructure

[![Build & Push](https://github.com/janitapojarvi/service-example/actions/workflows/main.yml/badge.svg)](https://github.com/janitapojarvi/service-example/actions/workflows/main.yml)

GitOps infrastructure repository for deploying the [ServiceExample](https://github.com/vvitkovsky/ServiceExample) .NET 9.0 application using FluxCD v2. This repository manages Kubernetes manifests, secrets, and deployment automation - the application code lives externally.

## 🏗️ Architecture

**GitOps-based deployment** using FluxCD that watches this repository and automatically applies changes to a Kubernetes cluster.

### Key Components

- **Application**: .NET 9.0 service with MongoDB, Redis, and NATS dependencies
- **Infrastructure**: Sealed Secrets, Longhorn storage, monitoring stack (Prometheus, Loki, Grafana)
- **Automation**: ResourceSets for automatic image updates without Git write access

### Directory Structure

```
├── app/service-example/          # Application deployment manifests
│   ├── resourceset.yaml          # Manages HelmRelease with auto-updates
│   ├── resourceset-input-provider.yaml  # Scans DockerHub for new images
│   ├── network-policies.yaml     # Zero-trust network rules
│   └── *-sealedsecret.yaml       # Encrypted credentials
├── infra/                        # Infrastructure components
│   ├── secrets/                  # Sealed Secrets controller
│   ├── storage/                  # Longhorn distributed storage
│   └── monitoring/               # Observability stack
├── clusters/local/               # Cluster-level Flux Kustomizations
│   ├── flux-system/              # Flux bootstrap
│   └── *.yaml                    # Component references
└── manifests/                    # Secret templates (not deployed)
```

## 🔄 Deployment Workflows

### Automatic Image Updates

The system uses **Flux ResourceSets** to automatically deploy new container images:

1. CI/CD pushes new image with semver tag (e.g., `0.1.42`) to DockerHub
2. ResourceSetInputProvider scans registry every 5 minutes
3. ResourceSet updates HelmRelease with new image tag + digest
4. Flux applies the change directly to the cluster

**Trigger manual scan**:
```bash
kubectl -n service-example annotate resourcesetinputprovider service-example-image \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

### Helm Chart Updates

Chart version uses constraint `>=0.1.0`. The HelmRepository polls GitHub Pages every 10 minutes for new chart versions and automatically upgrades.

### Manual Deployment

Force immediate reconciliation:
```bash
kubectl -n flux-system reconcile kustomization flux-system --with-source
```

## 🔐 Secret Management

Secrets are encrypted using **Bitnami Sealed Secrets**:

1. **Edit plain secret** in `manifests/` (never commit real values to Git)
2. **Encrypt the secret**:
   ```bash
   kubeseal --format=yaml < manifests/mongodb-credentials.yaml \
     > app/service-example/mongodb-credentials-sealedsecret.yaml
   ```
3. **Commit sealed secret** (safe to commit - only cluster can decrypt)

The `main.key` file in the repo root is the Sealed Secrets private key for local encryption.

## 📊 Monitoring

### Grafana Dashboard

A pre-configured dashboard tracks:
- Service-Example pods: CPU, memory, status
- MongoDB: operations rate, connection health
- Redis: command rate, uptime
- NATS: connection count
- Logs from all components (via Loki)

**Export updated dashboard**:
```bash
kubectl get configmap service-example-dashboard -n monitoring -o yaml > \
  infra/monitoring/grafana-dashboard-service-example.yaml
```

### Observability Stack

- **Prometheus**: Metrics collection and alerting
- **Loki**: Log aggregation
- **Grafana**: Unified visualization
- **Promtail**: Log shipping

Access Grafana via the monitoring namespace service.

### Secrets Encryption

All secrets are encrypted at rest using Sealed Secrets. Only the cluster can decrypt them.

## 🛠️ Common Operations

### Add Infrastructure Component

1. Create directory: `infra/<component>/`
2. Add manifests (HelmRelease, namespace, etc.)
3. Reference in `clusters/local/<component>.yaml`
4. Update dependencies in `clusters/local/service-example.yaml`

### Update Application

Images update automatically via ResourceSets. To update chart version:

```bash
# Edit resourceset.yaml chart version constraint
vim app/service-example/resourceset.yaml
git commit && git push
```

### Debug Issues

```bash
# Check Flux resources
kubectl get kustomizations,helmreleases -A

# View errors
kubectl -n flux-system describe kustomization service-example

# Check application logs
kubectl -n service-example logs -l app.kubernetes.io/name=service-example

# Verify image updates
kubectl -n service-example describe resourcesetinputprovider service-example-image
```

## 🔗 Integration Points

| Component | Location |
|-----------|----------|
| **Helm Chart** | https://janitapojarvi.github.io/service-example-chart/ |
| **Application Source** | https://github.com/vvitkovsky/ServiceExample |
| **Container Registry** | docker.io/janzo83/serviceexample |
| **GitOps Source** | This repository |

## 📦 CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/main.yml`):
- Clones external ServiceExample repository
- Runs .NET tests
- Generates semantic version from commit count
- Builds and pushes Docker images

**Triggers**:
- Manual dispatch
- Weekly schedule (Monday 2 AM UTC)
- Git tags (v*.*.*)
- Workflow file changes

## 📝 Conventions

- **Reconciliation interval**: 10 minutes (standard)
- **Image scan interval**: 5 minutes
- **Pruning**: Enabled (deleted resources removed)
- **Version constraints**: Use `>=X.Y.Z` for automatic updates
- **Namespace creation**: Each component creates its own namespace

## ⚙️ Configuration

- **Flux version**: 2.7.x
- **Target cluster**: `local` environment
- **GitOps branch**: `main`
- **Network model**: NodePort services (no ingress)
- **Storage**: Longhorn distributed storage

## 📚 Additional Resources

- [FluxCD Documentation](https://fluxcd.io/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [ServiceExample Application](https://github.com/vvitkovsky/ServiceExample)
- [Helm Chart Repository](https://janitapojarvi.github.io/service-example-chart/)

## 📄 License

Infrastructure manifests are managed independently. Refer to the [ServiceExample repository](https://github.com/vvitkovsky/ServiceExample) for application licensing.
