package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "user_billing_stripe")
public class UserBillingStripeEntity {

  @Id
  @Column(name = "user_id", nullable = false)
  private String userId;

  @Column(name = "subscription_id")
  private String subscriptionId;

  @Column(name = "price_id")
  private String priceId;

  @Column(name = "family_seats", nullable = false)
  private int familySeats;

  @Column(name = "student_verified", nullable = false)
  private boolean studentVerified;

  @JdbcTypeCode(SqlTypes.JSON)
  @Column(name = "raw", nullable = false, columnDefinition = "jsonb")
  private String raw = "{}";

  public static UserBillingStripeEntity defaultsFor(String userId) {
    UserBillingStripeEntity e = new UserBillingStripeEntity();
    e.userId = userId;
    e.familySeats = 0;
    e.studentVerified = false;
    e.raw = "{}";
    return e;
  }

  public String getUserId() {
    return userId;
  }

  public void setUserId(String userId) {
    this.userId = userId;
  }

  public String getSubscriptionId() {
    return subscriptionId;
  }

  public void setSubscriptionId(String subscriptionId) {
    this.subscriptionId = subscriptionId;
  }

  public String getPriceId() {
    return priceId;
  }

  public void setPriceId(String priceId) {
    this.priceId = priceId;
  }

  public int getFamilySeats() {
    return familySeats;
  }

  public void setFamilySeats(int familySeats) {
    this.familySeats = familySeats;
  }

  public boolean isStudentVerified() {
    return studentVerified;
  }

  public void setStudentVerified(boolean studentVerified) {
    this.studentVerified = studentVerified;
  }

  public String getRaw() {
    return raw;
  }

  public void setRaw(String raw) {
    this.raw = raw == null ? "{}" : raw;
  }
}
