# Collector Shared Storage Configuration

## Overview
This configuration adds shared storage for the collector hotdir and outputs directories to support multiple pod replicas without ENOENT errors.

## Changes Made

### 1. New Collector Persistence Configuration
Added `collector.persistence` section in `values.yaml`:
```yaml
collector:
  persistence:
    enabled: true
    size: 2Gi
    accessModes:
      - ReadWriteMany  # Required for multiple pods
    storageClassName: "" # Use cluster default
```

### 2. Volume Mounts
Added volume mounts in deployment:
- `/app/collector/hotdir` - for file uploads
- `/app/collector/outputs` - for processed files

### 3. Environment Variables
Updated `STORAGE_DIR` to `/app/server/storage` to match the application's expected path structure.

## Usage

### Deploy with Shared Storage
```bash
helm install anything-llm . \
  --set collector.persistence.enabled=true \
  --set collector.persistence.storageClassName="efs-sc" \
  --set replicaCount=2
```

### Required Storage Classes
You need a storage class that supports `ReadWriteMany` access mode:

**AWS EKS:**
```yaml
# Example EFS StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-xxxxx
  directoryPerms: "700"
```

**Azure AKS:**
```yaml
# Azure Files StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi
provisioner: file.csi.azure.com
parameters:
  skuName: Standard_LRS
```

**GKE:**
```yaml
# Filestore StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: filestore-sc
provisioner: filestore.csi.storage.gke.io
parameters:
  tier: standard
```

## Verification

### Check PVC Status
```bash
kubectl get pvc -l app.kubernetes.io/name=anything-llm
```

### Test File Sharing
1. Upload a file through the UI
2. Check if file exists in all pods:
```bash
kubectl exec -it <pod-name> -- ls -la /app/collector/hotdir/
```

### Check Environment Variables
```bash
kubectl exec -it <pod-name> -- env | grep STORAGE_DIR
# Should show: STORAGE_DIR=/app/server/storage
```

## Troubleshooting

### ENOENT Error Still Occurs
1. Verify PVC is bound:
```bash
kubectl get pvc
```

2. Check storage class supports ReadWriteMany:
```bash
kubectl get storageclass
```

3. Verify volume mounts:
```bash
kubectl describe pod <pod-name>
```

### File Upload Issues
1. Check collector logs:
```bash
kubectl logs <pod-name> -c anything-llm | grep collector
```

2. Verify hotdir permissions:
```bash
kubectl exec -it <pod-name> -- ls -la /app/collector/hotdir/
```

## Migration from Single Pod
If upgrading from single pod deployment:

### ⚠️ IMPORTANT: Backup First!
1. **Backup database and storage** (see DATABASE_MIGRATION_SAFETY.md)
2. Update values.yaml with collector persistence
3. Upgrade helm release
4. Scale to multiple replicas

```bash
# Backup first
./backup.sh

# Then upgrade
helm upgrade anything-llm . \
  --set collector.persistence.enabled=true \
  --set replicaCount=2
```

### Database Safety
- The chart now uses `prisma migrate deploy` instead of `prisma db push`
- This ensures data safety during schema updates
- See DATABASE_MIGRATION_SAFETY.md for detailed information
