package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.UserInkEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserInkRepository extends JpaRepository<UserInkEntity, String> {}
