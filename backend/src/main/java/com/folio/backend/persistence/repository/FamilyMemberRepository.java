package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.FamilyMemberEntity;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FamilyMemberRepository
    extends JpaRepository<FamilyMemberEntity, FamilyMemberEntity.FamilyMemberId> {

  List<FamilyMemberEntity> findByIdFamilyOwnerUid(String familyOwnerUid);

  Optional<FamilyMemberEntity> findByIdMemberUid(String memberUid);

  long countByIdFamilyOwnerUid(String familyOwnerUid);
}
