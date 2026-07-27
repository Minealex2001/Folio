package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.UserEntity;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserRepository extends JpaRepository<UserEntity, String> {

  @Query("select u from UserEntity u where lower(u.email) = lower(:email)")
  Optional<UserEntity> findByEmailIgnoreCase(@Param("email") String email);

  @Query(
      "select case when count(u) > 0 then true else false end from UserEntity u where lower(u.email) = lower(:email)")
  boolean existsByEmailIgnoreCase(@Param("email") String email);

  List<UserEntity> findByDeletionScheduledForLessThanEqual(Instant cutoff);
}
