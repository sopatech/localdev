# RaidHelper Local Development Environment Makefile

.PHONY: help setup delete telepresence-connect telepresence-disconnect port-forwards port-forwards-stop

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
	@./scripts/port-forwards.sh &

port-forwards-stop: ## Stop all port forwards
	@echo "🔌 Stopping port forwards..."
	@pkill -f "kubectl port-forward" || true