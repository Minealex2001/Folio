package com.folio.backend.integrations;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class IntegrationCommandParserTest {

  @Test
  void parsesSupportedCommands() {
    assertThat(IntegrationCommandParser.parse("/folio link AbCd1234"))
        .isEqualTo(new IntegrationCommandParser.Parsed.Link("ABCD1234"));
    assertThat(IntegrationCommandParser.parse("/folio create task \"Buy milk\""))
        .isEqualTo(new IntegrationCommandParser.Parsed.CreateTask("Buy milk"));
    assertThat(IntegrationCommandParser.parse("/folio list tasks"))
        .isInstanceOf(IntegrationCommandParser.Parsed.ListTasks.class);
    assertThat(IntegrationCommandParser.parse("/folio done \"Buy milk\""))
        .isEqualTo(new IntegrationCommandParser.Parsed.CompleteTask("Buy milk"));
    assertThat(IntegrationCommandParser.parse("nope"))
        .isInstanceOf(IntegrationCommandParser.Parsed.Unknown.class);
  }
}
