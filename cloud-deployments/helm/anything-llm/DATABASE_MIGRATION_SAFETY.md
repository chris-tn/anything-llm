# Database Migration Safety Guide

## ⚠️ Important: Data Safety

### Why `prisma migrate deploy` instead of `prisma db push`?

**`prisma db push`** (DANGEROUS):
- Directly pushes schema changes to database
- Can cause data loss if schema changes are incompatible
- No rollback capability
- Overwrites existing data structure

**`prisma migrate deploy`** (SAFE):
- Applies only pre-generated migration files
- Preserves existing data
- Supports rollback
- Safe for production environments

## Migration Strategy

### 1. Development Environment
```bash
# Generate migration files (safe)
npx prisma migrate dev --name migration_name

# This creates migration files in prisma/migrations/
```

### 2. Production Environment
```bash
# Apply existing migrations (safe)
npx prisma migrate deploy

# This only applies pre-generated migration files
```

## Current Configuration

The Helm chart now uses:
```yaml
# For both PostgreSQL and SQLite
npx prisma migrate deploy --schema=./prisma/schema.prisma
```

## Backup Recommendations

### Before Major Updates
1. **Database Backup**:
```bash
# PostgreSQL
pg_dump -h host -U user -d database > backup.sql

# SQLite
cp /app/server/storage/anythingllm.db backup.db
```

2. **Storage Backup**:
```bash
# Backup documents and vector data
kubectl exec -it <pod-name> -- tar -czf /tmp/backup.tar.gz /app/server/storage/
kubectl cp <pod-name>:/tmp/backup.tar.gz ./backup.tar.gz
```

### Backup Script Example
```bash
#!/bin/bash
# backup.sh
NAMESPACE="default"
RELEASE_NAME="anything-llm"
BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"

mkdir -p $BACKUP_DIR

# Get pod name
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=anything-llm -o jsonpath='{.items[0].metadata.name}')

# Backup database
if kubectl get pvc -n $NAMESPACE | grep -q postgresql; then
  echo "Backing up PostgreSQL..."
  kubectl exec -it $POD_NAME -n $NAMESPACE -- pg_dump -h $PGHOST -U $PGUSER -d $PGDATABASE > $BACKUP_DIR/database.sql
else
  echo "Backing up SQLite..."
  kubectl cp $NAMESPACE/$POD_NAME:/app/server/storage/anythingllm.db $BACKUP_DIR/
fi

# Backup storage
echo "Backing up storage..."
kubectl exec -it $POD_NAME -n $NAMESPACE -- tar -czf /tmp/storage_backup.tar.gz /app/server/storage/
kubectl cp $NAMESPACE/$POD_NAME:/tmp/storage_backup.tar.gz $BACKUP_DIR/

echo "Backup completed: $BACKUP_DIR"
```

## Migration Testing

### 1. Test Migration on Staging
```bash
# Deploy to staging first
helm install anything-llm-staging . \
  --set database.provider=postgresql \
  --set postgresql.enabled=true

# Test migration
kubectl logs -f <pod-name> | grep -i "migrate\|prisma"
```

### 2. Verify Data Integrity
```bash
# Check if data exists after migration
kubectl exec -it <pod-name> -- npx prisma studio --schema=./prisma/schema.prisma
```

## Rollback Plan

### If Migration Fails
1. **Immediate Rollback**:
```bash
# Rollback to previous version
helm rollback anything-llm 1

# Or restore from backup
kubectl cp ./backup.sql <pod-name>:/tmp/
kubectl exec -it <pod-name> -- psql -h $PGHOST -U $PGUSER -d $PGDATABASE < /tmp/backup.sql
```

2. **Database Rollback**:
```bash
# PostgreSQL
npx prisma migrate resolve --rolled-back <migration_name>

# SQLite
# Restore from backup file
```

## Monitoring Migration

### Check Migration Status
```bash
# View migration history
kubectl exec -it <pod-name> -- npx prisma migrate status

# Check for migration errors
kubectl logs <pod-name> | grep -i "error\|migrate\|prisma"
```

### Health Checks
```bash
# Verify application health
kubectl get pods -l app.kubernetes.io/name=anything-llm

# Check readiness probe
kubectl describe pod <pod-name> | grep -A 10 "Readiness"
```

## Best Practices

1. **Always backup before migration**
2. **Test migrations on staging first**
3. **Use `prisma migrate deploy` in production**
4. **Monitor logs during migration**
5. **Have rollback plan ready**
6. **Schedule migrations during low-traffic periods**

## Troubleshooting

### Migration Fails
```bash
# Check migration status
kubectl exec -it <pod-name> -- npx prisma migrate status

# View detailed logs
kubectl logs <pod-name> | grep -i "prisma"

# Check database connectivity
kubectl exec -it <pod-name> -- npx prisma db pull
```

### Data Loss Prevention
- Never use `prisma db push` in production
- Always backup before major updates
- Test schema changes thoroughly
- Use staging environment for testing
