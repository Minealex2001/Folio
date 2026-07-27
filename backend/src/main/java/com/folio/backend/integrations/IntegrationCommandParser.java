package com.folio.backend.integrations;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class IntegrationCommandParser {

  private static final int MAX_TASK_TITLE_LEN = 200;
  private static final Pattern LINK =
      Pattern.compile("^/folio\\s+link\\s+([A-Za-z0-9]{6,12})$", Pattern.CASE_INSENSITIVE);
  private static final Pattern CREATE =
      Pattern.compile("^/folio\\s+create\\s+task\\s+\"([^\"]+)\"$", Pattern.CASE_INSENSITIVE);
  private static final Pattern LIST =
      Pattern.compile("^/folio\\s+list\\s+tasks\\s*$", Pattern.CASE_INSENSITIVE);
  private static final Pattern COMPLETE =
      Pattern.compile(
          "^/folio\\s+(?:complete\\s+task|done)\\s+\"([^\"]+)\"$", Pattern.CASE_INSENSITIVE);

  private IntegrationCommandParser() {}

  public static String normalizeCommandText(String raw) {
    String t = raw == null ? "" : raw.trim();
    t = t.replaceAll("(?i)^<at>.*?</at>\\s*", "");
    t = t.replaceAll("^@\\S+\\s+", "");
    return t.trim();
  }

  public sealed interface Parsed
      permits Parsed.Link, Parsed.CreateTask, Parsed.ListTasks, Parsed.CompleteTask, Parsed.Unknown {
    record Link(String code) implements Parsed {}

    record CreateTask(String title) implements Parsed {}

    record ListTasks() implements Parsed {}

    record CompleteTask(String title) implements Parsed {}

    record Unknown() implements Parsed {}
  }

  public static Parsed parse(String raw) {
    String text = normalizeCommandText(raw);
    Matcher link = LINK.matcher(text);
    if (link.matches()) {
      return new Parsed.Link(link.group(1).toUpperCase());
    }
    Matcher create = CREATE.matcher(text);
    if (create.matches()) {
      String title = create.group(1).trim();
      if (title.isEmpty() || title.length() > MAX_TASK_TITLE_LEN) {
        return new Parsed.Unknown();
      }
      return new Parsed.CreateTask(title);
    }
    if (LIST.matcher(text).matches()) {
      return new Parsed.ListTasks();
    }
    Matcher complete = COMPLETE.matcher(text);
    if (complete.matches()) {
      String title = complete.group(1).trim();
      if (title.isEmpty() || title.length() > MAX_TASK_TITLE_LEN) {
        return new Parsed.Unknown();
      }
      return new Parsed.CompleteTask(title);
    }
    return new Parsed.Unknown();
  }
}
