#!/usr/bin/env bash
# bootstrap-local.sh
# One-command local cluster bootstrap with Kind + ArgoCD
# Usage: ./bootstrap-local.sh

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"; exit 1; }

# ── Prerequisites Check ───────────────────────────────────────────────────────
log "Checking prerequisites..."

command -v kind >/dev/null 2>&1 || error "kind not found. Install from https://kind.sigs.k8s.io/"
command -v kubectl >/dev/null 2>&1 || error "kubectl not found"
command -v helm >/dev/null 2>&1 || error "helm not found"
command -v terraform >/dev/null 2>&1 || error "terraform not found"

log "All prerequisites satisfied ✅"

# ── Create Kind Cluster ───────────────────────────────────────────────────────
log "Creating Kind cluster..."

cat <<EOF | kind create cluster --name enterprise-gitops --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
  - role: worker
  - role: worker
EOF

log "Kind cluster created ✅"

# ── Set kubectl context ───────────────────────────────────────────────────────
kubectl cluster-info --context kind-enterprise-gitops

# ── Deploy ArgoCD via Terraform ───────────────────────────────────────────────
log "Deploying ArgoCD via Terraform..."

cd terraform/modules
terraform init
terraform apply -auto-approve

log "ArgoCD deployed ✅"

# ── Wait for ArgoCD ───────────────────────────────────────────────────────────
log "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s

# ── Get Initial Password ──────────────────────────────────────────────────────
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Enterprise GitOps Blueprint — Local Stack Ready!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ArgoCD UI:        ${YELLOW}http://localhost:8080${NC}"
echo -e "  Username:         ${YELLOW}admin${NC}"
echo -e "  Password:         ${YELLOW}${ARGOCD_PASSWORD}${NC}"
echo ""
echo -e "  Port-forward:     ${BLUE}kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ── Start port-forward ────────────────────────────────────────────────────────
log "Starting port-forward to ArgoCD UI..."
kubectl port-forward svc/argocd-server -n argocd 8080:443
