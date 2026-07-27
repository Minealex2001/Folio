package com.folio.backend.collab.ws;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

/**
 * Fase 27 — sync en vivo de collab vía STOMP/WebSocket.
 *
 * <p>Endpoint: {@code /ws/collab}. Auth JWT en frame CONNECT (ver {@link CollabStompAuthInterceptor}).
 * Destinos: SEND {@code /app/collab/{roomId}/update}, SUBSCRIBE {@code /topic/collab/{roomId}}.
 *
 * <p>El cliente Flutter actual ({@code collab_session_controller.dart}) usa last-write-wins con
 * {@code contentVersion} (no CRDT); el contrato del servidor replica title/blocks (legacy) y
 * wrappedRoomKey/contentCipher (E2E).
 */
@Configuration
@EnableWebSocketMessageBroker
public class CollabWebSocketConfig implements WebSocketMessageBrokerConfigurer {

  private final CollabStompAuthInterceptor authInterceptor;

  public CollabWebSocketConfig(CollabStompAuthInterceptor authInterceptor) {
    this.authInterceptor = authInterceptor;
  }

  @Override
  public void configureMessageBroker(MessageBrokerRegistry registry) {
    registry.enableSimpleBroker("/topic", "/queue");
    registry.setApplicationDestinationPrefixes("/app");
    registry.setUserDestinationPrefix("/user");
  }

  @Override
  public void registerStompEndpoints(StompEndpointRegistry registry) {
    registry.addEndpoint("/ws/collab").setAllowedOriginPatterns("*");
  }

  @Override
  public void configureClientInboundChannel(ChannelRegistration registration) {
    registration.interceptors(authInterceptor);
  }
}
