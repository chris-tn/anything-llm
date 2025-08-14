#!/bin/bash

# Script để verify cấu hình extraEnvs và extraSecrets cho AnythingLLM
# Usage: ./verify-extra-envs.sh [namespace] [release-name]

set -e

NAMESPACE=${1:-default}
RELEASE_NAME=${2:-anything-llm}
APP_NAME="${RELEASE_NAME}"

echo "🔍 Verifying extraEnvs and extraSecrets configuration for AnythingLLM..."
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
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
done

echo ""

# Kiểm tra Helm values
echo "📋 Checking Helm Values..."
HELM_VALUES=$(helm get values -n $NAMESPACE $RELEASE_NAME 2>/dev/null || echo "NOT_FOUND")

if [ "$HELM_VALUES" != "NOT_FOUND" ]; then
    echo "✅ Helm values found for release $RELEASE_NAME"
    
    # Kiểm tra extraEnvs
    EXTRA_ENVS=$(echo "$HELM_VALUES" | grep -A 10 "extraEnvs:" | grep -v "extraEnvs:" | grep -v "^-" | grep -v "^$" || echo "NOT_FOUND")
    if [ "$EXTRA_ENVS" != "NOT_FOUND" ]; then
        echo "✅ extraEnvs configured:"
        echo "$EXTRA_ENVS" | sed 's/^/   /'
    else
        echo "ℹ️  No extraEnvs configured"
    fi
    
    # Kiểm tra extraSecrets
    EXTRA_SECRETS=$(echo "$HELM_VALUES" | grep -A 10 "extraSecrets:" | grep -v "extraSecrets:" | grep -v "^-" | grep -v "^$" || echo "NOT_FOUND")
    if [ "$EXTRA_SECRETS" != "NOT_FOUND" ]; then
        echo "✅ extraSecrets configured:"
        echo "$EXTRA_SECRETS" | sed 's/^/   /'
    else
        echo "ℹ️  No extraSecrets configured"
    fi
else
    echo "❌ Helm values not found for release $RELEASE_NAME"
fi

echo ""

# Kiểm tra Environment Variables trong Pods
echo "🔧 Checking Environment Variables in Pods..."
for pod in $PODS; do
    POD_STATUS=$(kubectl get pod -n $NAMESPACE $pod -o jsonpath='{.status.phase}')
    if [ "$POD_STATUS" = "Running" ]; then
        echo "📋 Environment variables in $pod:"
        
        # Lấy tất cả env vars
        ALL_ENV_VARS=$(kubectl exec -n $NAMESPACE $pod -- env 2>/dev/null || echo "")
        
        if [ -n "$ALL_ENV_VARS" ]; then
            # Đếm tổng số env vars
            TOTAL_ENV_VARS=$(echo "$ALL_ENV_VARS" | wc -l)
            echo "   📊 Total environment variables: $TOTAL_ENV_VARS"
            
            # Tìm các env vars có thể là từ extraEnvs (không phải core vars)
            CORE_VARS="AWS_REGION|SERVER_PORT|STORAGE_DIR|NODE_ENV|UID|GID|COLLECTOR_PORT|PGHOST|PGPORT|PGDATABASE|PGUSER|PGPASSWORD|AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|JWT_SECRET"
            EXTRA_ENV_VARS=$(echo "$ALL_ENV_VARS" | grep -v -E "^($CORE_VARS)=" | head -10)
            
            if [ -n "$EXTRA_ENV_VARS" ]; then
                echo "   🔍 Potential extraEnvs (showing first 10):"
                echo "$EXTRA_ENV_VARS" | sed 's/^/     /'
            else
                echo "   ℹ️  No extra environment variables found"
            fi
        else
            echo "   ❌ Could not retrieve environment variables"
        fi
    fi
done

echo ""

# Kiểm tra Secret
echo "🔐 Checking Secret Configuration..."
SECRET_NAME="${APP_NAME}-secrets"
SECRET_EXISTS=$(kubectl get secret -n $NAMESPACE $SECRET_NAME 2>/dev/null && echo "EXISTS" || echo "NOT_FOUND")

if [ "$SECRET_EXISTS" = "EXISTS" ]; then
    echo "✅ Secret $SECRET_NAME exists"
    
    # Lấy danh sách keys trong secret
    SECRET_KEYS=$(kubectl get secret -n $NAMESPACE $SECRET_NAME -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || echo "")
    
    if [ -n "$SECRET_KEYS" ]; then
        echo "   📋 Secret keys:"
        echo "$SECRET_KEYS" | sed 's/^/     /'
        
        # Tìm các keys có thể là từ extraSecrets
        CORE_SECRET_KEYS="AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|JWT_SECRET"
        EXTRA_SECRET_KEYS=$(echo "$SECRET_KEYS" | grep -v -E "^($CORE_SECRET_KEYS)$")
        
        if [ -n "$EXTRA_SECRET_KEYS" ]; then
            echo "   🔍 Potential extraSecrets:"
            echo "$EXTRA_SECRET_KEYS" | sed 's/^/     /'
        else
            echo "   ℹ️  No extra secret keys found"
        fi
    else
        echo "   ❌ Could not retrieve secret keys"
    fi
else
    echo "❌ Secret $SECRET_NAME not found"
fi

echo ""

# Test Template Rendering
echo "🔧 Testing Template Rendering..."
echo "📋 Testing with sample extraEnvs and extraSecrets..."

# Tạo test values
TEST_VALUES=$(cat <<EOF
extraEnvs:
  TEST_ENV_VAR: "test-value"
  LLM_PROVIDER: "litellm"
  DEBUG_MODE: "true"

extraSecrets:
  TEST_SECRET: "test-secret-value"
  API_KEY: "sk-test-key"
EOF
)

# Test template rendering
TEMPLATE_OUTPUT=$(helm template $RELEASE_NAME . --set extraEnvs.TEST_ENV_VAR=test-value --set extraSecrets.TEST_SECRET=test-secret-value 2>/dev/null || echo "TEMPLATE_ERROR")

if [ "$TEMPLATE_OUTPUT" != "TEMPLATE_ERROR" ]; then
    echo "✅ Template rendering successful"
    
    # Kiểm tra env vars trong template
    ENV_VARS_IN_TEMPLATE=$(echo "$TEMPLATE_OUTPUT" | grep -A 20 "env:" | grep "name:" | grep -E "(TEST_ENV_VAR|LLM_PROVIDER|DEBUG_MODE)" || echo "")
    if [ -n "$ENV_VARS_IN_TEMPLATE" ]; then
        echo "   ✅ extraEnvs found in template:"
        echo "$ENV_VARS_IN_TEMPLATE" | sed 's/^/     /'
    fi
    
    # Kiểm tra secrets trong template
    SECRETS_IN_TEMPLATE=$(echo "$TEMPLATE_OUTPUT" | grep -A 20 "env:" | grep -A 5 "valueFrom:" | grep -E "(TEST_SECRET|API_KEY)" || echo "")
    if [ -n "$SECRETS_IN_TEMPLATE" ]; then
        echo "   ✅ extraSecrets found in template:"
        echo "$SECRETS_IN_TEMPLATE" | sed 's/^/     /'
    fi
else
    echo "❌ Template rendering failed"
fi

echo ""

# Recommendations
echo "💡 Recommendations:"
echo "   - Use extraEnvs for non-sensitive configuration"
echo "   - Use extraSecrets for API keys, passwords, and sensitive data"
echo "   - Test template rendering before deployment"
echo "   - Verify environment variables are set correctly in pods"
echo "   - Monitor application logs for configuration issues"

echo ""
echo "✅ Extra environment variables verification complete!"
