package com.folio.backend.billing;

import java.util.Arrays;
import java.util.List;
import org.springframework.stereotype.Component;

@Component
public class StripeCatalog {

  private final StripeProperties props;

  public StripeCatalog(StripeProperties props) {
    this.props = props;
  }

  public String secretKey(boolean debug) {
    if (debug) {
      return firstNonBlank(props.getTestSecretKey(), props.getSecretKey());
    }
    return blankToEmpty(props.getSecretKey());
  }

  public String webhookSecret(boolean test) {
    if (test) {
      return firstNonBlank(props.getTestWebhookSecret(), props.getWebhookSecret());
    }
    return blankToEmpty(props.getWebhookSecret());
  }

  public String catalogId(CheckoutKind kind, boolean debug) {
    return switch (kind) {
      case folio_cloud_monthly ->
          pick(debug, props.getTestPriceFolioCloudMonthly(), props.getPriceFolioCloudMonthly());
      case folio_family_monthly ->
          pick(debug, props.getTestPriceFolioCloudFamily(), props.getPriceFolioCloudFamily());
      case folio_student_monthly ->
          pick(debug, props.getTestPriceFolioCloudStudent(), props.getPriceFolioCloudStudent());
      case ink_small -> pick(debug, props.getTestPriceInkSmall(), props.getPriceInkSmall());
      case ink_medium -> pick(debug, props.getTestPriceInkMedium(), props.getPriceInkMedium());
      case ink_large -> pick(debug, props.getTestPriceInkLarge(), props.getPriceInkLarge());
      case backup_storage_pack_small ->
          pick(
              debug,
              props.getTestPriceBackupStoragePackSmall(),
              props.getPriceBackupStoragePackSmall());
      case backup_storage_pack_medium ->
          pick(
              debug,
              props.getTestPriceBackupStoragePackMedium(),
              props.getPriceBackupStoragePackMedium());
      case backup_storage_pack_large ->
          pick(
              debug,
              props.getTestPriceBackupStoragePackLarge(),
              props.getPriceBackupStoragePackLarge());
    };
  }

  public String priceFolioCloudMonthly(boolean debug) {
    return pick(debug, props.getTestPriceFolioCloudMonthly(), props.getPriceFolioCloudMonthly());
  }

  public String priceFolioCloudFamily(boolean debug) {
    return pick(debug, props.getTestPriceFolioCloudFamily(), props.getPriceFolioCloudFamily());
  }

  public String priceFolioCloudFamilyMember(boolean debug) {
    return pick(
        debug, props.getTestPriceFolioCloudFamilyMember(), props.getPriceFolioCloudFamilyMember());
  }

  public String priceFolioCloudStudent(boolean debug) {
    return pick(debug, props.getTestPriceFolioCloudStudent(), props.getPriceFolioCloudStudent());
  }

  public String priceInkSmall(boolean debug) {
    return pick(debug, props.getTestPriceInkSmall(), props.getPriceInkSmall());
  }

  public String priceInkMedium(boolean debug) {
    return pick(debug, props.getTestPriceInkMedium(), props.getPriceInkMedium());
  }

  public String priceInkLarge(boolean debug) {
    return pick(debug, props.getTestPriceInkLarge(), props.getPriceInkLarge());
  }

  public String priceBackupSmall(boolean debug) {
    return pick(
        debug, props.getTestPriceBackupStoragePackSmall(), props.getPriceBackupStoragePackSmall());
  }

  public String priceBackupMedium(boolean debug) {
    return pick(
        debug, props.getTestPriceBackupStoragePackMedium(), props.getPriceBackupStoragePackMedium());
  }

  public String priceBackupLarge(boolean debug) {
    return pick(
        debug, props.getTestPriceBackupStoragePackLarge(), props.getPriceBackupStoragePackLarge());
  }

  public List<String> legacyPriceIds() {
    String raw = blankToEmpty(props.getLegacyPriceIds());
    if (raw.isEmpty()) {
      return List.of();
    }
    return Arrays.stream(raw.split(",")).map(String::trim).filter(s -> !s.isEmpty()).toList();
  }

  public String successUrl() {
    String u = firstNonBlank(props.getCheckoutSuccessUrl(), props.getBillingPortalReturnUrl());
    return u.isEmpty() ? "https://folio.app" : u;
  }

  public String cancelUrl() {
    String c = blankToEmpty(props.getCheckoutCancelUrl());
    return c.isEmpty() ? successUrl() : c;
  }

  public String portalReturnUrl() {
    String u = blankToEmpty(props.getBillingPortalReturnUrl());
    return u.isEmpty() ? "https://folio.app" : u;
  }

  private static String pick(boolean debug, String test, String live) {
    if (debug) {
      return firstNonBlank(test, live);
    }
    return blankToEmpty(live);
  }

  private static String firstNonBlank(String a, String b) {
    String x = blankToEmpty(a);
    return x.isEmpty() ? blankToEmpty(b) : x;
  }

  private static String blankToEmpty(String s) {
    return s == null ? "" : s.trim();
  }
}
