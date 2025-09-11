#!/bin/bash

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

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check if port is already in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to start port forward
start_port_forward() {
    local service=$1
    local namespace=$2
    local local_port=$3
    local remote_port=$4
    local service_name="$service in $namespace"
    
    log_info "Starting port-forward for $service_name ($local_port:$remote_port)..."
    
    # Check if port is already in use
    if check_port $local_port; then
        log_warn "Port $local_port is already in use, skipping $service_name"
        return
    fi
    
    # Start port-forward in background
    kubectl port-forward "svc/$service" "$local_port:$remote_port" -n "$namespace" > /dev/null 2>&1 &
    local pid=$!
    
    # Wait a moment and check if the process is still running
    sleep 2
    if kill -0 $pid 2>/dev/null; then
        log_success "Port-forward started for $service_name (PID: $pid)"
        echo "$pid" >> /tmp/localdev-port-forwards.pids
    else
        log_error "Failed to start port-forward for $service_name"
        return 1
    fi
}

# Function to cleanup existing port forwards
cleanup_port_forwards() {
    log_info "Cleaning up existing port forwards..."
    
    # First, kill processes from our PID file if it exists
    if [ -f /tmp/localdev-port-forwards.pids ]; then
        while read -r pid; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                log_info "Stopping port-forward process $pid..."
                kill -TERM "$pid" 2>/dev/null || true
            fi
        done < /tmp/localdev-port-forwards.pids
    fi
    
    # Kill any remaining kubectl port-forward processes
    log_info "Stopping any remaining kubectl port-forward processes..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    # Wait for processes to terminate gracefully
    sleep 3
    
    # Force kill any stubborn processes
    pkill -9 -f "kubectl port-forward" 2>/dev/null || true
    
    # Remove PID file
    rm -f /tmp/localdev-port-forwards.pids
    
    # Wait a bit more to ensure cleanup
    sleep 1
    
    # Verify no kubectl port-forward processes are running
    if pgrep -f "kubectl port-forward" >/dev/null 2>&1; then
        log_warn "Some kubectl port-forward processes may still be running"
        log_info "You can manually stop them with: pkill -9 -f 'kubectl port-forward'"
    else
        log_success "All port-forward processes stopped successfully"
    fi
}

# Function to wait for services to be ready
wait_for_services() {
    log_info "Waiting for services to be ready..."
    
    # ArgoCD
    kubectl wait --for=condition=available --timeout=300s deployment/argo-argocd-server -n argocd || true
    
    # Prometheus
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus-server -n monitoring || true
    
    # Grafana
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring || true
    
    # Traefik
    kubectl wait --for=condition=available --timeout=300s deployment/traefik -n traefik || true
    
    # Linkerd
    kubectl wait --for=condition=available --timeout=300s deployment/linkerd-identity -n linkerd || true
    
    # NATS
    kubectl wait --for=condition=ready --timeout=300s pod/nats-0 -n nats || true
    
    log_success "Services are ready"
}

# Function to display service URLs
show_services() {
    # Get ArgoCD password for display
    local admin_password=""
    if kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; then
        admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "<check argocd-config.env>")
    else
        admin_password="<check argocd-config.env>"
    fi
    
    echo
    echo -e "${BLUE}🌐 Available Services:${NC}"
    echo "  ┌─────────────────────────────────────────────────┐"
    echo "  │ Service     │ URL                               │"
    echo "  ├─────────────────────────────────────────────────┤"
    echo "  │ Web App     │ http://raidhelper.local:8086      │"
    echo "  │ ArgoCD      │ http://localhost:8081             │"
    echo "  │ Prometheus  │ http://localhost:9091             │"
    echo "  │ Grafana     │ http://localhost:3000             │"
    echo "  │ Tempo       │ http://localhost:3200             │"
    echo "  │ Loki        │ http://localhost:3100             │"
    echo "  │ NATS        │ nats://localhost:4222             │"
    echo "  │ LocalStack  │ http://localhost:8000             │"
    echo "  │ Traefik UI  │ http://localhost:8085             │"
    echo "  │ Linkerd     │ http://localhost:50750            │"
    echo "  └─────────────────────────────────────────────────┘"
    echo
    echo -e "${BLUE}🔑 Default Credentials:${NC}"
    echo "  - Grafana: admin/admin123"
    echo "  - ArgoCD: admin/$admin_password"
    echo
}

# Main function
main() {
    echo -e "${BLUE}🔌 Starting Port Forwards for Local Development${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    # Create PID file for tracking
    touch /tmp/localdev-port-forwards.pids
    
    # Cleanup any existing port forwards
    cleanup_port_forwards
    
    # Wait for services to be ready
    wait_for_services
    
    # Start port forwards
    log_info "Starting port forwards..."
    
    # Traefik (main entry point for local domains) - FIRST
    start_port_forward "traefik" "traefik" "8086" "80"
    # Traefik dashboard
    start_port_forward "traefik" "traefik" "8085" "8081"
    
    # Core infrastructure services
    start_port_forward "argo-argocd-server" "argocd" "8081" "80"
    start_port_forward "prometheus-server" "monitoring" "9091" "80"
    start_port_forward "grafana" "monitoring" "3000" "80"
    start_port_forward "tempo" "monitoring" "3200" "3100"
    
    start_port_forward "loki" "monitoring" "3100" "3100"
    
    # NATS
    start_port_forward "nats" "nats" "4222" "4222"
    
    # LocalStack (DynamoDB emulation)
    start_port_forward "localstack" "storage" "8000" "4566"
    
    start_port_forward "web" "linkerd-viz" "50750" "8084"
    
    echo
    log_success "Port forwards started successfully!"
    
    # Show available services
    show_services
    
    log_info "Port forwards are running in the background."
    log_info "To stop all port forwards: ./scripts/port-forwards.sh --cleanup"
    log_info "For aggressive cleanup: ./scripts/port-forwards.sh --force-cleanup"
    log_info "To view this information again: ./scripts/port-forwards.sh --show-only"
    
    # If running interactively, keep the script running
    if [[ "${1:-}" != "--show-only" ]] && [[ -t 0 ]]; then
        echo
        log_info "Press Ctrl+C to stop all port forwards and exit..."
        
        # Function to cleanup on exit
        cleanup_on_exit() {
            echo
            log_info "Received interrupt signal, stopping port forwards..."
            cleanup_port_forwards
            log_success "Cleanup completed. Goodbye!"
            exit 0
        }
        
        # Set trap for cleanup
        trap cleanup_on_exit INT TERM
        
        # Keep script running
        while true; do
            sleep 5
            
            # Check if any port-forward processes died
            if [ -f /tmp/localdev-port-forwards.pids ]; then
                while read -r pid; do
                    if ! kill -0 "$pid" 2>/dev/null; then
                        log_warn "Port-forward process $pid died, you may need to restart"
                    fi
                done < /tmp/localdev-port-forwards.pids
            fi
        done
    fi
}

# Function for aggressive cleanup
aggressive_cleanup() {
    log_info "Performing aggressive cleanup of all kubectl port-forward processes..."
    
    # Kill all kubectl port-forward processes with SIGTERM first
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    
    # Force kill any remaining processes
    pkill -9 -f "kubectl port-forward" 2>/dev/null || true
    sleep 1
    
    # Remove PID file
    rm -f /tmp/localdev-port-forwards.pids
    
    # Check if any processes are still running
    if pgrep -f "kubectl port-forward" >/dev/null 2>&1; then
        log_error "Some processes are still running. You may need to restart your terminal or reboot."
        log_info "Running processes:"
        pgrep -f "kubectl port-forward" | xargs ps -p 2>/dev/null || true
    else
        log_success "All kubectl port-forward processes have been terminated"
    fi
}

# Handle different script arguments
case "${1:-}" in
    --show-only)
        show_services
        ;;
    --cleanup)
        cleanup_port_forwards
        ;;
    --force-cleanup)
        aggressive_cleanup
        ;;
    *)
        main "${1:-}"
        ;;
esac
