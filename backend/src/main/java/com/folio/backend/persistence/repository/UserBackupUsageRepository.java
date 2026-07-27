package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.UserBackupUsageEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserBackupUsageRepository extends JpaRepository<UserBackupUsageEntity, String> {}
