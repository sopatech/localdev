# RaidHelper Local Development Environment Makefile

.PHONY: help setup start stop status logs cleanup port-forwards telepresence-connect telepresence-disconnect deploy-infrastructure deploy-apps update-infrastructure

# Default target
help: ## Show this help message
	@echo "RaidHelper Local Development Environment"
	@echo "========================================"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Setup and Management
setup: ## Run complete setup (minikube, infrastructure, apps)
	@echo "🚀 Running complete environment setup..."
	./setup.sh

start: ## Start the local development environment
	@echo "🟢 Starting local development environment..."
	@$(MAKE) minikube-start
	@$(MAKE) port-forwards

stop: ## Stop the local development environment
	@echo "🔴 Stopping local development environment..."
	@$(MAKE) telepresence-disconnect
	@$(MAKE) port-forwards-stop
	@$(MAKE) minikube-stop

# Minikube Management
minikube-start: ## Start minikube
	@echo "🏃 Starting minikube..."
	@if ! minikube status >/dev/null 2>&1; then \
		minikube start; \
	else \
		echo "✅ Minikube is already running"; \
	fi

minikube-stop: ## Stop minikube
	@echo "⏹️  Stopping minikube..."
	@minikube stop

minikube-status: ## Show minikube status
	@minikube status

minikube-reset: ## Delete and recreate minikube cluster
	@echo "🔄 Resetting minikube cluster..."
	@read -p "This will delete all data. Continue? [y/N]: " confirm && [ "$$confirm" = "y" ]
	@minikube delete
	@minikube start
	@$(MAKE) deploy-infrastructure

# Infrastructure Management
deploy-infrastructure: ## Deploy infrastructure components (ArgoCD, Prometheus, etc.)
	@echo "🏗️  Deploying infrastructure..."
	@cd infrastructure && linkerd install --crds | kubectl apply -f -
	@cd infrastructure && helmfile apply

update-infrastructure: ## Update infrastructure components
	@echo "🔄 Updating infrastructure..."
	@cd infrastructure && helm repo update
	@cd infrastructure && helmfile apply

destroy-infrastructure: ## Destroy all infrastructure
	@echo "💥 Destroying infrastructure..."
	@read -p "This will destroy all infrastructure. Continue? [y/N]: " confirm && [ "$$confirm" = "y" ]
	@cd infrastructure && helmfile destroy

# Application Management
deploy-apps: ## Deploy RaidHelper applications (production)
	@echo "🚀 Deploying RaidHelper applications (production)..."
	@if [ -d "../manifests-microservices" ]; then \
		kubectl apply -f ../manifests-microservices/applications/production/; \
		echo "✅ Production applications deployed"; \
	else \
		echo "⚠️  manifests-microservices not found"; \
	fi

deploy-apps-local: ## Deploy RaidHelper applications (local development)
	@echo "🚀 Deploying RaidHelper applications (local development)..."
	@if [ -d "../manifests-microservices/applications/local" ]; then \
		kubectl apply -f ../manifests-microservices/applications/local/; \
		echo "✅ Local applications deployed"; \
	else \
		echo "⚠️  Local applications directory not found"; \
	fi

sync-apps: ## Sync all ArgoCD applications
	@echo "🔄 Syncing ArgoCD applications..."
	@argocd app sync --all

sync-apps-local: ## Sync local ArgoCD applications
	@echo "🔄 Syncing local ArgoCD applications..."
	@argocd app sync raidhelper-api-local raidhelper-realtime-local raidhelper-web-local

# Port Forwards
port-forwards: ## Start all port forwards
	@echo "🔌 Starting port forwards..."
	@./scripts/port-forwards.sh &

port-forwards-stop: ## Stop all port forwards
	@echo "🔌 Stopping port forwards..."
	@pkill -f "kubectl port-forward" || true

port-forwards-show: ## Show available services
	@./scripts/port-forwards.sh --show-only

# Linkerd
linkerd-check: ## Check linkerd installation and cluster
	@echo "🔗 Checking Linkerd..."
	@linkerd check || true

linkerd-check-proxy: ## Check linkerd data plane
	@echo "🔗 Checking Linkerd data plane..."
	@linkerd check --proxy || true

linkerd-viz: ## Open Linkerd dashboard
	@echo "🌐 Opening Linkerd dashboard..."
	@echo "URL: http://localhost:50750"

linkerd-top: ## Show live traffic (like kubectl top but for requests)
	@linkerd viz top deploy

linkerd-stat: ## Show deployment stats
	@linkerd viz stat deploy

linkerd-inject: ## Inject linkerd proxy into raidhelper namespace
	@echo "💉 Injecting Linkerd into raidhelper-prod namespace..."
	@kubectl get namespace raidhelper-prod -o yaml | linkerd inject - | kubectl apply -f -
	@kubectl rollout restart deployment -n raidhelper-prod

# Telepresence
telepresence-connect: ## Connect telepresence to cluster
	@echo "🔗 Connecting telepresence..."
	@telepresence connect

telepresence-disconnect: ## Disconnect telepresence
	@echo "🔗 Disconnecting telepresence..."
	@telepresence quit || true

telepresence-status: ## Show telepresence status
	@telepresence status

telepresence-list: ## List available services for intercept
	@telepresence list --namespace raidhelper-prod

# Intercept shortcuts
intercept-api: ## Intercept raidhelper-api service
	@echo "🎯 Intercepting API service..."
	@telepresence intercept raidhelper-api --namespace raidhelper-prod --port 8081 --env-file api.env
	@echo "Environment saved to api.env"
	@echo "Start your local API service on port 8081"

intercept-realtime: ## Intercept raidhelper-realtime service
	@echo "🎯 Intercepting Realtime service..."
	@telepresence intercept raidhelper-realtime --namespace raidhelper-prod --port 8082 --env-file realtime.env
	@echo "Environment saved to realtime.env"
	@echo "Start your local Realtime service on port 8082"

intercept-web: ## Intercept raidhelper-web service
	@echo "🎯 Intercepting Web service..."
	@telepresence intercept raidhelper-web --namespace raidhelper-prod --port 3000 --env-file web.env
	@echo "Environment saved to web.env"
	@echo "Start your local Web service on port 3000"

leave-intercepts: ## Leave all intercepts
	@echo "🚪 Leaving all intercepts..."
	@telepresence leave || true

# Status and Monitoring
status: ## Show cluster and service status
	@echo "📊 System Status"
	@echo "==============="
	@echo ""
	@echo "🏃 Minikube:"
	@minikube status || echo "❌ Minikube not running"
	@echo ""
	@echo "🔗 Telepresence:"
	@telepresence status || echo "❌ Telepresence not connected"
	@echo ""
	@echo "🏗️  Infrastructure Pods:"
	@kubectl get pods -n argocd,monitoring,traefik,linkerd --no-headers 2>/dev/null | awk '{print "  " $$1 " (" $$2 ") - " $$3}' || echo "❌ No infrastructure pods found"
	@echo ""
	@echo "🚀 RaidHelper Pods:"
	@kubectl get pods -n raidhelper-prod --no-headers 2>/dev/null | awk '{print "  " $$1 " (" $$2 ") - " $$3}' || echo "❌ No RaidHelper pods found"
	@echo ""
	@echo "🌐 Port Forwards:"
	@pgrep -f "kubectl port-forward" >/dev/null && echo "  ✅ Port forwards running" || echo "  ❌ No port forwards running"

logs: ## Show logs for core services
	@echo "📋 Recent logs from core services..."
	@echo "ArgoCD Server:"
	@kubectl logs deployment/argo-argocd-server -n argocd --tail=10 || true
	@echo ""
	@echo "Prometheus:"
	@kubectl logs deployment/prometheus-server -n monitoring --tail=10 || true

logs-api: ## Show RaidHelper API logs
	@kubectl logs -l app=raidhelper-api -n raidhelper-prod --tail=50 -f

logs-realtime: ## Show RaidHelper Realtime logs
	@kubectl logs -l app=raidhelper-realtime -n raidhelper-prod --tail=50 -f

logs-web: ## Show RaidHelper Web logs
	@kubectl logs -l app=raidhelper-web -n raidhelper-prod --tail=50 -f

# Development helpers
dev-api: ## Start API development (with intercept)
	@echo "🔧 Starting API development..."
	@$(MAKE) intercept-api
	@echo "Now run: cd ../raidhelper/cmd/api && export \$$(cat api.env | xargs) && go run main.go"

dev-realtime: ## Start Realtime development (with intercept)
	@echo "🔧 Starting Realtime development..."
	@$(MAKE) intercept-realtime
	@echo "Now run: cd ../raidhelper/cmd/realtime && export \$$(cat realtime.env | xargs) && go run main.go"

dev-web: ## Start Web development (with intercept)
	@echo "🔧 Starting Web development..."
	@$(MAKE) intercept-web
	@echo "Now run: cd ../raidhelper-web && export \$$(cat web.env | xargs) && npm start"

# Cleanup
cleanup: ## Clean up resources and reset environment
	@echo "🧹 Cleaning up..."
	@$(MAKE) leave-intercepts
	@$(MAKE) port-forwards-stop
	@$(MAKE) telepresence-disconnect
	@echo "✅ Cleanup complete"

cleanup-all: ## Complete cleanup including minikube
	@echo "🧹 Complete cleanup..."
	@read -p "This will delete minikube and all data. Continue? [y/N]: " confirm && [ "$$confirm" = "y" ]
	@$(MAKE) cleanup
	@minikube delete
	@docker system prune -f
	@echo "✅ Complete cleanup done"

# Utilities
shell-api: ## Get shell in API pod
	@kubectl exec -it $$(kubectl get pod -l app=raidhelper-api -n raidhelper-prod -o jsonpath='{.items[0].metadata.name}') -n raidhelper-prod -- /bin/sh

shell-realtime: ## Get shell in Realtime pod
	@kubectl exec -it $$(kubectl get pod -l app=raidhelper-realtime -n raidhelper-prod -o jsonpath='{.items[0].metadata.name}') -n raidhelper-prod -- /bin/sh

debug-dns: ## Test DNS resolution in cluster
	@kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

debug-network: ## Test network connectivity
	@kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash

# Quick access to services
open-argocd: ## Open ArgoCD in browser
	@echo "🌐 Opening ArgoCD..."
	@echo "URL: http://localhost:8080"
	@echo "Username: admin"
	@echo "Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo 'run setup.sh first')"

open-grafana: ## Open Grafana in browser
	@echo "🌐 Opening Grafana..."
	@echo "URL: http://localhost:3000"
	@echo "Username: admin"
	@echo "Password: admin123"

open-prometheus: ## Open Prometheus in browser
	@echo "🌐 Opening Prometheus..."
	@echo "URL: http://localhost:9090"

# Information
info: ## Show environment information
	@echo "ℹ️  Environment Information"
	@echo "=========================="
	@echo "OS: $$(uname -s)"
	@echo "Docker: $$(docker version --format '{{.Client.Version}}' 2>/dev/null || echo 'Not available')"
	@echo "Minikube: $$(minikube version --short 2>/dev/null || echo 'Not available')"
	@echo "kubectl: $$(kubectl version --client --short 2>/dev/null || echo 'Not available')"
	@echo "Helm: $$(helm version --short 2>/dev/null || echo 'Not available')"
	@echo "Helmfile: $$(helmfile version 2>/dev/null | head -1 || echo 'Not available')"
	@echo "ArgoCD: $$(argocd version --client --short 2>/dev/null || echo 'Not available')"
	@echo "Linkerd: $$(linkerd version --client --short 2>/dev/null || echo 'Not available')"
	@echo "Telepresence: $$(telepresence version 2>/dev/null || echo 'Not available')"
	@echo "Go: $$(go version 2>/dev/null | awk '{print $$3}' || echo 'Not available')"
	@echo ""
	@echo "Documentation:"
	@echo "  - Setup: README.md"
	@echo "  - Telepresence: docs/telepresence.md"
	@echo "  - Troubleshooting: docs/troubleshooting.md"
