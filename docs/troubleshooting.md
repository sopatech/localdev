# Troubleshooting Guide

This guide helps you resolve common issues with the local development environment.

## General Issues

### Minikube Won't Start

**Symptoms**: `minikube start` fails or hangs

**Solutions**:
```bash
# Check Docker Desktop is running
docker version

# Reset minikube
minikube delete
minikube start

# Check available resources
minikube config view
docker system df

# Ensure sufficient resources
minikube config set cpus 8
minikube config set memory 32768
```

### Services Not Responding

**Symptoms**: Port forwards work but services return connection errors

**Solutions**:
```bash
# Check service status
kubectl get pods -A
kubectl get services -A

# Check specific namespace
kubectl get pods -n raidhelper-prod
kubectl describe pod <pod-name> -n raidhelper-prod

# Restart failed pods
kubectl delete pod <pod-name> -n raidhelper-prod

# Check logs
kubectl logs <pod-name> -n raidhelper-prod
```

## Infrastructure Issues

### Helmfile Deployment Fails

**Symptoms**: `helmfile apply` errors or hangs

**Solutions**:
```bash
# Check current releases
helm list -A

# Update Helm repositories
helm repo update

# Deploy specific release
helmfile -e infrastructure apply --selector name=prometheus

# Delete and redeploy problematic release
helm delete <release-name> -n <namespace>
helmfile apply
```

### ArgoCD Not Accessible

**Symptoms**: Cannot access ArgoCD at localhost:8080

**Solutions**:
```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD server logs
kubectl logs deployment/argo-argocd-server -n argocd

# Restart ArgoCD server
kubectl rollout restart deployment/argo-argocd-server -n argocd

# Manual port forward
kubectl port-forward svc/argo-argocd-server -n argocd 8080:80

# Check admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Prometheus/Grafana Issues

**Symptoms**: Metrics not showing or dashboards empty

**Solutions**:
```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus-server -n monitoring 9090:80
# Visit http://localhost:9090/targets

# Check Prometheus configuration
kubectl get configmap prometheus-server -n monitoring -o yaml

# Restart Prometheus
kubectl rollout restart deployment/prometheus-server -n monitoring

# Check Grafana data sources
kubectl logs deployment/grafana -n monitoring

# Reset Grafana admin password
kubectl get secret grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d
```

## Telepresence Issues

### Cannot Connect to Cluster

**Symptoms**: `telepresence connect` fails

**Solutions**:
```bash
# Check kubectl connectivity
kubectl cluster-info

# Reset Telepresence
telepresence quit
rm -rf ~/.cache/telepresence
telepresence connect

# Check Telepresence traffic manager
kubectl get pods -n telepresence

# Reinstall traffic manager
telepresence uninstall --everything
telepresence helm install

# Check firewall/proxy settings
telepresence status
```

### Intercept Fails

**Symptoms**: `telepresence intercept` command fails

**Solutions**:
```bash
# Check service exists
kubectl get service <service-name> -n <namespace>

# List available services
telepresence list --namespace <namespace>

# Check service has proper labels
kubectl describe service <service-name> -n <namespace>

# Try intercept with specific port mapping
telepresence intercept <service-name> --namespace <namespace> --port 8080:8081

# Check for port conflicts
lsof -i :<local-port>
```

### Local Service Not Receiving Traffic

**Symptoms**: Intercept created but local service gets no requests

**Solutions**:
```bash
# Verify intercept is active
telepresence list

# Check intercept conditions
telepresence intercept <service-name> --namespace <namespace> --port <port> --http-header X-Test=value

# Test with correct headers
curl -H "X-Test: value" http://<service-url>

# Check local service is listening
netstat -ln | grep <local-port>

# Verify environment variables
telepresence intercept <service-name> --namespace <namespace> --port <port> --env-file env.txt
cat env.txt
```

## Networking Issues

### Port Forward Conflicts

**Symptoms**: Port already in use errors

**Solutions**:
```bash
# Find what's using the port
lsof -i :8080

# Kill existing port forwards
pkill -f "kubectl port-forward"

# Use different ports
kubectl port-forward svc/argo-argocd-server -n argocd 8081:80

# Restart port forward script
./scripts/port-forwards.sh --cleanup
./scripts/port-forwards.sh
```

### DNS Resolution Issues

**Symptoms**: Cannot resolve cluster service names

**Solutions**:
```bash
# Check CoreDNS
kubectl get pods -n kube-system | grep coredns

# Test DNS resolution from pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check DNS configuration
kubectl get configmap coredns -n kube-system -o yaml

# Restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system
```

## Resource Issues

### Pods Stuck in Pending

**Symptoms**: Pods not starting, stuck in Pending state

**Solutions**:
```bash
# Check node resources
kubectl top nodes
kubectl describe nodes

# Check pod resource requests
kubectl describe pod <pod-name> -n <namespace>

# Check available resources
kubectl get nodes -o wide

# Scale down resource-heavy pods temporarily
kubectl scale deployment <deployment-name> --replicas=1 -n <namespace>

# Increase minikube resources
minikube stop
minikube config set memory 40960
minikube start
```

### Out of Disk Space

**Symptoms**: Pods failing due to disk pressure

**Solutions**:
```bash
# Check disk usage
kubectl top nodes
minikube ssh 'df -h'

# Clean up Docker images
docker system prune -a

# Clean up minikube
minikube ssh 'docker system prune -a'

# Check for large logs
kubectl logs <pod-name> -n <namespace> --tail=100

# Rotate logs
minikube ssh 'sudo logrotate -f /etc/logrotate.conf'
```

## Application-Specific Issues

### RaidHelper Services Not Starting

**Symptoms**: RaidHelper pods crashlooping or not ready

**Solutions**:
```bash
# Check pod status
kubectl get pods -n raidhelper-prod

# Check pod logs
kubectl logs <pod-name> -n raidhelper-prod

# Check configuration
kubectl get configmap -n raidhelper-prod
kubectl get secret -n raidhelper-prod

# Check image pull issues
kubectl describe pod <pod-name> -n raidhelper-prod

# Update image tags
kubectl set image deployment/<deployment-name> <container-name>=<new-image> -n raidhelper-prod
```

### Database Connection Issues

**Symptoms**: Services can't connect to databases

**Solutions**:
```bash
# Check if database pods are running
kubectl get pods -A | grep postgres
kubectl get pods -A | grep redis
kubectl get pods -A | grep nats

# Test connectivity from service pod
kubectl exec -it <service-pod> -n raidhelper-prod -- nc -zv <db-host> <db-port>

# Check service discovery
kubectl get services -A | grep postgres

# Verify configuration
kubectl get configmap raidhelper-api-config -n raidhelper-prod -o yaml
```

## Development Workflow Issues

### Hot Reload Not Working

**Symptoms**: Changes not reflected in local development

**Solutions**:
```bash
# Verify intercept is active
telepresence list

# Check local service is running
ps aux | grep <your-service>

# Restart local service
# Kill and restart your local development server

# Check file watching
# Ensure your development tools are watching the right files

# Verify environment variables
env | grep <relevant-vars>
```

### Debugging Not Working

**Symptoms**: Cannot attach debugger to intercepted service

**Solutions**:
```bash
# Ensure debugger port is forwarded
telepresence intercept <service> --namespace <namespace> --port 8080:8080,40000:40000

# Start service with debug flags
dlv debug --headless --listen=:40000 --api-version=2 ./cmd/api

# Connect debugger to localhost:40000

# Check firewall isn't blocking debug port
lsof -i :40000
```

## Performance Issues

### Slow Response Times

**Symptoms**: Local development is slower than expected

**Solutions**:
```bash
# Check resource usage
top
docker stats

# Monitor network latency
ping <cluster-ip>

# Check for resource constraints
kubectl top pods -A
kubectl top nodes

# Reduce resource requests in development
# Edit deployment resources temporarily

# Use local databases for development
# Set up local PostgreSQL/Redis instead of cluster services
```

### High Memory Usage

**Symptoms**: System running out of memory

**Solutions**:
```bash
# Check memory usage
free -h
docker stats

# Reduce minikube memory if needed
minikube stop
minikube config set memory 16384
minikube start

# Scale down non-essential services
kubectl scale deployment grafana --replicas=0 -n monitoring
kubectl scale deployment prometheus-server --replicas=0 -n monitoring

# Use resource limits
kubectl patch deployment <deployment> -n <namespace> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","resources":{"limits":{"memory":"512Mi"}}}]}}}}'
```

## Recovery Procedures

### Complete Environment Reset

When all else fails:

```bash
# Stop everything
telepresence quit
pkill -f "kubectl port-forward"

# Reset minikube
minikube stop
minikube delete

# Clean Docker
docker system prune -a

# Start fresh
./setup.sh
```

### Partial Reset (Keep Minikube)

```bash
# Stop services
telepresence quit
pkill -f "kubectl port-forward"

# Reset infrastructure
cd infrastructure
helmfile destroy
helmfile apply

# Restart port forwards
./scripts/port-forwards.sh
```

### Emergency Debugging

```bash
# Get cluster state
kubectl cluster-info dump > cluster-dump.txt

# Get all events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Check system pods
kubectl get pods -n kube-system

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

## Getting Help

### Useful Commands for Support

```bash
# System info
uname -a
docker version
minikube version
kubectl version

# Cluster info
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A

# Resource info
kubectl top nodes
kubectl top pods -A
df -h
free -h
```

### Log Collection

```bash
# Collect all logs
mkdir debug-logs
kubectl logs deployment/argo-argocd-server -n argocd > debug-logs/argocd.log
kubectl logs deployment/prometheus-server -n monitoring > debug-logs/prometheus.log
kubectl logs deployment/grafana -n monitoring > debug-logs/grafana.log

# Export configurations
kubectl get configmaps -A -o yaml > debug-logs/configmaps.yaml
kubectl get services -A -o yaml > debug-logs/services.yaml
```

### Community Resources

- **Kubernetes Slack**: https://slack.k8s.io/
- **ArgoCD GitHub Issues**: https://github.com/argoproj/argo-cd/issues
- **Telepresence GitHub Issues**: https://github.com/telepresenceio/telepresence/issues
- **Linkerd GitHub Issues**: https://github.com/linkerd/linkerd2/issues

Remember: Always check the logs first - they usually contain the most helpful information for debugging!
