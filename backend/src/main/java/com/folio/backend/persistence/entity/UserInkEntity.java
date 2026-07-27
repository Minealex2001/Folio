package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "user_ink")
public class UserInkEntity {

  @Id
  @Column(name = "user_id", nullable = false)
  private String userId;

  @Column(name = "monthly_balance", nullable = false)
  private BigDecimal monthlyBalance = BigDecimal.ZERO;

  @Column(name = "purchased_balance", nullable = false)
  private BigDecimal purchasedBalance = BigDecimal.ZERO;

  @Column(name = "monthly_period_key")
  private String monthlyPeriodKey;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  @PrePersist
  @PreUpdate
  void touch() {
    updatedAt = Instant.now();
  }

  public static UserInkEntity defaultsFor(String userId) {
    UserInkEntity e = new UserInkEntity();
    e.userId = userId;
    e.monthlyBalance = BigDecimal.ZERO;
    e.purchasedBalance = BigDecimal.ZERO;
    return e;
  }

  public String getUserId() {
    return userId;
  }

  public void setUserId(String userId) {
    this.userId = userId;
  }

  public BigDecimal getMonthlyBalance() {
    return monthlyBalance;
  }

  public void setMonthlyBalance(BigDecimal monthlyBalance) {
    this.monthlyBalance = monthlyBalance;
  }

  public BigDecimal getPurchasedBalance() {
    return purchasedBalance;
  }

  public void setPurchasedBalance(BigDecimal purchasedBalance) {
    this.purchasedBalance = purchasedBalance;
  }

  public String getMonthlyPeriodKey() {
    return monthlyPeriodKey;
  }

  public void setMonthlyPeriodKey(String monthlyPeriodKey) {
    this.monthlyPeriodKey = monthlyPeriodKey;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }

  public void setUpdatedAt(Instant updatedAt) {
    this.updatedAt = updatedAt;
  }
}
