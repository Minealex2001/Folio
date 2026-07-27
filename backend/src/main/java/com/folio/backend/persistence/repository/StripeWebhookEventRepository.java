package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.StripeWebhookEventEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StripeWebhookEventRepository
    extends JpaRepository<StripeWebhookEventEntity, String> {}
