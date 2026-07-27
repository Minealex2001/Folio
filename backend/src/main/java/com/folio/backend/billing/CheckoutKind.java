package com.folio.backend.billing;

public enum CheckoutKind {
  folio_cloud_monthly,
  folio_family_monthly,
  folio_student_monthly,
  ink_small,
  ink_medium,
  ink_large,
  backup_storage_pack_small,
  backup_storage_pack_medium,
  backup_storage_pack_large;

  public static CheckoutKind fromRaw(String raw) {
    String kind = raw == null || raw.isBlank() ? "folio_cloud_monthly" : raw.trim();
    if ("backup_storage_pack".equals(kind)) {
      kind = "backup_storage_pack_small";
    }
    return CheckoutKind.valueOf(kind);
  }

  public boolean isSubscription() {
    return this == folio_cloud_monthly
        || this == folio_family_monthly
        || this == folio_student_monthly
        || this == backup_storage_pack_small
        || this == backup_storage_pack_medium
        || this == backup_storage_pack_large;
  }
}
