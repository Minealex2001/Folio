package com.folio.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class PasswordEncoderConfig {

  @Bean
  public PasswordEncoder passwordEncoder() {
    // OWASP-recommended defaults for Argon2id (Spring Security 6.2+)
    return Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();
  }
}
