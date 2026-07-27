package com.folio.backend.admin;

import com.folio.backend.admin.dto.AdminUserTargetRequest;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * QA / self-host admin surface: grant Folio Cloud without Stripe, ink, staff flag.
 *
 * <p>Auth: header {@code X-Folio-Admin-Key: $FOLIO_ADMIN_API_KEY} <b>or</b> JWT of a {@code
 * folioStaff} user.
 */
@RestController
@RequestMapping("/api/v1/admin")
public class AdminController {

  private final AdminGate adminGate;
  private final AdminService adminService;

  public AdminController(AdminGate adminGate, AdminService adminService) {
    this.adminGate = adminGate;
    this.adminService = adminService;
  }

  @PostMapping("/users/lookup")
  public Map<String, Object> lookup(
      HttpServletRequest request, @Valid @RequestBody AdminUserTargetRequest body) {
    adminGate.requireAdmin(request);
    return adminService.lookup(body);
  }

  /** Full Cloud features (backup, AI, publish, collab) without paying Stripe. */
  @PostMapping("/entitlements/grant-cloud")
  public Map<String, Object> grantCloud(
      HttpServletRequest request, @Valid @RequestBody AdminUserTargetRequest body) {
    adminGate.requireAdmin(request);
    return adminService.grantCloud(body);
  }

  @PostMapping("/entitlements/revoke-cloud")
  public Map<String, Object> revokeCloud(
      HttpServletRequest request, @Valid @RequestBody AdminUserTargetRequest body) {
    adminGate.requireAdmin(request);
    return adminService.revokeCloud(body);
  }

  @PostMapping("/ink/grant")
  public Map<String, Object> grantInk(
      HttpServletRequest request, @Valid @RequestBody AdminUserTargetRequest body) {
    adminGate.requireAdmin(request);
    return adminService.grantInk(body);
  }

  @PostMapping("/staff")
  public Map<String, Object> setStaff(
      HttpServletRequest request, @Valid @RequestBody AdminUserTargetRequest body) {
    adminGate.requireAdmin(request);
    return adminService.setStaff(body);
  }
}
