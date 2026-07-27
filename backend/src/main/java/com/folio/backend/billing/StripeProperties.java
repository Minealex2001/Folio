package com.folio.backend.billing;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "folio.stripe")
public class StripeProperties {

  private String secretKey = "";
  private String testSecretKey = "";
  private String webhookSecret = "";
  private String testWebhookSecret = "";
  private String checkoutSuccessUrl = "https://folio.app";
  private String checkoutCancelUrl = "";
  private String billingPortalReturnUrl = "https://folio.app";
  private String priceFolioCloudMonthly = "";
  private String priceFolioCloudFamily = "";
  private String priceFolioCloudFamilyMember = "";
  private String priceFolioCloudStudent = "";
  private String priceInkSmall = "";
  private String priceInkMedium = "";
  private String priceInkLarge = "";
  private String priceBackupStoragePackSmall = "";
  private String priceBackupStoragePackMedium = "";
  private String priceBackupStoragePackLarge = "";
  private String testPriceFolioCloudMonthly = "";
  private String testPriceFolioCloudFamily = "";
  private String testPriceFolioCloudFamilyMember = "";
  private String testPriceFolioCloudStudent = "";
  private String testPriceInkSmall = "";
  private String testPriceInkMedium = "";
  private String testPriceInkLarge = "";
  private String testPriceBackupStoragePackSmall = "";
  private String testPriceBackupStoragePackMedium = "";
  private String testPriceBackupStoragePackLarge = "";
  private String legacyPriceIds = "";

  public String getSecretKey() {
    return secretKey;
  }

  public void setSecretKey(String secretKey) {
    this.secretKey = secretKey;
  }

  public String getTestSecretKey() {
    return testSecretKey;
  }

  public void setTestSecretKey(String testSecretKey) {
    this.testSecretKey = testSecretKey;
  }

  public String getWebhookSecret() {
    return webhookSecret;
  }

  public void setWebhookSecret(String webhookSecret) {
    this.webhookSecret = webhookSecret;
  }

  public String getTestWebhookSecret() {
    return testWebhookSecret;
  }

  public void setTestWebhookSecret(String testWebhookSecret) {
    this.testWebhookSecret = testWebhookSecret;
  }

  public String getCheckoutSuccessUrl() {
    return checkoutSuccessUrl;
  }

  public void setCheckoutSuccessUrl(String checkoutSuccessUrl) {
    this.checkoutSuccessUrl = checkoutSuccessUrl;
  }

  public String getCheckoutCancelUrl() {
    return checkoutCancelUrl;
  }

  public void setCheckoutCancelUrl(String checkoutCancelUrl) {
    this.checkoutCancelUrl = checkoutCancelUrl;
  }

  public String getBillingPortalReturnUrl() {
    return billingPortalReturnUrl;
  }

  public void setBillingPortalReturnUrl(String billingPortalReturnUrl) {
    this.billingPortalReturnUrl = billingPortalReturnUrl;
  }

  public String getPriceFolioCloudMonthly() {
    return priceFolioCloudMonthly;
  }

  public void setPriceFolioCloudMonthly(String priceFolioCloudMonthly) {
    this.priceFolioCloudMonthly = priceFolioCloudMonthly;
  }

  public String getPriceFolioCloudFamily() {
    return priceFolioCloudFamily;
  }

  public void setPriceFolioCloudFamily(String priceFolioCloudFamily) {
    this.priceFolioCloudFamily = priceFolioCloudFamily;
  }

  public String getPriceFolioCloudFamilyMember() {
    return priceFolioCloudFamilyMember;
  }

  public void setPriceFolioCloudFamilyMember(String priceFolioCloudFamilyMember) {
    this.priceFolioCloudFamilyMember = priceFolioCloudFamilyMember;
  }

  public String getPriceFolioCloudStudent() {
    return priceFolioCloudStudent;
  }

  public void setPriceFolioCloudStudent(String priceFolioCloudStudent) {
    this.priceFolioCloudStudent = priceFolioCloudStudent;
  }

  public String getPriceInkSmall() {
    return priceInkSmall;
  }

  public void setPriceInkSmall(String priceInkSmall) {
    this.priceInkSmall = priceInkSmall;
  }

  public String getPriceInkMedium() {
    return priceInkMedium;
  }

  public void setPriceInkMedium(String priceInkMedium) {
    this.priceInkMedium = priceInkMedium;
  }

  public String getPriceInkLarge() {
    return priceInkLarge;
  }

  public void setPriceInkLarge(String priceInkLarge) {
    this.priceInkLarge = priceInkLarge;
  }

  public String getPriceBackupStoragePackSmall() {
    return priceBackupStoragePackSmall;
  }

  public void setPriceBackupStoragePackSmall(String priceBackupStoragePackSmall) {
    this.priceBackupStoragePackSmall = priceBackupStoragePackSmall;
  }

  public String getPriceBackupStoragePackMedium() {
    return priceBackupStoragePackMedium;
  }

  public void setPriceBackupStoragePackMedium(String priceBackupStoragePackMedium) {
    this.priceBackupStoragePackMedium = priceBackupStoragePackMedium;
  }

  public String getPriceBackupStoragePackLarge() {
    return priceBackupStoragePackLarge;
  }

  public void setPriceBackupStoragePackLarge(String priceBackupStoragePackLarge) {
    this.priceBackupStoragePackLarge = priceBackupStoragePackLarge;
  }

  public String getTestPriceFolioCloudMonthly() {
    return testPriceFolioCloudMonthly;
  }

  public void setTestPriceFolioCloudMonthly(String testPriceFolioCloudMonthly) {
    this.testPriceFolioCloudMonthly = testPriceFolioCloudMonthly;
  }

  public String getTestPriceFolioCloudFamily() {
    return testPriceFolioCloudFamily;
  }

  public void setTestPriceFolioCloudFamily(String testPriceFolioCloudFamily) {
    this.testPriceFolioCloudFamily = testPriceFolioCloudFamily;
  }

  public String getTestPriceFolioCloudFamilyMember() {
    return testPriceFolioCloudFamilyMember;
  }

  public void setTestPriceFolioCloudFamilyMember(String testPriceFolioCloudFamilyMember) {
    this.testPriceFolioCloudFamilyMember = testPriceFolioCloudFamilyMember;
  }

  public String getTestPriceFolioCloudStudent() {
    return testPriceFolioCloudStudent;
  }

  public void setTestPriceFolioCloudStudent(String testPriceFolioCloudStudent) {
    this.testPriceFolioCloudStudent = testPriceFolioCloudStudent;
  }

  public String getTestPriceInkSmall() {
    return testPriceInkSmall;
  }

  public void setTestPriceInkSmall(String testPriceInkSmall) {
    this.testPriceInkSmall = testPriceInkSmall;
  }

  public String getTestPriceInkMedium() {
    return testPriceInkMedium;
  }

  public void setTestPriceInkMedium(String testPriceInkMedium) {
    this.testPriceInkMedium = testPriceInkMedium;
  }

  public String getTestPriceInkLarge() {
    return testPriceInkLarge;
  }

  public void setTestPriceInkLarge(String testPriceInkLarge) {
    this.testPriceInkLarge = testPriceInkLarge;
  }

  public String getTestPriceBackupStoragePackSmall() {
    return testPriceBackupStoragePackSmall;
  }

  public void setTestPriceBackupStoragePackSmall(String testPriceBackupStoragePackSmall) {
    this.testPriceBackupStoragePackSmall = testPriceBackupStoragePackSmall;
  }

  public String getTestPriceBackupStoragePackMedium() {
    return testPriceBackupStoragePackMedium;
  }

  public void setTestPriceBackupStoragePackMedium(String testPriceBackupStoragePackMedium) {
    this.testPriceBackupStoragePackMedium = testPriceBackupStoragePackMedium;
  }

  public String getTestPriceBackupStoragePackLarge() {
    return testPriceBackupStoragePackLarge;
  }

  public void setTestPriceBackupStoragePackLarge(String testPriceBackupStoragePackLarge) {
    this.testPriceBackupStoragePackLarge = testPriceBackupStoragePackLarge;
  }

  public String getLegacyPriceIds() {
    return legacyPriceIds;
  }

  public void setLegacyPriceIds(String legacyPriceIds) {
    this.legacyPriceIds = legacyPriceIds;
  }
}
