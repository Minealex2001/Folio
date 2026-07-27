package com.folio.backend.ai;

import com.folio.backend.ai.dto.AiCompleteRequest;
import com.folio.backend.ai.dto.AiCompleteResponse;
import com.folio.backend.ai.dto.AiTranscribeRequest;
import com.folio.backend.ai.dto.AiTranscribeResponse;
import com.folio.backend.user.FolioUserPrincipal;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/ai")
public class AiController {

  private final AiService aiService;

  public AiController(AiService aiService) {
    this.aiService = aiService;
  }

  @GetMapping("/pricing")
  public Map<String, Object> pricing() {
    FolioUserPrincipal.requireUid();
    return aiService.pricing();
  }

  @PostMapping("/complete")
  public AiCompleteResponse complete(@RequestBody AiCompleteRequest request) {
    return aiService.complete(FolioUserPrincipal.requireUid(), request);
  }

  @PostMapping("/transcribe")
  public AiTranscribeResponse transcribe(@RequestBody AiTranscribeRequest request) {
    return aiService.transcribe(FolioUserPrincipal.requireUid(), request);
  }
}
