package com.folio.backend.published;

import com.folio.backend.published.dto.PublishedPageRequest;
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
@RequestMapping("/api/v1/published-pages")
public class PublishedPagesController {

  private final PublishedPagesService service;

  public PublishedPagesController(PublishedPagesService service) {
    this.service = service;
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> create(@RequestBody PublishedPageRequest body) {
    return service.create(FolioUserPrincipal.requireUid(), body.storagePath());
  }

  @PutMapping("/{id}")
  public Map<String, Object> update(@PathVariable UUID id, @RequestBody PublishedPageRequest body) {
    return service.update(FolioUserPrincipal.requireUid(), id, body.storagePath());
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

  @GetMapping("/mine")
  public List<Map<String, Object>> mine() {
    return service.listMine(FolioUserPrincipal.requireUid());
  }
}
