# MS-Mascotas (Microservicio de Reportes)

Microservicio responsable de la gestión de reportes de mascotas perdidas y encontradas en la plataforma **Sanos y Salvos**.

## Responsabilidades

- Crear y consultar reportes de mascotas perdidas (`ReportePerdido`)
- Crear y consultar reportes de mascotas encontradas (`ReporteEncontrado`)
- Almacenar fotografías en MinIO (almacenamiento compatible con S3)
- Publicar eventos en RabbitMQ para notificar al sistema de geolocalización y coincidencias

## Tecnologías

| Herramienta | Versión | Rol |
|------------|---------|-----|
| Spring Boot | 3.2.5 | Framework principal |
| Spring Data JPA | 3.x | Persistencia |
| Spring AMQP | 3.x | Mensajería con RabbitMQ |
| MinIO | 8.5.7 | Almacenamiento de imágenes |
| PostgreSQL | 15 | Base de datos de reportes |
| RabbitMQ | 3.12 | Message broker |
| JaCoCo | 0.8.11 | Cobertura de código |

## Arquitectura interna

```
ms-mascotas/
└── src/main/java/com/sanosysalvos/mascotas/
    ├── controller/    # ReporteController
    ├── service/       # ReporteService, MinioService, EventPublisher
    ├── factory/       # ReporteFactory
    ├── domain/        # Reporte, ReportePerdido, ReporteEncontrado
    ├── dto/           # ReporteRequestDTO, ReporteResponseDTO
    ├── repository/    # ReporteRepository
    ├── events/        # ReporteNuevoEvent
    └── config/        # MinioConfig, RabbitMQConfig, SecurityConfig, JwtAuthFilter
```

## Puerto

`8082`

## Base de datos

`mascotas_db` en PostgreSQL.

## Patrones de diseño implementados

### Factory Method Pattern
`ReporteFactory` centraliza la creación de los distintos tipos de reporte. El cliente solo indica el tipo (`PERDIDO` / `ENCONTRADO`) y la factory instancia la clase correcta:

```java
// ReporteFactory.java
public Reporte crear(ReporteRequestDTO dto) {
    return switch (dto.getTipo()) {
        case PERDIDO    -> new ReportePerdido(dto);
        case ENCONTRADO -> new ReporteEncontrado(dto);
    };
}
```

### Observer Pattern (Eventos de dominio)
Al crearse un reporte, `EventPublisher` publica un `ReporteNuevoEvent` en RabbitMQ. Los microservicios `ms-geolocalizacion` y `ms-coincidencias` son los observadores que reaccionan asincrónicamente.

## Requisitos previos

- Java 21
- Maven 3.9+
- PostgreSQL 15 con base `mascotas_db`
- RabbitMQ 3.12
- MinIO (o bucket S3)

## Ejecución en local

```bash
mvn clean package -DskipTests
java -jar target/ms-mascotas-1.0.0.jar
```

### Variables de entorno

```env
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/mascotas_db
SPRING_DATASOURCE_USERNAME=sanosadmin
SPRING_DATASOURCE_PASSWORD=sanospassword
RABBITMQ_HOST=localhost
MINIO_ENDPOINT=http://localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET=mascotas-fotos
JWT_SECRET=tu_clave_secreta_base64
```

## Ejecutar pruebas

```bash
mvn test
# Cobertura en: target/site/jacoco/index.html
mvn verify
```

## Endpoints principales

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/api/reportes` | Crear reporte (multipart con foto) |
| GET | `/api/reportes` | Listar todos los reportes |
| GET | `/api/reportes/{id}` | Obtener reporte por ID |
| GET | `/api/reportes/usuario` | Reportes del usuario autenticado |

## Docker

```bash
docker build -t ms-mascotas .
docker run -p 8082:8082 ms-mascotas
```
