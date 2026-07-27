package com.folio.backend.integrations;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PendingIntegrationCommandRepository
    extends JpaRepository<PendingIntegrationCommandEntity, UUID> {

  List<PendingIntegrationCommandEntity> findByUserIdAndStatusAndVaultId(
      String userId, String status, String vaultId);

  Optional<PendingIntegrationCommandEntity> findByIdAndUserId(UUID id, String userId);
}
