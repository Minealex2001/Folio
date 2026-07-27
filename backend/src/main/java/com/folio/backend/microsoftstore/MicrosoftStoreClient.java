package com.folio.backend.microsoftstore;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.folio.backend.common.ApiException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** Port of {@code functions/src/microsoft_store.ts} HTTP bits. */
@Component
public class MicrosoftStoreClient {

  private static final Logger log = LoggerFactory.getLogger(MicrosoftStoreClient.class);
  private static final long BACKUP_SMALL = 20L * 1024 * 1024 * 1024;
  private static final long BACKUP_MEDIUM = 75L * 1024 * 1024 * 1024;
  private static final long BACKUP_LARGE = 250L * 1024 * 1024 * 1024;

  private final MicrosoftStoreProperties props;
  private final ObjectMapper objectMapper;
  private final HttpClient httpClient;

  public MicrosoftStoreClient(MicrosoftStoreProperties props, ObjectMapper objectMapper) {
    this.props = props;
    this.objectMapper = objectMapper;
    this.httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(20)).build();
  }

  public String acquireAccessToken() {
    if (!props.isValidationConfigured()) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "Microsoft Store validation is not configured (Azure AD + MS_STORE_PRODUCT_FOLIO_CLOUD_MONTHLY).");
    }
    String[] scopes = {
      "https://onestore.microsoft.com/.default", "https://purchase.mp.microsoft.com/.default"
    };
    for (String scope : scopes) {
      String tok = fetchAzureAdToken(scope);
      if (tok != null) {
        return tok;
      }
    }
    throw new ApiException(
        HttpStatus.INTERNAL_SERVER_ERROR,
        "internal",
        "Could not acquire Azure AD token for Microsoft Store (check tenant, client id/secret, and API permissions).");
  }

  private String fetchAzureAdToken(String scope) {
    try {
      String tenant = props.getAzureAdTenantId().trim();
      String url =
          props.getTokenUrlTemplate().replace("{tenant}", URLEncoder.encode(tenant, StandardCharsets.UTF_8));
      String body =
          "client_id="
              + enc(props.getAzureAdClientId().trim())
              + "&client_secret="
              + enc(props.getAzureAdClientSecret().trim())
              + "&scope="
              + enc(scope)
              + "&grant_type=client_credentials";
      HttpRequest req =
          HttpRequest.newBuilder(URI.create(url))
              .timeout(Duration.ofSeconds(30))
              .header("Content-Type", "application/x-www-form-urlencoded")
              .POST(HttpRequest.BodyPublishers.ofString(body))
              .build();
      HttpResponse<String> res = httpClient.send(req, HttpResponse.BodyHandlers.ofString());
      JsonNode json = objectMapper.readTree(res.body());
      if (res.statusCode() >= 200 && res.statusCode() < 300 && json.hasNonNull("access_token")) {
        return json.get("access_token").asText();
      }
      log.warn("Azure AD token failed {} {} {}", scope, json.path("error").asText(), res.statusCode());
      return null;
    } catch (Exception e) {
      log.warn("Azure AD token exception", e);
      return null;
    }
  }

  public List<Map<String, Object>> queryUserCollection(String collectionsId) {
    String token = acquireAccessToken();
    try {
      String jsonBody =
          objectMapper.writeValueAsString(
              Map.of(
                  "beneficiaries",
                  List.of(collectionsId),
                  "modifiedAfter",
                  "1970-01-01T00:00:00.000Z",
                  "maxPageSize",
                  100));
      HttpRequest req =
          HttpRequest.newBuilder(URI.create(props.getCollectionsQueryUrl()))
              .timeout(Duration.ofSeconds(30))
              .header("Authorization", "Bearer " + token)
              .header("Content-Type", "application/json; charset=utf-8")
              .POST(HttpRequest.BodyPublishers.ofString(jsonBody))
              .build();
      HttpResponse<String> res = httpClient.send(req, HttpResponse.BodyHandlers.ofString());
      JsonNode parsed;
      try {
        parsed = objectMapper.readTree(res.body());
      } catch (Exception e) {
        throw new ApiException(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "internal",
            "Microsoft Store collections API returned invalid JSON.");
      }
      if (res.statusCode() < 200 || res.statusCode() >= 300) {
        throw new ApiException(
            HttpStatus.PRECONDITION_FAILED,
            "failed_precondition",
            "Microsoft Store collections query failed (HTTP " + res.statusCode() + ").");
      }
      return normalizeItems(parsed);
    } catch (ApiException e) {
      throw e;
    } catch (Exception e) {
      throw new ApiException(
          HttpStatus.INTERNAL_SERVER_ERROR, "internal", "Microsoft Store collections query error");
    }
  }

  @SuppressWarnings("unchecked")
  private List<Map<String, Object>> normalizeItems(JsonNode payload) {
    List<Map<String, Object>> out = new ArrayList<>();
    JsonNode raw =
        firstPresent(
            payload,
            "Items",
            "items",
            "DataItems",
            "dataItems",
            "CollectionItems",
            "collectionItems");
    if (raw == null || !raw.isArray()) {
      return out;
    }
    for (JsonNode x : raw) {
      if (x != null && x.isObject()) {
        out.add(objectMapper.convertValue(x, Map.class));
      }
    }
    return out;
  }

  private static JsonNode firstPresent(JsonNode root, String... keys) {
    for (String k : keys) {
      if (root.has(k)) {
        return root.get(k);
      }
    }
    return null;
  }

  public CollectionScan scanCollectionItems(List<Map<String, Object>> items) {
    String monthlyId = blank(props.getProductFolioCloudMonthly());
    boolean subscriptionActive = false;
    String subscriptionStoreProductId = null;

    for (Map<String, Object> item : items) {
      if (itemMatchesMonthlySubscription(item)) {
        subscriptionActive = true;
        subscriptionStoreProductId =
            !monthlyId.isEmpty() ? monthlyId : orEmpty(itemProductId(item));
        if (subscriptionStoreProductId.isEmpty()) {
          subscriptionStoreProductId = null;
        }
        break;
      }
    }

    List<ConsumableGrant> consumableGrants = new ArrayList<>();
    List<BackupGrant> backupStorageGrants = new ArrayList<>();
    for (Map<String, Object> item : items) {
      String pid = itemProductId(item);
      if (pid.isEmpty()) {
        continue;
      }
      if (normId(pid).equals(normId(monthlyId))) {
        continue;
      }
      if (!itemLooksActive(item)) {
        continue;
      }
      String key = microsoftPurchaseDedupKey(item);
      if (key == null) {
        continue;
      }
      int qty = itemQuantity(item);
      int dropsEach = inkDropsForProductId(pid);
      if (dropsEach > 0) {
        consumableGrants.add(new ConsumableGrant(key, dropsEach * qty));
        continue;
      }
      long backupEach = backupBytesForProductId(pid);
      if (backupEach > 0) {
        backupStorageGrants.add(new BackupGrant(key + ":backup", backupEach * qty));
      }
    }
    return new CollectionScan(
        subscriptionActive, subscriptionStoreProductId, consumableGrants, backupStorageGrants);
  }

  public boolean itemMatchesMonthlySubscription(Map<String, Object> item) {
    String pid = itemProductId(item);
    if (pid.isEmpty()) {
      return false;
    }
    if (!normId(pid).equals(normId(props.getProductFolioCloudMonthly()))) {
      return false;
    }
    return itemLooksActive(item);
  }

  public int inkDropsForProductId(String productId) {
    String p = normId(productId);
    if (p.isEmpty()) {
      return 0;
    }
    if (p.equals(normId(props.getInkSmall()))) {
      return 300;
    }
    if (p.equals(normId(props.getInkMedium()))) {
      return 1000;
    }
    if (p.equals(normId(props.getInkLarge()))) {
      return 2500;
    }
    return 0;
  }

  public long backupBytesForProductId(String productId) {
    String p = normId(productId);
    if (p.isEmpty()) {
      return 0;
    }
    if (!blank(props.getBackupStoragePackLarge()).isEmpty()
        && p.equals(normId(props.getBackupStoragePackLarge()))) {
      return BACKUP_LARGE;
    }
    if (!blank(props.getBackupStoragePackMedium()).isEmpty()
        && p.equals(normId(props.getBackupStoragePackMedium()))) {
      return BACKUP_MEDIUM;
    }
    String small = blank(props.getBackupStoragePackSmall());
    if (!small.isEmpty() && p.equals(normId(small))) {
      return BACKUP_SMALL;
    }
    return 0;
  }

  public String microsoftPurchaseDedupKey(Map<String, Object> item) {
    String pid = itemProductId(item);
    String sku = itemSkuId(item);
    Object omRaw = first(item, "orderManagementData", "OrderManagementData");
    if (omRaw instanceof Map<?, ?> om) {
      Object orderId = first((Map<String, Object>) om, "orderId", "OrderId");
      if (orderId instanceof String s && !s.trim().isEmpty()) {
        return "msstore:order:" + s.trim();
      }
    }
    Object lm = first(item, "lastModified", "LastModified");
    String lmStr = lm instanceof String s ? s.trim() : "";
    if (!pid.isEmpty() && !sku.isEmpty() && !lmStr.isEmpty()) {
      return "msstore:" + normId(pid) + ":" + normId(sku) + ":" + lmStr;
    }
    return null;
  }

  private static boolean itemLooksActive(Map<String, Object> item) {
    String st = itemState(item).toLowerCase(Locale.ROOT);
    if (st.isEmpty()) {
      return true;
    }
    if (st.contains("revoke") || st.contains("cancel") || "inactive".equals(st)) {
      return false;
    }
    return true;
  }

  private static String itemProductId(Map<String, Object> item) {
    Object v = first(item, "productId", "ProductId");
    return v instanceof String s ? s.trim() : "";
  }

  private static String itemSkuId(Map<String, Object> item) {
    Object v = first(item, "skuId", "SkuId");
    return v instanceof String s ? s.trim() : "";
  }

  private static String itemState(Map<String, Object> item) {
    Object v = first(item, "state", "State", "status", "Status");
    return v instanceof String s ? s.trim() : "";
  }

  private static int itemQuantity(Map<String, Object> item) {
    Object v = first(item, "quantity", "Quantity");
    double n =
        v instanceof Number num
            ? num.doubleValue()
            : (v != null ? Double.parseDouble(String.valueOf(v)) : 1);
    if (!Double.isFinite(n) || n < 1) {
      return 1;
    }
    return Math.min(1000, (int) n);
  }

  private static Object first(Map<?, ?> map, String... keys) {
    for (String k : keys) {
      if (map.containsKey(k)) {
        return map.get(k);
      }
    }
    return null;
  }

  private static String normId(String s) {
    return s == null ? "" : s.trim().toLowerCase(Locale.ROOT);
  }

  private static String blank(String s) {
    return s == null ? "" : s.trim();
  }

  private static String orEmpty(String s) {
    return s == null ? "" : s;
  }

  private static String enc(String s) {
    return URLEncoder.encode(s, StandardCharsets.UTF_8);
  }

  public record ConsumableGrant(String dedupKey, int drops) {}

  public record BackupGrant(String dedupKey, long bytes) {}

  public record CollectionScan(
      boolean subscriptionActive,
      String subscriptionStoreProductId,
      List<ConsumableGrant> consumableGrants,
      List<BackupGrant> backupStorageGrants) {}
}
