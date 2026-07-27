package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.UserFolioCloudEntity;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface UserFolioCloudRepository extends JpaRepository<UserFolioCloudEntity, String> {

  List<UserFolioCloudEntity> findByFamilyOwnerUid(String familyOwnerUid);

  /**
   * Eligible for monthly ink refill (replaces Firestore {@code folioCloudSubscribers} index).
   * Active cloud rows with a Stripe price id, or with an active Microsoft Store monthly sub.
   */
  @Query(
      value =
          """
          SELECT c.* FROM user_folio_cloud c
          LEFT JOIN user_billing_microsoft_store m ON m.user_id = c.user_id
          WHERE c.active = TRUE
            AND (c.subscription_price_id IS NOT NULL OR COALESCE(m.subscription_active, FALSE) = TRUE)
          """,
      nativeQuery = true)
  List<UserFolioCloudEntity> findEligibleForMonthlyInkRefill();
}
