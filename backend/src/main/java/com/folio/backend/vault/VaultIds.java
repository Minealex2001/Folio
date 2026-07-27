package com.folio.backend.vault;

import com.folio.backend.common.ApiException;
import java.util.Base64;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;

public final class VaultIds {
  private static final Pattern VAULT_ID = Pattern.compile("^[A-Za-z0-9_-]{1,128}$");
  private static final Pattern BLOB_ID = Pattern.compile("^[0-9a-f]{64}$");
  private static final Pattern FINGERPRINT = Pattern.compile("^[0-9a-f]+$", Pattern.CASE_INSENSITIVE);

  private VaultIds() {}

  public static String requireVaultId(String raw) {
    String v = raw == null ? "" : raw.trim();
    if (!VAULT_ID.matcher(v).matches()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "vaultId invalid");
    }
    return v;
  }

  public static String requireBlobId(String raw) {
    String b = raw == null ? "" : raw.trim().toLowerCase();
    if (!BLOB_ID.matcher(b).matches()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "blobId invalid");
    }
    return b;
  }

  public static String requireFingerprint(String raw) {
    String fp = raw == null ? "" : raw.trim().toLowerCase();
    if (fp.isEmpty() || fp.length() > 200 || !FINGERPRINT.matcher(fp).matches()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "contentFingerprint invalid");
    }
    return fp;
  }

  public static void validateRestoreWrap(String wrapB64, String wrapKind) {
    if (wrapB64 == null || wrapB64.isBlank()) {
      return;
    }
    if (!"vaultDek".equals(wrapKind) && !"packKey".equals(wrapKind)) {
      throw new ApiException(
          HttpStatus.BAD_REQUEST,
          "invalid_argument",
          "cloudPackRestoreWrapKind must be vaultDek or packKey");
    }
    byte[] buf;
    try {
      buf = Base64.getDecoder().decode(wrapB64.trim());
    } catch (IllegalArgumentException e) {
      throw new ApiException(
          HttpStatus.BAD_REQUEST, "invalid_argument", "cloudPackRestoreWrapB64 invalid base64");
    }
    if (buf.length < 44 || buf.length > 4096) {
      throw new ApiException(
          HttpStatus.BAD_REQUEST, "invalid_argument", "cloudPackRestoreWrapB64 size invalid");
    }
  }
}
