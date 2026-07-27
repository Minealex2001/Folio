package com.folio.backend.storage;

import com.folio.backend.config.StorageProperties;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.Delete;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.DeleteObjectsRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Response;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.ObjectIdentifier;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Object;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

@Service
public class StorageService {

  private final S3Client s3Client;
  private final S3Presigner s3Presigner;
  private final StorageProperties props;

  public StorageService(S3Client s3Client, S3Presigner s3Presigner, StorageProperties props) {
    this.s3Client = s3Client;
    this.s3Presigner = s3Presigner;
    this.props = props;
  }

  public String bucket() {
    return props.bucket();
  }

  public String presignUpload(String path, Duration ttl, long maxBytes) {
    PutObjectRequest.Builder put =
        PutObjectRequest.builder().bucket(props.bucket()).key(normalize(path));
    if (maxBytes > 0) {
      put.contentLength(maxBytes);
    }
    return s3Presigner
        .presignPutObject(
            PutObjectPresignRequest.builder()
                .signatureDuration(ttl)
                .putObjectRequest(put.build())
                .build())
        .url()
        .toExternalForm();
  }

  public String presignDownload(String path, Duration ttl) {
    GetObjectRequest get =
        GetObjectRequest.builder().bucket(props.bucket()).key(normalize(path)).build();
    return s3Presigner
        .presignGetObject(
            GetObjectPresignRequest.builder().signatureDuration(ttl).getObjectRequest(get).build())
        .url()
        .toExternalForm();
  }

  public void putBytes(String path, byte[] bytes, String contentType) {
    s3Client.putObject(
        PutObjectRequest.builder()
            .bucket(props.bucket())
            .key(normalize(path))
            .contentType(contentType == null ? "application/octet-stream" : contentType)
            .build(),
        RequestBody.fromBytes(bytes));
  }

  public byte[] getBytes(String path) {
    return s3Client
        .getObjectAsBytes(
            GetObjectRequest.builder().bucket(props.bucket()).key(normalize(path)).build())
        .asByteArray();
  }

  public boolean exists(String path) {
    try {
      s3Client.headObject(
          HeadObjectRequest.builder().bucket(props.bucket()).key(normalize(path)).build());
      return true;
    } catch (NoSuchKeyException e) {
      return false;
    } catch (software.amazon.awssdk.services.s3.model.S3Exception e) {
      if (e.statusCode() == 404) {
        return false;
      }
      throw e;
    }
  }

  public long objectSize(String path) {
    return s3Client
        .headObject(HeadObjectRequest.builder().bucket(props.bucket()).key(normalize(path)).build())
        .contentLength();
  }

  public void delete(String path) {
    s3Client.deleteObject(
        DeleteObjectRequest.builder().bucket(props.bucket()).key(normalize(path)).build());
  }

  /** Deletes all objects under {@code prefix} (inclusive). Used later by purgeUserAccount. */
  public int deletePrefix(String prefix) {
    String p = normalize(prefix);
    if (!p.isEmpty() && !p.endsWith("/")) {
      p = p + "/";
    }
    int deleted = 0;
    String token = null;
    do {
      ListObjectsV2Request.Builder req =
          ListObjectsV2Request.builder().bucket(props.bucket()).prefix(p).maxKeys(1000);
      if (token != null) {
        req.continuationToken(token);
      }
      ListObjectsV2Response page = s3Client.listObjectsV2(req.build());
      List<S3Object> contents = page.contents();
      if (contents != null && !contents.isEmpty()) {
        List<ObjectIdentifier> ids = new ArrayList<>();
        for (S3Object o : contents) {
          ids.add(ObjectIdentifier.builder().key(o.key()).build());
        }
        s3Client.deleteObjects(
            DeleteObjectsRequest.builder()
                .bucket(props.bucket())
                .delete(Delete.builder().objects(ids).quiet(true).build())
                .build());
        deleted += ids.size();
      }
      token = page.isTruncated() ? page.nextContinuationToken() : null;
    } while (token != null);
    return deleted;
  }

  public List<String> listKeys(String prefix) {
    String p = normalize(prefix);
    List<String> keys = new ArrayList<>();
    String token = null;
    do {
      ListObjectsV2Request.Builder req =
          ListObjectsV2Request.builder().bucket(props.bucket()).prefix(p).maxKeys(1000);
      if (token != null) {
        req.continuationToken(token);
      }
      ListObjectsV2Response page = s3Client.listObjectsV2(req.build());
      if (page.contents() != null) {
        for (S3Object o : page.contents()) {
          keys.add(o.key());
        }
      }
      token = page.isTruncated() ? page.nextContinuationToken() : null;
    } while (token != null);
    return keys;
  }

  private static String normalize(String path) {
    if (path == null) {
      return "";
    }
    String p = path.trim();
    while (p.startsWith("/")) {
      p = p.substring(1);
    }
    return p;
  }
}
