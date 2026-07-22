/// Resultado del parseo de un comando `/folio …` (espejo del servidor).
sealed class IntegrationCommandParseResult {
  const IntegrationCommandParseResult();
}

class IntegrationCommandLink extends IntegrationCommandParseResult {
  const IntegrationCommandLink(this.code);
  final String code;
}

class IntegrationCommandCreateTask extends IntegrationCommandParseResult {
  const IntegrationCommandCreateTask(this.title);
  final String title;
}

class IntegrationCommandListTasks extends IntegrationCommandParseResult {
  const IntegrationCommandListTasks();
}

class IntegrationCommandCompleteTask extends IntegrationCommandParseResult {
  const IntegrationCommandCompleteTask(this.title);
  final String title;
}

class IntegrationCommandUnknown extends IntegrationCommandParseResult {
  const IntegrationCommandUnknown();
}

/// Normaliza y parsea texto de comando Slack/Teams/Discord.
class IntegrationCommandParser {
  const IntegrationCommandParser();

  static const int maxTaskTitleLength = 200;

  IntegrationCommandParseResult parse(String raw) {
    var text = raw.trim();
    text = text.replaceFirst(RegExp(r'^<at>.*?</at>\s*', caseSensitive: false), '');
    text = text.replaceFirst(RegExp(r'^@\S+\s+'), '');
    text = text.trim();

    final link = RegExp(r'^/folio\s+link\s+([A-Za-z0-9]{6,12})$', caseSensitive: false)
        .firstMatch(text);
    if (link != null) {
      return IntegrationCommandLink(link.group(1)!.toUpperCase());
    }

    final create = RegExp(
      r'^/folio\s+create\s+task\s+"([^"]+)"$',
      caseSensitive: false,
    ).firstMatch(text);
    if (create != null) {
      final title = create.group(1)!.trim();
      if (title.isEmpty || title.length > maxTaskTitleLength) {
        return const IntegrationCommandUnknown();
      }
      return IntegrationCommandCreateTask(title);
    }

    final listTasks = RegExp(
      r'^/folio\s+list\s+tasks\s*$',
      caseSensitive: false,
    ).firstMatch(text);
    if (listTasks != null) {
      return const IntegrationCommandListTasks();
    }

    final complete = RegExp(
      r'^/folio\s+(?:complete\s+task|done)\s+"([^"]+)"$',
      caseSensitive: false,
    ).firstMatch(text);
    if (complete != null) {
      final title = complete.group(1)!.trim();
      if (title.isEmpty || title.length > maxTaskTitleLength) {
        return const IntegrationCommandUnknown();
      }
      return IntegrationCommandCompleteTask(title);
    }

    return const IntegrationCommandUnknown();
  }
}
