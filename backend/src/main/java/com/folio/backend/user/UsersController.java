package com.folio.backend.user;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users")
public class UsersController {

  @GetMapping("/me")
  public Map<String, String> me() {
    FolioUserPrincipal principal = FolioUserPrincipal.requireCurrent();
    return Map.of("uid", principal.uid(), "email", principal.email());
  }
}
