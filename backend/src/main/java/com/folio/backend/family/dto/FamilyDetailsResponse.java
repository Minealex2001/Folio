package com.folio.backend.family.dto;

import java.util.List;
import java.util.Map;

public record FamilyDetailsResponse(
    List<String> members, Map<String, Map<String, String>> membersInfo) {}
