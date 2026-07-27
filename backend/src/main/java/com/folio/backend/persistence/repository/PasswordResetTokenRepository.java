package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.PasswordResetTokenEntity;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetTokenEntity, UUID> {

  Optional<PasswordResetTokenEntity> findByTokenHash(String tokenHash);
}
