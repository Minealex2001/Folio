package com.folio.backend.collab.ws;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.folio.backend.AbstractIntegrationTest;
import com.folio.backend.TestEntitlements;
import com.folio.backend.persistence.entity.CollabRoomEntity;
import com.folio.backend.persistence.repository.CollabRoomRepository;
import com.jayway.jsonpath.JsonPath;
import java.lang.reflect.Type;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.MediaType;
import org.springframework.messaging.converter.MappingJackson2MessageConverter;
import org.springframework.messaging.simp.stomp.StompFrameHandler;
import org.springframework.messaging.simp.stomp.StompHeaders;
import org.springframework.messaging.simp.stomp.StompSession;
import org.springframework.messaging.simp.stomp.StompSessionHandlerAdapter;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.messaging.WebSocketStompClient;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class CollabWebSocketIT extends AbstractIntegrationTest {

  @LocalServerPort private int port;
  @Autowired private MockMvc mockMvc;
  @Autowired private TestEntitlements entitlements;
  @Autowired private CollabRoomRepository roomRepository;

  private String ownerToken;
  private String ownerUid;
  private String memberToken;
  private String memberUid;

  @BeforeEach
  void setUp() throws Exception {
    String e1 = uniqueEmail("ws-owner");
    ownerUid = register(e1);
    entitlements.enableCollab(ownerUid);
    ownerToken = login(e1);

    String e2 = uniqueEmail("ws-member");
    memberUid = register(e2);
    entitlements.enableCollab(memberUid);
    memberToken = login(e2);
  }

  @Test
  void twoClients_liveUpdateRetransmittedAndContentVersionAdvances() throws Exception {
    RoomSeed seed = seedSealedRoom();

    WebSocketStompClient clientA = stompClient();
    WebSocketStompClient clientB = stompClient();

    StompSession sessionA = connect(clientA, ownerToken);
    StompSession sessionB = connect(clientB, memberToken);

    CompletableFuture<Map<?, ?>> received = new CompletableFuture<>();
    sessionB.subscribe(
        "/topic/collab/" + seed.roomId(),
        new StompFrameHandler() {
          @Override
          public Type getPayloadType(StompHeaders headers) {
            return Map.class;
          }

          @Override
          public void handleFrame(StompHeaders headers, Object payload) {
            received.complete((Map<?, ?>) payload);
          }
        });

    // Dar tiempo a que el SUBSCRIBE se registre en el broker simple
    Thread.sleep(200);

    int before = roomRepository.findById(UUID.fromString(seed.roomId())).orElseThrow().getContentVersion();

    Map<String, Object> update =
        Map.of(
            "contentCipher",
            "cipher-live-v2",
            "contentVersion",
            before + 1,
            "updatedBy",
            ownerUid,
            "changedKeys",
            java.util.List.of("contentCipher", "contentVersion", "updatedAt", "updatedBy"));
    sessionA.send("/app/collab/" + seed.roomId() + "/update", update);

    Map<?, ?> payload = received.get(8, TimeUnit.SECONDS);
    assertThat(payload.get("type")).isEqualTo("room.update");
    assertThat(payload.get("roomId")).isEqualTo(seed.roomId());
    assertThat(payload.get("contentVersion")).isEqualTo(before + 1);
    assertThat(payload.get("contentCipher")).isEqualTo("cipher-live-v2");

    CollabRoomEntity room = roomRepository.findById(UUID.fromString(seed.roomId())).orElseThrow();
    assertThat(room.getContentVersion()).isEqualTo(before + 1);
    assertThat(room.getContentCipher()).isEqualTo("cipher-live-v2");

    sessionA.disconnect();
    sessionB.disconnect();
  }

  @Test
  void connectWithoutAuthIsRejected() {
    WebSocketStompClient client = stompClient();
    assertThatThrownBy(() -> connect(client, null))
        .isInstanceOf(ExecutionException.class)
        .hasRootCauseInstanceOf(Exception.class);
  }

  @Test
  void invalidUpdateIsNotRetransmitted() throws Exception {
    RoomSeed seed = seedSealedRoom();

    WebSocketStompClient clientA = stompClient();
    WebSocketStompClient clientB = stompClient();
    StompSession sessionA = connect(clientA, ownerToken);
    StompSession sessionB = connect(clientB, memberToken);

    CompletableFuture<Map<?, ?>> received = new CompletableFuture<>();
    sessionB.subscribe(
        "/topic/collab/" + seed.roomId(),
        new StompFrameHandler() {
          @Override
          public Type getPayloadType(StompHeaders headers) {
            return Map.class;
          }

          @Override
          public void handleFrame(StompHeaders headers, Object payload) {
            received.complete((Map<?, ?>) payload);
          }
        });
    Thread.sleep(200);

    int before = roomRepository.findById(UUID.fromString(seed.roomId())).orElseThrow().getContentVersion();

    // wrappedRoomKey es inmutable tras el seal — el validador debe rechazar
    Map<String, Object> illegal =
        Map.of(
            "wrappedRoomKey",
            "changed-key-should-fail-xxxxxxxxxxxx",
            "contentCipher",
            "nope",
            "contentVersion",
            before + 1,
            "changedKeys",
            java.util.List.of("wrappedRoomKey", "contentCipher", "contentVersion"));
    sessionA.send("/app/collab/" + seed.roomId() + "/update", illegal);

    assertThatThrownBy(() -> received.get(2, TimeUnit.SECONDS)).isInstanceOf(TimeoutException.class);

    CollabRoomEntity room = roomRepository.findById(UUID.fromString(seed.roomId())).orElseThrow();
    assertThat(room.getContentVersion()).isEqualTo(before);

    sessionA.disconnect();
    sessionB.disconnect();
  }

  private RoomSeed seedSealedRoom() throws Exception {
    MvcResult created =
        mockMvc
            .perform(
                post("/api/v1/collab/rooms")
                    .header("Authorization", "Bearer " + ownerToken)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"vaultPageId\":\"ws-page\"}"))
            .andExpect(status().isOk())
            .andReturn();
    String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId");
    String joinCode = JsonPath.read(created.getResponse().getContentAsString(), "$.joinCode");

    mockMvc
        .perform(
            post("/api/v1/collab/rooms/join")
                .header("Authorization", "Bearer " + memberToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"joinCode\":\"" + joinCode + "\"}"))
        .andExpect(status().isOk());

    mockMvc
        .perform(
            put("/api/v1/collab/rooms/" + roomId)
                .header("Authorization", "Bearer " + ownerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"wrappedRoomKey\":\"abcdefghijklmnopqrstuvwx\",\"contentCipher\":\"cipher1\",\"contentVersion\":1,\"updatedBy\":\""
                        + ownerUid
                        + "\",\"changedKeys\":[\"wrappedRoomKey\",\"contentCipher\",\"contentVersion\",\"updatedAt\",\"updatedBy\"]}"))
        .andExpect(status().isOk());

    return new RoomSeed(roomId, joinCode);
  }

  private WebSocketStompClient stompClient() {
    WebSocketStompClient client = new WebSocketStompClient(new StandardWebSocketClient());
    client.setMessageConverter(new MappingJackson2MessageConverter());
    return client;
  }

  private StompSession connect(WebSocketStompClient client, String accessToken)
      throws ExecutionException, InterruptedException, TimeoutException {
    StompHeaders connectHeaders = new StompHeaders();
    if (accessToken != null) {
      connectHeaders.add("Authorization", "Bearer " + accessToken);
    }
    return client
        .connectAsync(
            "ws://localhost:" + port + "/ws/collab",
            new WebSocketHttpHeaders(),
            connectHeaders,
            new StompSessionHandlerAdapter() {})
        .get(5, TimeUnit.SECONDS);
  }

  private String register(String email) throws Exception {
    MvcResult reg =
        mockMvc
            .perform(
                post("/api/v1/auth/register")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        "{\"email\":\""
                            + email
                            + "\",\"password\":\"password123\",\"displayName\":\"W\"}"))
            .andExpect(status().isCreated())
            .andReturn();
    return JsonPath.read(reg.getResponse().getContentAsString(), "$.uid");
  }

  private String login(String email) throws Exception {
    MvcResult login =
        mockMvc
            .perform(
                post("/api/v1/auth/login")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"email\":\"" + email + "\",\"password\":\"password123\"}"))
            .andExpect(status().isOk())
            .andReturn();
    return JsonPath.read(login.getResponse().getContentAsString(), "$.accessToken");
  }

  private record RoomSeed(String roomId, String joinCode) {}
}
