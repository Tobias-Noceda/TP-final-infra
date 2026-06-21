#!/bin/bash
set -euo pipefail

# ============================================================
# Full GKE + Sock Shop Teardown Script
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/deploy/terraform/GCP"
NAMESPACE="sock-shop"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()    { echo -e "${GREEN}[✔]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[✘]${NC} $1"; exit 1; }
section(){ echo -e "\n${YELLOW}━━━ $1 ━━━${NC}"; }

# ============================================================
# STEP 1: Connect kubectl (best-effort)
# ============================================================
section "Connecting kubectl to the cluster"

cd "$TF_DIR"

KUBECTL_OK=false
if CREDENTIALS_CMD=$(terraform output -raw get_credentials_command 2>/dev/null); then
  if eval "$CREDENTIALS_CMD" && kubectl cluster-info >/dev/null 2>&1; then
    KUBECTL_OK=true
    log "kubectl connected"
  fi
fi

if [ "$KUBECTL_OK" = false ]; then
  warn "Could not reach cluster via kubectl (already destroyed or never created) — skipping Kubernetes cleanup"
fi

# ============================================================
# STEP 2: Delete Kubernetes Ingress (releases LB and IP)
# ============================================================
section "Deleting GCE Ingress"

if [ "$KUBECTL_OK" = true ]; then
  if kubectl get ingress sock-shop -n "$NAMESPACE" >/dev/null 2>&1; then
      kubectl delete ingress sock-shop -n "$NAMESPACE"

      kubectl wait \
        --for=delete ingress/sock-shop \
        -n "$NAMESPACE" \
        --timeout=600s

      log "Ingress deleted"
  fi
fi

# ============================================================
# STEP 2: Delete Kubernetes namespace (releases PVCs/PVs/disks)
# ============================================================
if [ "$KUBECTL_OK" = true ]; then
  section "Deleting Kubernetes resources"

  if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    warn "Deleting namespace '$NAMESPACE' — this blocks until bound PVs (and their GCE disks) are reclaimed"
    kubectl delete namespace "$NAMESPACE" --timeout=300s || error "Namespace deletion failed or timed out — check for stuck PVCs/finalizers before re-running"
    log "Namespace deleted, PVCs/PVs reclaimed"
  else
    log "Namespace '$NAMESPACE' not found — nothing to clean up"
  fi

  # Safety net: any PV that lost its claim but is still hanging around
  LEFTOVER_PVS=$(kubectl get pv -o jsonpath="{.items[?(@.spec.claimRef.namespace=='$NAMESPACE')].metadata.name}" 2>/dev/null || true)
  if [ -n "$LEFTOVER_PVS" ]; then
    warn "Leftover PVs still referencing $NAMESPACE: $LEFTOVER_PVS"
    warn "Check 'gcloud compute disks list' afterwards for orphaned disks"
  fi
fi

# ============================================================
# STEP 3: Terraform Destroy
# ============================================================
section "Terraform: Destroying GKE Cluster and Resources"

cd "$TF_DIR"

terraform destroy -auto-approve || error "Terraform destroy failed"

log "Terraform destroy complete"

# ============================================================
# DONE
# ============================================================
section "Destruction complete"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Sock Shop is down!                     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
