package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.MicrosoftStoreProcessedBackupGrantEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MicrosoftStoreProcessedBackupGrantRepository
    extends JpaRepository<MicrosoftStoreProcessedBackupGrantEntity, String> {

  void deleteByUserId(String userId);
}
