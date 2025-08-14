#!/bin/bash

# Script để verify cấu hình multi-pod setup cho AnythingLLM
# Usage: ./verify-multi-pod-setup.sh [namespace] [release-name]

set -e

NAMESPACE=${1:-default}
RELEASE_NAME=${2:-anything-llm}
APP_NAME="${RELEASE_NAME}"

echo "🔍 Verifying multi-pod setup for AnythingLLM..."
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo ""

# Kiểm tra PVC
echo "📦 Checking PVC configuration..."
PVC_NAME="${APP_NAME}-storage"
PVC_STATUS=$(kubectl get pvc -n $NAMESPACE $PVC_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "NOT_FOUND")

if [ "$PVC_STATUS" = "Bound" ]; then
    echo "✅ PVC $PVC_NAME is bound"
    
    # Kiểm tra access modes
    ACCESS_MODES=$(kubectl get pvc -n $NAMESPACE $PVC_NAME -o jsonpath='{.spec.accessModes[*]}')
    if [[ $ACCESS_MODES == *"ReadWriteMany"* ]]; then
        echo "✅ PVC supports ReadWriteMany access mode"
    else
        echo "❌ PVC does NOT support ReadWriteMany access mode"
        echo "   Current access modes: $ACCESS_MODES"
        echo "   This will prevent multiple pods from mounting the storage"
    fi
    
    # Kiểm tra storage class
    STORAGE_CLASS=$(kubectl get pvc -n $NAMESPACE $PVC_NAME -o jsonpath='{.spec.storageClassName}')
    echo "📋 Storage Class: $STORAGE_CLASS"
    
else
    echo "❌ PVC $PVC_NAME is not bound (Status: $PVC_STATUS)"
fi

echo ""

# Kiểm tra Collector PVC
echo "📦 Checking Collector PVC configuration..."
COLLECTOR_PVC_NAME="${APP_NAME}-collector-storage"
COLLECTOR_PVC_STATUS=$(kubectl get pvc -n $NAMESPACE $COLLECTOR_PVC_NAME -o jsonpath='{.status.phase}' 2>/dev/null || echo "NOT_FOUND")

if [ "$COLLECTOR_PVC_STATUS" = "Bound" ]; then
    echo "✅ Collector PVC $COLLECTOR_PVC_NAME is bound"
    
    # Kiểm tra access modes
    COLLECTOR_ACCESS_MODES=$(kubectl get pvc -n $NAMESPACE $COLLECTOR_PVC_NAME -o jsonpath='{.spec.accessModes[*]}')
    if [[ $COLLECTOR_ACCESS_MODES == *"ReadWriteMany"* ]]; then
        echo "✅ Collector PVC supports ReadWriteMany access mode"
    else
        echo "❌ Collector PVC does NOT support ReadWriteMany access mode"
        echo "   Current access modes: $COLLECTOR_ACCESS_MODES"
    fi
else
    echo "❌ Collector PVC $COLLECTOR_PVC_NAME is not bound (Status: $COLLECTOR_PVC_STATUS)"
fi

echo ""

# Kiểm tra Pods
echo "🐳 Checking Pods..."
PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=anything-llm -o jsonpath='{.items[*].metadata.name}')

if [ -z "$PODS" ]; then
    echo "❌ No pods found for AnythingLLM"
    exit 1
fi

POD_COUNT=$(echo $PODS | wc -w)
echo "📊 Found $POD_COUNT pod(s):"

for pod in $PODS; do
    POD_STATUS=$(kubectl get pod -n $NAMESPACE $pod -o jsonpath='{.status.phase}')
    echo "   - $pod: $POD_STATUS"
    
    if [ "$POD_STATUS" = "Running" ]; then
        # Kiểm tra volume mounts
        VOLUME_MOUNTS=$(kubectl get pod -n $NAMESPACE $pod -o jsonpath='{.spec.containers[0].volumeMounts[*].name}')
        if [[ $VOLUME_MOUNTS == *"storage"* ]]; then
            echo "     ✅ Main storage volume mounted"
        else
            echo "     ❌ Main storage volume NOT mounted"
        fi
        
        if [[ $VOLUME_MOUNTS == *"collector-storage"* ]]; then
            echo "     ✅ Collector storage volume mounted"
        else
            echo "     ❌ Collector storage volume NOT mounted"
        fi
    fi
done

echo ""

# Kiểm tra LLM models trong pods
echo "🤖 Checking LLM models in pods..."
for pod in $PODS; do
    POD_STATUS=$(kubectl get pod -n $NAMESPACE $pod -o jsonpath='{.status.phase}')
    if [ "$POD_STATUS" = "Running" ]; then
        echo "📁 Checking models in $pod:"
        
        # Kiểm tra thư mục models
        if kubectl exec -n $NAMESPACE $pod -- test -d /app/server/storage/models 2>/dev/null; then
            echo "   ✅ Models directory exists"
            
            # Đếm số file .gguf
            GGUF_COUNT=$(kubectl exec -n $NAMESPACE $pod -- find /app/server/storage/models -name "*.gguf" 2>/dev/null | wc -l)
            echo "   📊 Found $GGUF_COUNT .gguf model files"
            
            # Kiểm tra thư mục downloaded
            if kubectl exec -n $NAMESPACE $pod -- test -d /app/server/storage/models/downloaded 2>/dev/null; then
                DOWNLOADED_COUNT=$(kubectl exec -n $NAMESPACE $pod -- ls /app/server/storage/models/downloaded/*.gguf 2>/dev/null | wc -l)
                echo "   📥 Downloaded models: $DOWNLOADED_COUNT"
            else
                echo "   ⚠️  Downloaded models directory not found"
            fi
        else
            echo "   ❌ Models directory does not exist"
        fi
    fi
done

echo ""

# Kiểm tra Storage Classes
echo "💾 Checking Storage Classes..."
STORAGE_CLASSES=$(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}')

echo "Available Storage Classes:"
for sc in $STORAGE_CLASSES; do
    ACCESS_MODES=$(kubectl get storageclass $sc -o jsonpath='{.allowedTopologies[0].matchLabelExpressions[0].values[*]}' 2>/dev/null || echo "N/A")
    echo "   - $sc (Access Modes: $ACCESS_MODES)"
done

echo ""

# Recommendations
echo "💡 Recommendations:"
if [ "$PVC_STATUS" != "Bound" ]; then
    echo "   - Fix PVC binding issue first"
elif [[ $ACCESS_MODES != *"ReadWriteMany"* ]]; then
    echo "   - Update PVC to use ReadWriteMany access mode"
    echo "   - Ensure storage class supports ReadWriteMany"
fi

if [ "$POD_COUNT" -eq 1 ]; then
    echo "   - Consider scaling to multiple replicas for high availability"
    echo "   - Use: kubectl scale deployment $APP_NAME --replicas=2"
fi

echo ""
echo "✅ Verification complete!"

