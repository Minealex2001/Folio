package com.folio.backend.storage;

import static org.assertj.core.api.Assertions.assertThat;

import com.folio.backend.AbstractIntegrationTest;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CreateBucketRequest;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;

class StorageServiceIT extends AbstractIntegrationTest {

  private static final AtomicBoolean MINIO_READY = new AtomicBoolean(false);

  @Autowired private StorageService storageService;
  @Autowired private S3Client s3Client;
  @Autowired private com.folio.backend.config.StorageProperties props;

  @BeforeAll
  static void ensureMinio() {
    try {
      ensureComposeMinio();
      MINIO_READY.set(true);
    } catch (Exception e) {
      System.err.println("MinIO unavailable for StorageServiceIT: " + e.getMessage());
      MINIO_READY.set(false);
    }
  }

  @Test
  void presignUploadDownloadRoundTripAndDeletePrefix() throws Exception {
    Assumptions.assumeTrue(MINIO_READY.get(), "MinIO required");
    ensureBucket();
    String key = "users/test/backups/" + UUID.randomUUID() + ".bin";
    byte[] payload = ("hello-" + UUID.randomUUID()).getBytes(StandardCharsets.UTF_8);

    String putUrl = storageService.presignUpload(key, Duration.ofMinutes(5), payload.length);
    HttpClient client = HttpClient.newHttpClient();
    HttpResponse<String> put =
        client.send(
            HttpRequest.newBuilder(URI.create(putUrl))
                .PUT(HttpRequest.BodyPublishers.ofByteArray(payload))
                .build(),
            HttpResponse.BodyHandlers.ofString());
    assertThat(put.statusCode()).isBetween(200, 299);

    String getUrl = storageService.presignDownload(key, Duration.ofMinutes(5));
    HttpResponse<byte[]> get =
        client.send(
            HttpRequest.newBuilder(URI.create(getUrl)).GET().build(),
            HttpResponse.BodyHandlers.ofByteArray());
    assertThat(get.statusCode()).isBetween(200, 299);
    assertThat(get.body()).isEqualTo(payload);

    String other = "users/test/backups/other-" + UUID.randomUUID() + ".bin";
    storageService.putBytes(other, "x".getBytes(StandardCharsets.UTF_8), "application/octet-stream");
    int deleted = storageService.deletePrefix("users/test/backups/");
    assertThat(deleted).isGreaterThanOrEqualTo(2);
    assertThat(storageService.exists(key)).isFalse();
  }

  private void ensureBucket() {
    try {
      s3Client.headBucket(HeadBucketRequest.builder().bucket(props.bucket()).build());
    } catch (Exception e) {
      s3Client.createBucket(CreateBucketRequest.builder().bucket(props.bucket()).build());
    }
  }

  private static void ensureComposeMinio() throws Exception {
    java.io.File dir = backendDirStatic();
    ProcessBuilder pb =
        new ProcessBuilder("docker", "compose", "-f", "docker-compose.yml", "up", "-d", "minio");
    pb.directory(dir);
    pb.redirectErrorStream(true);
    Process p = pb.start();
    p.getInputStream().readAllBytes();
    if (p.waitFor() != 0) {
      throw new IllegalStateException("docker compose up minio failed");
    }
    for (int i = 0; i < 40; i++) {
      try {
        HttpClient client = HttpClient.newHttpClient();
        HttpResponse<String> r =
            client.send(
                HttpRequest.newBuilder(URI.create("http://localhost:9000/minio/health/live"))
                    .GET()
                    .timeout(Duration.ofSeconds(2))
                    .build(),
                HttpResponse.BodyHandlers.ofString());
        if (r.statusCode() == 200) {
          return;
        }
      } catch (Exception ignored) {
      }
      Thread.sleep(500);
    }
    throw new IllegalStateException("MinIO not ready");
  }

  private static java.io.File backendDirStatic() {
    java.io.File cwd = new java.io.File(System.getProperty("user.dir"));
    if (new java.io.File(cwd, "docker-compose.yml").isFile()) {
      return cwd;
    }
    java.io.File nested = new java.io.File(cwd, "backend/docker-compose.yml");
    if (nested.isFile()) {
      return nested.getParentFile();
    }
    throw new IllegalStateException("Cannot locate docker-compose.yml");
  }
}
