package com.folio.backend.integrations.jira;

import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/integrations/jira")
public class JiraOAuthController {

  private final JiraOAuthService service;

  public JiraOAuthController(JiraOAuthService service) {
    this.service = service;
  }

  @PostMapping("/oauth-exchange")
  public ResponseEntity<Map<String, Object>> oauthExchange(@RequestBody Map<String, Object> body) {
    return service.exchange(body);
  }
}
