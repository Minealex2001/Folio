package com.folio.backend.ai;

import java.util.LinkedHashMap;
import java.util.Map;

/** Tabla de costes de tinta (puerto de INK_COST_BY_OPERATION en functions/src/index.ts). */
public final class InkPricing {

  public static final Map<String, Integer> COST_BY_OPERATION =
      Map.ofEntries(
          Map.entry("rewrite_block", 3),
          Map.entry("summarize_selection", 3),
          Map.entry("extract_tasks", 6),
          Map.entry("summarize_page", 6),
          Map.entry("generate_insert", 9),
          Map.entry("generate_page", 15),
          Map.entry("chat_turn", 6),
          Map.entry("agent_main", 16),
          Map.entry("agent_followup", 9),
          Map.entry("edit_page_panel", 9),
          Map.entry("transcribe_cloud", 2),
          Map.entry("default", 6));

  public static final int MAX_PER_REQUEST = 16;
  public static final int PROMPT_LENGTH_SURCHARGE_THRESHOLD = 32000;
  public static final int EXTRA_FOR_LONG_PROMPT = 2;
  public static final int TOKENS_PER_SURCHARGE_UNIT = 6000;
  public static final int MAX_TOKEN_SURCHARGE = 10;

  private InkPricing() {}

  public static Map<String, Object> pricingResponse() {
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("costByOperation", COST_BY_OPERATION);
    out.put("inkMaxPerRequest", MAX_PER_REQUEST);
    out.put("promptLengthSurchargeThreshold", PROMPT_LENGTH_SURCHARGE_THRESHOLD);
    out.put("extraForLongPrompt", EXTRA_FOR_LONG_PROMPT);
    out.put("tokensPerSurchargeUnit", TOKENS_PER_SURCHARGE_UNIT);
    out.put("maxTokenSurcharge", MAX_TOKEN_SURCHARGE);
    return out;
  }

  public static String normalizeOperationKind(String raw) {
    if (raw == null) {
      return "default";
    }
    String kind = raw.trim();
    if (kind.isEmpty() || !COST_BY_OPERATION.containsKey(kind)) {
      return "default";
    }
    return kind;
  }

  public static int resolveInkCost(String operationKind, int promptLength) {
    int base = COST_BY_OPERATION.getOrDefault(operationKind, COST_BY_OPERATION.get("default"));
    int cost = base;
    if (promptLength > PROMPT_LENGTH_SURCHARGE_THRESHOLD) {
      cost += EXTRA_FOR_LONG_PROMPT;
    }
    return Math.min(cost, MAX_PER_REQUEST);
  }

  public static int tokenSurchargeInk(Integer totalTokenCount) {
    if (totalTokenCount == null || totalTokenCount <= 0) {
      return 0;
    }
    return Math.min(MAX_TOKEN_SURCHARGE, totalTokenCount / TOKENS_PER_SURCHARGE_UNIT);
  }

  public static InkBalances debit(int monthly, int purchased, int cost) {
    if (cost <= 0) {
      return new InkBalances(monthly, purchased);
    }
    if (monthly >= cost) {
      return new InkBalances(monthly - cost, purchased);
    }
    return new InkBalances(0, purchased - (cost - monthly));
  }

  public record InkBalances(int monthly, int purchased) {}
}
