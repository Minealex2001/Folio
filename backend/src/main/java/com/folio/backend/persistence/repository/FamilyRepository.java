package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.FamilyEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FamilyRepository extends JpaRepository<FamilyEntity, String> {}
