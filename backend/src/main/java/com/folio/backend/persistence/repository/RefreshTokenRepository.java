package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.RefreshTokenEntity;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RefreshTokenRepository extends JpaRepository<RefreshTokenEntity, UUID> {

  Optional<RefreshTokenEntity> findByTokenHash(String tokenHash);

  List<RefreshTokenEntity> findByUserIdAndRevokedAtIsNull(String userId);

  @Modifying(clearAutomatically = true, flushAutomatically = true)
  @Query(
      "update RefreshTokenEntity r set r.revokedAt = CURRENT_TIMESTAMP where r.userId = :userId and r.revokedAt is null")
  int revokeAllActiveForUser(@Param("userId") String userId);
}
