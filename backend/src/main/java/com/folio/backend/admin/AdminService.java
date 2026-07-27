package com.folio.backend.admin;

import com.folio.backend.account.AccountService;
import com.folio.backend.account.dto.AccountMeResponse;
import com.folio.backend.admin.dto.AdminUserTargetRequest;
import com.folio.backend.billing.FolioCloudEntitlementService;
import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.entity.UserInkEntity;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserInkRepository;
import com.folio.backend.persistence.repository.UserRepository;
import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminService {

  private final UserRepository userRepository;
  private final UserFolioCloudRepository folioCloudRepository;
  private final UserInkRepository inkRepository;
  private final FolioCloudEntitlementService entitlements;
  private final AccountService accountService;

  public AdminService(
      UserRepository userRepository,
      UserFolioCloudRepository folioCloudRepository,
      UserInkRepository inkRepository,
      FolioCloudEntitlementService entitlements,
      AccountService accountService) {
    this.userRepository = userRepository;
    this.folioCloudRepository = folioCloudRepository;
    this.inkRepository = inkRepository;
    this.entitlements = entitlements;
    this.accountService = accountService;
  }

  @Transactional(readOnly = true)
  public Map<String, Object> lookup(AdminUserTargetRequest req) {
    UserEntity user = resolveUser(req);
    return snapshot(user.getId());
  }

  /**
   * Full Folio Cloud features without Stripe. Sets {@code admin_override} so recompute keeps them.
   */
  @Transactional
  public Map<String, Object> grantCloud(AdminUserTargetRequest req) {
    UserEntity user = resolveUser(req);
    accountService.ensure(user.getId());
    UserFolioCloudEntity cloud =
        folioCloudRepository
            .findById(user.getId())
            .orElseGet(() -> UserFolioCloudEntity.defaultsFor(user.getId()));
    cloud.setAdminOverride(true);
    folioCloudRepository.save(cloud);

    if (Boolean.TRUE.equals(req.alsoStaff())) {
      user.setFolioStaff(true);
      userRepository.save(user);
    }

    entitlements.recomputeEffectiveFolioCloud(user.getId());

    Integer drops = req.inkDrops();
    if (drops != null && drops > 0) {
      addPurchasedInk(user.getId(), drops);
    }
    return snapshot(user.getId());
  }

  @Transactional
  public Map<String, Object> revokeCloud(AdminUserTargetRequest req) {
    UserEntity user = resolveUser(req);
    UserFolioCloudEntity cloud =
        folioCloudRepository
            .findById(user.getId())
            .orElseGet(() -> UserFolioCloudEntity.defaultsFor(user.getId()));
    cloud.setAdminOverride(false);
    folioCloudRepository.save(cloud);
    entitlements.recomputeEffectiveFolioCloud(user.getId());
    return snapshot(user.getId());
  }

  @Transactional
  public Map<String, Object> grantInk(AdminUserTargetRequest req) {
    UserEntity user = resolveUser(req);
    accountService.ensure(user.getId());
    int drops = req.inkDrops() != null ? req.inkDrops() : 1000;
    if (drops <= 0) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "inkDrops must be > 0");
    }
    addPurchasedInk(user.getId(), drops);
    return snapshot(user.getId());
  }

  @Transactional
  public Map<String, Object> setStaff(AdminUserTargetRequest req) {
    UserEntity user = resolveUser(req);
    boolean staff = req.staff() == null || Boolean.TRUE.equals(req.staff());
    user.setFolioStaff(staff);
    userRepository.save(user);
    accountService.ensure(user.getId());
    entitlements.recomputeEffectiveFolioCloud(user.getId());
    return snapshot(user.getId());
  }

  private void addPurchasedInk(String uid, int drops) {
    UserInkEntity ink =
        inkRepository.findById(uid).orElseGet(() -> UserInkEntity.defaultsFor(uid));
    ink.setPurchasedBalance(ink.getPurchasedBalance().add(BigDecimal.valueOf(drops)));
    inkRepository.save(ink);
  }

  private UserEntity resolveUser(AdminUserTargetRequest req) {
    if (req == null) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "Body required");
    }
    String uid = req.uid() != null ? req.uid().trim() : "";
    String email = req.email() != null ? req.email().trim() : "";
    if (!uid.isEmpty()) {
      return userRepository
          .findById(uid)
          .orElseThrow(
              () -> new ApiException(HttpStatus.NOT_FOUND, "user_not_found", "User not found"));
    }
    if (!email.isEmpty()) {
      return userRepository
          .findByEmailIgnoreCase(email)
          .orElseThrow(
              () ->
                  new ApiException(
                      HttpStatus.NOT_FOUND, "user_not_found", "No user with that email"));
    }
    throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "uid or email required");
  }

  private Map<String, Object> snapshot(String uid) {
    AccountMeResponse me = accountService.me(uid);
    UserEntity user = userRepository.findById(uid).orElseThrow();
    UserFolioCloudEntity cloud =
        folioCloudRepository.findById(uid).orElseGet(() -> UserFolioCloudEntity.defaultsFor(uid));
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("uid", me.uid());
    out.put("email", me.email());
    out.put("displayName", me.displayName());
    out.put("folioStaff", user.isFolioStaff());
    out.put("adminOverride", cloud.isAdminOverride());
    out.put("folioCloud", me.folioCloud());
    out.put("ink", me.ink());
    return out;
  }
}
