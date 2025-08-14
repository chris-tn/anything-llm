#!/bin/bash

# Script để deploy AnythingLLM với LiteLLM configuration
# Usage: ./deploy-with-litellm.sh [namespace] [release-name] [api-key]

set -e

NAMESPACE=${1:-default}
RELEASE_NAME=${2:-anything-llm}
API_KEY=${3:-"sk-123abc"}

echo "🚀 Deploying AnythingLLM with LiteLLM configuration..."
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo ""

# Kiểm tra kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    exit 1
fi

# Kiểm tra helm
if ! command -v helm &> /dev/null; then
    echo "❌ helm is not installed"
    exit 1
fi

# Kiểm tra namespace
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "📦 Creating namespace $NAMESPACE..."
    kubectl create namespace $NAMESPACE
fi

# Kiểm tra storage class
echo "💾 Checking storage class..."
STORAGE_CLASSES=$(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}')
if [[ $STORAGE_CLASSES == *"efs-sc"* ]]; then
    echo "✅ EFS storage class found"
    STORAGE_CLASS="efs-sc"
elif [[ $STORAGE_CLASSES == *"azurefile-csi"* ]]; then
    echo "✅ Azure Files storage class found"
    STORAGE_CLASS="azurefile-csi"
elif [[ $STORAGE_CLASSES == *"filestore-sc"* ]]; then
    echo "✅ Filestore storage class found"
    STORAGE_CLASS="filestore-sc"
else
    echo "⚠️  No ReadWriteMany storage class found, using default"
    STORAGE_CLASS=""
fi

echo ""

# Deploy với LiteLLM configuration
echo "📦 Deploying AnythingLLM with LiteLLM..."

helm upgrade --install $RELEASE_NAME . \
  --namespace $NAMESPACE \
  --set replicaCount=2 \
  --set database.provider=postgresql \
  --set postgresql.enabled=true \
  --set postgresql.auth.username=anythingllm \
  --set postgresql.auth.password=anythingllm \
  --set postgresql.auth.database=anythingllm \
  --set postgresql.primary.persistence.enabled=true \
  --set postgresql.primary.persistence.size=8Gi \
  --set persistence.enabled=true \
  --set persistence.size=5Gi \
  --set persistence.accessModes[0]=ReadWriteMany \
  --set persistence.storageClassName="$STORAGE_CLASS" \
  --set collector.persistence.enabled=true \
  --set collector.persistence.size=2Gi \
  --set collector.persistence.accessModes[0]=ReadWriteMany \
  --set collector.persistence.storageClassName="$STORAGE_CLASS" \
  --set extraEnvs.LLM_PROVIDER=litellm \
  --set extraEnvs.LITE_LLM_MODEL_PREF=gpt-3.5-turbo \
  --set extraEnvs.LITE_LLM_MODEL_TOKEN_LIMIT=4096 \
  --set extraEnvs.LITE_LLM_BASE_PATH=http://litellm-server:4000 \
  --set extraSecrets.LITE_LLM_API_KEY="$API_KEY" \
  --set secrets.create=true \
  --set secrets.jwtSecret="my-random-string-for-seeding" \
  --wait \
  --timeout=10m

echo ""

# Kiểm tra deployment
echo "🔍 Checking deployment status..."
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=anything-llm

echo ""

# Kiểm tra services
echo "🌐 Checking services..."
kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=anything-llm

echo ""

# Kiểm tra PVCs
echo "💾 Checking PVCs..."
kubectl get pvc -n $NAMESPACE -l app.kubernetes.io/name=anything-llm

echo ""

# Verify configuration
echo "✅ Verifying configuration..."
./scripts/verify-extra-envs.sh $NAMESPACE $RELEASE_NAME

echo ""

# Instructions
echo "📋 Next steps:"
echo "1. Ensure LiteLLM server is running at http://litellm-server:4000"
echo "2. Update LITE_LLM_BASE_PATH if your LiteLLM server is at different URL"
echo "3. Replace API key with your actual LiteLLM API key"
echo "4. Access AnythingLLM UI at: kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME 3001:3001"
echo "5. Monitor logs: kubectl logs -f -n $NAMESPACE -l app.kubernetes.io/name=anything-llm"

echo ""
echo "✅ Deployment complete!"
