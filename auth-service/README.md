# Auth Service

Microservicio de autenticación y gestión de usuarios para la plataforma **Sanos y Salvos**.

## Responsabilidades

- Registro e inicio de sesión de usuarios
- Generación y validación de tokens JWT (access + refresh)
- Verificación de correo electrónico
- Rate limiting por IP
- Gestión de sesiones con Redis

## Tecnologías

| Herramienta | Versión | Rol |
|------------|---------|-----|
| Spring Boot | 3.2.5 | Framework principal |
| Spring Security | 6.x | Autenticación y autorización |
| Spring Data JPA | 3.x | Acceso a base de datos |
| Spring Data Redis | 3.x | Caché de tokens y rate limiting |
| JJWT | 0.12.3 | Generación/validación JWT |
| PostgreSQL | 15 | Base de datos de usuarios |
| Redis | 7 | Caché y blacklist de tokens |
| JaCoCo | 0.8.11 | Cobertura de código |

## Arquitectura interna

```
auth-service/
└── src/main/java/com/sanosysalvos/auth/
    ├── controller/    # AuthController (register, login, refresh, verify-email)
    ├── service/       # AuthService, EmailService, RateLimitService
    ├── domain/        # User (entidad JPA)
    ├── repository/    # UserRepository, RefreshTokenRepository
    └── config/        # JwtUtils, JwtAuthFilter, SecurityConfig
```

## Puerto

`8081`

## Base de datos

`auth_db` en PostgreSQL. Las tablas se crean automáticamente con Hibernate (`ddl-auto=update`).

## Requisitos previos

- Java 21
- Maven 3.9+
- PostgreSQL 15 corriendo con la base `auth_db`
- Redis 7 corriendo en el puerto 6379

## Ejecución en local

```bash
# 1. Compilar
mvn clean package -DskipTests

# 2. Ejecutar
java -jar target/auth-service-1.0.0.jar
```

### Variables de entorno requeridas

```env
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/auth_db
SPRING_DATASOURCE_USERNAME=sanosadmin
SPRING_DATASOURCE_PASSWORD=sanospassword
SPRING_DATA_REDIS_HOST=localhost
SPRING_DATA_REDIS_PORT=6379
JWT_SECRET=tu_clave_secreta_base64
MAIL_HOST=smtp.gmail.com
MAIL_USERNAME=tu@email.com
MAIL_PASSWORD=tu_password
```

## Ejecutar pruebas

```bash
mvn test
```

Para generar reporte de cobertura:

```bash
mvn verify
# Reporte en: target/site/jacoco/index.html
```

## Endpoints principales

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/api/auth/register` | Registrar nuevo usuario |
| POST | `/api/auth/login` | Iniciar sesión |
| POST | `/api/auth/refresh` | Renovar access token |
| GET | `/api/auth/verify-email` | Verificar correo |

## Docker

```bash
docker build -t auth-service .
docker run -p 8081:8081 \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://host.docker.internal:5432/auth_db \
  auth-service
```

## Patrones de diseño aplicados

- **Chain of Responsibility:** `JwtAuthFilter` forma una cadena de filtros con Spring Security
- **Repository Pattern:** `UserRepository` abstrae el acceso a datos
- **Strategy Pattern:** Algoritmos de validación JWT intercambiables mediante configuración
