#!/bin/bash
# =============================================================
# user-data.sh â€” Bootstrap EC2 para Sanos y Salvos
# Variables como ${db_host} son reemplazadas por Terraform templatefile.
# =============================================================
exec > /var/log/sanos-deploy.log 2>&1
echo "=== Inicio bootstrap EC2 $(date) ==="

# ---- Instalar Docker y cliente PostgreSQL ----
dnf install -y docker postgresql15
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# ---- Swap 3GB para t3.medium con 5 JVMs Spring Boot ----
fallocate -l 3G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=3072
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
echo 10 > /proc/sys/vm/swappiness
echo "[OK] Swap 3GB activado"

# ---- Login ECR (usa LabInstanceProfile, sin credenciales explÃ­citas) ----
ECR_PASS=$(aws ecr get-login-password --region ${aws_region})
echo "$ECR_PASS" | docker login --username AWS --password-stdin ${ecr_registry}
echo "[OK] ECR login"

# ---- Inicializar bases de datos en RDS ----
echo "[INFO] Creando bases de datos en RDS..."
PGPASSWORD="${db_pass}" psql -h ${db_host} -U ${db_user} -d postgres -c "
  SELECT 'CREATE DATABASE auth_db'            WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'auth_db') \gexec
  SELECT 'CREATE DATABASE mascotas_db'        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'mascotas_db') \gexec
  SELECT 'CREATE DATABASE geolocalizacion_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'geolocalizacion_db') \gexec
  SELECT 'CREATE DATABASE coincidencias_db'   WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'coincidencias_db') \gexec
" || echo "[WARN] Error creando BDs, pueden ya existir"

PGPASSWORD="${db_pass}" psql -h ${db_host} -U ${db_user} -d geolocalizacion_db \
  -c "CREATE EXTENSION IF NOT EXISTS postgis;" || true
PGPASSWORD="${db_pass}" psql -h ${db_host} -U ${db_user} -d coincidencias_db \
  -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;" || true
echo "[OK] Bases de datos inicializadas"

# ---- Red de contenedores ----
docker network create sanos-network || true

# ---- RabbitMQ (imagen pÃºblica, siempre disponible) ----
docker run -d --name rabbitmq \
  --network sanos-network \
  --restart unless-stopped \
  -p 5672:5672 \
  -p 15672:15672 \
  -e RABBITMQ_DEFAULT_USER=${rabbitmq_user} \
  -e RABBITMQ_DEFAULT_PASS=${rabbitmq_pass} \
  rabbitmq:3.12-alpine
echo "[OK] RabbitMQ iniciado"
sleep 25

# =============================================================
# Script para iniciar microservicios (se puede re-ejecutar
# despuÃ©s de hacer docker push de las imÃ¡genes a ECR)
# =============================================================
cat > /home/ec2-user/start-services.sh << 'STARTSCRIPT'
#!/bin/bash
exec >> /var/log/sanos-services.log 2>&1
echo "=== Iniciando microservicios $(date) ==="

ECR="${ecr_registry}"
PROYECTO="${proyecto}"

# Re-login ECR
aws ecr get-login-password --region ${aws_region} | \
  docker login --username AWS --password-stdin "$ECR"

pull_or_warn() {
  local img="$1"
  docker pull "$img" && return 0
  echo "[WARN] No se pudo pull $img â€” reintenta despuÃ©s de docker push"
  return 1
}

# auth-service
docker rm -f auth-service 2>/dev/null || true
IMG="$ECR/$PROYECTO/auth-service:latest"
pull_or_warn "$IMG" && \
docker run -d --name auth-service \
  --network sanos-network --restart unless-stopped --memory 512m \
  -p 8081:8081 \
  -e JAVA_TOOL_OPTIONS="-Xmx256m -Xms64m -XX:MaxMetaspaceSize=128m -XX:+UseSerialGC" \
  -e DB_HOST=${db_host} -e DB_USER=${db_user} -e DB_PASS=${db_pass} \
  -e REDIS_HOST=${redis_host} -e REDIS_PASS=${redis_pass} \
  -e JWT_SECRET=${jwt_secret} \
  -e AUTO_VERIFY_EMAIL=true \
  -e MAIL_HOST=localhost -e MAIL_PORT=1025 -e MAIL_USER="" -e MAIL_PASS="" \
  "$IMG" && echo "[OK] auth-service" || echo "[FAIL] auth-service"

# ms-mascotas
docker rm -f ms-mascotas 2>/dev/null || true
IMG="$ECR/$PROYECTO/ms-mascotas:latest"
pull_or_warn "$IMG" && \
docker run -d --name ms-mascotas \
  --network sanos-network --restart unless-stopped --memory 512m \
  -p 8082:8082 \
  -e JAVA_TOOL_OPTIONS="-Xmx256m -Xms64m -XX:MaxMetaspaceSize=128m -XX:+UseSerialGC" \
  -e DB_HOST=${db_host} -e DB_USER=${db_user} -e DB_PASS=${db_pass} \
  -e RABBITMQ_HOST=rabbitmq -e RABBITMQ_USER=${rabbitmq_user} -e RABBITMQ_PASS=${rabbitmq_pass} \
  -e S3_BUCKET=${s3_bucket} -e AWS_REGION=${aws_region} \
  -e JWT_SECRET=${jwt_secret} \
  "$IMG" && echo "[OK] ms-mascotas" || echo "[FAIL] ms-mascotas"

# ms-geolocalizacion
docker rm -f ms-geolocalizacion 2>/dev/null || true
IMG="$ECR/$PROYECTO/ms-geolocalizacion:latest"
pull_or_warn "$IMG" && \
docker run -d --name ms-geolocalizacion \
  --network sanos-network --restart unless-stopped --memory 512m \
  -p 8083:8083 \
  -e JAVA_TOOL_OPTIONS="-Xmx256m -Xms64m -XX:MaxMetaspaceSize=128m -XX:+UseSerialGC" \
  -e DB_HOST=${db_host} -e DB_USER=${db_user} -e DB_PASS=${db_pass} \
  -e RABBITMQ_HOST=rabbitmq -e RABBITMQ_USER=${rabbitmq_user} -e RABBITMQ_PASS=${rabbitmq_pass} \
  -e JWT_SECRET=${jwt_secret} \
  "$IMG" && echo "[OK] ms-geolocalizacion" || echo "[FAIL] ms-geolocalizacion"

# ms-coincidencias
docker rm -f ms-coincidencias 2>/dev/null || true
IMG="$ECR/$PROYECTO/ms-coincidencias:latest"
pull_or_warn "$IMG" && \
docker run -d --name ms-coincidencias \
  --network sanos-network --restart unless-stopped --memory 512m \
  -p 8084:8084 \
  -e JAVA_TOOL_OPTIONS="-Xmx256m -Xms64m -XX:MaxMetaspaceSize=128m -XX:+UseSerialGC" \
  -e DB_HOST=${db_host} -e DB_USER=${db_user} -e DB_PASS=${db_pass} \
  -e RABBITMQ_HOST=rabbitmq -e RABBITMQ_USER=${rabbitmq_user} -e RABBITMQ_PASS=${rabbitmq_pass} \
  -e JWT_SECRET=${jwt_secret} \
  "$IMG" && echo "[OK] ms-coincidencias" || echo "[FAIL] ms-coincidencias"

echo "[INFO] Esperando 90s para que microservicios inicialicen..."
sleep 90

# bff-service
docker rm -f bff-service 2>/dev/null || true
IMG="$ECR/$PROYECTO/bff-service:latest"
pull_or_warn "$IMG" && \
docker run -d --name bff-service \
  --network sanos-network --restart unless-stopped --memory 512m \
  -p 8080:8080 \
  -e JAVA_TOOL_OPTIONS="-Xmx256m -Xms64m -XX:MaxMetaspaceSize=128m -XX:+UseSerialGC" \
  -e AUTH_HOST=auth-service -e AUTH_PORT=8081 \
  -e MASCOTAS_HOST=ms-mascotas -e MASCOTAS_PORT=8082 \
  -e GEO_HOST=ms-geolocalizacion -e GEO_PORT=8083 \
  -e COINCIDENCIAS_HOST=ms-coincidencias -e COINCIDENCIAS_PORT=8084 \
  -e REDIS_HOST=${redis_host} -e REDIS_PASS=${redis_pass} \
  -e JWT_SECRET=${jwt_secret} \
  "$IMG" && echo "[OK] bff-service" || echo "[FAIL] bff-service"

echo "=== Microservicios iniciados $(date) ==="
STARTSCRIPT

chmod +x /home/ec2-user/start-services.sh
chown ec2-user:ec2-user /home/ec2-user/start-services.sh

# Intentar iniciar servicios ahora (puede fallar si imÃ¡genes no estÃ¡n en ECR aÃºn)
echo "[INFO] Intentando iniciar microservicios (puede fallar si imÃ¡genes no estÃ¡n en ECR)..."
/home/ec2-user/start-services.sh || echo "[INFO] start-services.sh fallÃ³ â€” ejecutar de nuevo despuÃ©s de docker push"

echo "=== Bootstrap EC2 completo $(date) ==="
echo "=== Para reiniciar servicios: /home/ec2-user/start-services.sh ==="
