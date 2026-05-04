#!/bin/bash
# ============================================
# Smoke Test Script - Validates all services
# Usage: ./scripts/smoke-test.sh [BASE_URL]
# ============================================

set -e

BASE=${1:-"http://localhost"}
BFF="http://localhost:9090"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0

test_endpoint() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    TOTAL=$((TOTAL + 1))
    
    STATUS=$(curl -sf -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$STATUS" = "$expected_status" ]; then
        echo -e "  ${GREEN}✓${NC} $name (HTTP $STATUS)"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} $name (Expected $expected_status, got $STATUS)"
        FAILED=$((FAILED + 1))
    fi
}

test_endpoint_post() {
    local name=$1
    local url=$2
    local data=$3
    local expected_status=${4:-200}
    TOTAL=$((TOTAL + 1))
    
    STATUS=$(curl -sf -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$data" "$url" 2>/dev/null || echo "000")
    
    if [ "$STATUS" = "$expected_status" ]; then
        echo -e "  ${GREEN}✓${NC} $name (HTTP $STATUS)"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} $name (Expected $expected_status, got $STATUS)"
        FAILED=$((FAILED + 1))
    fi
}

echo "=========================================="
echo "  Sanos y Salvos - Smoke Tests"
echo "=========================================="
echo ""

# Frontend
echo "--- Frontend ---"
test_endpoint "Frontend Homepage" "$BASE"
test_endpoint "Frontend Assets" "$BASE/index.html"

# Health Checks
echo ""
echo "--- Health Endpoints ---"
test_endpoint "Auth Service Health" "http://localhost:8081/actuator/health"
test_endpoint "Mascotas Service Health" "http://localhost:8082/actuator/health"
test_endpoint "Geo Service Health" "http://localhost:8083/actuator/health"
test_endpoint "Coincidencias Health" "http://localhost:8084/actuator/health"
test_endpoint "BFF Service Health" "$BFF/actuator/health"

# API Endpoints via BFF
echo ""
echo "--- API Endpoints (via BFF) ---"
test_endpoint "GET /api/reportes" "$BFF/api/reportes"
test_endpoint "GET /api/geo/heatmap" "$BFF/api/geo/heatmap"
test_endpoint "GET /api/geo/clusters" "$BFF/api/geo/clusters"
test_endpoint "GET /api/dashboard" "$BFF/api/dashboard"

# Auth Endpoints
echo ""
echo "--- Auth Endpoints ---"
test_endpoint_post "POST /api/auth/login (invalid)" "$BFF/api/auth/login" '{"email":"test@test.com","password":"wrong"}' "401"

# Swagger
echo ""
echo "--- Documentation ---"
test_endpoint "Auth Swagger" "http://localhost:8081/swagger-ui.html" "302"
test_endpoint "Mascotas Swagger" "http://localhost:8082/swagger-ui.html" "302"

# Infrastructure
echo ""
echo "--- Infrastructure ---"
test_endpoint "RabbitMQ Management" "http://localhost:15672" "200"
test_endpoint "MinIO Console" "http://localhost:9001" "200"

echo ""
echo "=========================================="
echo -e "  Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC} (of $TOTAL)"
if [ $FAILED -eq 0 ]; then
    echo -e "  ${GREEN}All tests passed!${NC}"
else
    echo -e "  ${YELLOW}Some tests failed. Check logs.${NC}"
fi
echo "=========================================="

exit $FAILED
