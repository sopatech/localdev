# RaidHelper Local Development Environment Makefile

.PHONY: help setup delete setup-private-repos telepresence-connect telepresence-disconnect port-forwards port-forwards-stop tunnel tunnel-restart tunnel-stop tunnel-status tunnel-apply cert-create cert-cleanup cert-status

# Default target
help: ## Show this help message
	@echo "RaidHelper Local Development Environment"
	@echo "========================================"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Setup
setup: ## Run complete setup (minikube, infrastructure, apps)
	@echo "🚀 Running complete environment setup..."
	./setup.sh

delete: ## Delete minikube cluster
	@echo "💥 Deleting minikube cluster..."
	@minikube delete

# Telepresence
telepresence-connect: ## Connect telepresence to cluster
	@echo "🔗 Connecting Telepresence..."
	@telepresence connect

telepresence-disconnect: ## Disconnect telepresence
	@echo "🔌 Disconnecting Telepresence..."
	@telepresence quit

# Port Forwards
port-forwards: ## Start all port forwards
	@echo "🔌 Starting port forwards..."
	@./scripts/port-forwards.sh

port-forwards-stop: ## Stop all port forwards
	@echo "🔌 Stopping port forwards..."
	@pkill -f "kubectl port-forward" || true

# Cloudflare Tunnel (Ephemeral)
tunnel: ## Start ephemeral tunnel and apply configuration
	@echo "🚇 Starting ephemeral tunnel..."
	@./scripts/tunnel.sh start

tunnel-restart: ## Restart ephemeral tunnel with new URL
	@echo "🔄 Restarting ephemeral tunnel..."
	@./scripts/tunnel.sh restart

tunnel-stop: ## Stop ephemeral tunnel
	@echo "🛑 Stopping ephemeral tunnel..."
	@./scripts/tunnel.sh stop

tunnel-status: ## Show tunnel status
	@echo "📊 Checking tunnel status..."
	@./scripts/tunnel.sh status

tunnel-apply: ## Apply tunnel config to running deployments (survives ArgoCD syncs)
	@echo "🔧 Applying tunnel configuration to deployments..."
	@./scripts/tunnel.sh apply

# Local HTTPS Certificate
cert-create: ## Create and install local HTTPS certificate for raidhelper.local
	@echo "🏠 Creating local HTTPS certificate..."
	@./scripts/create-local-cert.sh create

cert-cleanup: ## Remove local HTTPS certificate from cluster and local machine
	@echo "🧹 Cleaning up local HTTPS certificate..."
	@./scripts/create-local-cert.sh cleanup

cert-status: ## Show local certificate status
	@echo "📊 Checking local certificate status..."
	@./scripts/create-local-cert.sh status