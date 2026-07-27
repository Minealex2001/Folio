package com.folio.backend;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

class SchemaMigrationIT extends AbstractIntegrationTest {

  private static final Set<String> EXPECTED_TABLES =
      Set.of(
          "users",
          "user_folio_cloud",
          "user_ink",
          "user_billing_stripe",
          "user_billing_microsoft_store",
          "families",
          "family_members",
          "collab_rooms",
          "collab_room_members",
          "collab_room_media",
          "collab_join_attempts",
          "published_pages",
          "community_templates",
          "stripe_webhook_events",
          "stripe_processed_checkouts",
          "microsoft_store_processed_purchases",
          "microsoft_store_processed_backup_grants",
          "vault_backups",
          "vault_backup_blobs",
          "user_app_profile",
          "user_vault_profile",
          "user_vault_sync",
          "user_plain_vault_sync_secret",
          "user_backup_usage",
          "integration_user_index",
          "pending_integration_command",
          "integration_webhook_connections",
          "integration_link_codes",
          "teams_webhook_endpoints",
          "folio_diagnostics",
          "folio_diagnostic_signatures",
          "refresh_tokens",
          "email_verification_tokens",
          "password_reset_tokens");

  @Autowired private JdbcTemplate jdbcTemplate;
  @Autowired private MockMvc mockMvc;

  @Test
  void flywayCreatesAllExpectedTablesAndAuthColumns() {
    List<String> tables =
        jdbcTemplate.queryForList(
            """
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
            """,
            String.class);
    assertThat(tables).containsAll(EXPECTED_TABLES);

    List<String> userColumns =
        jdbcTemplate.queryForList(
            """
            SELECT column_name FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'users'
            """,
            String.class);
    assertThat(userColumns)
        .contains("password_hash", "email_verified_at", "status", "email", "display_name");
  }

  @Test
  void healthIsPublic() throws Exception {
    mockMvc
        .perform(get("/api/v1/health"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("ok"));
  }
}
