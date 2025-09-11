# Local Development Environment

This repository contains the complete local development environment setup for the RaidHelper microservices using minikube, ArgoCD, Telepresence 2, and other modern Kubernetes tools.

## 🏗️ Architecture

The local development environment includes:

- **minikube**: Local Kubernetes cluster
- **ArgoCD**: GitOps deployment management
- **Traefik**: Edge router for HTTP traffic
- **Linkerd**: Service mesh for gRPC traffic
- **Prometheus + Grafana**: Metrics and monitoring
- **Tempo**: Distributed tracing
- **Loki**: Log aggregation
- **LocalStack**: Local DynamoDB for data storage
- **NATS**: Messaging system
- **Telepresence 2**: Local development with cluster integration
- **cert-manager**: Certificate management

## 🚀 Quick Start

### Prerequisites

- Docker Desktop
- minikube
- kubectl
- helmfile
- helm
- argocd CLI
- telepresence
- go
- curl

### System Requirements

- **Memory**: 8GB RAM (minikube uses 8GB)
- **CPU**: 6 cores (minikube uses 6 CPUs)
- **Disk**: 50GB free space
- **Docker**: At least 10GB memory allocated to Docker Desktop (8GB for minikube + 2GB overhead)

### Resource Usage

The infrastructure components are optimized for local development:

- **Prometheus**: 1Gi memory limit (increased from 256Mi to prevent OOMKilled)
- **LocalStack**: 256Mi memory limit (DynamoDB only)
- **NATS**: Lightweight messaging system
- **Other services**: Minimal resource usage for local development

### Setup

1. **Clone this repository**:
   ```bash
   git clone https://github.com/sopatech/localdev.git
   cd localdev
   ```

2. **Run the setup script**:
   ```bash
   ./setup.sh
   ```
   
   The setup script will:
   - Configure and start minikube
   - Deploy all infrastructure (ArgoCD, Prometheus, LocalStack, etc.)
   - Set up private repository access for ArgoCD
   - Configure Docker registry secrets for private container images
   - Deploy your applications

3. **Start port-forwards**:
   ```bash
   ./scripts/port-forwards.sh
   ```

4. **Initialize DynamoDB table** (optional):
   ```bash
   ./scripts/init-dynamodb.sh
   ```

5. **Access the services**:
   - ArgoCD: http://localhost:8081 (admin/admin123)
   - Prometheus: http://localhost:9091
   - Grafana: http://localhost:3000 (admin/admin123)
   - Tempo: http://localhost:3200
   - Loki: http://localhost:3100
   - Traefik: http://localhost:8086 (main entry point)
   - Traefik UI: http://localhost:8085
   - LocalStack: http://localhost:8000 (DynamoDB)
   - NATS: nats://localhost:4222
   - Linkerd: http://localhost:50750

## 🌐 Local Domain Configuration

### Setting Up Local Domains

1. **Configure local domains** (optional but recommended):
   ```bash
   ./scripts/setup-local-domains.sh add
   ```

2. **Access services via domains** (requires port 8086):
   - **Main App**: http://raidhelper.local:8086
   - **API**: http://api.raidhelper.local:8086  
   - **WebSocket**: ws://ws.raidhelper.local:8086

### Important: Port Requirements

**Local domains require port 8086** because:
- All traffic routes through Traefik on port 8086
- Traefik uses the Host header to route to the correct service
- The `/etc/hosts` file only maps domains to IP addresses (no ports)

**Alternative: Direct Port Access**
If you prefer not to use domains, you can access services directly:
- **API**: http://localhost:8082 (direct port forward)
- **WebSocket**: ws://localhost:8083 (direct port forward)
- **Web**: http://localhost:8084 (direct port forward)

## 🗄️ DynamoDB Setup

### LocalStack DynamoDB

LocalStack provides a local DynamoDB instance for development:

1. **Access LocalStack**: http://localhost:8000
2. **Initialize RaidHelper table**:
   ```bash
   ./scripts/init-dynamodb.sh
   ```

### Table Structure

The script creates a `raidhelper` table with:
- **Primary Key**: PK (Hash) + SK (Range)
- **Local Secondary Indexes**: LSI1-LSI5
- **Capacity**: 10 read/write units each

### AWS CLI Configuration

For LocalStack, use these settings:
```bash
export AWS_ENDPOINT_URL=http://localhost:8000
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
```

## 🔧 Development Workflow

### Using Telepresence for Local Development

1. **Connect Telepresence**:
   ```bash
   telepresence connect
   ```

2. **Intercept any service**:
   ```bash
   telepresence intercept <service-name> --namespace raidhelper-local --port <local-port>
   # Example: telepresence intercept raidhelper-api --namespace raidhelper-local --port 8081
   ```

3. **Start your local service**:
   ```bash
   # In your service directory
   go run ./cmd/api
   ```

### Testing RaidHelper Services

1. **Access services locally**:
   ```bash
   curl http://raidhelper-api-service.raidhelper-local.svc.cluster.local:8081/health
   curl http://raidhelper-realtime-service.raidhelper-local.svc.cluster.local:8082/health
   curl http://raidhelper-web-service.raidhelper-local.svc.cluster.local/
   ```

2. **Test with local intercepts**:
   ```bash
   curl -H "Host: raidhelper-api" http://localhost:8081/health
   ```

### Using LocalStack for DynamoDB

LocalStack provides local DynamoDB for development:

1. **DynamoDB**:
   ```bash
   # Using AWS CLI with LocalStack endpoint
   aws dynamodb list-tables --endpoint-url http://localhost:4566
   
   # Create a table
   aws dynamodb create-table \
     --table-name test-table \
     --attribute-definitions AttributeName=id,AttributeType=S \
     --key-schema AttributeName=id,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --endpoint-url http://localhost:4566
   ```

2. **Configure your application**:
   ```bash
   export AWS_ENDPOINT_URL=http://localhost:4566
   export AWS_DEFAULT_REGION=us-east-1
   export AWS_ACCESS_KEY_ID=test
   export AWS_SECRET_ACCESS_KEY=test
   ```

### ArgoCD Application Management

ArgoCD manages applications from the `manifests-microservices` repository:

- **Local environment**: `applications/local/`
- **Production environment**: `applications/production/`
- **All RaidHelper services**: Automatically deployed and managed
- **Environment separation**: Local uses LocalStack, Production uses real AWS

## 📁 Directory Structure

```
localdev/
├── setup.sh                    # Main setup script
├── Makefile                     # Common operations
├── infrastructure/             # Infrastructure components
│   ├── helmfile.yaml          # Helmfile configuration
│   ├── argocd-values.yaml     # ArgoCD values
│   ├── traefik-values.yaml    # Traefik values
│   ├── prometheus-values.yaml # Prometheus values
│   ├── localstack-values.yaml # LocalStack values
│   ├── nats-values.yaml       # NATS values
│   ├── nats-surveyor-values.yaml # NATS Surveyor values
│   ├── tempo-values.yaml      # Tempo values
│   ├── loki-values-simple.yaml # Loki values
│   └── telepresence-values.yaml # Telepresence values
├── scripts/                    # Helper scripts
│   └── port-forwards.sh       # Port-forward script
└── docs/                       # Documentation
    ├── README.md              # This file
    ├── telepresence.md        # Telepresence guide
    └── troubleshooting.md     # Troubleshooting guide
```

## ☁️ DynamoDB (LocalStack)

LocalStack provides local DynamoDB for development and testing:

### Configuration

LocalStack is configured to run only DynamoDB for optimal resource usage:

```yaml
# localstack-values.yaml
startServices: "dynamodb"
resources:
  requests:
    cpu: 50m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

### Usage Examples

```bash
# List DynamoDB tables
aws dynamodb list-tables --endpoint-url http://localhost:4566

# Create a table
aws dynamodb create-table \
  --table-name users \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --endpoint-url http://localhost:4566

# Put an item
aws dynamodb put-item \
  --table-name users \
  --item '{"id":{"S":"123"},"name":{"S":"John Doe"}}' \
  --endpoint-url http://localhost:4566
```

## 🔍 Observability Stack

### Metrics (Prometheus)

- **RaidHelper API**: `http://localhost:9090/targets`
- **RaidHelper Realtime**: `http://localhost:9090/targets`
- **RaidHelper Web**: `http://localhost:9090/targets`
- **Traefik**: `http://localhost:9090/targets`
- **Linkerd**: `http://localhost:9090/targets`
- **NATS**: `http://localhost:9090/targets`
- **LocalStack**: `http://localhost:9090/targets`
- **Tempo**: `http://localhost:9090/targets`
- **Loki**: `http://localhost:9090/targets`

### Logs (Loki)

- **Centralized logging**: `http://localhost:3100`
- **Log aggregation** from all services
- **Integrated with Grafana** for log visualization

### Traces (Tempo)

- **Distributed tracing**: `http://localhost:3200`
- **Trace storage** for all services
- **Integrated with Grafana** for trace visualization

### Visualization (Grafana)

- **Unified observability**: `http://localhost:3000` (admin/admin123)
- **Pre-configured dashboards**:
  - Linkerd service mesh
  - Traefik edge router
  - ArgoCD GitOps
  - Tempo distributed tracing
  - Loki log aggregation
- **Connected datasources**:
  - Prometheus (metrics)
  - Loki (logs)
  - Tempo (traces)
- **Correlation features**:
  - Traces to logs
  - Traces to metrics
  - Service map visualization

## 🚨 Troubleshooting

### Common Issues

1. **Telepresence connection fails**:
   ```bash
   telepresence quit
   telepresence connect
   ```

2. **ArgoCD sync issues**:
   ```bash
   kubectl get applications -n argocd
   kubectl describe application <app-name> -n argocd
   ```

3. **Port-forward conflicts**:
   ```bash
   pkill -f "kubectl port-forward"
   ./scripts/port-forwards.sh
   ```

4. **Prometheus OOMKilled**:
   ```bash
   # Check Prometheus memory usage
   kubectl top pod -n monitoring
   # Prometheus is configured with 1Gi memory limit
   ```

5. **LocalStack connection issues**:
   ```bash
   # Check LocalStack status
   kubectl get pods -n storage
   curl http://localhost:4566/_localstack/health
   ```

### Logs

```bash
# ArgoCD logs
kubectl logs -f deployment/argo-argocd-server -n argocd

# Traefik logs
kubectl logs -f deployment/traefik -n traefik

# Prometheus logs
kubectl logs -f deployment/prometheus-server -n monitoring

# LocalStack logs
kubectl logs -f deployment/localstack -n storage

# NATS logs
kubectl logs -f deployment/nats -n nats

# Linkerd logs
kubectl logs -f deployment/linkerd-controller -n linkerd
```

## 🔄 Updates

### Updating Infrastructure

```bash
cd infrastructure
helmfile apply
```

### Updating Applications

Applications are managed by ArgoCD from the `manifests-microservices` repository. To update:

```bash
# Deploy local applications
make deploy-apps-local

# Sync applications
make sync-apps-local

# Or manually sync in ArgoCD UI: http://localhost:8080
```

## 🧹 Cleanup

### Stop All Services

```bash
# Stop port-forwards
pkill -f "kubectl port-forward"

# Disconnect Telepresence
telepresence quit

# Stop minikube
minikube stop
```

### Complete Cleanup

```bash
# Delete minikube cluster
minikube delete

# Remove Docker images
docker system prune -a
```

## 📚 Additional Resources

- [Telepresence Documentation](https://www.telepresence.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Linkerd Documentation](https://linkerd.io/docs/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Prometheus Documentation](https://prometheus.io/docs/)

## 🤝 Contributing

1. Make changes to the configuration files
2. Test with `./setup.sh`
3. Update documentation as needed
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License.