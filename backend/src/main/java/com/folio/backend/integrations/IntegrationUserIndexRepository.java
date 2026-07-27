package com.folio.backend.integrations;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface IntegrationUserIndexRepository
    extends JpaRepository<IntegrationUserIndexEntity, String> {

  List<IntegrationUserIndexEntity> findByUserId(String userId);

  void deleteByUserId(String userId);
}
