package com.folio.backend.integrations;

import org.springframework.data.jpa.repository.JpaRepository;

public interface TeamsWebhookEndpointRepository
    extends JpaRepository<TeamsWebhookEndpointEntity, String> {}
