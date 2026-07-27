package com.folio.backend.account;

import com.folio.backend.account.dto.AccountMeResponse;
import com.folio.backend.account.dto.UpdateDisplayNameRequest;
import com.folio.backend.common.ApiException;
import com.folio.backend.family.FamilyService;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.entity.UserInkEntity;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.folio.backend.persistence.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AccountService {

  private static final Logger log = LoggerFactory.getLogger(AccountService.class);

  private final UserRepository userRepository;
  private final UserFolioCloudRepository folioCloudRepository;
  private final UserInkRepository inkRepository;
  private final FamilyService familyService;

  public AccountService(
      UserRepository userRepository,
      UserFolioCloudRepository folioCloudRepository,
      UserInkRepository inkRepository,
      FamilyService familyService) {
    this.userRepository = userRepository;
    this.folioCloudRepository = folioCloudRepository;
    this.inkRepository = inkRepository;
    this.familyService = familyService;
  }

  @Transactional(readOnly = true)
  public AccountMeResponse me(String uid) {
    UserEntity user = requireUser(uid);
    UserFolioCloudEntity cloud =
        folioCloudRepository.findById(uid).orElseGet(() -> UserFolioCloudEntity.defaultsFor(uid));
    UserInkEntity ink = inkRepository.findById(uid).orElseGet(() -> UserInkEntity.defaultsFor(uid));
    return toResponse(user, cloud, ink);
  }

  /**
   * Idempotent repair of 1:1 profile rows — port of ensureUserDocExists
   * (functions/src/index.ts). Creates missing user_folio_cloud / user_ink rows.
   */
  @Transactional
  public AccountMeResponse ensure(String uid) {
    UserEntity user = requireUser(uid);
    UserFolioCloudEntity cloud =
        folioCloudRepository
            .findById(uid)
            .orElseGet(() -> folioCloudRepository.save(UserFolioCloudEntity.defaultsFor(uid)));
    UserInkEntity ink =
        inkRepository
            .findById(uid)
            .orElseGet(() -> inkRepository.save(UserInkEntity.defaultsFor(uid)));
    return toResponse(user, cloud, ink);
  }

  /**
   * Updates display_name (max 80, collapse whitespace). Propagates best-effort to
   * family_members.display_name_snapshot when the caller belongs to a family.
   */
  @Transactional
  public AccountMeResponse updateDisplayName(String uid, UpdateDisplayNameRequest request) {
    String raw = request.displayName().trim().replaceAll("\\s+", " ");
    if (raw.isEmpty()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "displayName is required");
    }
    if (raw.length() > 80) {
      throw new ApiException(
          HttpStatus.BAD_REQUEST, "invalid_argument", "displayName must be at most 80 characters");
    }
    UserEntity user = requireUser(uid);
    user.setDisplayName(raw);
    userRepository.save(user);
    try {
      familyService.propagateDisplayNameSnapshot(uid, raw);
    } catch (RuntimeException e) {
      log.warn("updateDisplayName: family membersInfo update failed {} — {}", uid, e.toString());
    }
    return me(uid);
  }

  private UserEntity requireUser(String uid) {
    return userRepository
        .findById(uid)
        .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "user_not_found", "User not found"));
  }

  private static AccountMeResponse toResponse(
      UserEntity user, UserFolioCloudEntity cloud, UserInkEntity ink) {
    return new AccountMeResponse(
        user.getId(),
        user.getEmail(),
        user.getDisplayName(),
        user.getEmailVerifiedAt(),
        user.getCreatedAt(),
        user.isFolioStaff(),
        new AccountMeResponse.FolioCloudDto(
            cloud.isActive(),
            cloud.getSubscriptionStatus(),
            cloud.getSubscriptionPriceId(),
            cloud.isFamily(),
            cloud.isStudent(),
            cloud.isStudentVerified(),
            cloud.getFamilyOwnerUid(),
            cloud.getFamilySeats(),
            cloud.getFeatures()),
        new AccountMeResponse.InkDto(
            ink.getMonthlyBalance(), ink.getPurchasedBalance(), ink.getMonthlyPeriodKey()));
  }
}
