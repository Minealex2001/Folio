package com.folio.backend.persistence.repository;
import com.folio.backend.persistence.entity.CollabRoomMemberEntity;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
public interface CollabRoomMemberRepository extends JpaRepository<CollabRoomMemberEntity, CollabRoomMemberEntity.Pk> {
  List<CollabRoomMemberEntity> findByRoomId(UUID roomId);

  List<CollabRoomMemberEntity> findByMemberUid(String memberUid);

  List<CollabRoomMemberEntity> findByMemberUid(String memberUid, Pageable pageable);

  boolean existsByRoomIdAndMemberUid(UUID roomId, String memberUid);

  long countByRoomId(UUID roomId);

  void deleteByRoomId(UUID roomId);

  void deleteByRoomIdAndMemberUid(UUID roomId, String memberUid);

  void deleteByMemberUid(String memberUid);
}
