package com.folio.backend.auth;

import com.folio.backend.config.AppProperties;
import com.folio.backend.config.MailProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class EmailService {

  private static final Logger log = LoggerFactory.getLogger(EmailService.class);

  private final JavaMailSender mailSender;
  private final MailProperties mailProperties;
  private final AppProperties appProperties;

  public EmailService(
      JavaMailSender mailSender, MailProperties mailProperties, AppProperties appProperties) {
    this.mailSender = mailSender;
    this.mailProperties = mailProperties;
    this.appProperties = appProperties;
  }

  public void sendEmailVerification(String toEmail, String rawToken) {
    String link =
        appProperties.publicBaseUrl() + "/api/v1/auth/verify-email?token=" + rawToken;
    SimpleMailMessage message = new SimpleMailMessage();
    message.setFrom(mailProperties.from());
    message.setTo(toEmail);
    message.setSubject("Verify your Folio email");
    message.setText(
        "Verify your email by opening this link (or POST the token to /api/v1/auth/verify-email):\n\n"
            + link
            + "\n\nToken: "
            + rawToken
            + "\n");
    send(message);
  }

  public void sendPasswordReset(String toEmail, String rawToken) {
    String link = appProperties.publicBaseUrl() + "/reset-password?token=" + rawToken;
    SimpleMailMessage message = new SimpleMailMessage();
    message.setFrom(mailProperties.from());
    message.setTo(toEmail);
    message.setSubject("Reset your Folio password");
    message.setText(
        "Reset your password with this token (POST to /api/v1/auth/reset-password):\n\n"
            + link
            + "\n\nToken: "
            + rawToken
            + "\n");
    send(message);
  }

  protected void send(SimpleMailMessage message) {
    try {
      mailSender.send(message);
    } catch (Exception e) {
      log.warn("Failed to send email to {}: {}", message.getTo(), e.toString());
      throw e;
    }
  }
}
