# mirrord Guide

This guide explains how to use mirrord for local development with the RaidHelper microservices.

## What is mirrord?

mirrord is a tool that allows you to run your local service with seamless access to everything in the cloud. This enables you to:

- Test your local code against real cluster services
- Debug services with production-like dependencies
- Develop faster without container rebuilds
- Access cluster-internal services from your local machine
- **No authentication required** - works out of the box!

## Prerequisites

- mirrord installed (see main README for installation)
- Local development environment running (`./setup.sh`)
- kubectl configured to access your minikube cluster

## Basic Usage

### 1. Run Your Service with Cloud Access

The simplest way to use mirrord is to run your local service with cloud access:

```bash
# Basic usage - mirrord will auto-detect the target
mirrord exec go run ./cmd/api

# Specify target explicitly (using deployment)
mirrord exec --target deployment/raidhelper-api --target-namespace apps go run ./cmd/api

# Or using service
mirrord exec --target service/raidhelper-api-service --target-namespace apps go run ./cmd/api
```

### 2. Verify Connection

Check that your local service can access cluster services:

```bash
# Your local service can now access cluster services like:
# - raidhelper-api-service.apps.svc.cluster.local:8080
# - raidhelper-realtime-service.apps.svc.cluster.local:8080
# - All databases, queues, and other cluster services
```

### 3. Available Targets

See what services you can target:

```bash
make mirrord-status
```

This will show you all available services in the `apps` namespace.

## Advanced Usage

### Environment Variables

mirrord automatically provides access to cluster environment variables:

```bash
# Run with environment file
mirrord exec --target deployment/raidhelper-api --target-namespace apps --env-file .env go run ./cmd/api

# Environment variables are automatically available to your local process
```

### File System Access

Access cluster file systems from your local service:

```bash
# Enable file system access
mirrord exec --target deployment/raidhelper-api --target-namespace apps --fs-mode write go run ./cmd/api
```

### Multiple Services

You can run multiple services locally, each targeting different cluster services:

```bash
# Terminal 1: API service
mirrord exec --target deployment/raidhelper-api --target-namespace apps go run ./cmd/api

# Terminal 2: Realtime service  
mirrord exec --target deployment/raidhelper-realtime --target-namespace apps go run ./cmd/realtime
```

## Development Workflows

### 1. Full Local Development

Run all RaidHelper services locally with cloud access:

```bash
# Terminal 1: API
mirrord exec --target deployment/raidhelper-api --target-namespace apps go run ./cmd/api

# Terminal 2: Realtime
mirrord exec --target deployment/raidhelper-realtime --target-namespace apps go run ./cmd/realtime

# Terminal 3: Web (if developing locally)
mirrord exec --target deployment/raidhelper-web --target-namespace apps npm start
```

### 2. Selective Development

Run only the service you're working on, use cluster services for others:

```bash
# Only run API locally, use cluster realtime and web
mirrord exec --target deployment/raidhelper-api --target-namespace apps go run ./cmd/api
```

### 3. Testing with Real Data

Use mirrord to test local changes against production-like data:

```bash
# Your local service automatically gets access to:
# - Real databases (DynamoDB via LocalStack)
# - Real messaging (NATS)
# - Real configuration
# - Real service discovery
```

## Environment Variables

mirrord automatically provides access to cluster environment variables. Common variables you'll have access to:

- Database connection strings
- Redis/NATS URLs
- Service discovery endpoints
- Configuration values
- API keys and secrets

## Troubleshooting

### Connection Issues

```bash
# Check kubectl connectivity
kubectl cluster-info

# Verify cluster access
kubectl get pods -n apps

# Check mirrord installation
mirrord --version

# Try with explicit target
mirrord exec --target deployment/<deployment-name> --target-namespace apps <your-command>
```

### Service Not Found

```bash
# List available services
kubectl get services -n apps

# Check service is running
kubectl get pods -n apps

# Use explicit target
mirrord exec --target deployment/raidhelper-api --target-namespace apps go run ./cmd/api
```

### Local Service Not Receiving Traffic

```bash
# Verify mirrord is running
ps aux | grep mirrord

# Check local service is listening
netstat -ln | grep <local-port>

# Test with curl
curl http://localhost:<local-port>/health
```

## Best Practices

### 1. Use Explicit Targets

Always specify the target service explicitly to avoid confusion:

```bash
mirrord exec --target deployment/raidhelper-api --target-namespace apps go run ./cmd/api
```

### 2. Monitor Resource Usage

Local development can consume more resources. Monitor your local machine's CPU and memory.

### 3. Start Small

Begin by running one service locally, then expand to multiple services as needed.

### 4. Regular Cleanup

Regularly check and clean up mirrord processes:

```bash
# Check running mirrord processes
ps aux | grep mirrord

# Kill specific mirrord process if needed
pkill -f "mirrord.*raidhelper-api"
```

## Integration with IDEs

### VS Code

Add launch configuration to `.vscode/launch.json`:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug API with mirrord",
            "type": "go",
            "request": "launch",
            "mode": "auto",
            "program": "${workspaceFolder}/cmd/api",
            "preLaunchTask": "mirrord-exec"
        }
    ]
}
```

### GoLand

1. Create a Run Configuration
2. Set working directory to your service directory
3. Set up pre-launch mirrord exec command
4. Use mirrord exec with your debugger

## Monitoring and Observability

While using mirrord, you can still access all observability tools:

- **Grafana**: http://localhost:3000 - View metrics for your local service
- **Prometheus**: http://localhost:9090 - Query metrics directly
- **Linkerd**: http://localhost:50750 - View service mesh traffic
- **ArgoCD**: http://localhost:8080 - Monitor deployments

Your local service will appear in these tools as part of the cluster, making debugging easier.

## Benefits of mirrord

- ✅ **No setup required** - Works out of the box
- ✅ **Faster debugging** - Use your favorite IDE tools
- ✅ **Real cloud data** - Access actual databases, queues, and services
- ✅ **Safe testing** - No risk of breaking shared environments
- ✅ **Cost effective** - No need for personal dev environments
- ✅ **No authentication** - No cloud accounts or API keys needed

## Additional Resources

- [mirrord Documentation](https://metalbear.com/mirrord/)
- [mirrord GitHub](https://github.com/metalbear-co/mirrord)
- [mirrord Community](https://discord.gg/metalbear)
