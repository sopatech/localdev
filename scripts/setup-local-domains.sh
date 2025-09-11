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

# Configuration
LOCAL_DOMAIN="${LOCAL_DOMAIN:-local}"
PROJECT_NAME="${PROJECT_NAME:-raidhelper}"
SERVICES="${SERVICES:-}"

# Default services if none provided
if [ -z "$SERVICES" ]; then
    SERVICES="web:8086,api:8086,ws:8086"
fi

# Parse services
parse_services() {
    local services_str="$1"
    local services=()
    
    IFS=',' read -ra SERVICE_ARRAY <<< "$services_str"
    for service in "${SERVICE_ARRAY[@]}"; do
        IFS=':' read -ra PARTS <<< "$service"
        local name="${PARTS[0]}"
        local port="${PARTS[1]}"
        services+=("$name:$port")
    done
    
    printf '%s\n' "${services[@]}"
}

# Add domain to /etc/hosts
add_to_hosts() {
    local domain="$1"
    local ip="${2:-127.0.0.1}"
    
    if grep -q "$domain" /etc/hosts; then
        log_info "Domain $domain already exists in /etc/hosts"
    else
        log_info "Adding $domain to /etc/hosts"
        echo "$ip $domain" | sudo tee -a /etc/hosts > /dev/null
        log_success "Added $domain to /etc/hosts"
    fi
}

# Remove domain from /etc/hosts
remove_from_hosts() {
    local domain="$1"
    
    if grep -q "$domain" /etc/hosts; then
        log_info "Removing $domain from /etc/hosts"
        sudo sed -i.bak "/$domain/d" /etc/hosts
        log_success "Removed $domain from /etc/hosts"
    else
        log_info "Domain $domain not found in /etc/hosts"
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  add     Add local domains to /etc/hosts"
    echo "  remove  Remove local domains from /etc/hosts"
    echo "  show    Show current configuration"
    echo ""
    echo "Environment Variables:"
    echo "  LOCAL_DOMAIN    Local domain suffix (default: local)"
    echo "  PROJECT_NAME    Project name (default: raidhelper)"
    echo "  SERVICES        Comma-separated list of services (default: web:8086,api:8086,ws:8086)"
    echo ""
    echo "Examples:"
    echo "  # Basic usage (RaidHelper defaults)"
    echo "  $0 add"
    echo ""
    echo "  # Custom project"
    echo "  PROJECT_NAME=myapp LOCAL_DOMAIN=dev $0 add"
    echo ""
    echo "  # Custom services"
    echo "  SERVICES='frontend:3000,backend:8080,db:5432' $0 add"
    echo ""
    echo "  # Remove domains"
    echo "  $0 remove"
}

# Main function
main() {
    local command="${1:-show}"
    
    case "$command" in
        "add")
            log_info "Setting up local domains for project: $PROJECT_NAME"
            log_info "Domain suffix: $LOCAL_DOMAIN"
            log_info "Services: $SERVICES"
            echo ""
            
            # Add main domain
            add_to_hosts "$PROJECT_NAME.$LOCAL_DOMAIN"
            
            # Add service domains
            while IFS= read -r service; do
                IFS=':' read -ra PARTS <<< "$service"
                local name="${PARTS[0]}"
                local port="${PARTS[1]}"
                local domain="$name.$PROJECT_NAME.$LOCAL_DOMAIN"
                
                add_to_hosts "$domain"
            done < <(parse_services "$SERVICES")
            
            echo ""
            log_success "Local domains setup complete!"
            echo ""
            log_info "You can now access:"
            echo "  Main app: http://$PROJECT_NAME.$LOCAL_DOMAIN"
            while IFS= read -r service; do
                IFS=':' read -ra PARTS <<< "$service"
                local name="${PARTS[0]}"
                local port="${PARTS[1]}"
                local domain="$name.$PROJECT_NAME.$LOCAL_DOMAIN"
                echo "  $name: http://$domain"
            done < <(parse_services "$SERVICES")
            ;;
            
        "remove")
            log_info "Removing local domains for project: $PROJECT_NAME"
            
            # Remove main domain
            remove_from_hosts "$PROJECT_NAME.$LOCAL_DOMAIN"
            
            # Remove service domains
            while IFS= read -r service; do
                IFS=':' read -ra PARTS <<< "$service"
                local name="${PARTS[0]}"
                local port="${PARTS[1]}"
                local domain="$name.$PROJECT_NAME.$LOCAL_DOMAIN"
                
                remove_from_hosts "$domain"
            done < <(parse_services "$SERVICES")
            
            log_success "Local domains removed!"
            ;;
            
        "show")
            echo "Current configuration:"
            echo "  Project: $PROJECT_NAME"
            echo "  Domain: $LOCAL_DOMAIN"
            echo "  Services: $SERVICES"
            echo ""
            echo "Domains that would be created:"
            echo "  Main: $PROJECT_NAME.$LOCAL_DOMAIN"
            while IFS= read -r service; do
                IFS=':' read -ra PARTS <<< "$service"
                local name="${PARTS[0]}"
                local port="${PARTS[1]}"
                local domain="$name.$PROJECT_NAME.$LOCAL_DOMAIN"
                echo "  $name: $domain"
            done < <(parse_services "$SERVICES")
            ;;
            
        "help"|"-h"|"--help")
            show_usage
            ;;
            
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
