#!/bin/bash

# Cloudflare Tunnel Management Script for RaidHelper Development
# 
# This script manages ephemeral Cloudflare tunnels for local development.
# The tunnel connects to Traefik on port 8080 (web), which then routes traffic
# to the appropriate services. Cloudflare handles TLS termination at their edge.
#
# Port Configuration:
# - Tunnel connects to: localhost:8080 (Traefik web entry point)
# - Traefik dashboard: localhost:8081
# - API service: localhost:8082
# - WebSocket service: localhost:8083
# - Web service: localhost:8084

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Configuration
CONFIG_DIR="/Users/rinse/work/sopatech/localdev/config"
TUNNEL_ENV_FILE="$CONFIG_DIR/tunnel.env"
NAMESPACE="apps"
CONFIGMAP_NAME="tunnel-config"
PID_FILE="/tmp/cloudflared.pid"
LOG_FILE="/tmp/cloudflared.log"

# Function to check prerequisites
check_prerequisites() {
    # Check if cloudflared is installed
    if ! command -v cloudflared &> /dev/null; then
        log_error "cloudflared is not installed. Please install it first:"
        echo "  brew install cloudflared"
        exit 1
    fi
    log_success "cloudflared is installed"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    log_success "kubectl is available"
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Make sure minikube is running:"
        echo "  minikube start"
        exit 1
    fi
    log_success "Connected to Kubernetes cluster"
    
    # Check if the namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' does not exist. Please run setup first:"
        echo "  make setup"
        exit 1
    fi
    log_success "Namespace '$NAMESPACE' exists"
}

# Function to start ephemeral tunnel
start_tunnel() {
    log_info "Starting ephemeral Cloudflare tunnel (connecting to Traefik web endpoint on port 8080)..."
    
    # Clear previous log
    > "$LOG_FILE"
    
    # Start tunnel in background (connect to Traefik web endpoint on port 8080)
    # Cloudflare handles TLS termination at their edge - no need for cluster TLS
    cloudflared tunnel --url http://localhost:8080 > "$LOG_FILE" 2>&1 &
    TUNNEL_PID=$!
    
    # Wait for tunnel to start and get URL
    log_info "Waiting for tunnel to start..."
    # Give cloudflared a moment to start writing to the log file
    sleep 3
    for i in {1..30}; do
        sleep 2
        # Check if the log file exists and has content
        if [ -f "$LOG_FILE" ]; then
            # Try to extract the tunnel URL from the log
            # Use strings to handle binary characters in the log file
            TUNNEL_URL=$(strings "$LOG_FILE" | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | head -1)
            if [ -n "$TUNNEL_URL" ]; then
                log_info "Found tunnel URL: $TUNNEL_URL"
                break
            fi
        fi
        if [ $((i % 5)) -eq 0 ]; then
            log_info "Still waiting for tunnel URL... (attempt $i/30)"
            if [ -f "$LOG_FILE" ]; then
                log_info "Log file size: $(wc -l < "$LOG_FILE") lines"
                # Show last few lines of log for debugging
                log_info "Last few lines of log:"
                tail -3 "$LOG_FILE" | sed 's/^/  /'
            fi
        fi
    done
    
    if [ -z "$TUNNEL_URL" ]; then
        log_error "Failed to extract tunnel URL from cloudflared output after 30 attempts"
        log_info "This could be due to:"
        echo "  • Network connectivity issues"
        echo "  • Cloudflare service being unavailable"
        echo "  • Port 8086 not being accessible (make sure Traefik is running)"
        echo ""
        log_info "Log file contents:"
        if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
            cat "$LOG_FILE"
        else
            log_info "Log file not found or empty"
        fi
        log_info "Stopping tunnel process..."
        kill $TUNNEL_PID 2>/dev/null || true
        exit 1
    fi
    
    # Extract hostname from URL
    TUNNEL_HOSTNAME=$(echo "$TUNNEL_URL" | sed 's|https://||')
    
    # Save PID
    echo "$TUNNEL_PID" > "$PID_FILE"
    
    log_success "Ephemeral tunnel started: $TUNNEL_URL"
    log_info "Tunnel PID: $TUNNEL_PID"
}

# Function to create tunnel environment file
create_tunnel_env() {
    log_info "Creating tunnel environment configuration..."
    
    mkdir -p "$CONFIG_DIR"
    
    cat > "$TUNNEL_ENV_FILE" << EOF
# Ephemeral Tunnel Configuration
# This file is generated by the tunnel script
# WARNING: This URL will change when the tunnel restarts!

# Tunnel URL (ephemeral - changes on restart)
TUNNEL_URL=$TUNNEL_HOSTNAME
TWITCH_REDIRECT_URI=https://$TUNNEL_HOSTNAME/oauth/twitch
HOST=$TUNNEL_HOSTNAME

# API and WebSocket URLs for Next.js
NEXT_PUBLIC_API_URL=http://localhost:8082
NEXT_PUBLIC_WS_URL=ws://localhost:8083

# Twitch OAuth configuration
TWITCH_CLIENT_ID=5svgsqtpx6xa538w6mz0lzev46btb9

# Generated on: $(date)
# Tunnel URL: $TUNNEL_URL
# WARNING: This is an ephemeral tunnel - URL will change on restart!
EOF
    
    log_success "Tunnel environment file created: $TUNNEL_ENV_FILE"
}

# Function to create self-signed certificate for tunnel
create_tunnel_certificate() {
    # Get tunnel hostname from environment file if not set
    if [ -z "${TUNNEL_HOSTNAME:-}" ] && [ -f "$TUNNEL_ENV_FILE" ]; then
        TUNNEL_HOSTNAME=$(grep "^TUNNEL_URL=" "$TUNNEL_ENV_FILE" | cut -d'=' -f2)
    fi
    
    if [ -z "${TUNNEL_HOSTNAME:-}" ]; then
        log_error "TUNNEL_HOSTNAME not set and cannot read from tunnel.env file"
        return 1
    fi
    
    log_info "Creating self-signed certificate for tunnel host: $TUNNEL_HOSTNAME"
    
    # Generate self-signed certificate using openssl
    local cert_dir="/tmp/tunnel-certs"
    mkdir -p "$cert_dir"
    
    # Generate private key and certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$cert_dir/tls.key" \
        -out "$cert_dir/tls.crt" \
        -subj "/CN=$TUNNEL_HOSTNAME" \
        -addext "subjectAltName=DNS:$TUNNEL_HOSTNAME,DNS:*.trycloudflare.com" 2>/dev/null
    
    # Create Kubernetes secret with the certificate
    kubectl create secret tls tunnel-tls \
        --cert="$cert_dir/tls.crt" \
        --key="$cert_dir/tls.key" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Save certificate for manual browser trust (optional)
    local cert_save_dir="$HOME/.local/share/raidhelper-certs"
    mkdir -p "$cert_save_dir"
    cp "$cert_dir/tls.crt" "$cert_save_dir/tunnel-$(date +%s).crt"
    
    # Clean up temporary files
    rm -rf "$cert_dir"
    
    log_success "Self-signed certificate created for $TUNNEL_HOSTNAME"
    log_info "Certificate saved to: $cert_save_dir/ for manual browser trust"
    log_warning "Browser will show security warnings - this is normal for self-signed certificates"
    log_info "To trust manually: Import $cert_save_dir/tunnel-*.crt into your browser's certificate store"
}

# Function to create tunnel ingress route
create_tunnel_ingress() {
    # Get tunnel hostname from environment file if not set
    if [ -z "${TUNNEL_HOSTNAME:-}" ] && [ -f "$TUNNEL_ENV_FILE" ]; then
        TUNNEL_HOSTNAME=$(grep "^TUNNEL_URL=" "$TUNNEL_ENV_FILE" | cut -d'=' -f2)
    fi
    
    if [ -z "${TUNNEL_HOSTNAME:-}" ]; then
        log_error "TUNNEL_HOSTNAME not set and cannot read from tunnel.env file"
        return 1
    fi
    
    log_info "Creating tunnel ingress route for host: $TUNNEL_HOSTNAME"
    
    # Create a new ingress route for the tunnel URL (HTTP - Cloudflare handles TLS)
    cat <<EOF | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: raidhelper-tunnel-ingress
  namespace: $NAMESPACE
  labels:
    environment: local
    tunnel: ephemeral
spec:
  entryPoints:
  - web
  routes:
  - kind: Rule
    match: Host(\`$TUNNEL_HOSTNAME\`)
    services:
    - name: raidhelper-web-service
      port: 80
EOF
    
    log_success "Tunnel ingress route created for $TUNNEL_HOSTNAME (HTTP - Cloudflare handles TLS)"
}

# Function to apply tunnel configuration to Kubernetes
apply_tunnel_config() {
    log_info "Applying tunnel configuration to Kubernetes..."
    
    # Create ConfigMap
    if ! kubectl create configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" \
        --from-env-file="$TUNNEL_ENV_FILE" --dry-run=client -o yaml | kubectl apply -f -; then
        log_error "Failed to create/update ConfigMap '$CONFIGMAP_NAME'"
        return 1
    fi
    log_success "ConfigMap '$CONFIGMAP_NAME' created/updated"
    
    # No certificate needed - Cloudflare handles TLS termination
    
    # Create tunnel ingress route
    if ! create_tunnel_ingress; then
        log_error "Failed to create tunnel ingress route"
        return 1
    fi
    
    # Patch deployments
    for deployment in raidhelper-api raidhelper-realtime raidhelper-web; do
        log_info "Patching deployment '$deployment'..."
        if ! kubectl patch deployment "$deployment" -n "$NAMESPACE" \
            --type=json -p='[{"op": "add", "path": "/spec/template/spec/containers/0/envFrom/-", "value": {"configMapRef": {"name": "'"$CONFIGMAP_NAME"'"}}}]' 2>/dev/null; then
            # Try replace if add fails
            if ! kubectl patch deployment "$deployment" -n "$NAMESPACE" \
                --type=json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/envFrom", "value": [{"configMapRef": {"name": "'"$CONFIGMAP_NAME"'"}}]}]'; then
                log_warning "Failed to patch deployment '$deployment' - it may not exist yet"
                continue
            fi
        fi
        log_success "Deployment '$deployment' patched"
    done
}

# Function to clean up tunnel ingress route
cleanup_tunnel_ingress() {
    log_info "Cleaning up old tunnel ingress route..."
    kubectl delete ingressroute raidhelper-tunnel-ingress -n "$NAMESPACE" 2>/dev/null || log_info "No existing tunnel ingress route to clean up"
}

# Function to stop tunnel
stop_tunnel() {
    if [ -f "$PID_FILE" ]; then
        TUNNEL_PID=$(cat "$PID_FILE")
        if kill -0 "$TUNNEL_PID" 2>/dev/null; then
            log_info "Stopping tunnel (PID: $TUNNEL_PID)..."
            kill "$TUNNEL_PID"
            sleep 2
            log_success "Tunnel stopped"
        else
            log_warning "Tunnel process not running"
        fi
        rm -f "$PID_FILE"
    else
        log_warning "No tunnel PID file found"
    fi
    
    # Also kill any remaining cloudflared processes
    pkill -f "cloudflared tunnel" 2>/dev/null || true
    log_success "All cloudflared tunnel processes stopped"
    
    # Clean up tunnel ingress route
    cleanup_tunnel_ingress
}

# Function to show tunnel status
show_status() {
    echo "🚇 Cloudflare Tunnel Status"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    if [ -f "$PID_FILE" ]; then
        TUNNEL_PID=$(cat "$PID_FILE")
        if kill -0 "$TUNNEL_PID" 2>/dev/null; then
            log_success "Tunnel is running (PID: $TUNNEL_PID)"
            
            if [ -f "$TUNNEL_ENV_FILE" ]; then
                TUNNEL_URL=$(grep "^TUNNEL_URL=" "$TUNNEL_ENV_FILE" | cut -d'=' -f2)
                if [ -n "$TUNNEL_URL" ]; then
                    echo "• Tunnel URL: https://$TUNNEL_URL"
                    echo "• Twitch OAuth URL: https://$TUNNEL_URL/oauth/twitch"
                fi
            fi
        else
            log_warning "Tunnel PID file exists but process is not running"
        fi
    else
        log_warning "No tunnel is currently running"
    fi
    
    echo ""
    echo "Available commands:"
    echo "  ./scripts/tunnel.sh start    - Start ephemeral tunnel"
    echo "  ./scripts/tunnel.sh restart  - Restart tunnel with new URL"
    echo "  ./scripts/tunnel.sh stop     - Stop tunnel"
    echo "  ./scripts/tunnel.sh status   - Show tunnel status"
    echo "  ./scripts/tunnel.sh apply    - Apply tunnel config to Kubernetes"
}

# Function to show Twitch OAuth setup instructions
show_twitch_instructions() {
    echo ""
    echo "🔄 TUNNEL MANAGEMENT:"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "• Tunnel URL: $TUNNEL_URL"
    echo "• Tunnel PID: $TUNNEL_PID (saved in $PID_FILE)"
    echo ""
    echo "To restart tunnel with new URL:"
    echo "  ./scripts/tunnel.sh restart"
    echo ""
    echo "To stop tunnel:"
    echo "  ./scripts/tunnel.sh stop"
    echo ""
    echo "⚠️  WARNING: This is an ephemeral tunnel!"
    echo "   • URL changes every time you restart the tunnel"
    echo "   • You'll need to update Twitch OAuth settings each time"
    echo "   • For production, use a permanent tunnel instead"
    echo ""
    echo "🔧 TWITCH OAUTH SETUP REQUIRED:"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "⚠️  IMPORTANT: You need to update your Twitch OAuth application:"
    echo ""
    echo "1. Go to: https://dev.twitch.tv/console/apps"
    echo "2. Find your RaidHelper application"
    echo "3. Update the 'OAuth Redirect URLs' to include:"
    echo "   https://$TUNNEL_HOSTNAME/oauth/twitch"
    echo ""
    echo "4. Save the changes"
    echo ""
}

# Function to start tunnel and apply configuration
start_tunnel_setup() {
    echo "🚇 Ephemeral Cloudflare Tunnel Setup for RaidHelper Development"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    check_prerequisites
    start_tunnel
    create_tunnel_env
    apply_tunnel_config
    show_twitch_instructions
    
    log_success "Ephemeral tunnel setup complete!"
    log_warning "Remember to update your Twitch OAuth redirect URL!"
}

# Function to restart tunnel
restart_tunnel() {
    echo "🔄 Restarting Ephemeral Cloudflare Tunnel"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    stop_tunnel
    start_tunnel
    create_tunnel_env
    apply_tunnel_config
    show_twitch_instructions
    
    log_success "Tunnel restart complete!"
    log_warning "Don't forget to update your Twitch OAuth redirect URL!"
}

# Function to apply tunnel configuration only
apply_config_only() {
    if [ ! -f "$TUNNEL_ENV_FILE" ]; then
        log_error "No tunnel environment file found. Start a tunnel first:"
        echo "  ./scripts/tunnel.sh start"
        exit 1
    fi
    
    log_info "Applying tunnel configuration to Kubernetes..."
    apply_tunnel_config
    log_success "Configuration applied successfully!"
}

# Handle different script arguments
case "${1:-}" in
    start)
        start_tunnel_setup
        ;;
    restart)
        restart_tunnel
        ;;
    stop)
        echo "🛑 Stopping Ephemeral Cloudflare Tunnel"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        stop_tunnel
        log_success "Tunnel stopped successfully!"
        ;;
    status)
        show_status
        ;;
    apply)
        apply_config_only
        ;;
    --help|-h)
        echo "Cloudflare Tunnel Management Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  start     Start ephemeral tunnel and apply configuration"
        echo "  restart   Restart tunnel with new URL"
        echo "  stop      Stop tunnel"
        echo "  status    Show tunnel status"
        echo "  apply     Apply tunnel configuration to Kubernetes"
        echo "  --help    Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 start     # Start tunnel and configure everything"
        echo "  $0 restart   # Get new tunnel URL"
        echo "  $0 stop      # Stop tunnel"
        echo "  $0 status    # Check if tunnel is running"
        ;;
    "")
        show_status
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        echo "Use '$0 --help' for usage information"
        exit 1
        ;;
esac
