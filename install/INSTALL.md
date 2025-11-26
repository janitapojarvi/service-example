# Cluster Installation Guide

This guide walks through setting up a Kubernetes cluster using MicroK8s and deploying the service-example application stack via GitOps with FluxCD.

## Step 1: Install MicroK8s

For self-managed cluster i used [MicroK8s](https://microk8s.io/).

Install MicroK8s with the specified resources:

**Linux/macOS**:
```bash
sudo microk8s install --cpu 8 --mem 8 --channel 1.34/stable
```

**Windows (PowerShell as Administrator)**:
```powershell
microk8s install --cpu 8 --mem 8 --channel 1.34/stable
```

**Note**: On Windows, MicroK8s runs in a Multipass VM. You don't need `sudo`, but you must run PowerShell as Administrator.


**Resource notes**: These values (8 CPU, 8 GB RAM) are what i used to for running the full stack (application + MongoDB + Redis + NATS + monitoring). Adjust based on your workload requirements. 


## Step 2: Export Kubeconfig

Export the kubeconfig to use with local kubectl and Helm or alternatively run those thru microk8s:

**Linux/macOS**:
```bash
sudo microk8s kubectl config view --raw > ~/.kube/config
```

**Windows (PowerShell)**:
```powershell
# Create .kube directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.kube"

# Export kubeconfig
microk8s kubectl config view --raw | Out-File -Encoding utf8 -FilePath "$env:USERPROFILE\.kube\config"
```

## Step 3: Install Flux Operator

Install the Flux Operator using Helm:

```bash
helm install flux-operator \
  oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --namespace flux-system \
  --create-namespace
```

**Using MicroK8s Helm directly**:

```bash
sudo microk8s helm install flux-operator \
  oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --namespace flux-system \
  --create-namespace
```

Verify the operator is running:

```bash
kubectl -n flux-system get pods
```

Wait until the flux-operator pod is `Running` and `Ready`.

## Step 4: Install Sealed Secrets Private Key

**Important**: Apply the Sealed Secrets private key **before** Flux installs the sealed-secrets-controller. This ensures all encrypted secrets in the repository can be decrypted automatically.

The `main.key` file will be provided separately. Apply it:

```bash
kubectl apply -f main.key
```
**Security Note**: The `main.key` file contains sensitive cryptographic material. Store it securely and never commit it to version control.

## Step 5: Bootstrap Flux GitOps

Apply the FluxInstance manifest to start GitOps synchronization:

```bash
kubectl apply -f install/flux-instance-sync.yaml
```

This will:
- Install Flux controllers (source, kustomize, helm, notification)
- Configure Flux to watch the `janitapojarvi/service-example` repository
- Start deploying infrastructure and applications from `clusters/local/`

## Step 6: Monitor Deployment Progress

Watch Flux reconciliation:

```bash
# Check Flux system components
kubectl -n flux-system get pods

# View Kustomizations
kubectl -n flux-system get kustomizations

# Check HelmReleases across all namespaces
kubectl get helmreleases -A

# Watch application namespace
kubectl -n service-example get pods -w
```

### Expected Deployment Order

1. **Infrastructure** (deployed first):
   - Sealed Secrets controller
   - Longhorn storage
   - Monitoring stack (Prometheus, Loki, Grafana, Promtail)

2. **Application** (deployed after infrastructure):
   - MongoDB (with encrypted credentials)
   - Redis (with encrypted credentials)
   - NATS (with encrypted credentials)
   - Service-Example application

## Step 7: Verify Installation

Check that all components are running:

```bash
# Infrastructure
kubectl -n flux-system get helmrelease sealed-secrets
kubectl -n longhorn-system get pods
kubectl -n monitoring get pods

# Application
kubectl -n service-example get pods
kubectl -n service-example get helmrelease
kubectl -n service-example get resourcesets
```

All pods should be in `Running` state and HelmReleases should show `Ready=True`.

## Step 8: Access Services

### Service-Example Application

Access the application using port-forward:

**Linux/macOS**:
```bash
# Forward local port 9080 to the service
kubectl -n service-example port-forward svc/service-example 9080:9080
```

Open in browser: http://localhost:9080/swagger/index.html

This API enpoint should be available: http://localhost:9080/api/Person

### Grafana Dashboard

Access Grafana using port-forward:

**Linux/macOS**:
```bash
# Get Grafana admin password
kubectl -n monitoring get secret prometheus-release-grafana -o jsonpath='{.data.admin-password}' | base64 -d

# Forward local port 3000 to Grafana
kubectl -n monitoring port-forward svc/prometheus-release-grafana 80:80

# Access Grafana at http://localhost
```

**Windows (PowerShell)**:
```powershell
# Get Grafana admin password
$password = kubectl -n monitoring get secret prometheus-release-grafana -o jsonpath='{.data.admin-password}'
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))

# Forward local port to Grafana
kubectl -n monitoring port-forward svc/prometheus-release-grafana 80:80

# Open in browser
Start-Process "http://localhost"
```

**Login**: Username `admin`, password from above command.

The service-example dashboard is pre-configured and will appear automatically.

## Troubleshooting

### Flux not syncing

```bash
# Force reconciliation
kubectl -n flux-system reconcile kustomization flux-system --with-source

# Check for errors
kubectl -n flux-system describe kustomization flux-system
```

### Sealed secret decryption fails

```bash
# Verify the private key is present before sealed-secrets controller starts
kubectl -n flux-system get secret sealed-secrets-key

# Check sealed-secrets controller logs
kubectl -n flux-system logs -l app.kubernetes.io/name=sealed-secrets
```

### Pods stuck in Pending

```bash
# Check events
kubectl -n service-example get events --sort-by='.lastTimestamp'

# Check PVC binding (if storage issues)
kubectl -n service-example get pvc
```

### Image updates not working

```bash
# Check ResourceSetInputProvider status
kubectl -n service-example get resourcesetinputproviders

# Describe the image provider
kubectl -n service-example describe resourcesetinputprovider service-example-image

# Force image scan
kubectl -n service-example annotate resourcesetinputprovider service-example-image \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

### Network connectivity issues

```bash
# Verify network policies
kubectl -n service-example get networkpolicy

# Test connectivity from app pod (replace <pod-name>)
kubectl -n service-example exec <pod-name> -- nc -zv mongodb 27017
kubectl -n service-example exec <pod-name> -- nc -zv redis 6379
kubectl -n service-example exec <pod-name> -- nc -zv nats 4222
```

## Uninstallation

To completely remove the deployment:

```bash
# Delete FluxInstance (stops GitOps sync)
kubectl delete fluxinstance flux -n flux-system

# Delete namespaces
kubectl delete namespace service-example monitoring longhorn-system

# Uninstall Flux Operator
helm uninstall flux-operator -n flux-system

# Delete flux-system namespace
kubectl delete namespace flux-system
```

To remove MicroK8s entirely:

```bash
sudo microk8s uninstall
```
