package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.VaultBackupEntity;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VaultBackupRepository extends JpaRepository<VaultBackupEntity, VaultBackupEntity.Pk> {
  List<VaultBackupEntity> findByUserIdOrderByVaultIdAsc(String userId);

  List<VaultBackupEntity> findByUserIdOrderByVaultIdAsc(String userId, Pageable pageable);
}
