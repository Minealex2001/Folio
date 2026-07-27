package com.folio.backend.vault.dto;

import java.util.List;

public record CheckBlobsRequest(String vaultId, List<String> blobIds) {}
