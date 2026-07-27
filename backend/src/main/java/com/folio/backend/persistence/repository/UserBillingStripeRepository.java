package com.folio.backend.persistence.repository;

import com.folio.backend.persistence.entity.UserBillingStripeEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserBillingStripeRepository extends JpaRepository<UserBillingStripeEntity, String> {}
