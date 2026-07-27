package com.folio.backend.config;

import com.folio.backend.auth.JwtAuthenticationFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;
import org.springframework.http.HttpStatus;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

  private final JwtAuthenticationFilter jwtAuthenticationFilter;

  public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter) {
    this.jwtAuthenticationFilter = jwtAuthenticationFilter;
  }

  @Bean
  public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    http.csrf(AbstractHttpConfigurer::disable)
        .cors(Customizer.withDefaults())
        .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .exceptionHandling(
            ex -> ex.authenticationEntryPoint(new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED)))
        .authorizeHttpRequests(
            auth ->
                auth.requestMatchers("/api/v1/health")
                    .permitAll()
                    .requestMatchers(
                        "/api/v1/auth/register",
                        "/api/v1/auth/login",
                        "/api/v1/auth/refresh",
                        "/api/v1/auth/verify-email",
                        "/api/v1/auth/forgot-password",
                        "/api/v1/auth/reset-password")
                    .permitAll()
                    // logout + resend-verification require a valid access token (fail-closed)
                    .requestMatchers(
                        "/swagger-ui.html",
                        "/swagger-ui/**",
                        "/v3/api-docs",
                        "/v3/api-docs/**")
                    .permitAll()
                    .requestMatchers(HttpMethod.OPTIONS, "/**")
                    .permitAll()
                    // Admin: Auth via X-Folio-Admin-Key or folioStaff inside AdminGate
                    .requestMatchers("/api/v1/admin/**")
                    .permitAll()
                    // Públicos con verificación propia (Stripe / OAuth / firma plataforma)
                    .requestMatchers(
                        "/api/v1/billing/webhook",
                        "/api/v1/billing/catalog-prices",
                        "/api/v1/integrations/jira/oauth-exchange",
                        "/api/v1/diagnostics/report",
                        "/api/v1/integrations/slack/command",
                        "/api/v1/integrations/teams/command",
                        "/api/v1/integrations/spotify/oauth-callback")
                    .permitAll()
                    // Lectura pública (firestore.rules allow read: if true). /mine requiere auth.
                    .requestMatchers(HttpMethod.GET, "/api/v1/published-pages/mine")
                    .authenticated()
                    .requestMatchers(HttpMethod.GET, "/api/v1/published-pages/*")
                    .permitAll()
                    .requestMatchers(HttpMethod.GET, "/api/v1/community-templates", "/api/v1/community-templates/*")
                    .permitAll()
                    // Handshake público; JWT se exige en el frame STOMP CONNECT (Fase 27)
                    .requestMatchers("/ws/collab", "/ws/collab/**")
                    .permitAll()
                    // Fail-closed: everything else requires a valid Bearer token
                    .anyRequest()
                    .authenticated())
        .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
    return http.build();
  }
}
