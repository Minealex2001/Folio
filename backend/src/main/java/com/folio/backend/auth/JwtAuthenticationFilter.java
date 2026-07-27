package com.folio.backend.auth;

import com.folio.backend.user.FolioUserPrincipal;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.http.HttpHeaders;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

  private final JwtService jwtService;

  public JwtAuthenticationFilter(JwtService jwtService) {
    this.jwtService = jwtService;
  }

  @Override
  protected void doFilterInternal(
      HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
      throws ServletException, IOException {
    String header = request.getHeader(HttpHeaders.AUTHORIZATION);
    if (header != null && header.startsWith("Bearer ")) {
      String token = header.substring(7).trim();
      if (!token.isEmpty()) {
        try {
          Claims claims = jwtService.parseValidClaims(token);
          String uid = claims.getSubject();
          String email = claims.get("email", String.class);
          SecurityContextHolder.getContext()
              .setAuthentication(new FolioUserPrincipal(uid, email != null ? email : ""));
        } catch (JwtService.InvalidJwtException ex) {
          SecurityContextHolder.clearContext();
          response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
          response.setContentType("application/json");
          response
              .getWriter()
              .write("{\"error\":\"unauthorized\",\"message\":\"Invalid or expired token\"}");
          return;
        }
      }
    }
    filterChain.doFilter(request, response);
  }
}
