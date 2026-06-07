# Sanos y Salvos

Plataforma para reportar y encontrar mascotas perdidas en Chile. Permite publicar reportes de mascotas perdidas o encontradas, visualizarlas en un mapa interactivo y contar con un asistente virtual (Amigo) que guía a los usuarios y busca mascotas por zona.

---

## Tecnologías

| Capa | Tecnología |
|------|-----------|
| Frontend | React + Vite + Bootstrap 5 + React-Leaflet |
| API Gateway | Spring Boot (BFF) |
| Microservicios | Spring Boot (mascotas, geolocalización, coincidencias, auth) |
| Base de datos | PostgreSQL + PostGIS |
| Almacenamiento | MinIO (fotos) |
| Mensajería | RabbitMQ |
| Caché | Redis |
| Email | Mailhog (desarrollo) |
| Agente IA | n8n + Claude Sonnet (Anthropic) |

---

## Arquitectura

```
Usuario
  │
  ├── Frontend (React) :3000
  │     └── BFF (Spring Boot) :9090
  │           ├── ms-mascotas :8092
  │           ├── ms-geolocalizacion :8093
  │           ├── ms-coincidencias :8094
  │           └── auth-service :8091
  │
  └── Chat Widget
        └── n8n (Agente Amigo) :5678
              ├── Tool: Buscar Mascotas → BFF :9090
              └── Tool: Geocodificar Comuna → Nominatim API
```

---

## Iniciar el sistema

### Opción 1 — VSCode (recomendada)
Abre el proyecto en VSCode y presiona **Ctrl+Shift+B**

### Opción 2 — PowerShell
```powershell
.\iniciar.ps1
```

El script levanta todos los servicios, espera que estén listos y muestra las URLs de acceso.

### URLs disponibles
| Servicio | URL |
|----------|-----|
| Plataforma | http://localhost:3000 |
| Agente n8n | http://localhost:5678 |
| API (BFF) | http://localhost:9090 |
| MinIO | http://localhost:9001 |
| Mailhog | http://localhost:8025 |
| RabbitMQ | http://localhost:15672 |

---

## Funcionalidades implementadas

### Mapa interactivo
- Marcadores rojos (PERDIDO) y verdes (ENCONTRADO) por cada reporte
- **Hover** sobre un marcador: muestra todos los datos del animal (foto, especie, raza, nombre, color, dirección, fecha, recompensa)
- **Clic** sobre un marcador: popup con botón para ver contacto y detalle completo
- Filtro por tipo: Todos / Perdidos / Encontrados

### Formulario de reporte (3 pasos)

**Paso 1 — Datos de la mascota**
- Tipo: PERDIDO o ENCONTRADO
- Especie con autocompletado de razas desde APIs externas:
  - **Perro** → Dog CEO API (gratuita, +150 razas)
  - **Gato** → The Cat API (gratuita)
  - Otras especies → texto libre
- Nombre, color, tamaño, descripción, fecha, recompensa (opcional)

**Paso 2 — Ubicación (Nominatim / OpenStreetMap)**
- Buscador de dirección: escribe una dirección y el mapa vuela al lugar automáticamente
- Al hacer clic en el mapa o usar GPS, el campo dirección se rellena solo con la dirección real (geocodificación inversa)
- Integración 100% gratuita con OpenStreetMap

**Paso 3 — Foto**
- Sube foto JPG o PNG (máximo 10MB)
- Almacenada en MinIO

### Agente Amigo (n8n + Claude)
Asistente virtual accesible desde el chat flotante en la plataforma.

**Capacidades:**
- Contención emocional al usuario
- Búsqueda de mascotas por comuna usando coordenadas geográficas reales:
  1. Llama a **Nominatim** para obtener el bounding box de la comuna
  2. Consulta el API de la plataforma para obtener todos los reportes
  3. Filtra por lat/lng dentro del bounding box → encuentra mascotas aunque la dirección solo diga el nombre de la calle
- Guía paso a paso para crear un reporte
- Tips de búsqueda para mascotas perdidas
- Funciona para cualquier comuna de Chile

**Workflow n8n:**
- Archivo de importación: `IMPORTAR-BUSQUEDA-EN-N8N.json`
- Importar en n8n → Settings → Import from file → activar workflow

---

## APIs externas integradas (todas gratuitas)

| API | Uso | Límite |
|-----|-----|--------|
| [Nominatim (OpenStreetMap)](https://nominatim.openstreetmap.org) | Geocodificación en formulario y búsqueda del agente | Sin límite estricto |
| [Dog CEO API](https://dog.ceo/dog-api) | Autocompletado de razas de perros | Sin límite |
| [The Cat API](https://thecatapi.com) | Autocompletado de razas de gatos | 1000/mes gratis |

---

## Estructura del proyecto

```
Sanos-y-Salvos-main/
├── frontend/                        # React + Vite
│   ├── src/
│   │   ├── components/
│   │   │   ├── ReporteMap.jsx       # Mapa con tooltip hover y popup
│   │   │   └── ChatWidget.jsx       # Widget de chat flotante
│   │   ├── pages/
│   │   │   ├── Mapa.jsx             # Página del mapa (usa dashboardService)
│   │   │   └── Reportar.jsx         # Formulario 3 pasos con Nominatim + APIs de razas
│   │   └── services/
│   │       └── services.js          # Servicios HTTP
│   └── Dockerfile                   # Multi-stage: Node build + Nginx
├── bff-service/                     # API Gateway Spring Boot
├── ms-mascotas/                     # Microservicio mascotas
├── ms-geolocalizacion/              # Microservicio geolocalización
├── ms-coincidencias/                # Microservicio coincidencias automáticas
├── auth-service/                    # Autenticación JWT
├── docker-compose.yml               # Todos los servicios
├── docker-compose.n8n.yml           # n8n (agente)
├── IMPORTAR-BUSQUEDA-EN-N8N.json    # Workflow n8n con búsqueda geográfica
├── build_busqueda.py                # Script para regenerar el workflow n8n
├── iniciar.ps1                      # Script de inicio rápido
└── .vscode/
    └── tasks.json                   # Tarea VSCode (Ctrl+Shift+B)
```

---

## Rebuild del frontend

Cada vez que se modifique el código del frontend:

```powershell
# 1. Compilar
cd frontend
npm run build

# 2. Reconstruir imagen Docker (cambios permanentes)
cd ..
docker compose up -d --build frontend
```

---

## Regenerar workflow del agente n8n

Si se modifica el system message o las herramientas del agente:

```powershell
cd ..   # directorio raíz (Sanos-y-Salvos-main/)
python build_busqueda.py
```

Luego importar el archivo `IMPORTAR-BUSQUEDA-EN-N8N.json` en n8n.

---

## Repositorio

[github.com/MGcarva/sanos_y_salvos](https://github.com/MGcarva/sanos_y_salvos)
