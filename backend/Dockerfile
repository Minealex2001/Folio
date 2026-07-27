# Multi-stage build for Folio Cloud Spring Boot API (self-host / open source).
# Build: docker compose -f backend/docker-compose.yml build api
# Or:    docker build -t folio-api ./backend

FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

COPY pom.xml .
RUN mvn -B -q dependency:go-offline -DskipTests || true

COPY src ./src
RUN mvn -B -DskipTests package \
  && mv target/folio-backend-*.jar /app/app.jar

FROM eclipse-temurin:21-jre-jammy AS runtime

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd --system folio \
  && useradd --system --gid folio --home-dir /app --shell /usr/sbin/nologin folio

WORKDIR /app

COPY --from=build /app/app.jar /app/app.jar

USER folio

EXPOSE 8080

ENV SPRING_PROFILES_ACTIVE=docker \
    JAVA_OPTS="-XX:MaxRAMPercentage=75.0"

HEALTHCHECK --interval=15s --timeout=5s --start-period=90s --retries=10 \
  CMD curl -fsS http://127.0.0.1:8080/api/v1/health || exit 1

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
