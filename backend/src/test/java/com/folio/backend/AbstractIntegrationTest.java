package com.folio.backend;

import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.DockerClientFactory;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * Shared IT base. Prefers Testcontainers; if the Docker Java client cannot talk to Docker Desktop
 * (common on Windows with recent Desktop builds), falls back to a dedicated {@code folio_it}
 * database on the compose Postgres at localhost:5432 — never the live {@code folio} DB used by
 * {@code docker compose} api (tests truncate all tables in {@code @BeforeEach}).
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(TestMailConfig.class)
public abstract class AbstractIntegrationTest {

  private static final AtomicBoolean COMPOSE_STARTED = new AtomicBoolean(false);
  private static final PostgreSQLContainer<?> POSTGRES;
  private static final boolean USE_TESTCONTAINERS;

  static {
    boolean tc = false;
    PostgreSQLContainer<?> container = null;
    try {
      DockerClientFactory.instance().client();
      container =
          new PostgreSQLContainer<>(DockerImageName.parse("postgres:16-alpine"))
              .withDatabaseName("folio")
              .withUsername("folio")
              .withPassword("folio");
      container.start();
      tc = true;
    } catch (Throwable ex) {
      System.err.println(
          "Testcontainers unavailable ("
              + ex.getClass().getSimpleName()
              + ": "
              + ex.getMessage()
              + ") — falling back to docker compose Postgres DB folio_it on localhost:5432");
      ensureComposePostgres();
    }
    USE_TESTCONTAINERS = tc;
    POSTGRES = container;
  }

  @Autowired private JdbcTemplate jdbcTemplate;

  @BeforeEach
  void cleanDatabase() {
    String sql =
        """
        TRUNCATE TABLE
          folio_diagnostics,
          folio_diagnostic_signatures,
          pending_integration_command,
          integration_link_codes,
          teams_webhook_endpoints,
          integration_webhook_connections,
          integration_user_index,
          stripe_webhook_events,
          stripe_processed_checkouts,
          microsoft_store_processed_purchases,
          microsoft_store_processed_backup_grants,
          family_members,
          families,
          user_billing_stripe,
          user_billing_microsoft_store,
          collab_room_media,
          collab_room_members,
          collab_join_attempts,
          collab_rooms,
          published_pages,
          community_templates,
          vault_backup_blobs,
          vault_backups,
          user_vault_sync,
          user_plain_vault_sync_secret,
          user_app_profile,
          user_vault_profile,
          user_backup_usage,
          password_reset_tokens,
          email_verification_tokens,
          refresh_tokens,
          user_ink,
          user_folio_cloud,
          users
        RESTART IDENTITY CASCADE
        """;
    RuntimeException last = null;
    for (int attempt = 0; attempt < 6; attempt++) {
      try {
        jdbcTemplate.execute(sql);
        return;
      } catch (RuntimeException ex) {
        last = ex;
        try {
          Thread.sleep(150L * (attempt + 1));
        } catch (InterruptedException ie) {
          Thread.currentThread().interrupt();
          throw ex;
        }
      }
    }
    throw last;
  }

  protected static String uniqueEmail(String prefix) {
    return prefix + "+" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
  }

  private static java.io.File backendDir() {
    java.io.File cwd = new java.io.File(System.getProperty("user.dir"));
    java.io.File here = new java.io.File(cwd, "docker-compose.yml");
    if (here.isFile()) {
      return cwd;
    }
    java.io.File nested = new java.io.File(cwd, "backend/docker-compose.yml");
    if (nested.isFile()) {
      return nested.getParentFile();
    }
    throw new IllegalStateException(
        "Cannot locate backend/docker-compose.yml from user.dir=" + cwd.getAbsolutePath());
  }

  private static void ensureComposePostgres() {
    if (!COMPOSE_STARTED.compareAndSet(false, true)) {
      return;
    }
    java.io.File dir = backendDir();
    try {
      ProcessBuilder pb =
          new ProcessBuilder(
              "docker", "compose", "-f", "docker-compose.yml", "up", "-d", "postgres");
      pb.directory(dir);
      pb.redirectErrorStream(true);
      Process p = pb.start();
      String out = new String(p.getInputStream().readAllBytes());
      int code = p.waitFor();
      if (code != 0) {
        throw new IllegalStateException("docker compose up postgres failed (" + code + "): " + out);
      }
      for (int i = 0; i < 40; i++) {
        ProcessBuilder check =
            new ProcessBuilder(
                "docker",
                "compose",
                "-f",
                "docker-compose.yml",
                "exec",
                "-T",
                "postgres",
                "pg_isready",
                "-U",
                "folio",
                "-d",
                "folio");
        check.directory(dir);
        check.redirectErrorStream(true);
        Process c = check.start();
        c.getInputStream().readAllBytes();
        if (c.waitFor() == 0) {
          ensureFolioItDatabase(dir);
          return;
        }
        Thread.sleep(500);
      }
      throw new IllegalStateException("Postgres in docker compose did not become ready");
    } catch (Exception e) {
      throw new ExceptionInInitializerError(e);
    }
  }

  /** Separate DB so IT {@code TRUNCATE} cannot wipe local self-host data in {@code folio}. */
  private static void ensureFolioItDatabase(java.io.File dir) throws Exception {
    ProcessBuilder createdb =
        new ProcessBuilder(
            "docker",
            "compose",
            "-f",
            "docker-compose.yml",
            "exec",
            "-T",
            "postgres",
            "psql",
            "-U",
            "folio",
            "-d",
            "postgres",
            "-c",
            "CREATE DATABASE folio_it OWNER folio");
    createdb.directory(dir);
    createdb.redirectErrorStream(true);
    Process p = createdb.start();
    String out = new String(p.getInputStream().readAllBytes());
    int code = p.waitFor();
    if (code != 0 && !out.toLowerCase().contains("already exists")) {
      throw new IllegalStateException("CREATE DATABASE folio_it failed (" + code + "): " + out);
    }
  }

  @DynamicPropertySource
  static void datasourceProps(DynamicPropertyRegistry registry) {
    if (USE_TESTCONTAINERS && POSTGRES != null) {
      registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
      registry.add("spring.datasource.username", POSTGRES::getUsername);
      registry.add("spring.datasource.password", POSTGRES::getPassword);
    } else {
      registry.add("spring.datasource.url", () -> "jdbc:postgresql://localhost:5432/folio_it");
      registry.add("spring.datasource.username", () -> "folio");
      registry.add("spring.datasource.password", () -> "folio");
    }
    registry.add("spring.datasource.driver-class-name", () -> "org.postgresql.Driver");
  }
}
