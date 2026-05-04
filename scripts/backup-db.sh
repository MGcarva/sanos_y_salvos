#!/bin/bash
# ============================================
# Backup Script - PostgreSQL databases
# Usage: ./scripts/backup-db.sh
# Run via cron: 0 2 * * * /home/ec2-user/sanos-y-salvos/scripts/backup-db.sh
# ============================================

set -e

BACKUP_DIR="/home/ec2-user/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

mkdir -p $BACKUP_DIR

echo "Starting database backup..."

DATABASES=("auth_db" "mascotas_db" "geolocalizacion_db" "coincidencias_db")

for DB in "${DATABASES[@]}"; do
    echo "  Backing up $DB..."
    docker exec sanos-postgres pg_dump -U ${POSTGRES_USER:-postgres} $DB | gzip > "$BACKUP_DIR/${DB}_${DATE}.sql.gz"
    echo "  ✓ $DB backed up"
done

# Clean old backups
echo "Cleaning backups older than ${RETENTION_DAYS} days..."
find $BACKUP_DIR -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Optional: Upload to S3
if command -v aws &> /dev/null; then
    S3_BUCKET=${BACKUP_S3_BUCKET:-""}
    if [ -n "$S3_BUCKET" ]; then
        echo "Uploading to S3..."
        for DB in "${DATABASES[@]}"; do
            aws s3 cp "$BACKUP_DIR/${DB}_${DATE}.sql.gz" "s3://$S3_BUCKET/db-backups/${DB}_${DATE}.sql.gz"
        done
        echo "✓ Uploaded to S3"
    fi
fi

echo "Backup complete: $BACKUP_DIR"
ls -lh $BACKUP_DIR/*_${DATE}.sql.gz
