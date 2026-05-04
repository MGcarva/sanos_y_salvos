#!/bin/bash
# ============================================
# Deploy Script - Sanos y Salvos
# Usage: ./scripts/deploy.sh [build|pull]
# ============================================

set -e

MODE=${1:-build}
COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE=".env"

echo "=========================================="
echo "  Sanos y Salvos - Deploy ($MODE)"
echo "=========================================="

# Check .env file
if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: .env file not found!"
    echo "Copy .env.production to .env and update values"
    exit 1
fi

# Check for default passwords
if grep -q "CHANGE_ME" "$ENV_FILE"; then
    echo "ERROR: .env contains default CHANGE_ME values!"
    echo "Update ALL passwords before deploying."
    exit 1
fi

echo "[1/5] Stopping existing services..."
docker compose -f $COMPOSE_FILE down --timeout 30 2>/dev/null || true

echo "[2/5] Starting infrastructure..."
docker compose -f $COMPOSE_FILE up -d postgres redis rabbitmq minio

echo "  Waiting for infrastructure to be healthy..."
MAX_WAIT=120
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    PG_HEALTHY=$(docker inspect --format='{{.State.Health.Status}}' sanos-postgres 2>/dev/null || echo "starting")
    REDIS_HEALTHY=$(docker inspect --format='{{.State.Health.Status}}' sanos-redis 2>/dev/null || echo "starting")
    RMQ_HEALTHY=$(docker inspect --format='{{.State.Health.Status}}' sanos-rabbitmq 2>/dev/null || echo "starting")
    
    if [ "$PG_HEALTHY" = "healthy" ] && [ "$REDIS_HEALTHY" = "healthy" ] && [ "$RMQ_HEALTHY" = "healthy" ]; then
        echo "  Infrastructure healthy!"
        break
    fi
    
    echo "  Waiting... (${ELAPSED}s) PG=$PG_HEALTHY REDIS=$REDIS_HEALTHY RMQ=$RMQ_HEALTHY"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "WARNING: Infrastructure health check timed out. Proceeding anyway..."
fi

echo "[3/5] Initializing RabbitMQ and MinIO..."
docker compose -f $COMPOSE_FILE up -d rabbitmq-init minio-init
sleep 10

echo "[4/5] Starting microservices..."
if [ "$MODE" = "build" ]; then
    docker compose -f $COMPOSE_FILE up -d --build auth-service ms-mascotas ms-geolocalizacion ms-coincidencias bff-service frontend
elif [ "$MODE" = "pull" ]; then
    docker compose -f $COMPOSE_FILE pull auth-service ms-mascotas ms-geolocalizacion ms-coincidencias bff-service frontend
    docker compose -f $COMPOSE_FILE up -d auth-service ms-mascotas ms-geolocalizacion ms-coincidencias bff-service frontend
fi

echo "[5/5] Running health checks..."
sleep 45

SERVICES=("sanos-auth-service:8081" "sanos-ms-mascotas:8082" "sanos-ms-geolocalizacion:8083" "sanos-ms-coincidencias:8084" "sanos-bff-service:8080")
ALL_OK=true

for SVC in "${SERVICES[@]}"; do
    CONTAINER=$(echo $SVC | cut -d: -f1)
    PORT=$(echo $SVC | cut -d: -f2)
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER 2>/dev/null || echo "not found")
    if [ "$STATUS" = "healthy" ]; then
        echo "  ✓ $CONTAINER is healthy"
    else
        echo "  ✗ $CONTAINER status: $STATUS"
        ALL_OK=false
    fi
done

# Check frontend
FRONTEND_STATUS=$(curl -sf -o /dev/null -w "%{http_code}" http://localhost:80 2>/dev/null || echo "000")
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "  ✓ Frontend is accessible (HTTP $FRONTEND_STATUS)"
else
    echo "  ✗ Frontend not accessible (HTTP $FRONTEND_STATUS)"
    ALL_OK=false
fi

echo ""
echo "=========================================="
if [ "$ALL_OK" = true ]; then
    echo "  Deploy successful!"
else
    echo "  Deploy completed with warnings."
    echo "  Check logs: docker compose -f $COMPOSE_FILE logs -f [service]"
fi
echo "=========================================="
echo ""
echo "Services:"
echo "  Frontend:    http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_IP')"
echo "  BFF API:     http://localhost:9090"
echo "  RabbitMQ:    http://localhost:15672"
echo "  MinIO:       http://localhost:9001"
echo ""
