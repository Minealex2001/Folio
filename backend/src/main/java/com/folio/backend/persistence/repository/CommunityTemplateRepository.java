package com.folio.backend.persistence.repository;
import com.folio.backend.persistence.entity.CommunityTemplateEntity;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
public interface CommunityTemplateRepository extends JpaRepository<CommunityTemplateEntity, UUID> {
  List<CommunityTemplateEntity> findByOwnerUidOrderByUpdatedAtDesc(String ownerUid);

  List<CommunityTemplateEntity> findByOwnerUidOrderByUpdatedAtDesc(String ownerUid, Pageable pageable);

  List<CommunityTemplateEntity> findAllByOrderByUpdatedAtDesc();

  void deleteByOwnerUid(String ownerUid);
}
