package com.folio.backend.storage;

import com.folio.backend.config.StorageProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CreateBucketRequest;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.NoSuchBucketException;
import software.amazon.awssdk.services.s3.model.S3Exception;

/** Ensures the configured bucket exists in MinIO (perfiles {@code dev}/{@code test}/{@code docker}). */
@Component
@Profile({"dev", "test", "docker"})
public class MinioBucketBootstrap implements ApplicationRunner {

  private static final Logger log = LoggerFactory.getLogger(MinioBucketBootstrap.class);

  private final S3Client s3Client;
  private final StorageProperties props;

  public MinioBucketBootstrap(S3Client s3Client, StorageProperties props) {
    this.s3Client = s3Client;
    this.props = props;
  }

  @Override
  public void run(ApplicationArguments args) {
    if (!props.bootstrapBucket()) {
      return;
    }
    String bucket = props.bucket();
    try {
      s3Client.headBucket(HeadBucketRequest.builder().bucket(bucket).build());
      log.debug("S3 bucket '{}' already exists", bucket);
    } catch (NoSuchBucketException e) {
      s3Client.createBucket(CreateBucketRequest.builder().bucket(bucket).build());
      log.info("Created S3 bucket '{}'", bucket);
    } catch (S3Exception e) {
      if (e.statusCode() == 404) {
        s3Client.createBucket(CreateBucketRequest.builder().bucket(bucket).build());
        log.info("Created S3 bucket '{}'", bucket);
      } else {
        log.warn("Could not ensure bucket '{}': {}", bucket, e.getMessage());
      }
    } catch (Exception e) {
      log.warn("Could not ensure bucket '{}': {}", bucket, e.getMessage());
    }
  }
}
