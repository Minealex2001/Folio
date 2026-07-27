package com.folio.backend.integrations;

import org.springframework.data.jpa.repository.JpaRepository;

public interface IntegrationWebhookConnectionRepository
    extends JpaRepository<IntegrationWebhookConnectionEntity, String> {}
