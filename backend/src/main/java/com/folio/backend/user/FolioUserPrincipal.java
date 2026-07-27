package com.folio.backend.user;

import java.util.Collection;
import java.util.List;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

/** Principal placed in SecurityContext by JwtAuthenticationFilter. */
public record FolioUserPrincipal(String uid, String email) implements Authentication {

  @Override
  public Collection<? extends GrantedAuthority> getAuthorities() {
    return List.of(new SimpleGrantedAuthority("ROLE_USER"));
  }

  @Override
  public Object getCredentials() {
    return null;
  }

  @Override
  public Object getDetails() {
    return null;
  }

  @Override
  public Object getPrincipal() {
    return uid;
  }

  @Override
  public boolean isAuthenticated() {
    return true;
  }

  @Override
  public void setAuthenticated(boolean isAuthenticated) {
    throw new UnsupportedOperationException();
  }

  @Override
  public String getName() {
    return uid;
  }

  public static FolioUserPrincipal requireCurrent() {
    Authentication auth = SecurityContextHolder.getContext().getAuthentication();
    if (auth instanceof FolioUserPrincipal principal) {
      return principal;
    }
    throw new IllegalStateException("No authenticated Folio user in SecurityContext");
  }

  public static String requireUid() {
    return requireCurrent().uid();
  }
}
