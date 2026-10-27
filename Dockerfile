# Keycloak Quarkus - Multi-stage Dockerfile for AWS EKS
# Build stage: uses Maven to compile the Quarkus application
FROM maven:3.9.4-eclipse-temurin-17 AS builder

# Set working directory
WORKDIR /workspace

# Copy the root pom.xml
COPY pom.xml ./

# Copy the Quarkus server module and its dependencies
COPY quarkus/ quarkus/

# Build the Quarkus server application
# The quarkus-maven-plugin build goal creates a quarkus-app directory with quarkus-run.jar
RUN mvn -B clean package -pl quarkus/server -am -DskipTests -DskipChecks 2>&1 | tail -50

# Runtime stage
FROM eclipse-temurin:17-jdk

# Create a non-root user
RUN groupadd -r keycloak && useradd -r -g keycloak -d /opt/keycloak -s /sbin/nologin keycloak

# Set working directory
WORKDIR /opt/keycloak

# Copy the Quarkus application from the builder stage
# The quarkus-maven-plugin creates a quarkus-app directory with:
# - quarkus-run.jar (the main runnable JAR)
# - lib/ (all dependencies)
# - app/ (application classes)
COPY --from=builder /workspace/quarkus/server/target/quarkus-app/ /opt/keycloak/

# Set ownership
RUN chown -R keycloak:keycloak /opt/keycloak

# Switch to non-root user
USER keycloak

# Expose the HTTP port (default 8080) and management port (default 9000)
EXPOSE 8080 9000

# Environment variables
ENV LANG='en_US.UTF-8' LC_ALL='en_US.UTF-8' \
    TZ=UTC \
    JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0" \
    KC_HTTP_PORT=8080 \
    KC_HTTP_MANAGEMENT_PORT=9000 \
    KC_HEALTH_ENABLED=true \
    KC_HTTP_HOST=0.0.0.0 \
    KC_HTTP_MANAGEMENT_HOST=0.0.0.0

# Start the Keycloak server using the Quarkus runner
# The quarkus-run.jar is the main entry point created by the Quarkus build
# Using JSON notation for signal handling - java receives SIGTERM directly
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -Djava.util.logging.manager=org.jboss.logmanager.LogManager -jar /opt/keycloak/quarkus-run.jar"]
