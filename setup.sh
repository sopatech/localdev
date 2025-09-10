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

# Print section headers
print_header() {
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🔧 $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get install command for missing tools
get_install_command() {
    local tool="$1"
    local os_type=$(uname -s)
    
    case "$tool" in
        docker)
            if [[ "$os_type" == "Darwin" ]]; then
                echo "Install Docker Desktop from https://docs.docker.com/desktop/mac/install/"
            elif [[ "$os_type" == "Linux" ]]; then
                echo "curl -fsSL https://get.docker.com | sh"
            else
                echo "Visit https://docs.docker.com/get-docker/"
            fi
            ;;
        minikube)
            if [[ "$os_type" == "Darwin" ]]; then
                echo "brew install minikube"
            elif [[ "$os_type" == "Linux" ]]; then
                echo "curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && sudo install minikube-linux-amd64 /usr/local/bin/minikube"
            fi
            ;;
        kubectl)
            if [[ "$os_type" == "Darwin" ]]; then
                echo "brew install kubectl"
            elif [[ "$os_type" == "Linux" ]]; then
                echo "curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && sudo install kubectl /usr/local/bin/"
            fi
            ;;
        helm)
            if [[ "$os_type" == "Darwin" ]]; then
                echo "brew install helm"
            elif [[ "$os_type" == "Linux" ]]; then
                echo "curl https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz | tar -xzO linux-amd64/helm | sudo tee /usr/local/bin/helm > /dev/null && sudo chmod +x /usr/local/bin/helm"
            fi
            ;;
        helmfile)
            if [[ "$os_type" == "Darwin" ]]; then
                echo "brew install helmfile"
            elif [[ "$os_type" == "Linux" ]]; then
                echo "curl -L https://github.com/helmfile/helmfile/releases/download/v0.158.0/helmfile_0.158.0_linux_amd64.tar.gz | tar -xzO helmfile | sudo tee /usr/local/bin/helmfile > /dev/null && sudo chmod +x /usr/local/bin/helmfile"
            fi
            ;;
        argocd)
            if [[ "$os_type" == "Darwin" ]]; then
                echo "brew install argocd"
            elif [[ "$os_type" == "Linux" ]]; then
                echo "curl -sSL https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 -o argocd && sudo install argocd /usr/local/bin/"
            fi
            ;;
        telepresence)
            if [[ "$os_type" == "Darwin" ]]; then
                echo "brew install datawire/blackbird/telepresence"
            elif [[ "$os_type" == "Linux" ]]; then
                echo "sudo curl -fL https://app.getambassador.io/download/tel2oss/releases/download/v2.18.0/telepresence-linux-amd64 -o /usr/local/bin/telepresence && sudo chmod +x /usr/local/bin/telepresence"
            fi
            ;;
        linkerd)
            if [[ "$os_type" == "Darwin" ]]; then
                echo "brew install linkerd"
            elif [[ "$os_type" == "Linux" ]]; then
                echo "curl -sSL https://run.linkerd.io/install | sh"
            fi
            ;;
        go)
            if [[ "$os_type" == "Darwin" ]]; then
                echo "brew install go"
            elif [[ "$os_type" == "Linux" ]]; then
                echo "Visit https://golang.org/dl/ to download and install Go"
            fi
            ;;
        *)
            echo "Unknown tool: $tool"
            ;;
    esac
}

# Function to install a missing tool
install_tool() {
    local tool="$1"
    local os_type=$(uname -s)
    
    log_info "Installing $tool..."
    
    case "$tool" in
        docker)
            if [[ "$os_type" == "Darwin" ]]; then
                log_error "Docker Desktop must be installed manually from https://docs.docker.com/desktop/mac/install/"
                return 1
            elif [[ "$os_type" == "Linux" ]]; then
                curl -fsSL https://get.docker.com | sh
                sudo usermod -aG docker $USER
                log_warn "Please log out and back in for Docker group membership to take effect"
            fi
            ;;
        minikube)
            if [[ "$os_type" == "Darwin" ]]; then
                if command_exists brew; then
                    brew install minikube
                else
                    log_error "Homebrew is required to install minikube on macOS"
                    return 1
                fi
            elif [[ "$os_type" == "Linux" ]]; then
                curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
                sudo install minikube-linux-amd64 /usr/local/bin/minikube
                rm -f minikube-linux-amd64
            fi
            ;;
        kubectl)
            if [[ "$os_type" == "Darwin" ]]; then
                if command_exists brew; then
                    brew install kubectl
                else
                    log_error "Homebrew is required to install kubectl on macOS"
                    return 1
                fi
            elif [[ "$os_type" == "Linux" ]]; then
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                sudo install kubectl /usr/local/bin/
                rm -f kubectl
            fi
            ;;
        helm)
            if [[ "$os_type" == "Darwin" ]]; then
                if command_exists brew; then
                    brew install helm
                else
                    log_error "Homebrew is required to install helm on macOS"
                    return 1
                fi
            elif [[ "$os_type" == "Linux" ]]; then
                curl https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz | tar -xzO linux-amd64/helm | sudo tee /usr/local/bin/helm > /dev/null
                sudo chmod +x /usr/local/bin/helm
            fi
            ;;
        helmfile)
            if [[ "$os_type" == "Darwin" ]]; then
                if command_exists brew; then
                    brew install helmfile
                else
                    log_error "Homebrew is required to install helmfile on macOS"
                    return 1
                fi
            elif [[ "$os_type" == "Linux" ]]; then
                curl -L https://github.com/helmfile/helmfile/releases/download/v0.158.0/helmfile_0.158.0_linux_amd64.tar.gz | tar -xzO helmfile | sudo tee /usr/local/bin/helmfile > /dev/null
                sudo chmod +x /usr/local/bin/helmfile
            fi
            ;;
        argocd)
            if [[ "$os_type" == "Darwin" ]]; then
                if command_exists brew; then
                    brew install argocd
                else
                    log_error "Homebrew is required to install argocd on macOS"
                    return 1
                fi
            elif [[ "$os_type" == "Linux" ]]; then
                curl -sSL https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 -o argocd
                sudo install argocd /usr/local/bin/
                rm -f argocd
            fi
            ;;
        telepresence)
            if [[ "$os_type" == "Darwin" ]]; then
                if command_exists brew; then
                    brew install datawire/blackbird/telepresence
                else
                    log_error "Homebrew is required to install telepresence on macOS"
                    return 1
                fi
            elif [[ "$os_type" == "Linux" ]]; then
                sudo curl -fL https://app.getambassador.io/download/tel2oss/releases/download/v2.18.0/telepresence-linux-amd64 -o /usr/local/bin/telepresence
                sudo chmod +x /usr/local/bin/telepresence
            fi
            ;;
        linkerd)
            if [[ "$os_type" == "Darwin" ]]; then
                if command_exists brew; then
                    brew install linkerd
                else
                    log_error "Homebrew is required to install linkerd on macOS"
                    return 1
                fi
            elif [[ "$os_type" == "Linux" ]]; then
                curl -sSL https://run.linkerd.io/install | sh
                # Add to PATH if not already there
                if [[ ":$PATH:" != *":$HOME/.linkerd2/bin:"* ]]; then
                    export PATH=$PATH:$HOME/.linkerd2/bin
                    echo 'export PATH=$PATH:$HOME/.linkerd2/bin' >> ~/.bashrc
                    log_info "Added linkerd to PATH. You may need to restart your terminal."
                fi
            fi
            ;;
        go)
            if [[ "$os_type" == "Darwin" ]]; then
                if command_exists brew; then
                    brew install go
                else
                    log_error "Homebrew is required to install go on macOS"
                    return 1
                fi
            elif [[ "$os_type" == "Linux" ]]; then
                log_error "Go must be installed manually from https://golang.org/dl/"
                return 1
            fi
            ;;
        *)
            log_error "Unknown tool: $tool"
            return 1
            ;;
    esac
    
    # Verify installation
    if command_exists "$tool"; then
        log_success "$tool installed successfully"
        return 0
    else
        log_error "Failed to install $tool"
        return 1
    fi
}

# Function to check requirements
check_requirements() {
    print_header "CHECKING REQUIREMENTS"
    
    local missing_tools=()
    local tools=("docker" "minikube" "kubectl" "helm" "helmfile" "argocd" "telepresence" "linkerd" "go" "curl")
    
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            log_success "$tool is installed"
        else
            log_warn "$tool is not installed"
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo
        log_warn "Found ${#missing_tools[@]} missing tools:"
        echo
        for tool in "${missing_tools[@]}"; do
            echo -e "${YELLOW}  • $tool:${NC} $(get_install_command "$tool")"
        done
        echo
        
        # Check for Homebrew on macOS if needed
        local os_type=$(uname -s)
        if [[ "$os_type" == "Darwin" ]] && ! command_exists brew; then
            log_warn "Homebrew is not installed. Most tools require Homebrew on macOS."
            echo
            read -p "Would you like to install Homebrew first? [Y/n]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                log_info "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                if ! command_exists brew; then
                    log_error "Failed to install Homebrew. Please install it manually and run this script again."
                    exit 1
                fi
                log_success "Homebrew installed successfully!"
                echo
            fi
        fi
        
        # Ask if user wants to install missing tools
        read -p "Would you like this script to automatically install the missing tools? [Y/n]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo
            print_header "INSTALLING MISSING TOOLS"
            
            local failed_installs=()
            for tool in "${missing_tools[@]}"; do
                if ! install_tool "$tool"; then
                    failed_installs+=("$tool")
                fi
            done
            
            if [ ${#failed_installs[@]} -ne 0 ]; then
                echo
                log_error "Failed to install the following tools:"
                for tool in "${failed_installs[@]}"; do
                    echo -e "${RED}  • $tool:${NC} $(get_install_command "$tool")"
                done
                echo
                log_error "Please install the failed tools manually and run this script again."
                exit 1
            else
                echo
                log_success "All missing tools installed successfully!"
                
                # Check if we need to refresh PATH or restart
                if [[ "$os_type" == "Darwin" ]] && command_exists brew; then
                    log_info "You may need to restart your terminal or run 'source ~/.zshrc' to update your PATH"
                fi
            fi
        else
            echo
            log_error "Please install the missing tools manually and run this script again."
            exit 1
        fi
    fi
    
    log_success "All required tools are available!"
}

# Function to detect OS
detect_os() {
    local os_type=$(uname -s)
    case "$os_type" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to configure minikube
configure_minikube() {
    print_header "CONFIGURING MINIKUBE"
    
    # Check if minikube is already running
    local minikube_status=$(minikube status 2>/dev/null)
    if echo "$minikube_status" | grep -q "host: Running" && echo "$minikube_status" | grep -q "kubelet: Running"; then
        log_info "Minikube is already running"
        return
    fi
    
    # Check if minikube exists but is stopped
    if minikube profile list 2>/dev/null | grep -q "minikube"; then
        log_info "Minikube exists but is stopped. Starting minikube..."
        minikube start
        log_success "Minikube started successfully!"
        return
    fi
    
    log_info "Configuring minikube with 6 CPUs and 8GB memory..."
    
    # Configure minikube
    minikube config set cpus 6
    minikube config set memory 8192
    minikube config set driver docker
    
    log_info "Starting minikube..."
    minikube start
    
    # Enable necessary addons
    log_info "Enabling minikube addons..."
    minikube addons enable ingress
    minikube addons enable metrics-server
    
    log_success "Minikube configured and started successfully!"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_header "DEPLOYING INFRASTRUCTURE"
    
    cd infrastructure
    
    log_info "Deploying full infrastructure stack with Helmfile..."
    log_info "This includes: ArgoCD, Traefik, Linkerd, Prometheus, Grafana, Tempo, Loki, Telepresence"
    
    # Traefik CRDs are now included in the Helm chart
    log_info "Traefik CRDs will be installed with the Helm chart..."
    
    # Install Linkerd via CLI (faster and more reliable than Helm)
    log_info "Installing Linkerd control plane..."
    if command_exists linkerd; then
        log_info "Installing Linkerd CRDs..."
        if ! linkerd install --crds | kubectl apply -f -; then
            log_error "Failed to install Linkerd CRDs"
            cd ..
            exit 1
        fi
        
        log_info "Installing Linkerd control plane..."
        if ! linkerd install --set proxyInit.runAsRoot=true | kubectl apply -f -; then
            log_error "Failed to install Linkerd control plane"
            cd ..
            exit 1
        fi
        
        log_info "Waiting for Linkerd control plane to be ready..."
        if ! linkerd check; then
            log_error "Linkerd control plane health check failed"
            cd ..
            exit 1
        fi
        
        log_info "Installing Linkerd Viz extension..."
        if ! linkerd viz install | kubectl apply -f -; then
            log_error "Failed to install Linkerd Viz extension"
            cd ..
            exit 1
        fi
        
        log_info "Waiting for Linkerd Viz to be ready..."
        if ! linkerd check --proxy; then
            log_error "Linkerd Viz health check failed"
            cd ..
            exit 1
        fi
        
        log_success "Linkerd installed and verified successfully!"
    else
        log_error "Linkerd CLI not found. Please run the setup script again to install missing tools."
        cd ..
        exit 1
    fi
    
    # Use helmfile to deploy remaining services
    log_info "Deploying remaining infrastructure with helmfile..."
    if ! helmfile apply; then
        log_error "Failed to deploy infrastructure with helmfile"
        cd ..
        exit 1
    fi
    
    log_info "Waiting for ArgoCD server to be ready..."
    if ! kubectl wait --for=condition=available --timeout=600s deployment/argo-argocd-server -n argocd; then
        log_error "ArgoCD server failed to become available within timeout"
        cd ..
        exit 1
    fi
    
    cd ..
    
    log_success "Infrastructure deployed successfully!"
}

# Function to get ArgoCD admin password
get_argocd_password() {
    print_header "CONFIGURING ARGOCD"
    
    # Wait for ArgoCD secret to be available
    log_info "Waiting for ArgoCD admin secret..."
    while ! kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; do
        sleep 5
    done
    
    # Get admin password
    local admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    log_success "ArgoCD admin password: $admin_password"
    
    # Start port-forward for ArgoCD access
    log_info "Setting up port-forward for ArgoCD..."
    kubectl port-forward svc/argo-argocd-server -n argocd 8080:80 &
    local port_forward_pid=$!
    sleep 10  # Give port-forward time to establish
    
    # Login to ArgoCD with retries
    log_info "Logging into ArgoCD..."
    local login_attempts=0
    while [ $login_attempts -lt 5 ]; do
        if echo "y" | argocd login localhost:8080 --username admin --password "$admin_password" --insecure >/dev/null 2>&1; then
            log_success "Successfully logged into ArgoCD"
            break
        else
            log_info "ArgoCD not ready yet, waiting 10 seconds... (attempt $((login_attempts + 1))/5)"
            sleep 10
            login_attempts=$((login_attempts + 1))
        fi
    done
    
    if [ $login_attempts -eq 5 ]; then
        log_warn "Could not connect to ArgoCD for token generation, but basic setup is complete"
        log_info "You can manually generate a token later with:"
        echo "  kubectl port-forward svc/argo-argocd-server -n argocd 8080:80 &"
        echo "  argocd login localhost:8080 --username admin --password $admin_password --insecure"
        echo "  argocd account generate-token --account admin"
        
        # Store basic configuration
        cat > argocd-config.env << EOF
ARGOCD_SERVER=http://localhost:8080
ARGOCD_INSECURE=true
ARGOCD_ADMIN_PASSWORD=$admin_password
# Generate token manually: argocd account generate-token --account admin
EOF
        kill $port_forward_pid 2>/dev/null || true
        return
    fi
    
    # Generate API token
    log_info "Generating ArgoCD API token..."
    local api_token=""
    if api_token=$(argocd account generate-token --account admin 2>/dev/null); then
        log_success "ArgoCD API token generated successfully!"
        
        # Store configuration
        cat > argocd-config.env << EOF
ARGOCD_SERVER=http://localhost:8080
ARGOCD_TOKEN=$api_token
ARGOCD_INSECURE=true
ARGOCD_ADMIN_PASSWORD=$admin_password
EOF
        log_success "ArgoCD configuration saved to argocd-config.env"
    else
        log_warn "Could not generate API token, but ArgoCD is running"
        # Store basic configuration
        cat > argocd-config.env << EOF
ARGOCD_SERVER=http://localhost:8080
ARGOCD_INSECURE=true
ARGOCD_ADMIN_PASSWORD=$admin_password
# Generate token manually: argocd account generate-token --account admin
EOF
    fi
    
    # Clean up port-forward
    kill $port_forward_pid 2>/dev/null || true
}

# Function to deploy RaidHelper applications
deploy_applications() {
    print_header "DEPLOYING RAIDHELPER APPLICATIONS"
    
    # Check if manifests-microservices exists
    if [ ! -d "../manifests-microservices" ]; then
        log_warn "manifests-microservices directory not found. Skipping application deployment."
        log_info "You can deploy applications manually after creating the manifests repository."
        return
    fi
    
    log_info "Deploying RaidHelper applications via ArgoCD..."
    kubectl apply -f ../manifests-microservices/applications/production/
    
    log_success "RaidHelper applications deployed!"
}


# Function to display next steps
show_next_steps() {
    print_header "SETUP COMPLETE"
    
    # Get ArgoCD password for display
    local admin_password=""
    if kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; then
        admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "check argocd-config.env")
    else
        admin_password="check argocd-config.env"
    fi
    
    echo
    log_success "🎉 Local development environment is ready!"
    echo
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "  1. Start port-forwards: ./scripts/port-forwards.sh"
    echo "  2. Access ArgoCD: http://localhost:8081 (admin/$admin_password)"
    echo "  3. Access Grafana: http://localhost:3000 (admin/admin123)"
    echo "  4. Connect Telepresence: telepresence connect"
    echo "  5. Intercept a service: telepresence intercept <service-name> --namespace raidhelper-prod --port <local-port>"
    echo
    echo -e "${BLUE}📚 Documentation:${NC}"
    echo "  - Telepresence guide: docs/telepresence.md"
    echo "  - Troubleshooting: docs/troubleshooting.md"
    echo
    echo -e "${BLUE}🔧 Common Commands:${NC}"
    echo "  - make status    # Check cluster status"
    echo "  - make logs      # View logs"
    echo "  - make cleanup   # Clean up resources"
    echo "  - ./scripts/port-forwards.sh --show-only  # Show service URLs"
    echo "  - pkill -f 'kubectl port-forward'  # Stop all port-forwards"
    echo
    if [ -f "argocd-config.env" ]; then
        echo -e "${BLUE}🔑 ArgoCD Configuration:${NC}"
        echo "  Source the configuration: source argocd-config.env"
        echo
    fi
}

# Main function
main() {
    echo -e "${BLUE}🚀 RaidHelper Local Development Environment Setup${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    local os_type=$(detect_os)
    log_info "Detected OS: $os_type"
    
    # Check if user wants to continue
    echo
    read -p "Ready to begin setup? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Setup cancelled by user."
        exit 0
    fi
    
    # Run setup steps
    check_requirements
    configure_minikube
    deploy_infrastructure
    get_argocd_password
    deploy_applications
    show_next_steps
    
    log_success "Setup completed successfully! 🎉"
}

# Handle script interruption
trap 'log_error "Setup interrupted. You can run this script again to retry."; exit 1' INT

# Run main function
main "$@"
