package com.folio.backend.community;

import com.folio.backend.community.CommunityTemplatesService.CommunityTemplateWrite;
import com.folio.backend.community.dto.CommunityTemplateRequest;
import com.folio.backend.user.FolioUserPrincipal;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/community-templates")
public class CommunityTemplatesController {

  private final CommunityTemplatesService service;

  public CommunityTemplatesController(CommunityTemplatesService service) {
    this.service = service;
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> create(@RequestBody CommunityTemplateRequest body) {
    UUID id = body.id() == null || body.id().isBlank() ? null : UUID.fromString(body.id());
    return service.create(
        FolioUserPrincipal.requireUid(),
        new CommunityTemplateWrite(
            id,
            body.name(),
            body.description(),
            body.category(),
            body.emoji(),
            body.blockCount() == null ? 0 : body.blockCount(),
            body.storagePath(),
            body.storageDownloadUrl(),
            body.sizeBytes()));
  }

  @PutMapping("/{id}")
  public Map<String, Object> update(
      @PathVariable UUID id, @RequestBody CommunityTemplateRequest body) {
    return service.update(
        FolioUserPrincipal.requireUid(),
        id,
        new CommunityTemplateWrite(
            id,
            body.name(),
            body.description(),
            body.category(),
            body.emoji(),
            body.blockCount() == null ? 0 : body.blockCount(),
            body.storagePath(),
            body.storageDownloadUrl(),
            body.sizeBytes()));
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void delete(@PathVariable UUID id) {
    service.delete(FolioUserPrincipal.requireUid(), id);
  }

  @GetMapping("/{id}")
  public Map<String, Object> get(@PathVariable UUID id) {
    return service.get(id);
  }

  @GetMapping
  public List<Map<String, Object>> list() {
    return service.list();
  }
}
