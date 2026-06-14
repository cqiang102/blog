# syntax=docker/dockerfile:1
FROM maven:3.9.9-eclipse-temurin-21 AS build

WORKDIR /app

COPY pom.xml .
COPY src src
RUN --mount=type=cache,target=/root/.m2 \
    mvn package -DskipTests -B

FROM eclipse-temurin:21-jre-alpine

RUN apk add --no-cache curl tzdata \
    && addgroup -S blog \
    && adduser -S -G blog blog

WORKDIR /app

COPY --chown=blog:blog --from=build /app/target/personal-blog-api-0.1.0-SNAPSHOT.jar app.jar
RUN mkdir -p /app/logs \
    && chown blog:blog /app /app/logs

USER blog

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl --fail --silent http://localhost:8080/actuator/health/readiness || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
