package com.folio.backend.persistence.repository;
import com.folio.backend.persistence.entity.PublishedPageEntity;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
public interface PublishedPageRepository extends JpaRepository<PublishedPageEntity, UUID> {
  List<PublishedPageEntity> findByOwnerUidOrderByUpdatedAtDesc(String ownerUid);

  List<PublishedPageEntity> findByOwnerUidOrderByUpdatedAtDesc(String ownerUid, Pageable pageable);

  void deleteByOwnerUid(String ownerUid);
}
