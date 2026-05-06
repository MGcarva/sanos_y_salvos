# Arquetipos Maven — Sanos y Salvos

## ¿Qué es un Arquetipo Maven?

Un **arquetipo Maven** es una plantilla de proyecto reutilizable que genera automáticamente la estructura base de un nuevo proyecto Java/Spring con todas las configuraciones y dependencias preestablecidas. Es equivalente al concepto de "scaffolding" o "boilerplate" en otros ecosistemas.

Cuando se ejecuta `mvn archetype:generate`, Maven usa la plantilla del arquetipo para crear el esqueleto del proyecto nuevo, listo para desarrollar.

## Arquetipos en este proyecto

### `sanos-y-salvos-microservice-archetype`

Arquetipo personalizado para crear nuevos microservicios dentro del ecosistema **Sanos y Salvos**. Genera un microservicio Spring Boot preconfigurado con:

- **Estructura de paquetes** estándar del ecosistema
- **Dependencias base** gestionadas (JWT, RabbitMQ, JPA, Security, Lombok)
- **JwtAuthFilter** listo para validar tokens del auth-service
- **SecurityConfig** con política stateless y JWT
- **RabbitMQConfig** con exchange, queue y binding estándar
- **application.yml** con variables de entorno configurables
- **JaCoCo** para generación de reportes de cobertura de código
- **Test de carga de contexto** base

### Relación con Spring Boot Archetype

Todos los microservicios del proyecto también utilizan el arquetipo oficial de Spring Boot:

```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.2.5</version>
</parent>
```

Este arquetipo oficial provee:
- Plugin de empaquetado como JAR ejecutable (`spring-boot-maven-plugin`)
- Gestión de versiones de dependencias transitivas
- Soporte para perfiles de Spring
- Hot-reload con DevTools

## Estructura del arquetipo personalizado

```
sanos-y-salvos-microservice-archetype/
├── pom.xml                         ← POM del arquetipo (packaging: maven-archetype)
└── src/main/resources/
    ├── META-INF/maven/
    │   └── archetype-metadata.xml  ← Descriptor: propiedades requeridas y filesets
    └── archetype-resources/        ← Plantillas que se copian al nuevo proyecto
        ├── pom.xml                 ← POM template del microservicio
        └── src/
            ├── main/
            │   ├── java/
            │   │   ├── Application.java
            │   │   └── config/
            │   │       ├── JwtAuthFilter.java
            │   │       ├── SecurityConfig.java
            │   │       └── RabbitMQConfig.java
            │   └── resources/
            │       └── application.yml
            └── test/
                └── java/
                    └── ApplicationTests.java
```

## Cómo instalar el arquetipo localmente

```bash
cd maven-archetypes/sanos-y-salvos-microservice-archetype
mvn install
```

Esto instala el arquetipo en el repositorio local Maven (`~/.m2/repository`).

## Cómo generar un nuevo microservicio

Una vez instalado el arquetipo, ejecutar:

```bash
mvn archetype:generate \
  -DarchetypeGroupId=com.sanosysalvos \
  -DarchetypeArtifactId=sanos-y-salvos-microservice-archetype \
  -DarchetypeVersion=1.0.0 \
  -DgroupId=com.sanosysalvos \
  -DartifactId=ms-notificaciones \
  -Dversion=1.0.0 \
  -DserviceName="Microservicio de Notificaciones" \
  -DservicePort=8085 \
  -DdatabaseName=notificaciones_db
```

Maven generará automáticamente un proyecto con la estructura completa, listo para agregar la lógica de negocio específica.

## Propiedades configurables

| Propiedad | Descripción | Ejemplo |
|-----------|-------------|---------|
| `groupId` | Grupo del artefacto Maven | `com.sanosysalvos` |
| `artifactId` | Nombre del artefacto Maven | `ms-notificaciones` |
| `version` | Versión del servicio | `1.0.0` |
| `serviceName` | Nombre legible del servicio | `Microservicio de Notificaciones` |
| `servicePort` | Puerto HTTP del servicio | `8085` |
| `databaseName` | Nombre de la base de datos PostgreSQL | `notificaciones_db` |

## Beneficios del arquetipo en el proyecto

1. **Consistencia:** Todos los microservicios tienen la misma estructura de paquetes y configuración
2. **Velocidad:** Un nuevo microservicio puede estar operativo en minutos
3. **Mantenibilidad:** Cambiar la configuración base en el arquetipo se propaga a nuevos servicios
4. **Convención:** Establece estándares de naming, seguridad y mensajería en el ecosistema

## Microservicios generados con este arquetipo

| Servicio | Arquetipo base | Puerto | BD |
|---------|----------------|--------|----|
| auth-service | Spring Boot + arquetipo custom | 8081 | auth_db |
| ms-mascotas | Spring Boot + arquetipo custom | 8082 | mascotas_db |
| ms-geolocalizacion | Spring Boot + arquetipo custom | 8083 | geolocalizacion_db |
| ms-coincidencias | Spring Boot + arquetipo custom | 8084 | coincidencias_db |
| bff-service | Spring Boot + WebFlux | 8080 | (sin BD) |
