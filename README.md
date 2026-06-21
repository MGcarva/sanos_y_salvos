# Sanos y Salvos

Plataforma para reportar y encontrar mascotas perdidas en Chile. Los usuarios publican reportes de mascotas perdidas o encontradas, las visualizan en un mapa interactivo y pueden consultar a **Amigo**, un asistente virtual con IA que busca mascotas por comuna y guía en el proceso.

---

## PROMPT PARA IA — Cómo levantar este proyecto desde cero

> Copia este README completo y dáselo a cualquier IA (Claude, ChatGPT, Gemini, etc.) con el mensaje:
> **"Ayúdame a levantar este proyecto en mi PC siguiendo las instrucciones del README."**
> La IA leerá los pasos, ejecutará los comandos contigo y resolverá cualquier problema que aparezca.

---

## Requisitos previos

Solo necesitas **dos herramientas** instaladas en tu PC. Todo lo demás (Java, Node.js, PostgreSQL, etc.) corre dentro de Docker.

| Herramienta | Versión mínima | Descarga |
|---|---|---|
| **Docker Desktop** | 4.x | https://www.docker.com/products/docker-desktop |
| **Git** | 2.x | https://git-scm.com/downloads |

> **Windows**: Docker Desktop debe estar corriendo antes de continuar. Verifica con `docker --version` en PowerShell.
> **Mac/Linux**: Mismos requisitos. En Linux usar Docker Engine + Docker Compose plugin.

---

## Arquitectura del sistema

```
Usuario (navegador)
  │
  ├── Frontend React          → http://localhost:3000
  │     └── BFF Spring Boot  → http://localhost:9090
  │           ├── auth-service        (JWT, registro, login)
  │           ├── ms-mascotas         (reportes + fotos en MinIO)
  │           ├── ms-geolocalizacion  (mapa de calor, clusters)
  │           └── ms-coincidencias    (matching automático entre reportes)
  │
  └── Chat Widget (Amigo)
        └── n8n Workflow     → http://localhost:5678
              └── Claude AI (Anthropic) — busca mascotas por comuna

Infraestructura local:
  PostgreSQL + PostGIS  → datos
  Redis                 → caché de dashboard
  RabbitMQ              → eventos entre microservicios
  MinIO                 → almacenamiento de fotos
  Mailhog               → emails de verificación (desarrollo)
```

---

## Paso 1 — Clonar el repositorio

```bash
git clone https://github.com/MGcarva/sanos_y_salvos.git
cd sanos_y_salvos
```

---

## Paso 2 — Crear el archivo .env

Crea un archivo llamado `.env` en la raíz del proyecto con este contenido exacto.
**No subas este archivo a GitHub** (ya está en .gitignore).

```env
# ============================================================
#  Sanos y Salvos — Variables de entorno (desarrollo local)
# ============================================================

# --- PostgreSQL ---
POSTGRES_USER=sanos_admin
POSTGRES_PASSWORD=sanos_pass_2024

# --- Credenciales de BD para microservicios ---
DB_USER=sanos_admin
DB_PASS=sanos_pass_2024

# --- Redis ---
REDIS_PASS=redis_sanos_2024

# --- JWT (clave hex de 64 caracteres) ---
JWT_SECRET=900e3b1684f94a5dc9fabea59479207fe1f3e8b222785f8c756531ac146e4caf

# --- RabbitMQ ---
RABBITMQ_DEFAULT_USER=sanos_rabbit
RABBITMQ_DEFAULT_PASS=rabbit_sanos_2024
RABBITMQ_USER=sanos_rabbit
RABBITMQ_PASS=rabbit_sanos_2024

# --- MinIO (almacenamiento de fotos) ---
MINIO_ROOT_USER=minio_admin
MINIO_ROOT_PASSWORD=minio_sanos_2024
MINIO_ACCESS_KEY=minio_admin
MINIO_SECRET_KEY=minio_sanos_2024
MINIO_BUCKET=sanos-fotos

# --- Google Maps (opcional — solo para geocodificación en ms-geolocalizacion) ---
GOOGLE_MAPS_API_KEY=TU_API_KEY_AQUI
```

> **Nota sobre JWT_SECRET**: debe ser una cadena hexadecimal de exactamente 64 caracteres (32 bytes).
> Puedes generar una nueva con: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"` o usar la del ejemplo.

> **Nota sobre Google Maps**: si no tienes una API key, deja el valor `TU_API_KEY_AQUI`. El sistema funciona sin ella (la geocodificación del formulario usa OpenStreetMap/Nominatim que es gratuito sin key).

---

## Paso 3 — Levantar el sistema

### Windows (PowerShell)
```powershell
.\iniciar.ps1
```

### Windows (VSCode)
Abre el proyecto en VSCode y presiona `Ctrl+Shift+B`

### Cualquier sistema operativo (terminal)
```bash
docker compose -f docker-compose.yml -f docker-compose.n8n.yml up -d
```

El primer arranque descarga y compila todas las imágenes. **Puede tardar 5-15 minutos** dependiendo de tu internet y CPU.

### Verificar que todo esté corriendo

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Deberías ver estos contenedores con estado `healthy` o `Up`:

```
sanos-frontend          Up (healthy)
sanos-bff-service       Up (healthy)
sanos-auth-service      Up (healthy)
sanos-ms-mascotas       Up (healthy)
sanos-ms-geolocalizacion Up (healthy)
sanos-ms-coincidencias  Up (healthy)
sanos-postgres          Up (healthy)
sanos-redis             Up (healthy)
sanos-rabbitmq          Up (healthy)
sanos-minio             Up (healthy)
sanos-mailhog           Up
sanos-n8n               Up
```

> Los microservicios Spring Boot tardan ~2-3 minutos en pasar de `starting` a `healthy`. Es normal.

---

## Paso 4 — URLs de acceso

| Servicio | URL | Credenciales |
|---|---|---|
| **Plataforma** | http://localhost:3000 | Registra una cuenta nueva |
| **n8n (Agente IA)** | http://localhost:5678 | Sin contraseña (dev mode) |
| **API BFF** | http://localhost:9090/swagger-ui.html | — |
| **MinIO** | http://localhost:9001 | minio_admin / minio_sanos_2024 |
| **Mailhog** (emails) | http://localhost:8025 | Sin contraseña |
| **RabbitMQ** | http://localhost:15672 | sanos_rabbit / rabbit_sanos_2024 |

---

## Paso 5 — Configurar el Agente Amigo (n8n + Claude AI)

El agente virtual requiere una **API key de Anthropic** para funcionar. Los pasos son:

### 5.1 Obtener API key de Anthropic
1. Ve a https://console.anthropic.com
2. Crea una cuenta (hay créditos gratuitos para probar)
3. En **API Keys** → crea una nueva key → cópiala

### 5.2 Importar el workflow en n8n
1. Abre http://localhost:5678
2. Menú lateral → **Workflows** → botón **+** (o `Ctrl+I`)
3. Selecciona **Import from file**
4. Elige el archivo `IMPORTAR-BUSQUEDA-EN-N8N.json` de la raíz del proyecto
5. El workflow "Sanos y Salvos - Amigo (Busqueda)" aparecerá en la lista

### 5.3 Agregar la credencial de Anthropic en n8n
1. En n8n → menú lateral → **Credentials** → **Add Credential**
2. Busca `Anthropic` → selecciónalo
3. Pega tu API key en el campo correspondiente
4. Guarda con el nombre `Anthropic account` (ese nombre exacto lo espera el workflow)

### 5.4 Activar el workflow
1. Abre el workflow "Sanos y Salvos - Amigo (Busqueda)"
2. Revisa que el nodo de Claude no tenga error (debe mostrar la credencial Anthropic)
3. Activa el workflow con el toggle **Active** (arriba a la derecha)
4. El webhook queda disponible en: `http://localhost:5678/webhook/sanos-chat`

### 5.5 Verificar que el chat funciona
1. Abre http://localhost:3000
2. Haz clic en el botón de chat flotante (esquina inferior derecha)
3. Escribe: `hola, busco un gato perdido en Santiago`
4. Amigo debería responder con contención emocional y ofrecerse a buscar

---

## Paso 6 — Registrar un usuario y probar la plataforma

1. Abre http://localhost:3000
2. Clic en **Registrarse**
3. Completa nombre, email y contraseña
4. El email de verificación llega a **Mailhog** (http://localhost:8025) — no a tu correo real
5. Abre Mailhog, encuentra el email de verificación y haz clic en el enlace
6. Inicia sesión con tus credenciales
7. Prueba crear un reporte: **Nuevo Reporte** → completa los 3 pasos → envía

---

## Apagar el sistema

```bash
# Apagar sin borrar datos
docker compose -f docker-compose.yml -f docker-compose.n8n.yml down

# Apagar Y borrar todos los datos (base de datos, fotos, etc.)
docker compose -f docker-compose.yml -f docker-compose.n8n.yml down -v
```

---

## Troubleshooting — Problemas comunes

### El frontend no carga (http://localhost:3000 da error)
```bash
# Ver logs del frontend
docker logs sanos-frontend --tail 50

# Reconstruir solo el frontend
docker compose up -d --build frontend
```

### Error al crear reporte (403 o error de autenticación)
- Cierra sesión y vuelve a iniciar sesión para obtener un token fresco
- Si el problema persiste, revisa los logs del BFF: `docker logs sanos-bff-service --tail 50`

### Un microservicio no levanta o está en restart loop
```bash
# Ver logs de cualquier servicio
docker logs sanos-ms-mascotas --tail 100
docker logs sanos-auth-service --tail 100
docker logs sanos-bff-service --tail 100

# Reiniciar un servicio específico
docker compose restart ms-mascotas
```

### El agente Amigo no responde
- Verifica que el workflow esté **activo** en n8n (http://localhost:5678)
- Verifica que la credencial Anthropic esté configurada en el nodo de Claude
- Prueba el webhook directamente:
  ```bash
  curl -X POST http://localhost:5678/webhook/sanos-chat \
    -H "Content-Type: application/json" \
    -d '{"sessionId":"test1","message":"hola"}'
  ```

### Puerto ya en uso
Si algún puerto (3000, 5678, 9090, etc.) ya lo usa otra aplicación:
```bash
# Windows — ver qué proceso usa el puerto 3000
netstat -ano | findstr :3000

# Cambiar el puerto en docker-compose.yml:
# ports:
#   - "3001:3000"   ← cambia el primer número
```

### Reinicio limpio completo
```bash
# Borra todo y empieza desde cero
docker compose -f docker-compose.yml -f docker-compose.n8n.yml down -v
docker system prune -f
docker compose -f docker-compose.yml -f docker-compose.n8n.yml up -d
```

---

## Tecnologías

| Capa | Tecnología |
|---|---|
| Frontend | React 18 + Vite + Bootstrap 5 + React-Leaflet |
| API Gateway | Spring Boot 3 (BFF pattern) |
| Microservicios | Spring Boot 3 — mascotas, geolocalización, coincidencias, auth |
| Base de datos | PostgreSQL 15 + PostGIS (geometría espacial) |
| Almacenamiento | MinIO (S3-compatible, fotos de mascotas) |
| Mensajería | RabbitMQ 3.12 (eventos entre microservicios) |
| Caché | Redis 7 |
| Email (dev) | Mailhog |
| Agente IA | n8n + Claude Sonnet (Anthropic) |
| Seguridad | JWT stateless, Spring Security 6 |

---

## Estructura del proyecto

```
sanos_y_salvos/
├── frontend/                          # React + Vite
│   ├── src/
│   │   ├── components/
│   │   │   ├── ChatWidget.jsx         # Chat flotante con Amigo
│   │   │   └── ReporteMap.jsx         # Mapa interactivo con marcadores
│   │   ├── pages/
│   │   │   ├── Reportar.jsx           # Formulario 3 pasos
│   │   │   ├── MisReportes.jsx        # Reportes del usuario
│   │   │   └── Mapa.jsx               # Vista del mapa
│   │   ├── services/
│   │   │   ├── api.js                 # Axios + interceptor JWT
│   │   │   └── services.js            # Endpoints de la API
│   │   └── contexts/AuthContext.jsx   # Sesión del usuario
│   └── Dockerfile
├── bff-service/                       # API Gateway (puerto 9090)
├── auth-service/                      # Autenticación JWT (puerto 8091)
├── ms-mascotas/                       # Reportes + fotos (puerto 8092)
├── ms-geolocalizacion/                # Mapa de calor + clusters (puerto 8093)
├── ms-coincidencias/                  # Matching de mascotas (puerto 8094)
├── scripts/
│   ├── init-db.sql                    # Crea las 4 bases de datos
│   └── rabbitmq-definitions.json      # Exchanges y queues de RabbitMQ
├── docker-compose.yml                 # Stack principal
├── docker-compose.n8n.yml             # Agente Amigo (n8n)
├── IMPORTAR-BUSQUEDA-EN-N8N.json      # Workflow del agente para importar
├── iniciar.ps1                        # Script inicio rápido (Windows)
└── .env                               # Variables de entorno (NO subir a git)
```

---

## Repositorio

https://github.com/MGcarva/sanos_y_salvos
