package com.folio.backend.integrations;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

public final class PlatformSignatureVerifier {

  private PlatformSignatureVerifier() {}

  public static boolean verifySlack(
      String signingSecret, byte[] rawBody, String timestamp, String signature) {
    if (signingSecret == null
        || signingSecret.isBlank()
        || timestamp == null
        || timestamp.isBlank()
        || signature == null
        || signature.isBlank()
        || rawBody == null) {
      return false;
    }
    long ts;
    try {
      ts = Long.parseLong(timestamp);
    } catch (NumberFormatException e) {
      return false;
    }
    long ageSec = Math.abs(System.currentTimeMillis() / 1000L - ts);
    if (ageSec > 60 * 5) {
      return false;
    }
    String base = "v0:" + timestamp + ":" + new String(rawBody, StandardCharsets.UTF_8);
    String digest = hmacSha256Hex(signingSecret, base);
    String expected = "v0=" + digest;
    return constantTimeEquals(expected, signature);
  }

  public static boolean verifyTeamsOutgoingHmac(
      String securityToken, byte[] rawBody, String authorization) {
    String token = securityToken == null ? "" : securityToken.trim();
    if (token.isEmpty() || authorization == null || authorization.isBlank() || rawBody == null) {
      return false;
    }
    try {
      Mac mac = Mac.getInstance("HmacSHA256");
      mac.init(new SecretKeySpec(token.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
      String hash =
          java.util.Base64.getEncoder().encodeToString(mac.doFinal(rawBody));
      String expected = "HMAC " + hash;
      return constantTimeEquals(expected, authorization.trim());
    } catch (Exception e) {
      return false;
    }
  }

  private static String hmacSha256Hex(String secret, String base) {
    try {
      Mac mac = Mac.getInstance("HmacSHA256");
      mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
      return HexFormat.of().formatHex(mac.doFinal(base.getBytes(StandardCharsets.UTF_8)));
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  private static boolean constantTimeEquals(String a, String b) {
    byte[] left = a.getBytes(StandardCharsets.UTF_8);
    byte[] right = b.getBytes(StandardCharsets.UTF_8);
    return MessageDigest.isEqual(left, right);
  }
}
