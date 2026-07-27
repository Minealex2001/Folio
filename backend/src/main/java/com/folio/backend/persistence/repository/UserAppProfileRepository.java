package com.folio.backend.persistence.repository;
import com.folio.backend.persistence.entity.UserAppProfileEntity;
import org.springframework.data.jpa.repository.JpaRepository;
public interface UserAppProfileRepository extends JpaRepository<UserAppProfileEntity, String> {}
