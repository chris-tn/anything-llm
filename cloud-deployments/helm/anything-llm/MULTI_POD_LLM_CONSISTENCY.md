# Multi-Pod LLM Data Consistency

## Vấn đề

Khi chạy AnythingLLM với multiple pods (scaling > 1), dữ liệu LLM có thể không nhất quán giữa các pods do:

1. **LLM models được lưu trong storage chính** (`/app/server/storage/models/`)
2. **PVC chính trước đây sử dụng `ReadWriteOnce`** - chỉ 1 pod có thể mount
3. **Pods khác không thể truy cập LLM models** đã được tải

## Giải pháp đã áp dụng

### 1. Sửa PVC chính để hỗ trợ ReadWriteMany

File `templates/pvc.yaml` đã được cập nhật:
```yaml
spec:
  accessModes:
    {{- toYaml .Values.persistence.accessModes | nindent 4 }}
```

Thay vì hardcode `ReadWriteOnce`, giờ sử dụng cấu hình từ `values.yaml`:
```yaml
persistence:
  accessModes:
    - ReadWriteMany  # Cho phép multiple pods mount cùng lúc
```

### 2. Cấu hình Storage Class

Đảm bảo storage class hỗ trợ `ReadWriteMany`:

**AWS EKS (EFS):**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-xxxxx
```

**Azure AKS (Azure Files):**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi
provisioner: file.csi.azure.com
parameters:
  skuName: Standard_LRS
```

**GKE (Filestore):**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: filestore-sc
provisioner: filestore.csi.storage.gke.io
parameters:
  tier: standard
```

## Triển khai

### 1. Cập nhật Helm chart
```bash
# Pull latest chart
helm repo update

# Upgrade existing deployment
helm upgrade anything-llm . \
  --set persistence.accessModes[0]=ReadWriteMany \
  --set persistence.storageClassName="efs-sc" \
  --set replicaCount=2
```

### 2. Kiểm tra PVC status
```bash
kubectl get pvc -l app.kubernetes.io/name=anything-llm
```

### 3. Verify pods có thể mount storage
```bash
kubectl describe pod <pod-name>
# Tìm trong Events để đảm bảo không có lỗi mount
```

## Kiểm tra tính nhất quán

### 1. Verify LLM models được chia sẻ
```bash
# Kiểm tra model files trong tất cả pods
kubectl exec -it <pod-1> -- ls -la /app/server/storage/models/
kubectl exec -it <pod-2> -- ls -la /app/server/storage/models/
```

### 2. Test LLM functionality
- Upload document qua UI
- Kiểm tra embedding và LLM responses
- Đảm bảo cả 2 pods đều có thể xử lý requests

### 3. Monitor logs
```bash
# Kiểm tra logs của cả 2 pods
kubectl logs -f <pod-1> -c anything-llm
kubectl logs -f <pod-2> -c anything-llm
```

## Troubleshooting

### PVC không bound
```bash
kubectl describe pvc <pvc-name>
# Kiểm tra storage class có hỗ trợ ReadWriteMany
```

### Pod không start
```bash
kubectl describe pod <pod-name>
# Kiểm tra events để tìm lỗi mount volume
```

### LLM models không load
```bash
# Kiểm tra model files có tồn tại
kubectl exec -it <pod-name> -- ls -la /app/server/storage/models/downloaded/

# Kiểm tra permissions
kubectl exec -it <pod-name> -- ls -la /app/server/storage/
```

## Lưu ý quan trọng

1. **Backup trước khi upgrade** - Đảm bảo backup database và storage
2. **Storage class phải hỗ trợ ReadWriteMany** - Không phải tất cả storage classes đều hỗ trợ
3. **Performance** - Shared storage có thể chậm hơn local storage
4. **Model caching** - LLM models sẽ được cache trong memory của mỗi pod

## Migration từ single pod

```bash
# 1. Backup
./backup.sh

# 2. Update values.yaml
persistence:
  accessModes:
    - ReadWriteMany
  storageClassName: "efs-sc"

# 3. Upgrade
helm upgrade anything-llm . --values values.yaml

# 4. Scale up
kubectl scale deployment anything-llm --replicas=2
```

