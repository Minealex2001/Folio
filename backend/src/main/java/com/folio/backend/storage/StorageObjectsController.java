package com.folio.backend.storage;

import com.folio.backend.common.ApiException;
import com.folio.backend.user.FolioUserPrincipal;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

/**
 * Proxy de objetos S3/MinIO para el cliente Flutter (Fase 29). Evita URLs
 * presignadas con hostname interno {@code minio:9000} inaccesible desde el host.
 */
@RestController
@RequestMapping("/api/v1/storage/objects")
public class StorageObjectsController {

  public static final String PATH_HEADER = "X-Folio-Storage-Path";
  private static final long MAX_PUT_BYTES = 80L * 1024 * 1024;

  private final StorageService storageService;
  private final StoragePathAuthorizer pathAuthorizer;

  public StorageObjectsController(
      StorageService storageService, StoragePathAuthorizer pathAuthorizer) {
    this.storageService = storageService;
    this.pathAuthorizer = pathAuthorizer;
  }

  @PutMapping(consumes = MediaType.APPLICATION_OCTET_STREAM_VALUE)
  public ResponseEntity<Void> put(
      @RequestHeader(PATH_HEADER) String pathHeader, @RequestBody byte[] body) {
    String uid = FolioUserPrincipal.requireUid();
    String path = requirePath(pathHeader);
    if (body == null || body.length == 0) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "Empty body");
    }
    if (body.length > MAX_PUT_BYTES) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "Object too large");
    }
    pathAuthorizer.assertWrite(uid, path, body.length);
    storageService.putBytes(path, body, MediaType.APPLICATION_OCTET_STREAM_VALUE);
    return ResponseEntity.status(HttpStatus.CREATED).build();
  }

  @GetMapping
  public ResponseEntity<byte[]> get(@RequestHeader(PATH_HEADER) String pathHeader) {
    String uid = FolioUserPrincipal.requireUid();
    String path = requirePath(pathHeader);
    pathAuthorizer.assertRead(uid, path);
    if (!storageService.exists(path)) {
      throw new ApiException(HttpStatus.NOT_FOUND, "not_found", "Object not found");
    }
    byte[] bytes = storageService.getBytes(path);
    return ResponseEntity.ok()
        .contentType(MediaType.APPLICATION_OCTET_STREAM)
        .header(HttpHeaders.CONTENT_LENGTH, String.valueOf(bytes.length))
        .body(bytes);
  }

  @RequestMapping(method = RequestMethod.HEAD)
  public ResponseEntity<Void> head(@RequestHeader(PATH_HEADER) String pathHeader) {
    String uid = FolioUserPrincipal.requireUid();
    String path = requirePath(pathHeader);
    pathAuthorizer.assertRead(uid, path);
    if (!storageService.exists(path)) {
      return ResponseEntity.notFound().build();
    }
    long size = storageService.objectSize(path);
    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_LENGTH, String.valueOf(size))
        .build();
  }

  private static String requirePath(String raw) {
    String path = raw == null ? "" : raw.trim();
    while (path.startsWith("/")) {
      path = path.substring(1);
    }
    if (path.isEmpty() || path.contains("..") || path.length() > 1024) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "storage path invalid");
    }
    return path;
  }
}
