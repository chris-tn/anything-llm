# AnythingLLM Helm Chart

Helm chart để deploy AnythingLLM trên Kubernetes với hỗ trợ multi-pod và cấu hình linh hoạt.

## 🚀 Features

- ✅ **Multi-pod support** với shared storage
- ✅ **Flexible environment variables** với `extraEnvs` và `extraSecrets`
- ✅ **LiteLLM integration** sẵn sàng
- ✅ **PostgreSQL database** với pgvector
- ✅ **High availability** với multiple replicas
- ✅ **Health checks** và monitoring
- ✅ **Persistent storage** cho data và models

## 📋 Prerequisites

- Kubernetes cluster 1.19+
- Helm 3.0+
- Storage class hỗ trợ `ReadWriteMany` (EFS, Azure Files, Filestore)
- kubectl configured

## 🚀 Quick Start

### 1. Deploy với LiteLLM (Recommended)

```bash
# Clone repository
git clone <repository-url>
cd anything-llm/cloud-deployments/helm/anything-llm

# Deploy với LiteLLM
./scripts/deploy-with-litellm.sh default anything-llm "sk-your-api-key"
```

### 2. Deploy với custom configuration

```bash
# Sử dụng values file
helm install anything-llm . -f examples/litellm-values.yaml

# Hoặc sử dụng --set flags
helm install anything-llm . \
  --set replicaCount=2 \
  --set extraEnvs.LLM_PROVIDER=litellm \
  --set extraSecrets.LITE_LLM_API_KEY=sk-your-key
```

### 3. Deploy với external database

```bash
helm install anything-llm . \
  --set database.provider=postgresql \
  --set database.external.enabled=true \
  --set database.external.host=your-db-host \
  --set database.external.database=anythingllm \
  --set database.external.user=anythingllm \
  --set database.external.passwordSecretName=db-secret
```

## 📚 Configuration

### Core Environment Variables

```yaml
env:
  AWS_REGION: ""
  SERVER_PORT: 3001
  STORAGE_DIR: "/app/server/storage"
  NODE_ENV: "production"
  UID: 1000
  GID: 1000
```

### Extra Environment Variables

```yaml
extraEnvs:
  LLM_PROVIDER: "litellm"
  LITE_LLM_MODEL_PREF: "gpt-3.5-turbo"
  LITE_LLM_MODEL_TOKEN_LIMIT: "4096"
  LITE_LLM_BASE_PATH: "http://litellm-server:4000"
  DEBUG_MODE: "true"
  CUSTOM_SETTING: "value"
```

### Extra Secrets

```yaml
extraSecrets:
  LITE_LLM_API_KEY: "sk-your-api-key"
  DATABASE_PASSWORD: "secure-password"
  API_SECRET: "secret123"
```

## 🔧 Storage Configuration

### AWS EKS (EFS)

```yaml
persistence:
  accessModes:
    - ReadWriteMany
  storageClassName: "efs-sc"
```

### Azure AKS (Azure Files)

```yaml
persistence:
  accessModes:
    - ReadWriteMany
  storageClassName: "azurefile-csi"
```

### GKE (Filestore)

```yaml
persistence:
  accessModes:
    - ReadWriteMany
  storageClassName: "filestore-sc"
```

## 📖 Documentation

- [Multi-Pod LLM Consistency](MULTI_POD_LLM_CONSISTENCY.md) - Hướng dẫn về tính nhất quán dữ liệu
- [Extra Environment Variables Guide](EXTRA_ENVS_GUIDE.md) - Hướng dẫn sử dụng extraEnvs
- [Multi-Pod Fix](README_MULTI_POD_FIX.md) - Chi tiết về fix multi-pod issues

## 🛠️ Scripts

- `scripts/deploy-with-litellm.sh` - Deploy với LiteLLM configuration
- `scripts/verify-multi-pod-setup.sh` - Verify multi-pod setup
- `scripts/verify-extra-envs.sh` - Verify extraEnvs configuration

## 📁 Examples

- `examples/litellm-values.yaml` - Ví dụ cấu hình LiteLLM

## 🔍 Verification

### Kiểm tra deployment

```bash
# Kiểm tra pods
kubectl get pods -l app.kubernetes.io/name=anything-llm

# Kiểm tra services
kubectl get svc -l app.kubernetes.io/name=anything-llm

# Kiểm tra PVCs
kubectl get pvc -l app.kubernetes.io/name=anything-llm
```

### Verify configuration

```bash
# Verify multi-pod setup
./scripts/verify-multi-pod-setup.sh

# Verify extraEnvs
./scripts/verify-extra-envs.sh

# Check environment variables
kubectl exec -it <pod-name> -- env | grep -E "(LLM_|LITE_)"
```

## 🐛 Troubleshooting

### PVC không bound

```bash
kubectl describe pvc <pvc-name>
# Kiểm tra storage class có hỗ trợ ReadWriteMany
```

### Pod không start

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Environment variables không được set

```bash
kubectl exec -it <pod-name> -- env | grep <variable-name>
helm get values <release-name>
```

## 🔄 Upgrading

```bash
# Upgrade với cấu hình mới
helm upgrade anything-llm . \
  --set extraEnvs.NEW_VAR=value \
  --set extraSecrets.NEW_SECRET=value

# Upgrade với values file
helm upgrade anything-llm . -f new-values.yaml
```

## 🗑️ Uninstalling

```bash
# Uninstall release
helm uninstall anything-llm

# Delete PVCs (optional)
kubectl delete pvc -l app.kubernetes.io/name=anything-llm

# Delete secrets (optional)
kubectl delete secret -l app.kubernetes.io/name=anything-llm
```

## 📊 Monitoring

### Health checks

```bash
# Check readiness
kubectl get pods -l app.kubernetes.io/name=anything-llm -o wide

# Check logs
kubectl logs -f -l app.kubernetes.io/name=anything-llm
```

### Metrics

```bash
# Port forward metrics
kubectl port-forward svc/anything-llm 9090:9090

# Access metrics
curl http://localhost:9090/metrics
```

## 🔐 Security

- API keys được lưu trữ trong Kubernetes secrets
- Pods chạy với non-root user
- Network policies có thể được áp dụng
- Secrets được encrypted at rest

## 🤝 Contributing

1. Fork repository
2. Create feature branch
3. Make changes
4. Test với `helm template .`
5. Submit pull request

## 📄 License

MIT License - see LICENSE file for details

---

**Version:** 1.0.0  
**Last Updated:** $(date)  
**Status:** ✅ Production Ready
