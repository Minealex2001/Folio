package com.folio.backend.family;

import com.folio.backend.billing.FolioCloudEntitlementService;
import com.folio.backend.billing.StripeApiClient;
import com.folio.backend.common.ApiException;
import com.folio.backend.family.dto.FamilyDetailsResponse;
import com.folio.backend.family.dto.InviteFamilyMemberRequest;
import com.folio.backend.family.dto.RemoveFamilyMemberRequest;
import com.folio.backend.family.dto.VerifyStudentRequest;
import com.folio.backend.persistence.entity.FamilyEntity;
import com.folio.backend.persistence.entity.FamilyMemberEntity;
import com.folio.backend.persistence.entity.UserBillingStripeEntity;
import com.folio.backend.persistence.entity.UserEntity;
import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import com.folio.backend.persistence.repository.FamilyMemberRepository;
import com.folio.backend.persistence.repository.FamilyRepository;
import com.folio.backend.persistence.repository.UserBillingStripeRepository;
import com.folio.backend.persistence.repository.UserFolioCloudRepository;
import com.folio.backend.persistence.repository.UserRepository;
import com.folio.backend.student.StudentEmailChecker;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class FamilyService {

  private final UserRepository userRepository;
  private final UserFolioCloudRepository folioCloudRepository;
  private final UserBillingStripeRepository stripeBillingRepository;
  private final FamilyRepository familyRepository;
  private final FamilyMemberRepository familyMemberRepository;
  private final FolioCloudEntitlementService entitlements;
  private final StudentEmailChecker studentEmailChecker;
  private final StripeApiClient stripeApi;

  public FamilyService(
      UserRepository userRepository,
      UserFolioCloudRepository folioCloudRepository,
      UserBillingStripeRepository stripeBillingRepository,
      FamilyRepository familyRepository,
      FamilyMemberRepository familyMemberRepository,
      FolioCloudEntitlementService entitlements,
      StudentEmailChecker studentEmailChecker,
      StripeApiClient stripeApi) {
    this.userRepository = userRepository;
    this.folioCloudRepository = folioCloudRepository;
    this.stripeBillingRepository = stripeBillingRepository;
    this.familyRepository = familyRepository;
    this.familyMemberRepository = familyMemberRepository;
    this.entitlements = entitlements;
    this.studentEmailChecker = studentEmailChecker;
    this.stripeApi = stripeApi;
  }

  @Transactional
  public Map<String, Object> invite(String callerUid, InviteFamilyMemberRequest request) {
    boolean debug = request != null && Boolean.TRUE.equals(request.debug());
    if (!stripeApi.isConfigured(debug)) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED, "failed_precondition", "Stripe not configured.");
    }

    String email =
        request == null || request.email() == null
            ? ""
            : request.email().trim().toLowerCase(Locale.ROOT);
    if (email.isEmpty()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "Email is required");
    }

    UserEntity target =
        userRepository
            .findByEmailIgnoreCase(email)
            .orElseThrow(
                () ->
                    new ApiException(
                        HttpStatus.NOT_FOUND,
                        "not_found",
                        "El usuario con este correo no está registrado en Folio Cloud."));
    String targetUid = target.getId();
    if (targetUid.equals(callerUid)) {
      throw new ApiException(
          HttpStatus.BAD_REQUEST, "invalid_argument", "No puedes invitarte a ti mismo.");
    }

    UserFolioCloudEntity ownerFc =
        folioCloudRepository
            .findById(callerUid)
            .orElseGet(() -> UserFolioCloudEntity.defaultsFor(callerUid));

    if (ownerFc.getFamilyOwnerUid() != null && !ownerFc.getFamilyOwnerUid().isBlank()) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "Los miembros de una familia no pueden invitar a otras personas.");
    }
    if (!ownerFc.isActive()) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "Debes tener una suscripción activa para invitar miembros.");
    }
    if (ownerFc.isStudent()) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "La suscripción de estudiantes no admite añadir miembros familiares.");
    }

    UserBillingStripeEntity stripeBilling =
        stripeBillingRepository.findById(callerUid).orElse(null);
    int familySeats = stripeBilling != null ? stripeBilling.getFamilySeats() : 0;

    long currentMembers = familyMemberRepository.countByIdFamilyOwnerUid(callerUid);
    if (currentMembers >= familySeats) {
      throw new ApiException(
          HttpStatus.TOO_MANY_REQUESTS,
          "resource_exhausted",
          "Has alcanzado el límite de miembros permitidos por tus ranuras contratadas ("
              + familySeats
              + "). Adquiere más ranuras en los ajustes de facturación.");
    }
    if (currentMembers >= 10) {
      throw new ApiException(
          HttpStatus.TOO_MANY_REQUESTS,
          "resource_exhausted",
          "Has alcanzado el límite máximo absoluto de 10 miembros familiares.");
    }

    UserFolioCloudEntity targetFc =
        folioCloudRepository
            .findById(targetUid)
            .orElseGet(() -> UserFolioCloudEntity.defaultsFor(targetUid));
    if (targetFc.getFamilyOwnerUid() != null && !targetFc.getFamilyOwnerUid().isBlank()) {
      if (callerUid.equals(targetFc.getFamilyOwnerUid())) {
        throw new ApiException(
            HttpStatus.CONFLICT, "already_exists", "El usuario ya está en tu familia.");
      }
      throw new ApiException(
          HttpStatus.CONFLICT, "already_exists", "El usuario ya pertenece a otra familia.");
    }
    if (familyMemberRepository.findByIdMemberUid(targetUid).isPresent()) {
      throw new ApiException(
          HttpStatus.CONFLICT, "already_exists", "El usuario ya pertenece a otra familia.");
    }
    if (targetFc.isActive()
        && (targetFc.getFamilyOwnerUid() == null || targetFc.getFamilyOwnerUid().isBlank())
        && FolioCloudEntitlementService.isFolioCloudPaidPlan(targetFc)) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "El usuario ya tiene una suscripción premium activa.");
    }

    if (!familyRepository.existsById(callerUid)) {
      FamilyEntity family = new FamilyEntity();
      family.setOwnerUid(callerUid);
      familyRepository.save(family);
    }

    targetFc.setFamilyOwnerUid(callerUid);
    folioCloudRepository.save(targetFc);

    FamilyMemberEntity member = new FamilyMemberEntity();
    member.setId(new FamilyMemberEntity.FamilyMemberId(callerUid, targetUid));
    member.setEmailSnapshot(target.getEmail() != null ? target.getEmail() : email);
    member.setDisplayNameSnapshot(target.getDisplayName() != null ? target.getDisplayName() : "");
    familyMemberRepository.save(member);

    entitlements.recomputeEffectiveFolioCloud(targetUid);
    entitlements.recomputeEffectiveFolioCloud(callerUid);
    return Map.of("ok", true);
  }

  @Transactional
  public Map<String, Object> remove(String callerUid, RemoveFamilyMemberRequest request) {
    boolean debug = request != null && Boolean.TRUE.equals(request.debug());
    if (!stripeApi.isConfigured(debug)) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED, "failed_precondition", "Stripe not configured.");
    }
    String memberUid =
        request == null || request.memberUid() == null ? "" : request.memberUid().trim();
    if (memberUid.isEmpty()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "memberUid is required");
    }

    UserFolioCloudEntity targetFc =
        folioCloudRepository
            .findById(memberUid)
            .orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "Miembro no encontrado."));

    String familyOwnerUid = targetFc.getFamilyOwnerUid();
    if (familyOwnerUid == null || familyOwnerUid.isBlank()) {
      familyOwnerUid =
          familyMemberRepository
              .findByIdMemberUid(memberUid)
              .map(m -> m.getId().getFamilyOwnerUid())
              .orElse(null);
    }
    if (familyOwnerUid == null || familyOwnerUid.isBlank()) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "El usuario no pertenece a ninguna familia.");
    }
    if (!callerUid.equals(familyOwnerUid) && !callerUid.equals(memberUid)) {
      throw new ApiException(
          HttpStatus.FORBIDDEN,
          "permission_denied",
          "No tienes permiso para eliminar a este miembro de la familia.");
    }

    familyMemberRepository.deleteById(new FamilyMemberEntity.FamilyMemberId(familyOwnerUid, memberUid));
    targetFc.setFamilyOwnerUid(null);
    folioCloudRepository.save(targetFc);

    entitlements.recomputeEffectiveFolioCloud(memberUid);
    entitlements.recomputeEffectiveFolioCloud(familyOwnerUid);
    return Map.of("ok", true);
  }

  @Transactional(readOnly = true)
  public FamilyDetailsResponse details(String uid) {
    UserFolioCloudEntity cloud =
        folioCloudRepository.findById(uid).orElseGet(() -> UserFolioCloudEntity.defaultsFor(uid));
    String familyOwnerUid = cloud.getFamilyOwnerUid();
    if (familyOwnerUid == null || familyOwnerUid.isBlank()) {
      familyOwnerUid =
          familyMemberRepository
              .findByIdMemberUid(uid)
              .map(m -> m.getId().getFamilyOwnerUid())
              .orElse(uid);
    }
    if (!familyRepository.existsById(familyOwnerUid)) {
      return new FamilyDetailsResponse(List.of(), Map.of());
    }
    List<FamilyMemberEntity> members =
        familyMemberRepository.findByIdFamilyOwnerUid(familyOwnerUid);
    List<String> memberUids =
        members.stream().map(m -> m.getId().getMemberUid()).toList();
    Map<String, Map<String, String>> membersInfo = new HashMap<>();
    for (FamilyMemberEntity m : members) {
      membersInfo.put(
          m.getId().getMemberUid(),
          Map.of(
              "email",
              m.getEmailSnapshot() != null ? m.getEmailSnapshot() : "",
              "displayName",
              m.getDisplayNameSnapshot() != null ? m.getDisplayNameSnapshot() : ""));
    }
    return new FamilyDetailsResponse(memberUids, membersInfo);
  }

  @Transactional
  public Map<String, Object> verifyStudent(String uid, VerifyStudentRequest request) {
    UserEntity user =
        userRepository
            .findById(uid)
            .orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "user_not_found", "User not found"));
    String custom =
        request != null && request.email() != null
            ? request.email().trim().toLowerCase(Locale.ROOT)
            : "";
    String email = !custom.isEmpty() ? custom : user.getEmail();
    if (email == null || email.isBlank()) {
      throw new ApiException(
          HttpStatus.BAD_REQUEST, "invalid_argument", "No email found. Provide an email.");
    }
    boolean verified = studentEmailChecker.isStudentEmail(email);
    if (verified) {
      UserBillingStripeEntity billing =
          stripeBillingRepository
              .findById(uid)
              .orElseGet(() -> UserBillingStripeEntity.defaultsFor(uid));
      billing.setStudentVerified(true);
      stripeBillingRepository.save(billing);
      UserFolioCloudEntity cloud =
          folioCloudRepository.findById(uid).orElseGet(() -> UserFolioCloudEntity.defaultsFor(uid));
      cloud.setStudentVerified(true);
      folioCloudRepository.save(cloud);
      entitlements.recomputeEffectiveFolioCloud(uid);
    }
    return Map.of("ok", true, "verified", verified);
  }

  /** Best-effort propagation of display name to family_members snapshot. */
  @Transactional
  public void propagateDisplayNameSnapshot(String uid, String displayName) {
    familyMemberRepository
        .findByIdMemberUid(uid)
        .ifPresent(
            m -> {
              m.setDisplayNameSnapshot(displayName);
              familyMemberRepository.save(m);
            });
  }
}
