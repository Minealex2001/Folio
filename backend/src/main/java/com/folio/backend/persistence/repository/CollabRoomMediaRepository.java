package com.folio.backend.persistence.repository;
import com.folio.backend.persistence.entity.CollabRoomMediaEntity;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
public interface CollabRoomMediaRepository extends JpaRepository<CollabRoomMediaEntity, UUID> {
  List<CollabRoomMediaEntity> findByRoomId(UUID roomId);
  Optional<CollabRoomMediaEntity> findByIdAndRoomId(UUID id, UUID roomId);
  void deleteByRoomId(UUID roomId);
}
