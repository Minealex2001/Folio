package com.folio.backend.storage;

/**
 * Optional hook so {@link StoragePathAuthorizer} can check collab membership without a hard
 * dependency cycle on the collab package at compile time of tests that only cover path families.
 */
@FunctionalInterface
public interface CollabMembershipLookup {
  boolean isMember(String roomId, String uid);
}
