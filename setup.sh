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

# Function to gather GitHub credentials
gather_github_credentials() {
    print_header "GITHUB CREDENTIALS SETUP"
    
    echo "🔐 GitHub Personal Access Token (PAT) Required"
    echo "=============================================="
    echo ""
    echo "Your GitHub PAT will be used for:"
    echo "  • ArgoCD to access private repositories (manifests-microservices)"
    echo "  • Kubernetes to pull private container images from GitHub Container Registry (ghcr.io)"
    echo ""
    echo "Required GitHub PAT permissions:"
    echo "  ✅ repo (Full control of private repositories)"
    echo "  ✅ read:packages (Download packages from GitHub Package Registry)"
    echo ""
    echo "To create a PAT:"
    echo "  1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)"
    echo "  2. Click 'Generate new token (classic)'"
    echo "  3. Select the permissions listed above"
    echo "  4. Copy the generated token"
    echo ""
    
    read -p "GitHub username: " GITHUB_USERNAME
    read -s -p "GitHub Personal Access Token: " GITHUB_TOKEN
    echo
    
    # Validate credentials by testing GitHub API
    log_info "Validating GitHub credentials..."
    if ! curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep -q "\"login\""; then
        log_error "Invalid GitHub credentials. Please check your username and token."
        return 1
    fi
    
    log_success "GitHub credentials validated successfully!"
}

# Function to setup private repositories
setup_private_repositories() {
    print_header "SETTING UP PRIVATE REPOSITORIES"
    
    log_info "Setting up private repository access for ArgoCD..."
    
    # Check if ArgoCD is running
    if ! kubectl get pods -n argocd | grep -q "argo-argocd-server.*Running"; then
        log_error "ArgoCD is not running. Cannot setup private repositories."
        return 1
    fi
    
    # Get ArgoCD admin password
    log_info "Getting ArgoCD admin password..."
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    
    # Start port-forward for ArgoCD
    log_info "Starting port-forward for ArgoCD..."
    pkill -f "kubectl port-forward.*argo-argocd-server" || true
    kubectl port-forward svc/argo-argocd-server -n argocd 8080:80 >/dev/null 2>&1 &
    sleep 5
    
    # Login to ArgoCD
    log_info "Logging into ArgoCD..."
    if ! echo "y" | argocd login localhost:8080 --username admin --password "$ARGOCD_PASSWORD" --insecure; then
        log_warn "ArgoCD CLI login failed. This might be due to version compatibility."
        log_info "You can manually add the repository later using the ArgoCD UI at http://localhost:8080"
        log_info "Or try updating ArgoCD CLI: brew upgrade argocd"
        return 1
    fi
    
    # Add private repositories
    log_info "Adding private repositories..."
    
    # Check if manifests-microservices repository exists
    if ! argocd repo list | grep -q "manifests-microservices"; then
        log_info "Adding manifests-microservices repository..."
        echo "Using GitHub credentials from previous step..."
        
        if ! argocd repo add https://github.com/sopatech/manifests-microservices \
            --username "$GITHUB_USERNAME" \
            --password "$GITHUB_TOKEN" \
            --type git; then
            log_error "Failed to add manifests-microservices repository"
            return 1
        fi
        
        log_success "Private repository added successfully!"
    else
        log_info "manifests-microservices repository already exists"
    fi
}

# Function to setup Docker registry secrets
setup_registry_secrets() {
    print_header "SETTING UP DOCKER REGISTRY SECRETS"
    
    log_info "Setting up Docker registry secrets for private container images..."
    
    # Create namespaces if they don't exist
    log_info "Creating namespaces..."
    kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace jobs --dry-run=client -o yaml | kubectl apply -f -
    
    # Function to create registry secret
    create_registry_secret() {
        local namespace=$1
        local secret_name="regcred"
        
        log_info "Setting up registry secret in namespace: $namespace"
        
        # Check if secret already exists
        if kubectl get secret "$secret_name" -n "$namespace" &> /dev/null; then
            log_info "Secret $secret_name already exists in namespace $namespace"
            return 0
        fi
        
        # Use GitHub credentials for GHCR
        log_info "Using GitHub credentials for GitHub Container Registry (ghcr.io)"
        local registry_url="ghcr.io"
        local username="$GITHUB_USERNAME"
        local password="$GITHUB_TOKEN"
        
        # Create the secret
        if ! kubectl create secret docker-registry "$secret_name" \
            --docker-server="$registry_url" \
            --docker-username="$username" \
            --docker-password="$password" \
            --docker-email="$username@example.com" \
            -n "$namespace"; then
            log_error "Failed to create registry secret in namespace: $namespace"
            return 1
        fi
        
        log_success "Registry secret created in namespace: $namespace"
    }
    
    # Create secrets for both namespaces
    create_registry_secret "apps"
    create_registry_secret "jobs"
    
    log_success "Docker registry secrets setup complete!"
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

# Function to setup local domains
setup_local_domains() {
    print_header "LOCAL DOMAINS SETUP"
    
    # Check if user wants to setup local domains
    echo "🌐 Local Domain Setup"
    echo "===================="
    echo ""
    echo "This will add local domains to your /etc/hosts file for easier development."
    echo "Example: raidhelper.local, api.raidhelper.local, ws.raidhelper.local"
    echo ""
    
    read -p "Setup local domains? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Skipping local domains setup."
        return 0
    fi
    
    # Load configuration from file if it exists
    if [ -f "config/local-domains.env" ]; then
        log_info "Loading local domains configuration from config/local-domains.env"
        source config/local-domains.env
    fi
    
    # Set project-specific configuration
    local project_name="${PROJECT_NAME:-raidhelper}"
    local local_domain="${LOCAL_DOMAIN:-local}"
    local services="${SERVICES:-web:80,api:8081,ws:8082}"
    
    log_info "Setting up local domains for project: $project_name"
    log_info "Domain suffix: $local_domain"
    log_info "Services: $services"
    
    # Run the local domains setup script
    if [ -f "scripts/setup-local-domains.sh" ]; then
        PROJECT_NAME="$project_name" LOCAL_DOMAIN="$local_domain" SERVICES="$services" \
            ./scripts/setup-local-domains.sh add
        log_success "Local domains setup complete!"
    else
        log_warn "Local domains setup script not found. Skipping."
    fi
}

# Function to initialize DynamoDB table
init_dynamodb() {
    print_header "INITIALIZING DYNAMODB TABLE"
    
    # Check if init script exists
    if [ ! -f "scripts/init-dynamodb.sh" ]; then
        log_warn "DynamoDB initialization script not found. Skipping."
        return
    fi
    
    # Check if LocalStack is running
    if ! kubectl get pods -n storage | grep -q "localstack.*Running"; then
        log_warn "LocalStack is not running. Skipping DynamoDB initialization."
        log_info "You can run './scripts/init-dynamodb.sh' manually after LocalStack is ready."
        return
    fi
    
    # Check if port forward is running for LocalStack
    if ! lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warn "LocalStack port forward (port 8000) is not running."
        log_info "Starting port-forward for LocalStack..."
        
        # Start targeted port-forward for LocalStack only
        pkill -f "kubectl port-forward.*localstack" || true
        kubectl port-forward svc/localstack -n storage 8000:4566 >/dev/null 2>&1 &
        local port_forward_pid=$!
        
        # Wait for port forward to be ready
        log_info "Waiting for port forward to be ready..."
        local max_attempts=30
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
                log_success "Port forward is ready!"
                break
            fi
            
            log_info "Attempt $attempt/$max_attempts: Waiting for port forward..."
            sleep 2
            ((attempt++))
        done
        
        if [ $attempt -gt $max_attempts ]; then
            log_error "Port forward failed to start. Skipping DynamoDB initialization."
            kill $port_forward_pid 2>/dev/null || true
            return
        fi
    fi
    
    log_info "Initializing DynamoDB table in LocalStack..."
    
    # Make script executable
    chmod +x scripts/init-dynamodb.sh
    
    # Run the initialization script
    if ./scripts/init-dynamodb.sh; then
        log_success "DynamoDB table initialized successfully!"
    else
        log_warn "DynamoDB table initialization failed or table already exists."
        log_info "You can run './scripts/init-dynamodb.sh' manually to retry."
    fi
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
    kubectl apply -f ../manifests-microservices/applications/local/
    
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
    echo "  1. Start port-forwards: make port-forwards"
    echo "  2. Access ArgoCD: http://localhost:8081 (admin/$admin_password)"
    echo "  3. Access Grafana: http://localhost:3000 (admin/admin123)"
    echo "  4. Access LocalStack: http://localhost:4566 (DynamoDB Local)"
    echo "  5. Access NATS: http://localhost:4222 (Messaging)"
    echo "  6. Connect Telepresence: make telepresence-connect"
    echo
    echo -e "${BLUE}🌐 Local Domains (if configured):${NC}"
    echo "  - Main App: http://raidhelper.local:8086"
    echo "  - API: http://api.raidhelper.local:8086"
    echo "  - WebSocket: ws://ws.raidhelper.local:8086"
    echo
    echo -e "${BLUE}📚 Documentation:${NC}"
    echo "  - Local domains: docs/local-domains.md"
    echo "  - Telepresence guide: docs/telepresence.md"
    echo "  - Troubleshooting: docs/troubleshooting.md"
    echo
    echo -e "${BLUE}🔧 Common Commands:${NC}"
    echo "  - make port-forwards        # Start all port-forwards"
    echo "  - make port-forwards-stop   # Stop all port-forwards"
    echo "  - make telepresence-connect # Connect Telepresence"
    echo "  - make telepresence-disconnect # Disconnect Telepresence"
    echo "  - make delete               # Delete minikube cluster"
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
    setup_local_domains
    get_argocd_password
    gather_github_credentials
    setup_private_repositories
    setup_registry_secrets
    init_dynamodb
    deploy_applications
    show_next_steps
    
    log_success "Setup completed successfully! 🎉"
}

# Handle script interruption
trap 'log_error "Setup interrupted. You can run this script again to retry."; exit 1' INT

# Run main function
main "$@"
