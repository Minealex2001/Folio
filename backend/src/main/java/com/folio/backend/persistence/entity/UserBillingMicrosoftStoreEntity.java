package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "user_billing_microsoft_store")
public class UserBillingMicrosoftStoreEntity {

  @Id
  @Column(name = "user_id", nullable = false)
  private String userId;

  @Column(name = "subscription_active", nullable = false)
  private boolean subscriptionActive;

  @Column(name = "subscription_store_product_id")
  private String subscriptionStoreProductId;

  @Column(name = "last_validated_at")
  private Instant lastValidatedAt;

  @Column(name = "last_item_count")
  private Integer lastItemCount;

  public static UserBillingMicrosoftStoreEntity defaultsFor(String userId) {
    UserBillingMicrosoftStoreEntity e = new UserBillingMicrosoftStoreEntity();
    e.userId = userId;
    e.subscriptionActive = false;
    return e;
  }

  public String getUserId() {
    return userId;
  }

  public void setUserId(String userId) {
    this.userId = userId;
  }

  public boolean isSubscriptionActive() {
    return subscriptionActive;
  }

  public void setSubscriptionActive(boolean subscriptionActive) {
    this.subscriptionActive = subscriptionActive;
  }

  public String getSubscriptionStoreProductId() {
    return subscriptionStoreProductId;
  }

  public void setSubscriptionStoreProductId(String subscriptionStoreProductId) {
    this.subscriptionStoreProductId = subscriptionStoreProductId;
  }

  public Instant getLastValidatedAt() {
    return lastValidatedAt;
  }

  public void setLastValidatedAt(Instant lastValidatedAt) {
    this.lastValidatedAt = lastValidatedAt;
  }

  public Integer getLastItemCount() {
    return lastItemCount;
  }

  public void setLastItemCount(Integer lastItemCount) {
    this.lastItemCount = lastItemCount;
  }
}
