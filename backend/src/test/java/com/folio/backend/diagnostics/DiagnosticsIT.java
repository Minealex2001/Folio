package com.folio.backend.diagnostics;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

class DiagnosticsIT extends AbstractIntegrationTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private FolioDiagnosticRepository repository;

  @Test
  void reportIsPublicAndPersists() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/diagnostics/report")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {
                      "installId":"install-1",
                      "kind":"crash",
                      "appVersion":"1.2.3",
                      "platform":"windows",
                      "channel":"stable",
                      "userNote":"boom",
                      "logExcerpt":"stack",
                      "signature":"sig-abc",
                      "telemetryEnabled":true
                    }
                    """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.ok").value(true))
        .andExpect(jsonPath("$.savedToYouTrack").value(false));

    assertThat(repository.findAll()).hasSize(1);
    assertThat(repository.findAll().getFirst().getInstallId()).isEqualTo("install-1");
  }

  @Test
  void reportRequiresInstallId() throws Exception {
    mockMvc
        .perform(
            post("/api/v1/diagnostics/report")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error").value("missing_install_id"));
  }
}
