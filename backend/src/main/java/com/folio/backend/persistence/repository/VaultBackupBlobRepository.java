package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.VaultBackupBlobEntity;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface VaultBackupBlobRepository
    extends JpaRepository<VaultBackupBlobEntity, VaultBackupBlobEntity.Pk> {

  List<VaultBackupBlobEntity> findByUserIdAndVaultId(String userId, String vaultId);

  List<VaultBackupBlobEntity> findByUserIdAndVaultIdAndBlobIdIn(
      String userId, String vaultId, Collection<String> blobIds);

  @Query(
      "select coalesce(sum(b.sizeBytes), 0) from VaultBackupBlobEntity b where b.userId = :userId")
  long sumSizeByUserId(@Param("userId") String userId);

  @Query(
      "select coalesce(sum(b.sizeBytes), 0) from VaultBackupBlobEntity b where b.userId = :userId and b.vaultId = :vaultId")
  long sumSizeByUserIdAndVaultId(@Param("userId") String userId, @Param("vaultId") String vaultId);

  void deleteByUserIdAndVaultIdAndBlobIdIn(String userId, String vaultId, Collection<String> blobIds);

  void deleteByUserIdAndVaultId(String userId, String vaultId);
}
