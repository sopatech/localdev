# Quick Start Guide

## 🚀 Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/sopatech/localdev.git
   cd localdev
   ```

2. **Run setup**:
   ```bash
   ./setup.sh
   ```

3. **Start development**:
   ```bash
   make start
   ```

## 🔗 Related Repositories

- **Main Application**: `sopatech/raidhelper` (your main application code)
- **Manifests**: `sopatech/manifests-microservices` (Kubernetes manifests)
- **Local Development**: `sopatech/localdev` (this repository)

## 📋 Prerequisites

Make sure you have these installed:
- Docker Desktop
- minikube
- kubectl
- helmfile
- helm
- argocd CLI
- telepresence
- go
- curl

## 🎯 Common Commands

```bash
# Start everything
make start

# Deploy local applications
make deploy-apps-local

# Check status
make status

# Open ArgoCD
make open-argocd

# Stop everything
make stop
```

## 🔧 Development Workflow

1. **Start local environment**: `make start`
2. **Deploy applications**: `make deploy-apps-local`
3. **Connect Telepresence**: `telepresence connect`
4. **Intercept service**: `telepresence intercept raidhelper-api --namespace raidhelper-local --port 8081`
5. **Develop locally**: Your code runs locally but connects to cluster services

## 📚 Full Documentation

See [README.md](README.md) for complete documentation.
