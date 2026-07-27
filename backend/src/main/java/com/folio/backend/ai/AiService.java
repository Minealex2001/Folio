package com.folio.backend.ai;

import com.folio.backend.ai.OpenAiClient.ChatMessage;
import com.folio.backend.ai.OpenAiClient.ChatRequest;
import com.folio.backend.ai.OpenAiClient.ChatResult;
import com.folio.backend.ai.OpenAiClient.ToolCall;
import com.folio.backend.ai.OpenAiClient.TranscribeResult;
import com.folio.backend.ai.dto.AiCompleteRequest;
import com.folio.backend.ai.dto.AiCompleteResponse;
import com.folio.backend.ai.dto.AiInkDto;
import com.folio.backend.ai.dto.AiTranscribeRequest;
import com.folio.backend.ai.dto.AiTranscribeResponse;
import com.folio.backend.common.ApiException;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class AiService {

  private static final Logger log = LoggerFactory.getLogger(AiService.class);

  private final OpenAiClient openAiClient;
  private final InkService inkService;

  public AiService(OpenAiClient openAiClient, InkService inkService) {
    this.openAiClient = openAiClient;
    this.inkService = inkService;
  }

  public Map<String, Object> pricing() {
    return InkPricing.pricingResponse();
  }

  public AiCompleteResponse complete(String uid, AiCompleteRequest req) {
    List<ChatMessage> messages = normalizeMessages(req.messages());
    String prompt = req.prompt() == null ? "" : req.prompt().trim();
    String systemPrompt = truncate(req.systemPrompt(), 20000);
    if (prompt.isEmpty() && messages.isEmpty()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "Missing prompt/messages");
    }
    String operationKind = InkPricing.normalizeOperationKind(req.operationKind());
    int promptLength = promptLengthForInk(prompt, systemPrompt, messages);
    int baseCost = InkPricing.resolveInkCost(operationKind, promptLength);

    if (inkService.isStaff(uid)) {
      ChatResult result =
          openAiClient.chatCompletion(
              new ChatRequest(
                  systemPrompt.isEmpty() ? null : systemPrompt,
                  prompt.isEmpty() ? null : prompt,
                  messages.isEmpty() ? null : messages,
                  req.responseSchema(),
                  req.maxTokens(),
                  req.temperature(),
                  req.tools(),
                  req.toolChoice()));
      InkPricing.InkBalances bal = inkService.readBalances(uid);
      return toCompleteResponse(result, bal, 0, 0, 0);
    }

    InkService.DebitResult debit = inkService.debitForAi(uid, baseCost);
    try {
      ChatResult result =
          openAiClient.chatCompletion(
              new ChatRequest(
                  systemPrompt.isEmpty() ? null : systemPrompt,
                  prompt.isEmpty() ? null : prompt,
                  messages.isEmpty() ? null : messages,
                  req.responseSchema(),
                  req.maxTokens(),
                  req.temperature(),
                  req.tools(),
                  req.toolChoice()));
      int extraWant = InkPricing.tokenSurchargeInk(result.totalTokenCount());
      int extraCharged =
          inkService.chargeExtraIfPossible(uid, extraWant, debit.allowSubscriptionInk());
      InkPricing.InkBalances bal = inkService.readBalances(uid);
      return toCompleteResponse(result, bal, baseCost + extraCharged, baseCost, extraCharged);
    } catch (RuntimeException e) {
      if (debit.debited()) {
        try {
          inkService.refund(uid, baseCost);
        } catch (Exception refundErr) {
          log.error("folioCloudAiComplete: refund after AI failure", refundErr);
        }
      }
      throw e;
    }
  }

  public AiTranscribeResponse transcribe(String uid, AiTranscribeRequest req) {
    String audioBase64 = req.audioBase64() == null ? "" : req.audioBase64().trim();
    if (audioBase64.isEmpty()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "audioBase64 required");
    }
    boolean chargeInk = Boolean.TRUE.equals(req.chargeInk());
    int baseInkCost = InkPricing.COST_BY_OPERATION.getOrDefault("transcribe_cloud", 1);
    int inkCost = baseInkCost;
    if (chargeInk && req.inkAmount() != null && req.inkAmount() >= 1) {
      inkCost = (int) Math.ceil(req.inkAmount());
    }

    boolean inkDebited = false;
    if (chargeInk && !inkService.isStaff(uid)) {
      inkService.debitForAi(uid, inkCost);
      inkDebited = true;
    }

    try {
      byte[] audio = Base64.getDecoder().decode(audioBase64);
      String language = req.language() == null ? "" : req.language().trim();
      TranscribeResult result = openAiClient.transcribe(audio, language);
      InkPricing.InkBalances bal = inkService.readBalances(uid);
      return new AiTranscribeResponse(
          result.transcript(), new AiInkDto(bal.monthly(), bal.purchased()));
    } catch (IllegalArgumentException e) {
      if (inkDebited) {
        inkService.refund(uid, inkCost);
      }
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "audioBase64 invalid");
    } catch (RuntimeException e) {
      if (inkDebited) {
        inkService.refund(uid, inkCost);
      }
      throw e;
    }
  }

  private static AiCompleteResponse toCompleteResponse(
      ChatResult result,
      InkPricing.InkBalances bal,
      int inkCharged,
      int inkBaseCharged,
      int inkTokenSurcharge) {
    List<Map<String, Object>> toolCalls = null;
    if (result.toolCalls() != null && !result.toolCalls().isEmpty()) {
      toolCalls = new ArrayList<>();
      for (ToolCall tc : result.toolCalls()) {
        toolCalls.add(
            Map.of(
                "id",
                tc.id(),
                "type",
                "function",
                "function",
                Map.of("name", tc.name(), "arguments", tc.arguments())));
      }
    }
    return new AiCompleteResponse(
        result.text(),
        toolCalls,
        new AiInkDto(bal.monthly(), bal.purchased()),
        inkCharged,
        inkBaseCharged,
        inkTokenSurcharge);
  }

  private static int promptLengthForInk(String prompt, String systemPrompt, List<ChatMessage> messages) {
    int n = 0;
    if (prompt != null && !prompt.isBlank()) {
      n += prompt.trim().length();
    }
    if (systemPrompt != null && !systemPrompt.isBlank()) {
      n += systemPrompt.trim().length();
    }
    if (messages != null) {
      for (ChatMessage m : messages) {
        if (m.content() != null) {
          n += m.content().length();
        }
      }
    }
    return n;
  }

  @SuppressWarnings("unchecked")
  private static List<ChatMessage> normalizeMessages(List<Map<String, Object>> raw) {
    if (raw == null || raw.isEmpty()) {
      return List.of();
    }
    List<ChatMessage> out = new ArrayList<>();
    for (Map<String, Object> item : raw) {
      if (item == null) {
        continue;
      }
      String role = stringVal(item.get("role")).trim().toLowerCase();
      if (!role.equals("system")
          && !role.equals("user")
          && !role.equals("assistant")
          && !role.equals("tool")) {
        continue;
      }
      String content = stringVal(item.get("content")).trim();
      if (role.equals("tool")) {
        String toolCallId = stringVal(item.get("tool_call_id")).trim();
        if (toolCallId.isEmpty() || content.isEmpty()) {
          continue;
        }
        out.add(new ChatMessage(role, content, null, toolCallId));
        continue;
      }
      if (role.equals("assistant")) {
        List<ToolCall> tcs = normalizeToolCalls(item.get("tool_calls"));
        if (content.isEmpty() && (tcs == null || tcs.isEmpty())) {
          continue;
        }
        out.add(new ChatMessage(role, content, tcs, null));
        continue;
      }
      if (content.isEmpty()) {
        continue;
      }
      out.add(new ChatMessage(role, content, null, null));
    }
    return out;
  }

  @SuppressWarnings("unchecked")
  private static List<ToolCall> normalizeToolCalls(Object raw) {
    if (!(raw instanceof List<?> list) || list.isEmpty()) {
      return null;
    }
    List<ToolCall> out = new ArrayList<>();
    for (Object item : list) {
      if (!(item instanceof Map<?, ?> m)) {
        continue;
      }
      String id = stringVal(m.get("id")).trim();
      Object fnObj = m.get("function");
      if (!(fnObj instanceof Map<?, ?> fn)) {
        continue;
      }
      String name = stringVal(fn.get("name")).trim();
      String args = stringVal(fn.get("arguments"));
      if (id.isEmpty() || name.isEmpty()) {
        continue;
      }
      out.add(new ToolCall(id, name, args));
    }
    return out.isEmpty() ? null : out;
  }

  private static String stringVal(Object v) {
    return v == null ? "" : String.valueOf(v);
  }

  private static String truncate(String raw, int max) {
    if (raw == null) {
      return "";
    }
    String s = raw.trim();
    if (s.length() <= max) {
      return s;
    }
    return s.substring(0, max);
  }
}
