package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.MicrosoftStoreProcessedPurchaseEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MicrosoftStoreProcessedPurchaseRepository
    extends JpaRepository<MicrosoftStoreProcessedPurchaseEntity, String> {

  void deleteByUserId(String userId);
}
