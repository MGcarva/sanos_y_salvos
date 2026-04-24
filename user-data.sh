#!/bin/bash
exec > /var/log/sanos-deploy.log 2>&1
echo "=== Inicio deploy Sanos y Salvos 04/23/2026 20:03:08 ==="

# ---- Instalar Docker ----
dnf install -y docker
systemctl start docker
systemctl enable docker

# ---- Swap 2GB para t3.micro (1GB RAM + 5 JVMs Spring Boot) ----
fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
echo 10 > /proc/sys/vm/swappiness
echo "[OK] Swap 2GB activado"

# ---- Login ECR (usa instance profile LabRole, sin credenciales explicitas) ----
ECR_PASS=$(aws ecr get-login-password --region us-east-1 2>/dev/null)
echo "$ECR_PASS" | docker login --username AWS --password-stdin 236373526017.dkr.ecr.us-east-1.amazonaws.com
echo "[OK] ECR login"

# ---- Red de contenedores ----
docker network create sanos-network

# ---- RabbitMQ ----
docker run -d --name rabbitmq \
  --network sanos-network \
  --restart unless-stopped \
  -e RABBITMQ_DEFAULT_USER=sanosrabbit \
  -e RABBITMQ_DEFAULT_PASS=SanosRabbit2026! \
  rabbitmq:3.12-alpine

echo "[OK] RabbitMQ iniciado, esperando 25s..."
sleep 25

# ---- auth-service ----
docker run -d --name auth-service \
  --network sanos-network \
  --restart unless-stopped \
  --memory 280m --memory-swap 280m \
  -p 8081:8081 \
  -e JAVA_TOOL_OPTIONS="-Xmx130m -Xms32m -XX:MaxMetaspaceSize=96m -XX:+UseSerialGC" \
  -e DB_HOST=sanos-y-salvos-postgres.crfnd54e1dqp.us-east-1.rds.amazonaws.com \
  -e DB_USER=sanosadmin \
  -e DB_PASS=SanosYSalvos2026! \
  -e REDIS_HOST=sanos-y-salvos-redis.jfb0yl.0001.use1.cache.amazonaws.com \
  -e REDIS_PASS=SanosRedis2026! \
  -e JWT_SECRET=404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970 \
  -e MAIL_HOST=localhost \
  -e MAIL_PORT=1025 \
  -e MAIL_USER= \
  -e MAIL_PASS= \
  -e AUTO_VERIFY_EMAIL=true \
  -e FRONTEND_URL=http://sanos-y-salvos-frontend-236373526017.s3-website-us-east-1.amazonaws.com \
  236373526017.dkr.ecr.us-east-1.amazonaws.com/sanos-y-salvos/auth-service:latest
echo "[OK] auth-service iniciado"

# ---- ms-mascotas ----
# Nota: MINIO_ENDPOINT apunta a S3. Las fotos requieren credenciales validas.
# Si las credenciales de Academy expiran, redeployar el EC2.
docker run -d --name ms-mascotas \
  --network sanos-network \
  --restart unless-stopped \
  --memory 280m --memory-swap 280m \
  -p 8082:8082 \
  -e JAVA_TOOL_OPTIONS="-Xmx130m -Xms32m -XX:MaxMetaspaceSize=96m -XX:+UseSerialGC" \
  -e DB_HOST=sanos-y-salvos-postgres.crfnd54e1dqp.us-east-1.rds.amazonaws.com \
  -e DB_USER=sanosadmin \
  -e DB_PASS=SanosYSalvos2026! \
  -e RABBITMQ_HOST=rabbitmq \
  -e RABBITMQ_USER=sanosrabbit \
  -e RABBITMQ_PASS=SanosRabbit2026! \
  -e MINIO_ENDPOINT=https://s3.amazonaws.com \
  -e MINIO_ACCESS_KEY=ASIATOCHVYYA7PPWF5S4 \
  -e MINIO_SECRET_KEY=7bm0NPMnwslEiIOeJEVyMY7EghT5vPIZRSOA57rW \
  -e JWT_SECRET=404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970 \
  236373526017.dkr.ecr.us-east-1.amazonaws.com/sanos-y-salvos/ms-mascotas:latest
echo "[OK] ms-mascotas iniciado"

# ---- ms-geolocalizacion ----
docker run -d --name ms-geolocalizacion \
  --network sanos-network \
  --restart unless-stopped \
  --memory 280m --memory-swap 280m \
  -p 8083:8083 \
  -e JAVA_TOOL_OPTIONS="-Xmx130m -Xms32m -XX:MaxMetaspaceSize=96m -XX:+UseSerialGC" \
  -e DB_HOST=sanos-y-salvos-postgres.crfnd54e1dqp.us-east-1.rds.amazonaws.com \
  -e DB_USER=sanosadmin \
  -e DB_PASS=SanosYSalvos2026! \
  -e RABBITMQ_HOST=rabbitmq \
  -e RABBITMQ_USER=sanosrabbit \
  -e RABBITMQ_PASS=SanosRabbit2026! \
  -e JWT_SECRET=404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970 \
  236373526017.dkr.ecr.us-east-1.amazonaws.com/sanos-y-salvos/ms-geolocalizacion:latest
echo "[OK] ms-geolocalizacion iniciado"

# ---- ms-coincidencias ----
docker run -d --name ms-coincidencias \
  --network sanos-network \
  --restart unless-stopped \
  --memory 280m --memory-swap 280m \
  -p 8084:8084 \
  -e JAVA_TOOL_OPTIONS="-Xmx130m -Xms32m -XX:MaxMetaspaceSize=96m -XX:+UseSerialGC" \
  -e DB_HOST=sanos-y-salvos-postgres.crfnd54e1dqp.us-east-1.rds.amazonaws.com \
  -e DB_USER=sanosadmin \
  -e DB_PASS=SanosYSalvos2026! \
  -e RABBITMQ_HOST=rabbitmq \
  -e RABBITMQ_USER=sanosrabbit \
  -e RABBITMQ_PASS=SanosRabbit2026! \
  -e JWT_SECRET=404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970 \
  236373526017.dkr.ecr.us-east-1.amazonaws.com/sanos-y-salvos/ms-coincidencias:latest
echo "[OK] ms-coincidencias iniciado"

# Dar tiempo a los microservicios para inicializar antes de arrancar el BFF
echo "Esperando 60s para que microservicios inicialicen y creen tablas..."
sleep 60

# ---- bff-service ----
docker run -d --name bff-service \
  --network sanos-network \
  --restart unless-stopped \
  --memory 280m --memory-swap 280m \
  -p 8080:8080 \
  -e JAVA_TOOL_OPTIONS="-Xmx130m -Xms32m -XX:MaxMetaspaceSize=96m -XX:+UseSerialGC" \
  -e AUTH_HOST=auth-service \
  -e MASCOTAS_HOST=ms-mascotas \
  -e GEO_HOST=ms-geolocalizacion \
  -e COINCIDENCIAS_HOST=ms-coincidencias \
  -e REDIS_HOST=sanos-y-salvos-redis.jfb0yl.0001.use1.cache.amazonaws.com \
  -e REDIS_PASS=SanosRedis2026! \
  -e JWT_SECRET=404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970 \
  236373526017.dkr.ecr.us-east-1.amazonaws.com/sanos-y-salvos/bff-service:latest
echo "[OK] bff-service iniciado"

echo "=== Deploy completo 04/23/2026 20:03:08 ==="