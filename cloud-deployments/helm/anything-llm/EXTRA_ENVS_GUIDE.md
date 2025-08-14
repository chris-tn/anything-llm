# Extra Environment Variables Guide

## Overview

Helm chart này hỗ trợ cơ chế linh hoạt để thêm các environment variables và secrets tùy chỉnh thông qua `extraEnvs` và `extraSecrets`.

## Cấu hình

### Extra Environment Variables

Sử dụng `extraEnvs` để thêm các environment variables không nhạy cảm:

```yaml
extraEnvs:
  LLM_PROVIDER: "litellm"
  LITE_LLM_MODEL_PREF: "gpt-3.5-turbo"
  LITE_LLM_MODEL_TOKEN_LIMIT: "4096"
  LITE_LLM_BASE_PATH: "http://127.0.0.1:4000"
  CUSTOM_SETTING: "value"
  DEBUG_MODE: "true"
```

### Extra Secrets

Sử dụng `extraSecrets` để thêm các environment variables nhạy cảm (API keys, passwords, etc.):

```yaml
extraSecrets:
  LITE_LLM_API_KEY: "sk-123abc"
  DATABASE_PASSWORD: "mypassword"
  API_SECRET: "secret123"
```

## Ví dụ sử dụng

### 1. LiteLLM Configuration

```yaml
extraEnvs:
  LLM_PROVIDER: "litellm"
  LITE_LLM_MODEL_PREF: "gpt-3.5-turbo"
  LITE_LLM_MODEL_TOKEN_LIMIT: "4096"
  LITE_LLM_BASE_PATH: "http://litellm-server:4000"

extraSecrets:
  LITE_LLM_API_KEY: "sk-your-actual-api-key"
```

### 2. Custom Database Configuration

```yaml
extraEnvs:
  DATABASE_HOST: "custom-db.example.com"
  DATABASE_PORT: "5432"
  DATABASE_NAME: "anythingllm"

extraSecrets:
  DATABASE_PASSWORD: "secure-password"
  DATABASE_USER: "dbuser"
```

### 3. External Service Integration

```yaml
extraEnvs:
  EXTERNAL_API_URL: "https://api.example.com"
  LOG_LEVEL: "debug"
  FEATURE_FLAG_ENABLED: "true"

extraSecrets:
  EXTERNAL_API_KEY: "api-key-123"
  WEBHOOK_SECRET: "webhook-secret"
```

## Deployment

### Sử dụng values.yaml

```yaml
# values.yaml
extraEnvs:
  LLM_PROVIDER: "litellm"
  LITE_LLM_MODEL_PREF: "gpt-3.5-turbo"

extraSecrets:
  LITE_LLM_API_KEY: "sk-123abc"

# Deploy
helm install anything-llm . -f values.yaml
```

### Sử dụng --set flag

```bash
helm install anything-llm . \
  --set extraEnvs.LLM_PROVIDER=litellm \
  --set extraEnvs.LITE_LLM_MODEL_PREF=gpt-3.5-turbo \
  --set extraSecrets.LITE_LLM_API_KEY=sk-123abc
```

### Sử dụng --set-string cho values có ký tự đặc biệt

```bash
helm install anything-llm . \
  --set-string extraEnvs.LITE_LLM_BASE_PATH="http://127.0.0.1:4000" \
  --set-string extraSecrets.LITE_LLM_API_KEY="sk-123abc"
```

## Verification

### Kiểm tra environment variables

```bash
# Kiểm tra tất cả env vars
kubectl exec -it <pod-name> -- env | grep -E "(LLM_|LITE_)"

# Kiểm tra specific env var
kubectl exec -it <pod-name> -- env | grep LLM_PROVIDER
```

### Kiểm tra secrets

```bash
# Kiểm tra secret được tạo
kubectl get secret <release-name>-secrets -o yaml

# Kiểm tra secret keys
kubectl get secret <release-name>-secrets -o jsonpath='{.data}' | jq
```

## Best Practices

### 1. Security
- Luôn sử dụng `extraSecrets` cho API keys, passwords, và thông tin nhạy cảm
- Không commit secrets vào git repository
- Sử dụng external secret management (HashiCorp Vault, AWS Secrets Manager, etc.)

### 2. Organization
- Nhóm các environment variables liên quan
- Sử dụng naming convention nhất quán
- Document các environment variables mới

### 3. Validation
- Test cấu hình trước khi deploy production
- Verify environment variables được set đúng trong pods
- Monitor logs để đảm bảo ứng dụng nhận được cấu hình

## Troubleshooting

### Environment variable không được set

```bash
# Kiểm tra values.yaml
helm get values <release-name>

# Kiểm tra template rendering
helm template . --set extraEnvs.TEST=value

# Kiểm tra pod env vars
kubectl exec -it <pod-name> -- env | grep TEST
```

### Secret không được tạo

```bash
# Kiểm tra secret template
helm template . --set extraSecrets.TEST_SECRET=value

# Kiểm tra secret exists
kubectl get secret <release-name>-secrets

# Kiểm tra secret content
kubectl get secret <release-name>-secrets -o yaml
```

### Pod không start

```bash
# Kiểm tra pod events
kubectl describe pod <pod-name>

# Kiểm tra pod logs
kubectl logs <pod-name>

# Kiểm tra secret mount
kubectl exec -it <pod-name> -- env | grep -E "(SECRET|KEY)"
```

## Migration từ hardcoded env vars

Nếu bạn đã có environment variables hardcoded trong deployment, có thể migrate sang `extraEnvs`:

### Trước (hardcoded)
```yaml
env:
  LLM_PROVIDER: "litellm"
  LITE_LLM_MODEL_PREF: "gpt-3.5-turbo"
```

### Sau (sử dụng extraEnvs)
```yaml
env:
  # Core env vars
  AWS_REGION: ""
  SERVER_PORT: 3001
  # ... other core vars

extraEnvs:
  LLM_PROVIDER: "litellm"
  LITE_LLM_MODEL_PREF: "gpt-3.5-turbo"
```

## Examples

### Complete LiteLLM Setup

```yaml
env:
  AWS_REGION: ""
  SERVER_PORT: 3001
  STORAGE_DIR: "/app/server/storage"
  NODE_ENV: "production"
  UID: 1000
  GID: 1000

extraEnvs:
  LLM_PROVIDER: "litellm"
  LITE_LLM_MODEL_PREF: "gpt-3.5-turbo"
  LITE_LLM_MODEL_TOKEN_LIMIT: "4096"
  LITE_LLM_BASE_PATH: "http://litellm-server:4000"

extraSecrets:
  LITE_LLM_API_KEY: "sk-your-actual-api-key"

secrets:
  create: true
  name: ""
  awsAccessKeyId: ""
  awsSecretAccessKey: ""
  jwtSecret: "my-random-string-for-seeding"
```

### Multi-Provider Setup

```yaml
extraEnvs:
  LLM_PROVIDER: "litellm"
  LITE_LLM_MODEL_PREF: "gpt-3.5-turbo"
  EMBEDDING_PROVIDER: "openai"
  VECTOR_DB_PROVIDER: "pinecone"
  LOG_LEVEL: "info"

extraSecrets:
  LITE_LLM_API_KEY: "sk-litellm-key"
  OPENAI_API_KEY: "sk-openai-key"
  PINECONE_API_KEY: "pinecone-key"
```
