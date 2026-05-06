# MS-Coincidencias (Microservicio de Coincidencias)

Microservicio responsable de encontrar coincidencias entre reportes de mascotas perdidas y encontradas en la plataforma **Sanos y Salvos**. Usa algoritmos de similitud difusa (fuzzy matching) para comparar descripciones y ubicaciones.

## Responsabilidades

- Escuchar eventos de geolocalización completada desde RabbitMQ
- Comparar descriptores de mascotas usando FuzzyWuzzy
- Calcular puntuación de coincidencia multi-criterio
- Exponer resultados de coincidencias por reporte

## Tecnologías

| Herramienta | Versión | Rol |
|------------|---------|-----|
| Spring Boot | 3.2.5 | Framework principal |
| Spring Data JPA | 3.x | Persistencia |
| FuzzyWuzzy | 1.4.0 | Similitud difusa de texto |
| Spring AMQP | 3.x | Consumidor RabbitMQ |
| PostgreSQL | 15 | Base de datos de coincidencias |

## Arquitectura interna

```
ms-coincidencias/
└── src/main/java/com/sanosysalvos/coincidencias/
    ├── controller/    # CoincidenciaController
    ├── service/       # CoincidenciaService, ScoringService, CandidateLoaderService
    ├── listener/      # CoincidenciasListener (RabbitMQ consumer)
    ├── domain/        # Coincidencia
    ├── dto/           # CandidatoDTO
    ├── repository/    # CoincidenciaRepository
    └── config/        # RabbitMQConfig, JwtAuthFilter
```

## Puerto

`8084`

## Base de datos

`coincidencias_db` en PostgreSQL.

## Algoritmo de coincidencia

El `ScoringService` calcula un puntaje compuesto:

| Criterio | Peso |
|---------|------|
| Similitud del nombre (FuzzyWuzzy) | 40% |
| Similitud de descripción | 30% |
| Distancia geográfica | 20% |
| Diferencia temporal | 10% |

Solo se retornan coincidencias con puntaje ≥ umbral configurado.

## Patrones de diseño implementados

### Strategy Pattern (Scoring)
`ScoringService` encapsula el algoritmo de puntuación. Puede cambiarse el criterio de peso sin modificar los demás componentes del servicio.

### Observer Pattern (Listener)
`CoincidenciasListener` reacciona al evento `geo.completado` publicado por `ms-geolocalizacion`, procesando automáticamente cada nuevo reporte sin dependencias directas entre servicios.

## Flujo de eventos

```
ms-geolocalizacion → [RabbitMQ: geo.completado] → CoincidenciasListener
    → CandidateLoaderService carga candidatos
    → ScoringService calcula puntajes
    → Guarda coincidencias en DB
```

## Requisitos previos

- Java 21
- Maven 3.9+
- PostgreSQL 15 con base `coincidencias_db`
- RabbitMQ 3.12

## Ejecución en local

```bash
mvn clean package -DskipTests
java -jar target/ms-coincidencias-1.0.0.jar
```

### Variables de entorno

```env
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/coincidencias_db
SPRING_DATASOURCE_USERNAME=sanosadmin
SPRING_DATASOURCE_PASSWORD=sanospassword
RABBITMQ_HOST=localhost
JWT_SECRET=tu_clave_secreta_base64
SCORING_THRESHOLD=0.6
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
| GET | `/api/coincidencias/{reporteId}` | Coincidencias para un reporte |

## Docker

```bash
docker build -t ms-coincidencias .
docker run -p 8084:8084 ms-coincidencias
```
