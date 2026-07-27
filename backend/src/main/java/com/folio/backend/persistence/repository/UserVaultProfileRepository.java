package com.folio.backend.persistence.repository;
import com.folio.backend.persistence.entity.UserVaultProfileEntity;
import org.springframework.data.jpa.repository.JpaRepository;
public interface UserVaultProfileRepository extends JpaRepository<UserVaultProfileEntity, UserVaultProfileEntity.Pk> {}
