package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.EmailVerificationTokenEntity;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface EmailVerificationTokenRepository
    extends JpaRepository<EmailVerificationTokenEntity, UUID> {

  Optional<EmailVerificationTokenEntity> findByTokenHash(String tokenHash);

  List<EmailVerificationTokenEntity> findByUserIdAndConsumedAtIsNull(String userId);

  @Modifying(clearAutomatically = true, flushAutomatically = true)
  @Query(
      "update EmailVerificationTokenEntity t set t.consumedAt = CURRENT_TIMESTAMP where t.userId = :userId and t.consumedAt is null")
  int consumeAllPendingForUser(@Param("userId") String userId);
}
