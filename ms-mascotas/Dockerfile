FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY pom.xml ./pom.xml
COPY ms-mascotas/pom.xml ./ms-mascotas/pom.xml
COPY ms-mascotas/src ./ms-mascotas/src
RUN apk add --no-cache maven && mvn -f ms-mascotas/pom.xml clean package -Dmaven.test.skip=true

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=builder /app/ms-mascotas/target/*.jar app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "app.jar"]
