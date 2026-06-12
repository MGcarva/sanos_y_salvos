# Sanos y Salvos — Presentación Técnica del Proyecto

> **Documento de referencia técnica** para la revisión ejecutiva del proyecto.  
> Versión: 1.0 · Fecha: Mayo 2026 · Clasificación: Interno

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Problema y Propuesta de Valor](#2-problema-y-propuesta-de-valor)
3. [Arquitectura General del Sistema](#3-arquitectura-general-del-sistema)
4. [Stack Tecnológico Consolidado](#4-stack-tecnológico-consolidado)
5. [Microservicios del Backend](#5-microservicios-del-backend)
   - [auth-service](#51-auth-service--autenticación-y-autorización)
   - [ms-mascotas](#52-ms-mascotas--gestión-de-reportes)
   - [ms-geolocalizacion](#53-ms-geolocalizacion--procesamiento-geográfico)
   - [ms-coincidencias](#54-ms-coincidencias--motor-de-matching)
   - [bff-service](#55-bff-service--backend-for-frontend)
6. [Frontend Web](#6-frontend-web)
7. [Modelo de Datos](#7-modelo-de-datos)
8. [Patrones de Diseño Implementados](#8-patrones-de-diseño-implementados)
9. [Infraestructura en la Nube (AWS + Terraform)](#9-infraestructura-en-la-nube-aws--terraform)
10. [Estrategia de Contenedores y Despliegue](#10-estrategia-de-contenedores-y-despliegue)
11. [Seguridad](#11-seguridad)
12. [Calidad y Pruebas](#12-calidad-y-pruebas)
13. [Estrategia de Control de Versiones](#13-estrategia-de-control-de-versiones)
14. [Flujo de Datos End-to-End](#14-flujo-de-datos-end-to-end)
15. [Decisiones de Arquitectura Clave](#15-decisiones-de-arquitectura-clave)

---

## 1. Resumen Ejecutivo

**Sanos y Salvos** es una plataforma web full-stack para la búsqueda y reencuentro de mascotas perdidas. El sistema permite a ciudadanos publicar reportes de mascotas perdidas o encontradas, visualizarlos en un mapa interactivo y recibir notificaciones de posibles coincidencias calculadas automáticamente por el sistema.

El proyecto está construido sobre una **arquitectura de microservicios** desplegada en **AWS**, con un backend en **Java 21 / Spring Boot 3.2**, un frontend en **React 18**, infraestructura gestionada con **Terraform** e integración continua mediante contenedores **Docker**.

| Indicador | Valor |
|-----------|-------|
| Microservicios de backend | 5 (auth, mascotas, geolocalizacion, coincidencias, bff) |
| Frontend | React 18 + Vite |
| Bases de datos | PostgreSQL 15 (4 esquemas separados) + PostGIS |
| Mensajería asíncrona | RabbitMQ 3.12 |
| Caché | Redis 7 (ElastiCache) |
| Almacenamiento de imágenes | Amazon S3 / MinIO |
| Infraestructura como código | Terraform (AWS) |
| Patrón de despliegue | Docker Compose (dev) + EC2 + ECS (prod) |
| Java versión | 21 (LTS) |
| Spring Boot versión | 3.2.5 |

---

## 2. Problema y Propuesta de Valor

### 2.1 Problema

Cada año, miles de mascotas se pierden sin que sus dueños tengan una forma centralizada, rápida y automatizada de cruzar información con personas que hayan encontrado animales en la zona. Los mecanismos actuales (grupos de redes sociales, carteles físicos) son ineficientes, no geolocalizados y no cuentan con inteligencia para sugerir coincidencias.

### 2.2 Solución

La plataforma ataca el problema desde tres ángulos:

1. **Reportes estructurados:** Un usuario puede publicar "mascota perdida" o "mascota encontrada" con foto, descripción y coordenadas geográficas.
2. **Mapa en tiempo real:** Todos los reportes activos se visualizan en un mapa interactivo con clusters y mapa de calor.
3. **Matching automático:** El sistema compara automáticamente los reportes nuevos contra los existentes usando un algoritmo de similitud difusa multi-criterio y notifica al usuario si hay coincidencias probables.

---

## 3. Arquitectura General del Sistema

El sistema adopta una arquitectura **orientada a microservicios** con comunicación mixta: REST síncrono para las operaciones del cliente final y mensajería asíncrona con RabbitMQ para los procesos internos de geolocalización y matching.

```
┌────────────────────────────────────────────────────────────────────┐
│                          INTERNET / CLIENTE                        │
└───────────────────────────────┬────────────────────────────────────┘
                                │
                    ┌───────────▼───────────┐
                    │ Application Load      │
                    │ Balancer (ALB - AWS)  │
                    └───────────┬───────────┘
                                │
                    ┌───────────▼───────────┐
                    │   Frontend React      │
                    │   (S3 + CloudFront    │
                    │    o Nginx/EC2)       │
                    └───────────┬───────────┘
                                │ HTTP/HTTPS
                    ┌───────────▼───────────┐
                    │     bff-service       │  ← Puerto 8080
                    │  (API Gateway / BFF)  │  ← Circuit Breaker (Resilience4j)
                    └─┬──────┬──────┬───┬──┘  ← Caché Redis
                      │      │      │   │
           ┌──────────┘  ┌───┘  ┌───┘   └────────────────┐
           │             │      │                         │
  ┌────────▼──┐  ┌───────▼──┐  ┌▼──────────────┐  ┌──────▼──────────┐
  │auth-service│  │ms-mascotas│  │ms-geolocalizacion│ │ms-coincidencias│
  │:8081       │  │:8082      │  │:8083            │ │:8084           │
  └─────┬──────┘  └──┬──┬───┘  └────────┬────────┘ └──────┬──────────┘
        │            │  │               │                  │
   ┌────▼────┐   ┌───▼┐ │         ┌────▼────┐        ┌────▼────┐
   │auth_db  │   │mas-│ │Evento   │geo_db   │        │coinc_db │
   │(PG15)   │   │cot-│ │RabbitMQ │(PostGIS)│        │(PG15)   │
   └─────────┘   │as_ │ └──┬──────┴─────────┘        └─────────┘
                 │db  │    │
                 │(PG)│  ┌─▼──────────┐
                 └────┘  │  RabbitMQ  │
                  │      │  3.12      │
                ┌─▼──┐   └────────────┘
                │ S3 │ (fotos mascotas)
                └────┘

     ─── Redis (ElastiCache) disponible para auth-service y bff-service ───
```

### 3.1 Principios arquitectónicos aplicados

| Principio | Implementación |
|-----------|---------------|
| Single Responsibility | Cada microservicio tiene un único dominio de negocio |
| Desacoplamiento | Comunicación asíncrona vía RabbitMQ entre servicios de dominio |
| Resiliencia | Circuit Breaker (Resilience4j) en bff-service |
| Escalabilidad horizontal | Cada servicio es un contenedor Docker independiente |
| Seguridad por capas | JWT validado en cada servicio + Spring Security |
| Infraestructura inmutable | Terraform gestiona toda la infraestructura AWS |

---

## 4. Stack Tecnológico Consolidado

### Backend

| Componente | Tecnología | Versión |
|-----------|-----------|---------|
| Lenguaje | Java | 21 (LTS) |
| Framework | Spring Boot | 3.2.5 |
| Seguridad | Spring Security | 6.x |
| ORM | Spring Data JPA / Hibernate | 3.x |
| Mensajería | Spring AMQP (RabbitMQ) | 3.x |
| HTTP reactivo | Spring WebFlux (WebClient) | 6.x |
| JWT | JJWT | 0.12.3 |
| Resiliencia | Resilience4j | 2.x |
| Datos espaciales | Hibernate Spatial + PostGIS | 6.x |
| Almacenamiento objetos | MinIO Client | 8.5.7 |
| Fuzzy matching | FuzzyWuzzy (me.xdrop) | 1.4.0 |
| API Docs | SpringDoc OpenAPI (Swagger UI) | 2.3.0 |
| Reducción boilerplate | Lombok | 1.18.42 |
| Build | Maven | 3.9+ |
| Cobertura | JaCoCo | 0.8.11 |

### Frontend

| Componente | Tecnología | Versión |
|-----------|-----------|---------|
| Lenguaje | JavaScript (ES Modules) | — |
| Framework UI | React | 18.3.1 |
| Bundler | Vite | 5.3.1 |
| Enrutamiento | React Router DOM | 6.23.1 |
| HTTP Client | Axios | 1.7.2 |
| Mapas interactivos | Leaflet + React Leaflet | 1.9.4 / 4.2.1 |
| Gráficos | Recharts | 2.12.7 |
| UI Framework | Bootstrap | 5.3.3 |
| Testing | Vitest + Testing Library | 1.6.0 |
| Servidor estático | Nginx | Alpine |

### Infraestructura y datos

| Componente | Tecnología | Versión |
|-----------|-----------|---------|
| Base de datos principal | PostgreSQL | 15 |
| Extensión espacial | PostGIS | 3.4 |
| Caché y sesiones | Redis | 7 |
| Message broker | RabbitMQ | 3.12 |
| Almacenamiento de objetos | Amazon S3 / MinIO | — |
| IaC | Terraform | — |
| Nube | AWS (Academy) | us-east-1 |
| Contenedores | Docker + Docker Compose | — |
| Registro de imágenes | Amazon ECR | — |
| Orquestación (prod) | Amazon ECS | — |
| Servidor (prod) | Amazon EC2 | — |
| Load Balancer | AWS ALB | — |

---

## 5. Microservicios del Backend

El backend sigue una estructura multi-módulo Maven con un POM padre (`com.sanosysalvos:sanos-y-salvos-parent:1.0.0`) que centraliza la gestión de dependencias y versiones compartidas.

```
sanos-y-salvos-parent (pom.xml raíz)
├── auth-service
├── ms-mascotas
├── ms-geolocalizacion
├── ms-coincidencias
└── bff-service
```

---

### 5.1 auth-service — Autenticación y Autorización

**Puerto:** `8081` | **Base de datos:** `auth_db`

#### Responsabilidades
- Registro de nuevos usuarios con verificación de correo electrónico
- Login con generación de tokens JWT (access token + refresh token)
- Renovación de tokens mediante endpoint de refresh
- Protección contra fuerza bruta mediante rate limiting por IP (Redis)
- Invalidación de tokens (blacklist en Redis)
- Gestión de estado de cuenta: bloqueo tras intentos fallidos, desbloqueo por expiración

#### Arquitectura interna

```
auth-service/
└── com.sanosysalvos.auth/
    ├── controller/    AuthController  (register, login, refresh, verify-email)
    ├── service/       AuthService, EmailService, RateLimitService
    ├── domain/        User (entidad JPA), UserSecurityStatus
    ├── repository/    UserRepository, RefreshTokenRepository
    └── config/        JwtUtils, JwtAuthFilter, SecurityConfig
```

#### Dependencias principales

```
Spring Boot Web · Spring Security · Spring Data JPA
Spring Data Redis · Spring Mail · JJWT 0.12.3
PostgreSQL 15 · Bean Validation · Lombok
```

#### Flujo de autenticación

```
Cliente  →  POST /auth/login
         ←  { accessToken (15 min), refreshToken (7 días) }
         →  POST /auth/refresh (con refreshToken)
         ←  { nuevo accessToken }
         →  POST /auth/logout (invalida tokens en Redis)
```

---

### 5.2 ms-mascotas — Gestión de Reportes

**Puerto:** `8082` | **Base de datos:** `mascotas_db`

#### Responsabilidades
- CRUD completo de reportes de mascotas perdidas y encontradas
- Subida y gestión de fotografías en MinIO / S3
- Publicación de eventos en RabbitMQ al crear un nuevo reporte
- Validación de datos de entrada (Bean Validation)
- Filtros de búsqueda por tipo, estado, fecha y zona

#### Arquitectura interna

```
ms-mascotas/
└── com.sanosysalvos.mascotas/
    ├── controller/    ReporteController
    ├── service/       ReporteService, MinioService, EventPublisher
    ├── factory/       ReporteFactory  ← Factory Method Pattern
    ├── domain/        Reporte (base), ReportePerdido, ReporteEncontrado
    ├── dto/           ReporteRequestDTO, ReporteResponseDTO
    ├── repository/    ReporteRepository
    ├── events/        ReporteNuevoEvent
    └── config/        MinioConfig, RabbitMQConfig, SecurityConfig, JwtAuthFilter
```

#### Patrón Factory Method

```java
// ReporteFactory.java
public Reporte crear(ReporteRequestDTO dto) {
    return switch (dto.getTipo()) {
        case PERDIDO    -> new ReportePerdido(dto);
        case ENCONTRADO -> new ReporteEncontrado(dto);
    };
}
```

El controlador delega la creación al factory, desacoplando la lógica de instanciación de la lógica de negocio.

#### Flujo de creación de reporte

```
POST /reportes  →  ReporteController
               →  ReporteFactory.crear(dto)        ← Factory Method
               →  MinioService.subirFoto(imagen)   ← S3/MinIO
               →  ReporteRepository.save(reporte)  ← PostgreSQL
               →  EventPublisher.publish(event)    ← RabbitMQ
```

---

### 5.3 ms-geolocalizacion — Procesamiento Geográfico

**Puerto:** `8083` | **Base de datos:** `geolocalizacion_db` (PostGIS)

#### Responsabilidades
- Suscripción al evento `reporte.nuevo` de RabbitMQ
- Geocodificación inversa y almacenamiento de coordenadas con tipos espaciales PostGIS
- Cálculo de clusters geográficos usando algoritmo K-means
- Generación de datos de mapa de calor (heatmap) para el frontend
- Publicación del evento `geo.completado` tras procesar la ubicación

#### Arquitectura interna

```
ms-geolocalizacion/
└── com.sanosysalvos.geolocalizacion/
    ├── controller/    GeoController  (heatmaps, clusters)
    ├── service/       GeocodingService, HeatmapService, ClusteringService
    ├── listener/      GeolocalizacionListener  ← Observer Pattern
    ├── domain/        UbicacionReporte
    ├── repository/    UbicacionRepository
    └── config/        RabbitMQConfig, JwtAuthFilter
```

#### Flujo de eventos

```
ms-mascotas → [RabbitMQ: reporte.nuevo] → GeolocalizacionListener
    → guarda coordenadas (PostGIS)
    → calcula clusters (K-means)
    → publica [RabbitMQ: geo.completado] → ms-coincidencias
```

#### Tecnología espacial

Usa **Hibernate Spatial** con **PostGIS 3.4** sobre PostgreSQL 15. Permite almacenar puntos geográficos como tipos nativos `GEOMETRY` y realizar consultas espaciales eficientes (distancias, bounding boxes, clusters).

---

### 5.4 ms-coincidencias — Motor de Matching

**Puerto:** `8084` | **Base de datos:** `coincidencias_db`

#### Responsabilidades
- Suscripción al evento `geo.completado` de RabbitMQ
- Comparación del nuevo reporte contra todos los reportes activos del tipo contrario
- Cálculo de un puntaje de similitud multi-criterio
- Persistencia de coincidencias con score ≥ umbral configurable
- Exposición de coincidencias por reporte vía REST

#### Arquitectura interna

```
ms-coincidencias/
└── com.sanosysalvos.coincidencias/
    ├── controller/    CoincidenciaController
    ├── service/       CoincidenciaService, ScoringService, CandidateLoaderService
    ├── listener/      CoincidenciasListener  ← Observer Pattern
    ├── domain/        Coincidencia
    ├── dto/           CandidatoDTO
    ├── repository/    CoincidenciaRepository
    └── config/        RabbitMQConfig, JwtAuthFilter
```

#### Algoritmo de Scoring (Strategy Pattern)

`ScoringService` encapsula el algoritmo de puntuación compuesta, intercambiable sin modificar `CoincidenciaService`:

| Criterio | Herramienta | Peso |
|---------|-------------|------|
| Similitud del nombre | FuzzyWuzzy (ratio) | 40% |
| Similitud de descripción | FuzzyWuzzy (partial ratio) | 30% |
| Distancia geográfica (km) | Fórmula Haversine | 20% |
| Diferencia temporal (horas) | Delta timestamp | 10% |

Solo se persisten y retornan coincidencias con **score ≥ umbral** (configurable por variable de entorno).

---

### 5.5 bff-service — Backend For Frontend

**Puerto:** `8080` | **Dependencias externas:** auth:8081, mascotas:8082, geo:8083, coincidencias:8084

#### Responsabilidades
- Punto de entrada único para el cliente React (API Gateway)
- Validación y reenvío de tokens JWT
- Agregación de respuestas para el dashboard (llamadas compuestas)
- Circuit Breaker con Resilience4j: aísla fallos de microservicios individuales
- Caché de respuestas frecuentes en Redis
- Manejo centralizado de errores y respuestas de fallback

#### Arquitectura interna

```
bff-service/
└── com.sanosysalvos.bff/
    ├── controller/    ReportesController, DashboardController,
    │                  GeoController, AuthController, CoincidenciasController
    ├── service/       AuthProxyService, MascotasProxyService,
    │                  CoincidenciasProxyService, GeoProxyService, DashboardService
    ├── filter/        JwtAuthFilter
    └── config/        RestTemplateConfig, SecurityConfig, GlobalExceptionHandler
```

#### Circuit Breaker

```
bff-service
  └── llama a ms-mascotas (via MascotasProxyService)
       ├── Estado CLOSED:  peticiones fluyen normalmente
       ├── Estado OPEN:    umbral de fallos superado → respuesta fallback inmediata
       └── Estado HALF-OPEN: prueba si el servicio se recuperó
```

El frontend nunca recibe un timeout bloqueante; siempre obtiene una respuesta (éxito o fallback graceful) en tiempo acotado.

---

## 6. Frontend Web

### 6.1 Estructura del proyecto

```
frontend/src/
├── App.jsx              ← Router principal
├── main.jsx             ← Entry point React + Bootstrap
├── contexts/
│   └── AuthContext.jsx  ← Context Provider (estado de sesión global)
├── components/
│   ├── Navbar.jsx
│   ├── Footer.jsx
│   ├── PrivateRoute.jsx ← Guarda de rutas protegidas
│   └── ReporteMap.jsx   ← Mapa Leaflet embebible
├── pages/
│   ├── Home.jsx
│   ├── Login.jsx
│   ├── Register.jsx
│   ├── VerifyEmail.jsx
│   ├── Reportar.jsx         ← Formulario de nuevo reporte con geolocalización
│   ├── MascotasPerdidas.jsx ← Listado + filtros
│   ├── MascotasEncontradas.jsx
│   ├── MisReportes.jsx      ← Dashboard personal del usuario
│   ├── ReporteDetalle.jsx   ← Detalle + coincidencias sugeridas
│   ├── Mapa.jsx             ← Mapa interactivo con heatmap y clusters
│   ├── Estadisticas.jsx     ← Gráficos con Recharts
│   └── NotFound.jsx
└── services/            ← Módulos de llamadas a bff-service vía Axios
```

### 6.2 Páginas y funcionalidades

| Página | Funcionalidad |
|--------|--------------|
| `Home` | Landing page con acceso a reportes recientes |
| `Login / Register` | Autenticación con validación y verificación de email |
| `Reportar` | Formulario con captura de coordenadas del navegador + upload de foto |
| `MascotasPerdidas / Encontradas` | Listado paginado con filtros por tipo, fecha y zona |
| `Mapa` | Mapa Leaflet con markers, heatmap y clusters dinámicos |
| `ReporteDetalle` | Información completa + coincidencias sugeridas con scores |
| `MisReportes` | Gestión personal de los reportes del usuario autenticado |
| `Estadisticas` | Gráficos de barras, líneas y torta con datos agregados (Recharts) |

### 6.3 Autenticación en el frontend

`AuthContext` implementa el patrón **Context/Provider** de React para evitar prop drilling. El token JWT se almacena de forma segura y se inyecta automáticamente en cada petición Axios mediante interceptores. `PrivateRoute` protege las rutas que requieren autenticación, redirigiendo al login si el token es inválido o inexistente.

### 6.4 Build y servidor estático

El frontend se construye con **Vite** (`npm run build`) generando assets estáticos optimizados. En producción se sirven mediante un contenedor **Nginx Alpine**, cuya configuración (`nginx.conf`) maneja el routing SPA (Single Page Application) redirigiendo todas las rutas al `index.html`.

---

## 7. Modelo de Datos

El sistema utiliza **cuatro bases de datos PostgreSQL independientes**, una por dominio de negocio. Las referencias cruzadas entre bases de datos se resuelven a nivel de aplicación, no con foreign keys SQL, preservando el aislamiento entre microservicios.

### 7.1 `auth_db`

```sql
roles               (id, name)
users               (id UUID PK, nombre, email UNIQUE, password_hash, rol_id FK,
                     created_at, is_active)
user_security_status (user_id FK PK, failed_attempts, is_locked, lock_expiry,
                      verification_token, verification_token_expiry, email_verified)
refresh_tokens      (id, user_id FK, token, expires_at, revoked)
```

### 7.2 `mascotas_db`

```sql
reporte_estados  (id, nombre)   -- ACTIVO, RESUELTO, ARCHIVADO
mascotas         (id UUID PK, nombre, especie, raza, color, descripcion, foto_url)
reportes         (id UUID PK, tipo, estado, user_id, mascota_id FK,
                  latitud, longitud, fecha_reporte, direccion)
```

### 7.3 `geolocalizacion_db` (PostGIS)

```sql
ubicaciones_reporte  (id UUID PK, reporte_id, tipo_reporte,
                      coordenadas GEOMETRY(Point, 4326),  -- tipo espacial PostGIS
                      fecha_procesado, cluster_id)
```

### 7.4 `coincidencias_db`

```sql
coincidencia_estados  (id, nombre)  -- PENDIENTE, CONFIRMADA, DESCARTADA
coincidencias         (id UUID PK, reporte_origen_id, reporte_candidato_id,
                       score DECIMAL, estado_id FK, created_at)
coincidencia_scores   (id, coincidencia_id FK, criterio, valor, peso)
```

---

## 8. Patrones de Diseño Implementados

El proyecto aplica de forma deliberada seis patrones de diseño reconocidos, distribuidos entre frontend y backend.

### 8.1 Factory Method — `ms-mascotas`

**Categoría:** Creacional (GoF)

**Problema:** El sistema gestiona dos tipos concretos de reporte (`ReportePerdido`, `ReporteEncontrado`). Sin el patrón, el servicio necesitaría `if/else` acoplando lógica de creación con lógica de negocio.

**Solución:** `ReporteFactory.crear(dto)` centraliza la instanciación. Agregar un nuevo tipo de reporte (ej. `ReporteAvistamiento`) solo requiere modificar la factory, no el servicio ni el controlador.

---

### 8.2 Observer — Comunicación por eventos (RabbitMQ)

**Categoría:** Comportamiento (GoF), adaptado a arquitectura distribuida

**Problema:** Al crear un reporte, tanto `ms-geolocalizacion` como `ms-coincidencias` necesitan reaccionar, pero `ms-mascotas` no debe conocerlos ni acoplarse a ellos.

**Solución:** `EventPublisher` (sujeto observable) publica `ReporteNuevoEvent` en RabbitMQ. `GeolocalizacionListener` y `CoincidenciasListener` (observadores) se suscriben independientemente. Se pueden agregar nuevos suscriptores sin tocar el publicador.

```
ms-mascotas → [RabbitMQ] → GeolocalizacionListener
                         → CoincidenciasListener
                         → [futuro] NotificacionesListener
```

---

### 8.3 Proxy — BFF Service

**Categoría:** Estructural (GoF)

**Problema:** El frontend necesita datos de múltiples microservicios. Llamadas directas implicarían problemas de CORS, múltiples autenticaciones y acoplamiento a la topología interna del sistema.

**Solución:** Cada `*ProxyService` en el BFF actúa como proxy transparente. El frontend solo conoce `bff-service:8080`. El BFF puede interceptar, transformar, cachear o agregar respuestas sin que el cliente lo note.

---

### 8.4 Strategy — `ScoringService` en `ms-coincidencias`

**Categoría:** Comportamiento (GoF)

**Problema:** El algoritmo de scoring puede evolucionar (diferentes pesos, nuevos criterios). Si está hardcodeado, cualquier cambio requiere modificar código de negocio.

**Solución:** `ScoringService` encapsula el algoritmo como una estrategia intercambiable. `CoincidenciaService` delega el cálculo sin conocer la implementación concreta.

| Criterio | Herramienta | Peso |
|---------|-------------|------|
| Nombre | FuzzyWuzzy | 40% |
| Descripción | FuzzyWuzzy | 30% |
| Ubicación GPS | Haversine | 20% |
| Temporalidad | Delta horas | 10% |

---

### 8.5 Context/Provider — Frontend React

**Categoría:** Comportamiento (patrón React)

**Problema:** El estado de autenticación (usuario, token JWT) debe estar disponible en toda la jerarquía de componentes sin pasar props manualmente por cada nivel.

**Solución:** `AuthContext.jsx` implementa un Context Provider global. `PrivateRoute.jsx` consume el contexto para proteger rutas. Todos los componentes acceden al estado de sesión sin prop drilling.

---

### 8.6 Circuit Breaker — `bff-service` con Resilience4j

**Categoría:** Resiliencia (patrón arquitectónico)

**Problema:** Si un microservicio cae o responde lento, el BFF acumularía threads bloqueados, propagando el fallo en cascada a toda la aplicación y al usuario.

**Solución:** Resilience4j implementa el Circuit Breaker en cada proxy del BFF. Cuando el número de fallos supera el umbral configurado, el circuito "abre" y retorna una respuesta de fallback inmediatamente, sin esperar timeout. El circuito se cierra automáticamente cuando el servicio se recupera.

---

## 9. Infraestructura en la Nube (AWS + Terraform)

Toda la infraestructura está definida como código con **Terraform**, lo que garantiza reproducibilidad, versionado y auditoría de cambios.

### 9.1 Recursos AWS aprovisionados

| Archivo Terraform | Recursos creados |
|------------------|-----------------|
| `vpc.tf` | VPC (`10.0.0.0/16`), subredes públicas y privadas, Internet Gateway, Route Tables |
| `security-groups.tf` | Security Groups para ALB, EC2, RDS, ElastiCache, ECS tasks |
| `rds.tf` | Amazon RDS PostgreSQL 15 (`db.t3.micro`), Multi-AZ opcional, backups automáticos |
| `elasticache.tf` | Amazon ElastiCache Redis 7 (`cache.t3.micro`), autenticación con contraseña |
| `s3.tf` | Bucket S3 para fotografías de mascotas, políticas de acceso, lifecycle rules |
| `ecr.tf` | Amazon ECR: repositorios de imágenes Docker por microservicio |
| `ecs.tf` | Amazon ECS: Task Definitions y Services para contenedores en producción |
| `alb.tf` | Application Load Balancer, Target Groups, Listeners HTTP/HTTPS, reglas de ruteo |
| `ec2.tf` | Instancia EC2 como Docker Host para los microservicios |
| `iam.tf` | Roles y políticas IAM para acceso a ECR, S3, Secrets Manager |
| `secrets.tf` | AWS Secrets Manager: credenciales de BD, Redis, JWT secret |
| `main.tf` | Configuración del backend de Terraform (estado remoto) |
| `provider.tf` | Provider AWS, región `us-east-1` |
| `variables.tf` | Variables parametrizables (proyecto, ambiente, clases de instancia, credenciales) |
| `outputs.tf` | Outputs: DNS del ALB, endpoint RDS, endpoint Redis, ARNs relevantes |

### 9.2 Diagrama de red

```
Internet
   │
   ▼
ALB (Application Load Balancer)
   │ /api/*
   ▼
EC2 (Docker Host)  ──── Docker Network ────┐
   │                                       │
   ├── bff-service      :8080              │
   ├── auth-service     :8081              │
   ├── ms-mascotas      :8082              │
   ├── ms-geolocalizacion :8083            │
   ├── ms-coincidencias  :8084             │
   └── rabbitmq          :5672/15672       │
                                           │
RDS PostgreSQL  ◄──────────────────────────┤
ElastiCache Redis ◄────────────────────────┤
S3 (fotos) ◄───────────────────────────────┘
```

### 9.3 Variables de infraestructura

| Variable | Descripción | Valor por defecto |
|---------|-------------|------------------|
| `proyecto` | Prefijo para todos los recursos | `sanos-y-salvos` |
| `ambiente` | Ambiente de despliegue | `prod` |
| `region` | Región AWS | `us-east-1` |
| `vpc_cidr` | Rango de IPs de la VPC | `10.0.0.0/16` |
| `db_instance_class` | Tipo de instancia RDS | `db.t3.micro` |
| `redis_node_type` | Tipo de nodo ElastiCache | `cache.t3.micro` |

---

## 10. Estrategia de Contenedores y Despliegue

### 10.1 Entorno de desarrollo (Docker Compose)

El archivo `docker-compose.yml` levanta el entorno completo con un solo comando:

```yaml
Servicios levantados:
  postgres    → postgis/postgis:15-3.4-alpine  (puerto 5432)
  redis       → redis:7-alpine                 (puerto 6380)
  rabbitmq    → rabbitmq:3.12-management       (puertos 5672, 15672)
  rabbitmq-init → carga definiciones automáticamente
  minio       → minio/minio:latest             (puertos 9000, 9001)
  minio-init  → crea bucket inicial
  mailhog     → mailhog/mailhog                (SMTP 2025, UI 8025)
  auth-service     → build local (8081)
  ms-mascotas      → build local (8082)
  ms-geolocalizacion → build local (8083)
  ms-coincidencias → build local (8084)
  bff-service      → build local (8080)
```

Todos los servicios cuentan con **healthchecks** configurados. Los microservicios esperan (`depends_on condition: service_healthy`) a que la infraestructura esté lista antes de arrancar, evitando condiciones de carrera en el startup.

### 10.2 Entorno de producción (AWS)

El despliegue en producción se realiza mediante scripts PowerShell:

| Script | Propósito |
|--------|-----------|
| `master-deploy.ps1` | Orquestador principal: ejecuta todos los pasos en orden |
| `deploy-backend.ps1` | Build Maven → Docker build → push a ECR → deploy en EC2 |
| `deploy-frontend.ps1` | `npm run build` → upload a S3 / Nginx |
| `register-backend.ps1` | Registra Task Definitions en ECS |
| `init-database.ps1` | Ejecuta scripts SQL de inicialización en RDS |
| `update-credentials.ps1` | Actualiza credenciales AWS Academy en Terraform |
| `smoke-test.ps1` | Pruebas de humo post-despliegue |

#### Flujo de despliegue CI/CD

```
1. developer hace push → rama feature/*
2. PR a develop → revisión
3. Merge a develop → trigger deploy
4. mvn clean package -DskipTests (todos los módulos)
5. docker build (imagen por microservicio)
6. docker push → Amazon ECR
7. aws ecs update-service (rolling update)
8. smoke-test.ps1 verifica endpoints clave
```

### 10.3 Dockerfiles

Cada microservicio tiene dos Dockerfiles:
- `Dockerfile` — desarrollo local (multi-stage build con JDK 21)
- `Dockerfile.deploy` — producción optimizado (imagen mínima, JRE 21 slim)

---

## 11. Seguridad

### 11.1 Autenticación y autorización

- **JWT stateless** con `accessToken` (15 min) y `refreshToken` (7 días)
- Cada microservicio valida el JWT de forma independiente mediante `JwtAuthFilter` (Spring Security)
- La clave secreta JWT se gestiona en **AWS Secrets Manager**, no en variables de entorno planas
- **Blacklist de tokens** en Redis: al hacer logout, el token queda invalidado antes de su expiración natural

### 11.2 Protección contra ataques

| Amenaza | Mitigación implementada |
|---------|------------------------|
| Fuerza bruta (login) | Rate limiting por IP con contadores Redis; bloqueo de cuenta tras N intentos |
| Tokens comprometidos | Blacklist Redis + refresh token rotation |
| Inyección SQL | Hibernate ORM + parameterized queries; nunca SQL concatenado |
| CORS | Política CORS configurada en Spring Security (solo orígenes permitidos) |
| Exposición de credenciales | Todos los secrets en AWS Secrets Manager; `sensitive = true` en Terraform |
| Escalada de privilegios | Roles por usuario validados en cada request en auth-service |
| Dependencias vulnerables | Verificación con Maven dependency plugin; JaCoCo cobertura mínima |

### 11.3 Seguridad de red

- **VPC** privada con subredes públicas (ALB) y privadas (RDS, ElastiCache, EC2)
- **Security Groups** con principio de mínimo privilegio: RDS solo acepta tráfico desde EC2; Redis solo desde servicios autorizados
- ALB con listeners HTTPS (TLS termination); HTTP redirige a HTTPS
- **IAM Roles** con políticas de mínimo privilegio para EC2/ECS (acceso solo a ECR y S3 propios)

---

## 12. Calidad y Pruebas

### 12.1 Cobertura de código

**JaCoCo 0.8.11** está configurado en el POM padre y en cada módulo hijo. Se genera un reporte de cobertura de código en cada build Maven.

```bash
mvn clean verify   # ejecuta tests + genera reporte JaCoCo
```

Reportes en: `target/site/jacoco/index.html` por módulo.

### 12.2 Tipos de pruebas

| Tipo | Framework | Alcance |
|------|-----------|---------|
| Unitarias (backend) | JUnit 5 + Mockito | Servicios, factories, scoring |
| Integración (backend) | Spring Boot Test + Testcontainers | Controladores, repositorios |
| Seguridad (backend) | Spring Security Test | Endpoints protegidos, JWT |
| Unitarias (frontend) | Vitest + Testing Library | Componentes React, hooks |
| E2E frontend | Vitest + jsdom | Flujos de usuario completos |
| Humo (producción) | `smoke-test.ps1` | Endpoints críticos post-deploy |

### 12.3 Estrategia de testing del frontend

```bash
npm run test           # Vitest en modo run (CI)
npm run test:watch     # Modo interactivo (desarrollo)
npm run test:coverage  # Reporte de cobertura
```

---

## 13. Estrategia de Control de Versiones

### 13.1 Git Flow adaptado

```
master   ──────────────────────── (producción estable, siempre desplegable)
  │
  └── develop ───────────────────── (integración continua)
        │
        ├── feature/frontend
        ├── feature/auth-service
        ├── feature/ms-mascotas
        ├── feature/ms-geolocalizacion
        ├── feature/ms-coincidencias
        ├── feature/bff-service
        └── feature/infraestructura
```

| Rama | Propósito | Política de merge |
|------|-----------|------------------|
| `master` | Producción estable | Solo desde `develop` vía PR, previa revisión |
| `develop` | Integración continua | Recibe merges de `feature/*` |
| `feature/*` | Desarrollo aislado | Se crean desde `develop`, regresan a `develop` |

### 13.2 Convención de commits (Conventional Commits)

```
<tipo>(<scope>): <descripción corta>

feat(ms-mascotas): implementar ReporteFactory con Factory Method
fix(bff-service): corregir circuit breaker cuando ms-mascotas no responde
test(ms-coincidencias): agregar pruebas unitarias a ScoringService
docs(auth-service): agregar README con instrucciones de instalación
chore(infraestructura): actualizar versión de Terraform provider AWS
refactor(ms-geolocalizacion): extraer ClusteringService a módulo independiente
```

---

## 14. Flujo de Datos End-to-End

### Caso de uso: Usuario reporta mascota perdida

```
1. Usuario completa formulario en React (foto + descripción + coords GPS)
   │
2. React → POST /reportes (con JWT en header Authorization)
   │
3. bff-service (JwtAuthFilter valida token)
   → MascotasProxyService.crearReporte() → Circuit Breaker
   │
4. ms-mascotas (JwtAuthFilter valida token)
   → ReporteController.crear(dto)
   → ReporteFactory.crear(dto)     // Factory Method: instancia ReportePerdido
   → MinioService.subirFoto()      // foto a S3/MinIO
   → ReporteRepository.save()      // persiste en mascotas_db
   → EventPublisher.publish(ReporteNuevoEvent)  // Observer: publica en RabbitMQ
   │
5. RabbitMQ entrega evento a dos suscriptores en paralelo:
   │
   ├── GeolocalizacionListener (ms-geolocalizacion)
   │     → guarda coordenadas PostGIS en geolocalizacion_db
   │     → recalcula clusters K-means
   │     → publica ReporteGeocompletadoEvent en RabbitMQ
   │
   └── CoincidenciasListener (ms-coincidencias)
         → espera ReporteGeocompletadoEvent
         → CandidateLoaderService carga reportes "encontrados" activos
         → ScoringService.calcular() para cada candidato  // Strategy
         → persiste coincidencias con score ≥ umbral en coincidencias_db
   │
6. Usuario consulta ReporteDetalle en React
   → bff-service agrega datos de mascotas + coincidencias en una sola respuesta
   → Usuario ve lista de posibles matches con porcentaje de similitud
```

---

## 15. Decisiones de Arquitectura Clave

### ¿Por qué microservicios y no monolito?

El dominio del problema tiene cuatro subdominios claramente separados (autenticación, reportes, geolocalización, matching). La arquitectura de microservicios permite:
- Escalar independientemente el servicio de matching (más CPU-intensivo) sin escalar auth
- Desplegar nuevas versiones del algoritmo de scoring sin afectar el resto del sistema
- Equipos de desarrollo trabajando en paralelo sin conflictos de merge

### ¿Por qué RabbitMQ para la comunicación interna?

La alternativa era REST síncrono entre microservicios. Se eligió RabbitMQ porque:
- La geolocalización y el matching son operaciones asíncronas por naturaleza (el usuario no espera el resultado en la misma request)
- Desacopla completamente los productores de los consumidores (Observer distribuido)
- Añadir un nuevo suscriptor (ej. servicio de notificaciones) no requiere cambiar `ms-mascotas`
- Tolerancia a fallos: si `ms-coincidencias` cae, los eventos se encolan y se procesan cuando vuelva

### ¿Por qué BFF y no API Gateway estándar?

El BFF permite personalizar la API para las necesidades específicas del cliente React:
- Agrega datos de múltiples servicios en una sola respuesta para el dashboard
- Aplica transformaciones y filtrado adaptados a la UI
- Centraliza el Circuit Breaker y la lógica de reintentos
- El frontend no necesita conocer la topología interna del backend

### ¿Por qué bases de datos separadas por microservicio?

Cada microservicio tiene su propia base de datos, lo que garantiza:
- Aislamiento: un esquema corrupto no afecta a otros servicios
- Independencia tecnológica: `ms-geolocalizacion` usa PostGIS, los demás PostgreSQL estándar
- Escalado independiente de almacenamiento
- Las referencias cruzadas se resuelven a nivel de aplicación, no con FK SQL entre bases

### ¿Por qué Terraform para la infraestructura?

- Reproducibilidad: el entorno de producción puede recrearse desde cero en minutos
- Versionado: los cambios de infraestructura se rastrean en Git como cualquier cambio de código
- Revisión: los pull requests de infraestructura pasan por revisión antes de aplicarse
- State management: Terraform rastea el estado real de los recursos AWS y solo aplica cambios incrementales

---

## Apéndice A — Puertos de los servicios

| Servicio | Puerto (dev) | Protocolo |
|---------|-------------|-----------|
| bff-service | 8080 | HTTP REST |
| auth-service | 8081 | HTTP REST |
| ms-mascotas | 8082 | HTTP REST |
| ms-geolocalizacion | 8083 | HTTP REST |
| ms-coincidencias | 8084 | HTTP REST |
| PostgreSQL | 5432 | TCP |
| Redis | 6380 (host) → 6379 (container) | TCP |
| RabbitMQ AMQP | 5672 | AMQP |
| RabbitMQ Management UI | 15672 | HTTP |
| MinIO API | 9000 | HTTP |
| MinIO Console | 9001 | HTTP |
| MailHog SMTP | 2025 | SMTP |
| MailHog UI | 8025 | HTTP |

---

## Apéndice B — Comandos de operación rápida

```bash
# Levantar entorno de desarrollo completo
docker compose up --build

# Compilar todos los módulos Maven
mvn clean package -DskipTests

# Ejecutar tests con cobertura
mvn clean verify

# Desplegar en producción (PowerShell)
./master-deploy.ps1

# Inicializar base de datos en RDS
./init-database.ps1

# Smoke tests post-despliegue
./smoke-test.ps1

# Build frontend
cd frontend && npm run build

# Tests frontend con cobertura
cd frontend && npm run test:coverage

# Inicializar Terraform
terraform init && terraform apply
```

---

*Documento generado para presentación técnica del proyecto Sanos y Salvos — Mayo 2026*
