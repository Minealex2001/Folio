package com.folio.backend.persistence.repository;
import com.folio.backend.persistence.entity.CollabRoomEntity;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CollabRoomRepository extends JpaRepository<CollabRoomEntity, UUID> {
  Optional<CollabRoomEntity> findByJoinCodeKey(String joinCodeKey);

  boolean existsByJoinCodeKey(String joinCodeKey);

  List<CollabRoomEntity> findByOwnerUid(String ownerUid);

  List<CollabRoomEntity> findByOwnerUid(String ownerUid, Pageable pageable);

  @Modifying(clearAutomatically = true)
  @Query("update CollabRoomEntity r set r.updatedBy = null where r.updatedBy = :uid")
  void clearUpdatedBy(@Param("uid") String uid);
}
