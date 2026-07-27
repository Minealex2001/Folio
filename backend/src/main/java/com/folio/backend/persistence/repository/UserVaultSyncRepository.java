package com.folio.backend.persistence.repository;
import com.folio.backend.persistence.entity.UserVaultSyncEntity;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
public interface UserVaultSyncRepository extends JpaRepository<UserVaultSyncEntity, UserVaultSyncEntity.Pk> {
  List<UserVaultSyncEntity> findByUserIdOrderByVaultIdAsc(String userId);
}
