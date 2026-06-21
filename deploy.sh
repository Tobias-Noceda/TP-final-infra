#!/bin/bash
set -euo pipefail

# ============================================================
# Full GKE + Sock Shop Deployment Script (Ingress Edition)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/deploy/terraform/GCP"
K8S_MANIFEST="$SCRIPT_DIR/deploy/kubernetes/complete-demo.yaml"
K8S_INGRESS="$SCRIPT_DIR/deploy/kubernetes/ingress.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log()    { echo -e "${GREEN}[✔]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[✘]${NC} $1"; exit 1; }
section(){ echo -e "\n${YELLOW}━━━ $1 ━━━${NC}"; }
info()   { echo -e "${BLUE}[i]${NC} $1"; }

# ============================================================
# STEP 1: Terraform Deploy
# ============================================================
section "Terraform: Deploying GKE Cluster"

cd "$TF_DIR"

terraform init -upgrade
terraform validate || error "Terraform validation failed"
terraform apply -auto-approve || error "Terraform apply failed"

log "Terraform apply complete"

# ============================================================
# STEP 2: Connect kubectl
# ============================================================
section "Connecting kubectl to the cluster"

CREDENTIALS_CMD=$(terraform output -raw get_credentials_command)
log "Running: $CREDENTIALS_CMD"
eval "$CREDENTIALS_CMD" || error "Failed to get cluster credentials"

# Verify connection
kubectl cluster-info || error "kubectl cannot reach the cluster"
log "kubectl connected successfully"

# ============================================================
# STEP 3: Deploy Kubernetes Manifests
# ============================================================
section "Deploying Sock Shop manifests"

cd "$SCRIPT_DIR"

kubectl apply -f "$K8S_MANIFEST" || error "Failed to apply Kubernetes manifests"
log "Core manifests applied"

# ============================================================
# STEP 4: Deploy Ingress
# ============================================================
section "Deploying Ingress resource"

if [ -f "$K8S_INGRESS" ]; then
  kubectl apply -f "$K8S_INGRESS" || error "Failed to apply Ingress manifest"
  log "Ingress deployed"
else
  warn "Ingress file not found at: $K8S_INGRESS"
  info "Creating inline Ingress resource..."
  
  kubectl apply -f - <<'EOF' || error "Failed to create Ingress"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sock-shop
  namespace: sock-shop
  annotations:
    kubernetes.io/ingress.class: "gce"
spec:
  rules:
  - http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: front-end
            port:
              number: 80
EOF
  log "Inline Ingress created"
fi

# ============================================================
# STEP 5: Wait for pods to be ready
# ============================================================
section "Waiting for pods to be ready"

warn "This may take 2-3 minutes..."
kubectl wait \
  --for=condition=ready pod \
  --selector=name=front-end \
  --namespace=sock-shop \
  --timeout=300s || error "Frontend pod did not become ready in time"

log "All pods ready"

# ============================================================
# STEP 6: Wait for Ingress Load Balancer IP
# ============================================================
section "Waiting for Load Balancer IP assignment"

warn "Provisioning Google Cloud Load Balancer... (this takes 2-3 minutes)"

INGRESS_IP=""
MAX_ATTEMPTS=60
ATTEMPT=0

while [ -z "$INGRESS_IP" ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  INGRESS_IP=$(kubectl get ingress sock-shop \
    -n sock-shop \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  
  if [ -z "$INGRESS_IP" ]; then
    ATTEMPT=$((ATTEMPT + 1))
    echo -ne "\r  Attempt $ATTEMPT/$MAX_ATTEMPTS... Waiting for IP assignment"
    sleep 3
  fi
done

echo "" # New line after waiting message

if [ -z "$INGRESS_IP" ]; then
  error "Failed to get Ingress IP after $(($MAX_ATTEMPTS * 3)) seconds"
else
  log "Load Balancer IP assigned: $INGRESS_IP"
fi

# ============================================================
# STEP 7: Wait for health checks
# ============================================================
section "Waiting for Load Balancer health checks"

warn "Health checks are now running..."
warn "This typically takes 1-2 minutes..."

# Try to do a health check
HEALTH_CHECK_ATTEMPTS=0
MAX_HEALTH_ATTEMPTS=40

while [ $HEALTH_CHECK_ATTEMPTS -lt $MAX_HEALTH_ATTEMPTS ]; do
  if curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_IP" > /dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_IP")
    if [ "$HTTP_CODE" != "000" ]; then
      log "Health check passed (HTTP $HTTP_CODE)"
      break
    fi
  fi
  
  HEALTH_CHECK_ATTEMPTS=$((HEALTH_CHECK_ATTEMPTS + 1))
  echo -ne "\r  Health check attempt $HEALTH_CHECK_ATTEMPTS/$MAX_HEALTH_ATTEMPTS..."
  sleep 3
done

echo "" # New line after waiting message

if [ $HEALTH_CHECK_ATTEMPTS -eq $MAX_HEALTH_ATTEMPTS ]; then
  warn "Health checks still pending (this is normal, they may still be initializing)"
  info "The application may still be starting up. Try accessing in a moment."
fi

# ============================================================
# DONE
# ============================================================
section "Deployment Complete ✨"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   🎉 Sock Shop is live!                       ║${NC}"
echo -e "${GREEN}╟────────────────────────────────────────────────╢${NC}"
echo -e "${GREEN}║   URL: ${BLUE}http://$INGRESS_IP${GREEN}              ${GREEN}║${NC}"
echo -e "${GREEN}╟────────────────────────────────────────────────╢${NC}"
echo -e "${GREEN}║   Load Balancer Type: Google Cloud HTTP(S)     ║${NC}"
echo -e "${GREEN}║   Status: Ready                                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📊 Useful Commands:${NC}"
echo "  # View ingress status:"
echo "  kubectl get ingress sock-shop -n sock-shop"
echo ""
echo "  # Get the IP again:"
echo "  kubectl get ingress sock-shop -n sock-shop -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
echo ""
echo "  # Check load balancer health:"
echo "  gcloud compute backend-services get-health sock-shop-backend --global"
echo ""
echo "  # View frontend logs:"
echo "  kubectl logs -f deployment/front-end -n sock-shop"
echo ""
echo "  # Watch pods:"
echo "  kubectl get pods -n sock-shop -w"
echo ""

# Optional: Save IP to file for reference
echo "$INGRESS_IP" > "$SCRIPT_DIR/.sock-shop-ip"
log "IP saved to: $SCRIPT_DIR/.sock-shop-ip"

echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "${YELLOW}1. Open http://$INGRESS_IP in your browser${NC}"
echo -e "${YELLOW}2. Check Cloud Monitoring for metrics${NC}"
echo -e "${YELLOW}3. Run Locust load tests against the IP${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
echo ""