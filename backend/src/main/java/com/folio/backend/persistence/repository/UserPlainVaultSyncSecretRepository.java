package com.folio.backend.persistence.repository;
import com.folio.backend.persistence.entity.UserPlainVaultSyncSecretEntity;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
public interface UserPlainVaultSyncSecretRepository extends JpaRepository<UserPlainVaultSyncSecretEntity, UserPlainVaultSyncSecretEntity.Pk> {
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select s from UserPlainVaultSyncSecretEntity s where s.userId = :userId and s.vaultId = :vaultId")
  Optional<UserPlainVaultSyncSecretEntity> findForUpdate(@Param("userId") String userId, @Param("vaultId") String vaultId);
}
