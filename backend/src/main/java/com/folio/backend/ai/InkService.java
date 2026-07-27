package com.folio.backend.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.entity.UserInkEntity;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.folio.backend.persistence.repository.UserRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class InkService {

  private static final Logger log = LoggerFactory.getLogger(InkService.class);
  private static final String INK_EXHAUSTED =
      "Insufficient ink. Buy an ink pack in Folio Cloud settings, wait for your monthly refill with an active subscription, or switch to a local AI provider (Ollama / LM Studio).";

  private final UserRepository userRepository;
  private final UserInkRepository inkRepository;
  private final UserFolioCloudRepository folioCloudRepository;
  private final ObjectMapper mapper;

  public InkService(
      UserRepository userRepository,
      UserInkRepository inkRepository,
      UserFolioCloudRepository folioCloudRepository,
      ObjectMapper mapper) {
    this.userRepository = userRepository;
    this.inkRepository = inkRepository;
    this.folioCloudRepository = folioCloudRepository;
    this.mapper = mapper;
  }

  public boolean isStaff(String uid) {
    return userRepository.findById(uid).map(UserEntity::isFolioStaff).orElse(false);
  }

  public boolean hasCloudAiSubscription(String uid) {
    return folioCloudRepository
        .findById(uid)
        .map(this::hasCloudAi)
        .orElse(false);
  }

  private boolean hasCloudAi(UserFolioCloudEntity fc) {
    if (!fc.isActive()) {
      return false;
    }
    try {
      JsonNode features = mapper.readTree(fc.getFeatures() == null ? "{}" : fc.getFeatures());
      return features.path("cloudAi").asBoolean(false);
    } catch (Exception e) {
      return false;
    }
  }

  @Transactional
  public DebitResult debitForAi(String uid, int cost) {
    if (cost <= 0 || isStaff(uid)) {
      InkPricing.InkBalances bal = readBalances(uid);
      return new DebitResult(bal, false, hasCloudAiSubscription(uid));
    }
    UserInkEntity ink =
        inkRepository
            .findById(uid)
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "User ink not found"));
    boolean allowSub = hasCloudAiSubscription(uid);
    int monthly = toInt(ink.getMonthlyBalance());
    int purchased = toInt(ink.getPurchasedBalance());
    if (allowSub) {
      if (monthly + purchased < cost) {
        throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "resource_exhausted", INK_EXHAUSTED);
      }
      InkPricing.InkBalances next = InkPricing.debit(monthly, purchased, cost);
      ink.setMonthlyBalance(BigDecimal.valueOf(next.monthly()));
      ink.setPurchasedBalance(BigDecimal.valueOf(next.purchased()));
    } else {
      if (purchased < cost) {
        throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "resource_exhausted", INK_EXHAUSTED);
      }
      InkPricing.InkBalances next = InkPricing.debit(0, purchased, cost);
      ink.setMonthlyBalance(BigDecimal.ZERO);
      ink.setPurchasedBalance(BigDecimal.valueOf(next.purchased()));
    }
    inkRepository.save(ink);
    return new DebitResult(readBalances(uid), true, allowSub);
  }

  @Transactional
  public void refund(String uid, int amount) {
    if (amount <= 0) {
      return;
    }
    try {
      UserInkEntity ink =
          inkRepository
              .findById(uid)
              .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "User ink not found"));
      int purchased = toInt(ink.getPurchasedBalance());
      ink.setPurchasedBalance(BigDecimal.valueOf(purchased + amount));
      inkRepository.save(ink);
    } catch (Exception e) {
      log.error("ink refund failed uid={} amount={}", uid, amount, e);
    }
  }

  @Transactional
  public int chargeExtraIfPossible(String uid, int extra, boolean allowSubscriptionInk) {
    if (extra <= 0 || isStaff(uid)) {
      return 0;
    }
    UserInkEntity ink = inkRepository.findById(uid).orElse(null);
    if (ink == null) {
      return 0;
    }
    int monthly = toInt(ink.getMonthlyBalance());
    int purchased = toInt(ink.getPurchasedBalance());
    int effectiveMonthly = allowSubscriptionInk ? monthly : 0;
    int take = Math.min(extra, effectiveMonthly + purchased);
    if (take <= 0) {
      return 0;
    }
    InkPricing.InkBalances next = InkPricing.debit(effectiveMonthly, purchased, take);
    if (allowSubscriptionInk) {
      ink.setMonthlyBalance(BigDecimal.valueOf(next.monthly()));
    } else {
      ink.setMonthlyBalance(BigDecimal.ZERO);
    }
    ink.setPurchasedBalance(BigDecimal.valueOf(next.purchased()));
    inkRepository.save(ink);
    return take;
  }

  public InkPricing.InkBalances readBalances(String uid) {
    return inkRepository
        .findById(uid)
        .map(i -> new InkPricing.InkBalances(toInt(i.getMonthlyBalance()), toInt(i.getPurchasedBalance())))
        .orElse(new InkPricing.InkBalances(0, 0));
  }

  private static int toInt(BigDecimal v) {
    if (v == null) {
      return 0;
    }
    return Math.max(0, v.setScale(0, RoundingMode.DOWN).intValue());
  }

  public record DebitResult(InkPricing.InkBalances balances, boolean debited, boolean allowSubscriptionInk) {}
}
