# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Bedrock_keycloak_MM1 (Keycloak, Quarkus distribution) - multi-stage build
# Build stage: Maven + JDK 17 builds the multi-module project and the
# Quarkus distribution (quarkus/dist), then runs the Keycloak "build" step.
# Runtime stage: amazoncorretto:17 runs the optimized distribution.
# ---------------------------------------------------------------------------
FROM maven:3.9.4-eclipse-temurin-17 AS builder

WORKDIR /workspace

# Build-time Keycloak options (they are fixed in the optimized image).
# The database vendor is a build-time option: postgres by default.
ARG KC_DB=postgres
ENV KC_DB=${KC_DB} \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=false

# Several modules: the whole project is the build context
COPY . .

# Parent POM first, then the modules the distribution needs
RUN mvn -B -ntp clean install -N -DskipTests \
    && mvn -B -ntp clean package -DskipTests -pl quarkus/dist -am

# Unpack the distribution and run the Keycloak build step (augmentation)
RUN mkdir -p /opt/keycloak \
    && tar -xzf quarkus/dist/target/keycloak-*.tar.gz --strip-components=1 -C /opt/keycloak \
    && /opt/keycloak/bin/kc.sh build \
    && chmod -R g+rwX /opt/keycloak

# ---------------------------------------------------------------------------
FROM amazoncorretto:17

LABEL org.opencontainers.image.title="bedrock-keycloak-mm1" \
      org.opencontainers.image.description="Keycloak (Quarkus distribution) for Bedrock_keycloak_MM1"

# JVM settings for containers, timezone, charset and locale
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:MetaspaceSize=96M -XX:MaxMetaspaceSize=256m -XX:+ExitOnOutOfMemoryError -Dfile.encoding=UTF-8 -Dsun.stdout.encoding=UTF-8 -Dsun.err.encoding=UTF-8 -Djava.security.egd=file:/dev/urandom -Duser.language=en -Duser.country=US" \
    JAVA_ADD_OPENS="--add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED --add-opens=java.base/java.security=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --enable-native-access=ALL-UNNAMED" \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    KC_RUN_IN_CONTAINER=true \
    KC_HEALTH_ENABLED=true \
    KC_LOG=console \
    KC_LOG_LEVEL=info

# Distribution built in the first stage (owned by a non-root user, group 0)
COPY --from=builder --chown=1000:0 /opt/keycloak /opt/keycloak

WORKDIR /opt/keycloak

# 8080 = HTTP, 8443 = HTTPS, 9000 = management interface (health endpoints)
EXPOSE 8080 8443 9000

# Non-root user
USER 1000:0

# java is the first process (exec) so that it receives SIGTERM for a graceful shutdown.
# The arguments of CMD (start --optimized) are passed to Keycloak.
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS $JAVA_ADD_OPENS -Dkc.home.dir=/opt/keycloak -Djboss.server.config.dir=/opt/keycloak/conf -Djava.util.logging.manager=org.jboss.logmanager.LogManager -Dpicocli.disable.closures=true -Dquarkus-log-max-startup-records=10000 -Djava.util.concurrent.ForkJoinPool.common.threadFactory=io.quarkus.bootstrap.forkjoin.QuarkusForkJoinWorkerThreadFactory -cp /opt/keycloak/lib/quarkus-run.jar io.quarkus.bootstrap.runner.QuarkusEntryPoint \"$@\"", "keycloak"]
CMD ["start", "--optimized"]
