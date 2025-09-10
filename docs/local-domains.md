# Local Domains Setup

This feature allows you to set up custom local domains for your development environment, making it easier to work with multiple services without remembering port numbers.

## Quick Start

1. **Copy the example configuration:**
   ```bash
   cp config/local-domains.env.example config/local-domains.env
   ```

2. **Customize for your project:**
   ```bash
   # Edit the configuration file
   nano config/local-domains.env
   ```

3. **Run setup:**
   ```bash
   make setup
   # or manually:
   ./scripts/setup-local-domains.sh add
   ```

## Configuration

### Environment Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `PROJECT_NAME` | Project name (used as subdomain) | `raidhelper` | `myapp` |
| `LOCAL_DOMAIN` | Local domain suffix | `local` | `dev`, `test` |
| `SERVICES` | Comma-separated list of services | `web:80,api:8081,ws:8082` | `frontend:3000,backend:8080` |

### Service Format

Services are defined as `name:port` pairs:
- `name`: Service name (becomes subdomain)
- `port`: Port number the service runs on

## Examples

### E-commerce Project
```bash
PROJECT_NAME=shop
LOCAL_DOMAIN=dev
SERVICES=frontend:3000,backend:8080,admin:8081,payment:8082
```

**Result:**
- `http://shop.dev` → Frontend
- `http://frontend.shop.dev` → Frontend (alternative)
- `http://backend.shop.dev` → Backend API
- `http://admin.shop.dev` → Admin panel
- `http://payment.shop.dev` → Payment service

### Microservices Project
```bash
PROJECT_NAME=myapp
LOCAL_DOMAIN=local
SERVICES=gateway:80,user-service:8081,order-service:8082,notification-service:8083
```

**Result:**
- `http://myapp.local` → Gateway
- `http://user-service.myapp.local` → User service
- `http://order-service.myapp.local` → Order service
- `http://notification-service.myapp.local` → Notification service

## Manual Usage

### Add Domains
```bash
# Using environment variables
PROJECT_NAME=myapp LOCAL_DOMAIN=dev ./scripts/setup-local-domains.sh add

# Using config file
./scripts/setup-local-domains.sh add
```

### Remove Domains
```bash
./scripts/setup-local-domains.sh remove
```

### Show Configuration
```bash
./scripts/setup-local-domains.sh show
```

## Integration with Traefik

The local domains work with Traefik ingress controller. Make sure your services have IngressRoute resources configured:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: my-service-ingress
  namespace: apps
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`my-service.myapp.local`)
      kind: Rule
      services:
        - name: my-service
          port: 8080
```

## Troubleshooting

### Domains Not Working
1. Check if Traefik is running: `kubectl get pods -n traefik`
2. Verify port-forward: `kubectl port-forward svc/traefik -n traefik 80:80`
3. Check /etc/hosts: `cat /etc/hosts | grep local`

### Permission Issues
The script needs sudo access to modify `/etc/hosts`. Make sure you have sudo privileges.

### Port Conflicts
If you get port conflicts, check what's using port 80:
```bash
sudo lsof -i :80
```

## Customization for Different Projects

To use this localdev repository for different projects:

1. **Copy the repository:**
   ```bash
   cp -r localdev my-new-project-dev
   cd my-new-project-dev
   ```

2. **Update configuration:**
   ```bash
   cp config/local-domains.env.example config/local-domains.env
   # Edit config/local-domains.env with your project settings
   ```

3. **Update manifests:**
   - Modify Kustomize overlays to match your services
   - Update IngressRoute resources with your domain names
   - Adjust resource limits and configurations

4. **Run setup:**
   ```bash
   make setup
   ```

This makes the localdev repository completely reusable across different projects! 🚀
