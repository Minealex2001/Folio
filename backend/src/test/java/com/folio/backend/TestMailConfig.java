package com.folio.backend;

import com.folio.backend.auth.EmailService;
import com.folio.backend.config.AppProperties;
import com.folio.backend.config.MailProperties;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

@TestConfiguration
public class TestMailConfig {

  @Bean
  @Primary
  RecordingEmailService recordingEmailService(
      JavaMailSender mailSender, MailProperties mailProperties, AppProperties appProperties) {
    return new RecordingEmailService(mailSender, mailProperties, appProperties);
  }

  /** Captures verification / reset tokens without talking to SMTP. */
  public static class RecordingEmailService extends EmailService {

    private final AtomicReference<String> lastVerificationToken = new AtomicReference<>();
    private final AtomicReference<String> lastResetToken = new AtomicReference<>();
    private final List<SimpleMailMessage> sent =
        Collections.synchronizedList(new ArrayList<>());

    public RecordingEmailService(
        JavaMailSender mailSender, MailProperties mailProperties, AppProperties appProperties) {
      super(mailSender, mailProperties, appProperties);
    }

    @Override
    public void sendEmailVerification(String toEmail, String rawToken) {
      lastVerificationToken.set(rawToken);
      SimpleMailMessage msg = new SimpleMailMessage();
      msg.setTo(toEmail);
      msg.setSubject("verify");
      msg.setText(rawToken);
      sent.add(msg);
    }

    @Override
    public void sendPasswordReset(String toEmail, String rawToken) {
      lastResetToken.set(rawToken);
      SimpleMailMessage msg = new SimpleMailMessage();
      msg.setTo(toEmail);
      msg.setSubject("reset");
      msg.setText(rawToken);
      sent.add(msg);
    }

    public String lastVerificationToken() {
      return lastVerificationToken.get();
    }

    public String lastResetToken() {
      return lastResetToken.get();
    }

    public List<SimpleMailMessage> sent() {
      return List.copyOf(sent);
    }

    public void clear() {
      lastVerificationToken.set(null);
      lastResetToken.set(null);
      sent.clear();
    }
  }
}
