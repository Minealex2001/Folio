package com.folio.backend.family;

import com.folio.backend.family.dto.FamilyDetailsResponse;
import com.folio.backend.family.dto.InviteFamilyMemberRequest;
import com.folio.backend.family.dto.RemoveFamilyMemberRequest;
import com.folio.backend.family.dto.VerifyStudentRequest;
import com.folio.backend.user.FolioUserPrincipal;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/family")
public class FamilyController {

  private final FamilyService familyService;

  public FamilyController(FamilyService familyService) {
    this.familyService = familyService;
  }

  @PostMapping("/invite")
  public Map<String, Object> invite(@RequestBody InviteFamilyMemberRequest body) {
    return familyService.invite(FolioUserPrincipal.requireUid(), body);
  }

  @PostMapping("/remove")
  public Map<String, Object> remove(@RequestBody RemoveFamilyMemberRequest body) {
    return familyService.remove(FolioUserPrincipal.requireUid(), body);
  }

  @GetMapping("/details")
  public FamilyDetailsResponse details() {
    return familyService.details(FolioUserPrincipal.requireUid());
  }

  @PostMapping("/verify-student")
  public Map<String, Object> verifyStudent(@RequestBody(required = false) VerifyStudentRequest body) {
    return familyService.verifyStudent(FolioUserPrincipal.requireUid(), body);
  }
}
