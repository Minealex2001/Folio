package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.StripeProcessedCheckoutEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StripeProcessedCheckoutRepository
    extends JpaRepository<StripeProcessedCheckoutEntity, String> {}
