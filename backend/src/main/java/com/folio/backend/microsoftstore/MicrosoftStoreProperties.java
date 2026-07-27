package com.folio.backend.microsoftstore;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "folio.microsoft-store")
public class MicrosoftStoreProperties {

  private String azureAdTenantId = "";
  private String azureAdClientId = "";
  private String azureAdClientSecret = "";
  private String productFolioCloudMonthly = "";
  private String inkSmall = "";
  private String inkMedium = "";
  private String inkLarge = "";
  private String backupStoragePackSmall = "";
  private String backupStoragePackMedium = "";
  private String backupStoragePackLarge = "";
  /** Overridable for tests (MockWebServer). */
  private String collectionsQueryUrl = "https://collections.mp.microsoft.com/v6.0/collections/query";

  private String tokenUrlTemplate =
      "https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token";

  public String getAzureAdTenantId() {
    return azureAdTenantId;
  }

  public void setAzureAdTenantId(String azureAdTenantId) {
    this.azureAdTenantId = azureAdTenantId;
  }

  public String getAzureAdClientId() {
    return azureAdClientId;
  }

  public void setAzureAdClientId(String azureAdClientId) {
    this.azureAdClientId = azureAdClientId;
  }

  public String getAzureAdClientSecret() {
    return azureAdClientSecret;
  }

  public void setAzureAdClientSecret(String azureAdClientSecret) {
    this.azureAdClientSecret = azureAdClientSecret;
  }

  public String getProductFolioCloudMonthly() {
    return productFolioCloudMonthly;
  }

  public void setProductFolioCloudMonthly(String productFolioCloudMonthly) {
    this.productFolioCloudMonthly = productFolioCloudMonthly;
  }

  public String getInkSmall() {
    return inkSmall;
  }

  public void setInkSmall(String inkSmall) {
    this.inkSmall = inkSmall;
  }

  public String getInkMedium() {
    return inkMedium;
  }

  public void setInkMedium(String inkMedium) {
    this.inkMedium = inkMedium;
  }

  public String getInkLarge() {
    return inkLarge;
  }

  public void setInkLarge(String inkLarge) {
    this.inkLarge = inkLarge;
  }

  public String getBackupStoragePackSmall() {
    return backupStoragePackSmall;
  }

  public void setBackupStoragePackSmall(String backupStoragePackSmall) {
    this.backupStoragePackSmall = backupStoragePackSmall;
  }

  public String getBackupStoragePackMedium() {
    return backupStoragePackMedium;
  }

  public void setBackupStoragePackMedium(String backupStoragePackMedium) {
    this.backupStoragePackMedium = backupStoragePackMedium;
  }

  public String getBackupStoragePackLarge() {
    return backupStoragePackLarge;
  }

  public void setBackupStoragePackLarge(String backupStoragePackLarge) {
    this.backupStoragePackLarge = backupStoragePackLarge;
  }

  public String getCollectionsQueryUrl() {
    return collectionsQueryUrl;
  }

  public void setCollectionsQueryUrl(String collectionsQueryUrl) {
    this.collectionsQueryUrl = collectionsQueryUrl;
  }

  public String getTokenUrlTemplate() {
    return tokenUrlTemplate;
  }

  public void setTokenUrlTemplate(String tokenUrlTemplate) {
    this.tokenUrlTemplate = tokenUrlTemplate;
  }

  public boolean isValidationConfigured() {
    return !blank(azureAdTenantId).isEmpty()
        && !blank(azureAdClientId).isEmpty()
        && !blank(azureAdClientSecret).isEmpty()
        && !blank(productFolioCloudMonthly).isEmpty();
  }

  private static String blank(String s) {
    return s == null ? "" : s.trim();
  }
}
