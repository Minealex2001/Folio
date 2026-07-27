package com.folio.backend.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.folio.backend.common.ApiException;
import com.folio.backend.config.OpenAiProperties;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
public class HttpOpenAiClient implements OpenAiClient {

  private static final Logger log = LoggerFactory.getLogger(HttpOpenAiClient.class);
  private static final int MAX_429_RETRIES = 3;

  private final OpenAiProperties props;
  private final ObjectMapper mapper;
  private final HttpClient http =
      HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(20)).build();

  public HttpOpenAiClient(OpenAiProperties props, ObjectMapper mapper) {
    this.props = props;
    this.mapper = mapper;
  }

  @Override
  public ChatResult chatCompletion(ChatRequest request) {
    requireKey();
    try {
      ObjectNode body = mapper.createObjectNode();
      body.put("model", props.model());
      body.put("temperature", request.temperature() != null ? request.temperature() : props.temperature());
      ArrayNode messages = body.putArray("messages");
      if (request.systemPrompt() != null && !request.systemPrompt().isBlank()) {
        messages.addObject().put("role", "system").put("content", request.systemPrompt().trim());
      }
      if (request.messages() != null) {
        for (ChatMessage m : request.messages()) {
          ObjectNode msg = messages.addObject();
          msg.put("role", m.role());
          msg.put("content", m.content() == null ? "" : m.content());
          if (m.toolCallId() != null) {
            msg.put("tool_call_id", m.toolCallId());
          }
          if (m.toolCalls() != null && !m.toolCalls().isEmpty()) {
            ArrayNode tcs = msg.putArray("tool_calls");
            for (ToolCall tc : m.toolCalls()) {
              ObjectNode n = tcs.addObject();
              n.put("id", tc.id());
              n.put("type", "function");
              n.putObject("function").put("name", tc.name()).put("arguments", tc.arguments());
            }
          }
        }
      }
      if (request.prompt() != null && !request.prompt().isBlank()) {
        messages.addObject().put("role", "user").put("content", request.prompt().trim());
      }
      if (messages.isEmpty()) {
        throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "Missing prompt/messages");
      }
      int maxTokens = request.maxTokens() != null ? request.maxTokens() : props.maxOutputTokens();
      applyOutputTokenLimit(body, props.model(), maxTokens);
      if (request.responseSchema() != null && !request.responseSchema().isEmpty()) {
        ObjectNode rf = body.putObject("response_format");
        rf.put("type", "json_schema");
        ObjectNode js = rf.putObject("json_schema");
        js.put("name", "folio_response");
        js.put("strict", true);
        js.set("schema", mapper.valueToTree(request.responseSchema()));
      }
      if (request.tools() != null && !request.tools().isEmpty()) {
        body.set("tools", mapper.valueToTree(request.tools()));
        body.put("tool_choice", request.toolChoice() != null ? request.toolChoice() : "auto");
      }

      String raw = postJson(props.baseUrl() + "/chat/completions", body.toString());
      return parseChatSuccess(raw);
    } catch (ApiException e) {
      throw e;
    } catch (Exception e) {
      log.error("OpenAI chatCompletion failed", e);
      throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "internal", "Quill Cloud request failed");
    }
  }

  @Override
  public TranscribeResult transcribe(byte[] audioWav, String languageOrEmpty) {
    requireKey();
    try {
      String boundary = "----FolioBoundary" + UUID.randomUUID().toString().replace("-", "");
      byte[] multipart = buildMultipart(boundary, audioWav, languageOrEmpty);
      int attempt = 0;
      while (true) {
        HttpRequest req =
            HttpRequest.newBuilder()
                .uri(URI.create(props.baseUrl() + "/audio/transcriptions"))
                .timeout(Duration.ofSeconds(60))
                .header("Authorization", "Bearer " + props.apiKey().trim())
                .header("Content-Type", "multipart/form-data; boundary=" + boundary)
                .POST(HttpRequest.BodyPublishers.ofByteArray(multipart))
                .build();
        HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        if (resp.statusCode() >= 200 && resp.statusCode() < 300) {
          JsonNode json = mapper.readTree(resp.body());
          String text = json.path("text").asText("").trim();
          JsonNode segments = json.path("segments");
          if (text.isEmpty()) {
            return new TranscribeResult("");
          }
          if (segments.isArray() && segments.size() > 1) {
            try {
              String diarized = diarize(segments);
              return new TranscribeResult(diarized);
            } catch (Exception diarErr) {
              log.warn("diarization fallback to plain text", diarErr);
              return new TranscribeResult("Speaker 1: " + text);
            }
          }
          return new TranscribeResult("Speaker 1: " + text);
        }
        boolean transientStatus =
            resp.statusCode() == 429
                || resp.statusCode() == 502
                || resp.statusCode() == 503
                || resp.statusCode() == 504;
        if (!transientStatus || attempt >= 2) {
          throw new ApiException(
              HttpStatus.INTERNAL_SERVER_ERROR,
              "internal",
              "Transcription failed (" + resp.statusCode() + ")");
        }
        attempt++;
        Thread.sleep(400L * (1L << (attempt - 1)));
      }
    } catch (ApiException e) {
      throw e;
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "internal", "Transcription interrupted");
    } catch (Exception e) {
      log.error("OpenAI transcribe failed", e);
      throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "internal", "Transcription request failed");
    }
  }

  private String diarize(JsonNode segments) throws Exception {
    StringBuilder prompt = new StringBuilder("Label speakers in this transcript segments JSON:\n");
    prompt.append(segments.toString());
    ChatResult r =
        chatCompletion(
            new ChatRequest(
                "Return JSON array of {speaker:number,text:string} only.",
                prompt.toString(),
                List.of(),
                null,
                2048,
                0.2,
                null,
                null));
    JsonNode parsed = mapper.readTree(r.text());
    ArrayNode turns;
    if (parsed.isArray()) {
      turns = (ArrayNode) parsed;
    } else {
      turns = mapper.createArrayNode();
      JsonNode arr = parsed.path("turns");
      if (!arr.isArray()) {
        arr = parsed.path("segments");
      }
      if (arr.isArray()) {
        turns = (ArrayNode) arr;
      }
    }
    if (turns.isEmpty()) {
      throw new IllegalStateException("Empty diarization");
    }
    StringBuilder out = new StringBuilder();
    for (JsonNode t : turns) {
      String text = t.path("text").asText("").trim();
      if (text.isEmpty()) {
        continue;
      }
      if (!out.isEmpty()) {
        out.append('\n');
      }
      out.append("Speaker ").append(t.path("speaker").asInt(1)).append(": ").append(text);
    }
    return out.toString();
  }

  private void requireKey() {
    if (!props.isConfigured()) {
      throw new ApiException(
          HttpStatus.BAD_REQUEST,
          "failed_precondition",
          "Quill Cloud: inferencia no configurada (clave API del proveedor).");
    }
  }

  private String postJson(String url, String jsonBody) throws Exception {
    int r429 = 0;
    for (int spin = 0; spin < 8; spin++) {
      HttpRequest req =
          HttpRequest.newBuilder()
              .uri(URI.create(url))
              .timeout(Duration.ofSeconds(120))
              .header("Content-Type", "application/json; charset=utf-8")
              .header("Authorization", "Bearer " + props.apiKey().trim())
              .POST(HttpRequest.BodyPublishers.ofString(jsonBody, StandardCharsets.UTF_8))
              .build();
      HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
      int status = resp.statusCode();
      String raw = resp.body();
      if (status == 429 && r429 < MAX_429_RETRIES) {
        r429++;
        Thread.sleep(400L * (1L << (r429 - 1)));
        continue;
      }
      if (status < 200 || status >= 300) {
        throwOpenAiHttpError(status, raw);
      }
      return raw;
    }
    throw new ApiException(
        HttpStatus.INTERNAL_SERVER_ERROR, "internal", "Quill Cloud: demasiados reintentos. Prueba más tarde.");
  }

  private ChatResult parseChatSuccess(String raw) throws Exception {
    JsonNode json = mapper.readTree(raw);
    if (json.path("error").has("message")) {
      throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "internal", "AI provider error");
    }
    JsonNode message = json.path("choices").path(0).path("message");
    String text = message.path("content").asText("").trim();
    List<ToolCall> toolCalls = new ArrayList<>();
    JsonNode tcs = message.path("tool_calls");
    if (tcs.isArray()) {
      for (JsonNode tc : tcs) {
        String id = tc.path("id").asText("").trim();
        String name = tc.path("function").path("name").asText("").trim();
        String args = tc.path("function").path("arguments").asText("");
        if (!id.isEmpty() && !name.isEmpty()) {
          toolCalls.add(new ToolCall(id, name, args));
        }
      }
    }
    if (text.isEmpty() && toolCalls.isEmpty()) {
      throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "internal", "Empty AI response. Try a shorter prompt.");
    }
    Integer tokens =
        json.path("usage").has("total_tokens") ? json.path("usage").path("total_tokens").asInt() : null;
    return new ChatResult(text, tokens, toolCalls.isEmpty() ? null : toolCalls);
  }

  private void applyOutputTokenLimit(ObjectNode body, String model, int maxTokens) {
    String m = model.trim().toLowerCase();
    if (m.startsWith("gpt-5") || m.startsWith("o1") || m.startsWith("o3") || m.startsWith("o4")) {
      body.put("max_completion_tokens", maxTokens);
    } else {
      body.put("max_tokens", maxTokens);
    }
  }

  private void throwOpenAiHttpError(int status, String raw) {
    String openAiMsg = "";
    try {
      openAiMsg = mapper.readTree(raw).path("error").path("message").asText("").trim();
    } catch (Exception ignored) {
      // keep empty
    }
    String quotaHint =
        "Esto viene del proveedor de inferencia de Quill Cloud (clave, cuota, facturación o modelo), no del saldo de gotas Folio.";
    if (status == 401 || status == 403 || status == 429) {
      throw new ApiException(
          HttpStatus.BAD_REQUEST,
          "failed_precondition",
          openAiMsg.isEmpty() ? quotaHint : openAiMsg + " " + quotaHint);
    }
    if (status == 400 || status == 404) {
      throw new ApiException(
          HttpStatus.BAD_REQUEST,
          "failed_precondition",
          openAiMsg.isEmpty() ? "Quill Cloud HTTP " + status : openAiMsg);
    }
    throw new ApiException(
        HttpStatus.INTERNAL_SERVER_ERROR,
        "internal",
        openAiMsg.isEmpty() ? "Quill Cloud devolvió un error. Inténtalo más tarde." : openAiMsg);
  }

  private byte[] buildMultipart(String boundary, byte[] audioWav, String languageOrEmpty) {
    String crlf = "\r\n";
    StringBuilder sb = new StringBuilder();
    sb.append("--").append(boundary).append(crlf);
    sb.append("Content-Disposition: form-data; name=\"file\"; filename=\"chunk.wav\"").append(crlf);
    sb.append("Content-Type: audio/wav").append(crlf).append(crlf);
    byte[] preamble = sb.toString().getBytes(StandardCharsets.UTF_8);

    StringBuilder mid = new StringBuilder();
    mid.append(crlf).append("--").append(boundary).append(crlf);
    mid.append("Content-Disposition: form-data; name=\"model\"").append(crlf).append(crlf);
    mid.append(props.transcribeModel()).append(crlf);
    if (languageOrEmpty != null && !languageOrEmpty.isBlank() && !"auto".equalsIgnoreCase(languageOrEmpty)) {
      mid.append("--").append(boundary).append(crlf);
      mid.append("Content-Disposition: form-data; name=\"language\"").append(crlf).append(crlf);
      mid.append(languageOrEmpty.trim().substring(0, Math.min(2, languageOrEmpty.trim().length())).toLowerCase())
          .append(crlf);
    }
    mid.append("--").append(boundary).append(crlf);
    mid.append("Content-Disposition: form-data; name=\"response_format\"").append(crlf).append(crlf);
    mid.append("verbose_json").append(crlf);
    mid.append("--").append(boundary).append("--").append(crlf);
    byte[] after = mid.toString().getBytes(StandardCharsets.UTF_8);

    byte[] out = new byte[preamble.length + audioWav.length + after.length];
    System.arraycopy(preamble, 0, out, 0, preamble.length);
    System.arraycopy(audioWav, 0, out, preamble.length, audioWav.length);
    System.arraycopy(after, 0, out, preamble.length + audioWav.length, after.length);
    return out;
  }
}
