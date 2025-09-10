# Telepresence Guide

This guide explains how to use Telepresence for local development with the RaidHelper microservices.

## What is Telepresence?

Telepresence is a tool that allows you to run a local service as if it were part of your Kubernetes cluster. This enables you to:

- Test your local code against real cluster services
- Debug services with production-like dependencies
- Develop faster without container rebuilds
- Access cluster-internal services from your local machine

## Prerequisites

- Telepresence installed (see main README for installation)
- Local development environment running (`./setup.sh`)
- kubectl configured to access your minikube cluster

## Basic Usage

### 1. Connect to the Cluster

First, establish a connection to the cluster:

```bash
telepresence connect
```

You should see output like:
```
Connected to context minikube (https://127.0.0.1:32768)
```

### 2. Verify Connection

Check that you can access cluster services:

```bash
curl http://raidhelper-api-service.raidhelper-prod.svc.cluster.local:8081/health
```

### 3. List Available Services

See what services you can intercept:

```bash
telepresence list --namespace raidhelper-prod
```

### 4. Intercept a Service

Intercept traffic to a service and redirect it to your local development server:

```bash
# Example: Intercept the API service
telepresence intercept raidhelper-api \
    --namespace raidhelper-prod \
    --port 8081 \
    --env-file api.env
```

This command:
- Intercepts traffic to `raidhelper-api` in the `raidhelper-prod` namespace
- Redirects it to your local port 8081
- Saves environment variables to `api.env` file

### 5. Start Your Local Service

Now start your local development server on the intercepted port:

```bash
# In your raidhelper/cmd/api directory
export $(cat api.env | xargs)
go run main.go
```

## Advanced Usage

### Conditional Intercepts

Intercept only specific traffic (e.g., with a header):

```bash
telepresence intercept raidhelper-api \
    --namespace raidhelper-prod \
    --port 8081 \
    --http-header X-Dev-User=yourname
```

Now only requests with `X-Dev-User: yourname` will be sent to your local service.

### Preview URLs

Generate a shareable preview URL:

```bash
telepresence intercept raidhelper-api \
    --namespace raidhelper-prod \
    --port 8081 \
    --preview-url=true
```

### Multiple Services

You can intercept multiple services simultaneously:

```bash
# Terminal 1: API service
telepresence intercept raidhelper-api --namespace raidhelper-prod --port 8081

# Terminal 2: Realtime service  
telepresence intercept raidhelper-realtime --namespace raidhelper-prod --port 8082
```

## Development Workflows

### 1. Full Local Development

Intercept all RaidHelper services for complete local development:

```bash
# Terminal 1: API
telepresence intercept raidhelper-api --namespace raidhelper-prod --port 8081
cd ../raidhelper/cmd/api && go run main.go

# Terminal 2: Realtime
telepresence intercept raidhelper-realtime --namespace raidhelper-prod --port 8082  
cd ../raidhelper/cmd/realtime && go run main.go

# Terminal 3: Web (if developing locally)
telepresence intercept raidhelper-web --namespace raidhelper-prod --port 3000
cd ../raidhelper-web && npm start
```

### 2. Selective Intercepts

Intercept only the service you're working on, use cluster services for others:

```bash
# Only intercept API, use cluster realtime and web
telepresence intercept raidhelper-api --namespace raidhelper-prod --port 8081
cd ../raidhelper/cmd/api && go run main.go
```

### 3. Testing with Real Data

Use intercepts to test local changes against production-like data:

```bash
# Intercept with specific header for your tests
telepresence intercept raidhelper-api \
    --namespace raidhelper-prod \
    --port 8081 \
    --http-header X-Test-User=developer

# Make requests with the header
curl -H "X-Test-User: developer" http://raidhelper-api-service.raidhelper-prod.svc.cluster.local:8081/raids
```

## Environment Variables

Telepresence automatically captures environment variables from the intercepted pod. Access them via:

```bash
# Save environment to file
telepresence intercept raidhelper-api --namespace raidhelper-prod --port 8081 --env-file api.env

# Use in your local development
export $(cat api.env | xargs)
go run main.go
```

Common environment variables you'll have access to:
- Database connection strings
- Redis/NATS URLs
- Service discovery endpoints
- Configuration values

## Troubleshooting

### Connection Issues

```bash
# Check connection status
telepresence status

# Reconnect if needed
telepresence quit
telepresence connect
```

### Port Conflicts

```bash
# Check what's using a port
lsof -i :8081

# Use a different local port
telepresence intercept raidhelper-api --namespace raidhelper-prod --port 8090:8081
```

### Service Not Found

```bash
# List available services
telepresence list --namespace raidhelper-prod

# Check if namespace exists
kubectl get namespaces

# Check if service is running
kubectl get services -n raidhelper-prod
```

### Cleanup

```bash
# Remove specific intercept
telepresence leave raidhelper-api-raidhelper-prod

# Remove all intercepts
telepresence leave

# Disconnect completely
telepresence quit
```

## Best Practices

### 1. Use Conditional Intercepts
Always use headers or other conditions to avoid intercepting production traffic accidentally.

### 2. Monitor Resource Usage
Local development can consume more resources. Monitor your local machine's CPU and memory.

### 3. Environment Isolation
Use different headers/conditions for different developers to avoid conflicts.

### 4. Start Small
Begin by intercepting one service, then expand to multiple services as needed.

### 5. Regular Cleanup
Regularly check and clean up intercepts to avoid confusion:

```bash
telepresence list
telepresence leave  # Remove all intercepts
```

## Integration with IDEs

### VS Code

Add launch configuration to `.vscode/launch.json`:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug API with Telepresence",
            "type": "go",
            "request": "launch",
            "mode": "auto",
            "program": "${workspaceFolder}/cmd/api",
            "envFile": "${workspaceFolder}/api.env",
            "preLaunchTask": "telepresence-intercept"
        }
    ]
}
```

### GoLand

1. Create a Run Configuration
2. Set working directory to your service directory
3. Add environment variables from the telepresence env file
4. Set up pre-launch telepresence intercept command

## Monitoring and Observability

While using Telepresence, you can still access all observability tools:

- **Grafana**: http://localhost:3000 - View metrics for intercepted and cluster services
- **Prometheus**: http://localhost:9090 - Query metrics directly
- **Linkerd**: http://localhost:50750 - View service mesh traffic
- **ArgoCD**: http://localhost:8080 - Monitor deployments

Your local service will appear in these tools as part of the cluster, making debugging easier.

## Additional Resources

- [Telepresence Official Documentation](https://www.telepresence.io/docs/)
- [Telepresence GitHub](https://github.com/telepresenceio/telepresence)
- [Telepresence Community](https://slack.cncf.io/) - #telepresence channel
