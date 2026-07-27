package com.folio.backend.admin;

import com.folio.backend.common.ApiException;
import com.folio.backend.config.AdminProperties;
import com.folio.backend.persistence.repository.UserRepository;
import com.folio.backend.user.FolioUserPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

/**
 * Admin access: valid {@code X-Folio-Admin-Key} matching {@code FOLIO_ADMIN_API_KEY}, or a JWT
 * user with {@code folio_staff=true}.
 */
@Component
public class AdminGate {

  public static final String HEADER = "X-Folio-Admin-Key";

  private final AdminProperties props;
  private final UserRepository userRepository;

  public AdminGate(AdminProperties props, UserRepository userRepository) {
    this.props = props;
    this.userRepository = userRepository;
  }

  public void requireAdmin(HttpServletRequest request) {
    if (apiKeyMatches(request)) {
      return;
    }
    if (callerIsStaff()) {
      return;
    }
    throw new ApiException(
        HttpStatus.FORBIDDEN,
        "permission_denied",
        "Admin requires X-Folio-Admin-Key or folioStaff JWT");
  }

  private boolean apiKeyMatches(HttpServletRequest request) {
    if (!props.isApiKeyConfigured()) {
      return false;
    }
    String provided = request.getHeader(HEADER);
    if (provided == null || provided.isBlank()) {
      return false;
    }
    return props.getApiKey().trim().equals(provided.trim());
  }

  private boolean callerIsStaff() {
    Authentication auth = SecurityContextHolder.getContext().getAuthentication();
    if (auth == null || !auth.isAuthenticated()) {
      return false;
    }
    String uid;
    try {
      uid = FolioUserPrincipal.requireUid();
    } catch (RuntimeException e) {
      return false;
    }
    return userRepository.findById(uid).map(u -> u.isFolioStaff()).orElse(false);
  }
}
