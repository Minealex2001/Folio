package com.folio.backend.integrations;

import org.springframework.data.jpa.repository.JpaRepository;

public interface IntegrationLinkCodeRepository
    extends JpaRepository<IntegrationLinkCodeEntity, String> {}
