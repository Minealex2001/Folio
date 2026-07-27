package com.folio.backend.collab.ws;

import com.folio.backend.auth.JwtService;
import com.folio.backend.collab.CollabService;
import com.folio.backend.user.FolioUserPrincipal;
import io.jsonwebtoken.Claims;
import java.security.Principal;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessageDeliveryException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.stereotype.Component;

/**
 * Autentica el frame STOMP CONNECT con {@link JwtService} (mismo JWT que el filtro HTTP) y exige
 * membresía de sala en SUBSCRIBE a {@code /topic/collab/{roomId}}.
 */
@Component
public class CollabStompAuthInterceptor implements ChannelInterceptor {

  private static final Pattern TOPIC_ROOM =
      Pattern.compile("^/topic/collab/([0-9a-fA-F-]{36})$");

  private final JwtService jwtService;
  private final CollabService collabService;

  public CollabStompAuthInterceptor(JwtService jwtService, CollabService collabService) {
    this.jwtService = jwtService;
    this.collabService = collabService;
  }

  @Override
  public Message<?> preSend(Message<?> message, MessageChannel channel) {
    StompHeaderAccessor accessor =
        MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
    if (accessor == null || accessor.getCommand() == null) {
      return message;
    }

    StompCommand command = accessor.getCommand();
    if (StompCommand.CONNECT.equals(command)) {
      authenticateConnect(accessor);
    } else if (StompCommand.SUBSCRIBE.equals(command)) {
      authorizeSubscribe(accessor);
    } else if (requiresAuthenticatedUser(command)) {
      if (accessor.getUser() == null) {
        deny("STOMP frame requires authenticated session");
      }
    }
    return message;
  }

  private void authenticateConnect(StompHeaderAccessor accessor) {
    String token = extractBearerToken(accessor);
    if (token == null || token.isBlank()) {
      deny("STOMP CONNECT requires Authorization Bearer token");
    }
    try {
      Claims claims = jwtService.parseValidClaims(token);
      String uid = claims.getSubject();
      if (uid == null || uid.isBlank()) {
        deny("Invalid JWT subject");
      }
      String email = claims.get("email", String.class);
      accessor.setUser(new FolioUserPrincipal(uid, email != null ? email : ""));
    } catch (JwtService.InvalidJwtException ex) {
      deny("Invalid or expired token");
    }
  }

  private void authorizeSubscribe(StompHeaderAccessor accessor) {
    Principal user = accessor.getUser();
    if (user == null) {
      deny("SUBSCRIBE requires authenticated session");
    }
    String destination = accessor.getDestination();
    if (destination == null) {
      deny("SUBSCRIBE destination required");
    }
    Matcher m = TOPIC_ROOM.matcher(destination);
    if (!m.matches()) {
      deny("Unknown collab subscribe destination");
    }
    String roomId = m.group(1);
    if (!collabService.isMember(roomId, user.getName())) {
      deny("Not a member of this collab room");
    }
  }

  private static boolean requiresAuthenticatedUser(StompCommand command) {
    return StompCommand.SEND.equals(command)
        || StompCommand.SUBSCRIBE.equals(command)
        || StompCommand.UNSUBSCRIBE.equals(command);
  }

  private static String extractBearerToken(StompHeaderAccessor accessor) {
    String header = firstNative(accessor, "Authorization");
    if (header == null) {
      header = firstNative(accessor, "authorization");
    }
    if (header != null && header.regionMatches(true, 0, "Bearer ", 0, 7)) {
      return header.substring(7).trim();
    }
    // Alternativa explícita por si el cliente no puede enviar Authorization en CONNECT
    String token = firstNative(accessor, "token");
    if (token != null && !token.isBlank()) {
      return token.trim();
    }
    return null;
  }

  private static String firstNative(StompHeaderAccessor accessor, String name) {
    List<String> values = accessor.getNativeHeader(name);
    if (values == null || values.isEmpty()) {
      return null;
    }
    return values.getFirst();
  }

  private static void deny(String message) {
    throw new MessageDeliveryException(message);
  }
}
