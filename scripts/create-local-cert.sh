#!/bin/bash

# Local Certificate Management Script for RaidHelper Development
# 
# This script creates and manages certificates for raidhelper.local development
# It creates a self-signed certificate and installs it on both the cluster and local machine

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
DOMAIN="raidhelper.local"
NAMESPACE="apps"
CERT_DIR="$HOME/.local/share/raidhelper-certs"
CLUSTER_SECRET_NAME="raidhelper-local-tls"

# Function to check prerequisites
check_prerequisites() {
    # Check if openssl is installed
    if ! command -v openssl &> /dev/null; then
        log_error "openssl is not installed. Please install it first:"
        echo "  brew install openssl"
        exit 1
    fi
    log_success "openssl is available"
    
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

# Function to create certificate directory
create_cert_directory() {
    log_info "Creating certificate directory: $CERT_DIR"
    mkdir -p "$CERT_DIR"
    log_success "Certificate directory created"
}

# Function to generate self-signed certificate
generate_certificate() {
    log_info "Generating self-signed certificate for $DOMAIN..."
    
    local key_file="$CERT_DIR/$DOMAIN.key"
    local cert_file="$CERT_DIR/$DOMAIN.crt"
    local csr_file="$CERT_DIR/$DOMAIN.csr"
    
    # Generate private key
    openssl genrsa -out "$key_file" 2048
    
    # Generate certificate signing request
    openssl req -new -key "$key_file" -out "$csr_file" -subj "/CN=$DOMAIN" \
        -addext "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN,IP:127.0.0.1,IP:10.0.0.1"
    
    # Generate self-signed certificate
    openssl x509 -req -in "$csr_file" -signkey "$key_file" -out "$cert_file" -days 365 \
        -extensions v3_req -extfile <(cat <<EOF
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
IP.1 = 127.0.0.1
IP.2 = 10.0.0.1
EOF
)
    
    # Clean up CSR file
    rm "$csr_file"
    
    log_success "Certificate generated: $cert_file"
    log_success "Private key generated: $key_file"
}

# Function to install certificate in Kubernetes cluster
install_cluster_certificate() {
    log_info "Installing certificate in Kubernetes cluster..."
    
    local key_file="$CERT_DIR/$DOMAIN.key"
    local cert_file="$CERT_DIR/$DOMAIN.crt"
    
    # Create Kubernetes secret with the certificate
    kubectl create secret tls "$CLUSTER_SECRET_NAME" \
        --cert="$cert_file" \
        --key="$key_file" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Certificate installed in cluster as secret: $CLUSTER_SECRET_NAME"
}

# Function to install certificate on local machine
install_local_certificate() {
    log_info "Installing certificate on local machine..."
    
    local cert_file="$CERT_DIR/$DOMAIN.crt"
    
    # Detect OS and install certificate accordingly
    case "$(uname -s)" in
        Darwin*)
            # macOS - add to system keychain
            log_info "Installing certificate in macOS keychain..."
            sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$cert_file"
            log_success "Certificate installed in macOS system keychain"
            ;;
        Linux*)
            # Linux - add to system certificate store
            log_info "Installing certificate in Linux certificate store..."
            sudo cp "$cert_file" /usr/local/share/ca-certificates/raidhelper-local.crt
            sudo update-ca-certificates
            log_success "Certificate installed in Linux certificate store"
            ;;
        *)
            log_warning "Unknown OS: $(uname -s). Please install certificate manually:"
            echo "  Certificate file: $cert_file"
            ;;
    esac
}

# Function to create local ingress route
create_local_ingress() {
    log_info "Creating local ingress route for $DOMAIN..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: raidhelper-local-ingress
  namespace: $NAMESPACE
  labels:
    environment: local
    domain: local
spec:
  entryPoints:
  - websecure
  routes:
  - kind: Rule
    match: Host(\`$DOMAIN\`)
    services:
    - name: raidhelper-web-service
      port: 80
  tls:
    secretName: $CLUSTER_SECRET_NAME
EOF
    
    log_success "Local ingress route created for $DOMAIN"
}

# Function to show setup instructions
show_setup_instructions() {
    echo ""
    echo "🏠 LOCAL HTTPS SETUP COMPLETE"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "• Domain: https://$DOMAIN"
    echo "• Certificate: $CERT_DIR/$DOMAIN.crt"
    echo "• Private Key: $CERT_DIR/$DOMAIN.key"
    echo "• Cluster Secret: $CLUSTER_SECRET_NAME"
    echo ""
    echo "🔧 NEXT STEPS:"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "1. Add to /etc/hosts (if not already done):"
    echo "   127.0.0.1 $DOMAIN"
    echo ""
    echo "2. Access your application:"
    echo "   https://$DOMAIN"
    echo ""
    echo "3. If you see certificate warnings, restart your browser"
    echo ""
    echo "4. For other devices on your network, add:"
    echo "   <your-ip> $DOMAIN"
    echo ""
}

# Function to clean up certificates
cleanup_certificates() {
    log_info "Cleaning up certificates..."
    
    # Remove from cluster
    kubectl delete secret "$CLUSTER_SECRET_NAME" -n "$NAMESPACE" 2>/dev/null || log_info "No cluster certificate to clean up"
    
    # Remove local ingress
    kubectl delete ingressroute raidhelper-local-ingress -n "$NAMESPACE" 2>/dev/null || log_info "No local ingress to clean up"
    
    # Remove local files
    if [ -d "$CERT_DIR" ]; then
        rm -rf "$CERT_DIR"
        log_success "Local certificate files removed"
    fi
    
    # Remove from system (macOS)
    if [[ "$(uname -s)" == "Darwin"* ]]; then
        log_info "Removing certificate from macOS keychain..."
        sudo security delete-certificate -c "$DOMAIN" /Library/Keychains/System.keychain 2>/dev/null || log_info "No certificate found in keychain"
    fi
    
    log_success "Certificate cleanup complete"
}

# Function to show certificate status
show_status() {
    echo "🏠 Local Certificate Status"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    if [ -f "$CERT_DIR/$DOMAIN.crt" ]; then
        log_success "Certificate exists: $CERT_DIR/$DOMAIN.crt"
        
        # Show certificate details
        echo "• Subject: $(openssl x509 -in "$CERT_DIR/$DOMAIN.crt" -noout -subject | sed 's/subject=//')"
        echo "• Valid until: $(openssl x509 -in "$CERT_DIR/$DOMAIN.crt" -noout -enddate | sed 's/notAfter=//')"
        echo "• SAN: $(openssl x509 -in "$CERT_DIR/$DOMAIN.crt" -noout -text | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/^[[:space:]]*//')"
    else
        log_warning "No certificate found"
    fi
    
    if kubectl get secret "$CLUSTER_SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
        log_success "Certificate installed in cluster"
    else
        log_warning "Certificate not installed in cluster"
    fi
    
    if kubectl get ingressroute raidhelper-local-ingress -n "$NAMESPACE" &> /dev/null; then
        log_success "Local ingress route exists"
    else
        log_warning "No local ingress route found"
    fi
}

# Handle different script arguments
case "${1:-}" in
    create)
        echo "🏠 Creating Local HTTPS Certificate for RaidHelper Development"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        check_prerequisites
        create_cert_directory
        generate_certificate
        install_cluster_certificate
        install_local_certificate
        create_local_ingress
        show_setup_instructions
        log_success "Local HTTPS setup complete!"
        ;;
    cleanup)
        echo "🧹 Cleaning Up Local HTTPS Certificate"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        cleanup_certificates
        log_success "Cleanup complete!"
        ;;
    status)
        show_status
        ;;
    --help|-h)
        echo "Local Certificate Management Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  create     Create and install local certificate"
        echo "  cleanup    Remove certificate from cluster and local machine"
        echo "  status     Show certificate status"
        echo "  --help     Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 create     # Create and install certificate"
        echo "  $0 cleanup    # Remove certificate"
        echo "  $0 status     # Check certificate status"
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
