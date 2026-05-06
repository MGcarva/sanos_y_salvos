# BFF Service (Backend For Frontend)

Servicio de tipo **Backend For Frontend (BFF)** que actúa como puerta de entrada única para el cliente React. Orquesta llamadas a los microservicios internos y aplica el patrón **Circuit Breaker** para tolerancia a fallos.

## Responsabilidades

- Punto de entrada único para el frontend (API Gateway)
- Validación y reenvío de tokens JWT
- Orquestación de respuestas compuestas (dashboard)
- Circuit Breaker con Resilience4j para resiliencia
- Proxy transparente a cada microservicio

## Tecnologías

| Herramienta | Versión | Rol |
|------------|---------|-----|
| Spring Boot | 3.2.5 | Framework principal |
| Spring WebFlux | 6.x | Operaciones HTTP reactivas |
| Resilience4j | 2.x | Circuit Breaker |
| Spring Data Redis | 3.x | Caché de respuestas |
| Spring Security | 6.x | Validación JWT |

## Arquitectura interna

```
bff-service/
└── src/main/java/com/sanosysalvos/bff/
    ├── controller/    # ReportesController, DashboardController,
    │                  # GeoController, AuthController, CoincidenciasController
    ├── service/       # AuthProxyService, MascotasProxyService,
    │                  # CoincidenciasProxyService, GeoProxyService, DashboardService
    ├── filter/        # JwtAuthFilter
    └── config/        # RestTemplateConfig, SecurityConfig, GlobalExceptionHandler
```

## Puerto

`8080`

## Microservicios a los que se conecta

| Servicio | Puerto |
|---------|--------|
| auth-service | 8081 |
| ms-mascotas | 8082 |
| ms-geolocalizacion | 8083 |
| ms-coincidencias | 8084 |

## Requisitos previos

- Java 21
- Maven 3.9+
- Todos los microservicios corriendo

## Ejecución en local

```bash
mvn clean package -DskipTests
java -jar target/bff-service-1.0.0.jar
```

### Variables de entorno requeridas

```env
AUTH_SERVICE_URL=http://localhost:8081
MASCOTAS_SERVICE_URL=http://localhost:8082
GEO_SERVICE_URL=http://localhost:8083
COINCIDENCIAS_SERVICE_URL=http://localhost:8084
JWT_SECRET=tu_clave_secreta_base64
```

## Ejecutar pruebas

```bash
mvn test
```

## Endpoints principales

| Método | Ruta | Microservicio destino |
|--------|------|-----------------------|
| POST | `/api/auth/**` | auth-service |
| GET/POST | `/api/reportes/**` | ms-mascotas |
| GET | `/api/geo/**` | ms-geolocalizacion |
| GET | `/api/coincidencias/**` | ms-coincidencias |
| GET | `/api/dashboard` | Agrega múltiples servicios |

## Docker

```bash
docker build -t bff-service .
docker run -p 8080:8080 \
  -e AUTH_SERVICE_URL=http://auth-service:8081 \
  -e MASCOTAS_SERVICE_URL=http://ms-mascotas:8082 \
  bff-service
```

## Patrones de diseño aplicados

- **BFF Pattern:** Un backend específico para el cliente frontend, adaptando las respuestas a lo que la UI necesita exactamente
- **Proxy Pattern:** Los `*ProxyService` delegan las llamadas a los microservicios correspondientes
- **Circuit Breaker Pattern:** Resilience4j evita cascadas de fallos cuando un microservicio no responde
- **Facade Pattern:** Expone una API unificada ocultando la complejidad de la arquitectura de microservicios
