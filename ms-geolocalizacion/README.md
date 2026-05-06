# MS-Geolocalizacion (Microservicio de Geolocalización)

Microservicio responsable del procesamiento geográfico de los reportes en la plataforma **Sanos y Salvos**. Genera clusters y mapas de calor para visualización en el frontend.

## Responsabilidades

- Escuchar eventos de nuevos reportes desde RabbitMQ
- Almacenar y consultar coordenadas geográficas con PostGIS
- Calcular clusters de reportes usando algoritmo K-means
- Generar datos de mapa de calor (heatmap)

## Tecnologías

| Herramienta | Versión | Rol |
|------------|---------|-----|
| Spring Boot | 3.2.5 | Framework principal |
| Spring Data JPA | 3.x | Persistencia |
| Hibernate Spatial | 6.x | Soporte PostGIS |
| Spring AMQP | 3.x | Consumidor RabbitMQ |
| PostgreSQL + PostGIS | 15 | BD espacial |

## Arquitectura interna

```
ms-geolocalizacion/
└── src/main/java/com/sanosysalvos/geolocalizacion/
    ├── controller/    # GeoController (heatmaps, clusters)
    ├── service/       # GeocodingService, HeatmapService, ClusteringService
    ├── listener/      # GeolocalizacionListener (RabbitMQ consumer)
    ├── domain/        # UbicacionReporte
    ├── repository/    # UbicacionRepository
    └── config/        # RabbitMQConfig, JwtAuthFilter
```

## Puerto

`8083`

## Base de datos

`geolocalizacion_db` en PostgreSQL con extensión **PostGIS** habilitada.

## Flujo de eventos

```
ms-mascotas → [RabbitMQ: reporte.nuevo] → GeolocalizacionListener
    → guarda coordenadas en DB
    → publica [RabbitMQ: geo.completado] → ms-coincidencias
```

## Patrones de diseño implementados

### Observer Pattern (Listener)
`GeolocalizacionListener` implementa el rol de observador: recibe `ReporteNuevoEvent` de RabbitMQ y actúa sin que `ms-mascotas` tenga conocimiento de él. Desacoplamiento total entre productores y consumidores.

### Strategy Pattern (Clustering)
`ClusteringService` aplica algoritmos intercambiables de agrupamiento geográfico. La estrategia actual es K-means, pero puede sustituirse sin cambiar el controlador.

## Requisitos previos

- Java 21
- Maven 3.9+
- PostgreSQL 15 con extensión PostGIS activada:
  ```sql
  CREATE EXTENSION IF NOT EXISTS postgis;
  ```
- RabbitMQ 3.12

## Ejecución en local

```bash
mvn clean package -DskipTests
java -jar target/ms-geolocalizacion-1.0.0.jar
```

### Variables de entorno

```env
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/geolocalizacion_db
SPRING_DATASOURCE_USERNAME=sanosadmin
SPRING_DATASOURCE_PASSWORD=sanospassword
RABBITMQ_HOST=localhost
JWT_SECRET=tu_clave_secreta_base64
```

## Ejecutar pruebas

```bash
mvn test
mvn verify
# Reporte de cobertura en: target/site/jacoco/index.html
```

## Endpoints principales

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/geo/heatmap` | Datos de mapa de calor |
| GET | `/api/geo/clusters` | Clusters de reportes |

## Docker

```bash
docker build -t ms-geolocalizacion .
docker run -p 8083:8083 ms-geolocalizacion
```
