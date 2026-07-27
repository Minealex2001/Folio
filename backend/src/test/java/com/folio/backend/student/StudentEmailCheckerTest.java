package com.folio.backend.student;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Port 1:1 of {@code functions/src/student_email.test.ts}. */
class StudentEmailCheckerTest {

  private StudentEmailChecker checker;

  @BeforeEach
  void setUp() {
    checker = new StudentEmailChecker();
  }

  @Test
  void acceptsKnownSwotUniversityDomains() {
    assertTrue(checker.isStudentEmail("pedro@ugr.es"));
    assertTrue(checker.isStudentEmail("lreilly@strath.ac.uk"));
    assertTrue(checker.isStudentEmail("lreilly@soft-eng.strath.ac.uk"));
  }

  @Test
  void acceptsFolioSpanishRegionalEducationDomains() {
    assertTrue(checker.isStudentEmail("alumno@educa.jcyl.es"));
    assertTrue(checker.isStudentEmail("a@alu.edu.gva.es"));
    assertTrue(checker.isStudentEmail("profe@centro.xtec.cat"));
    assertTrue(checker.isStudentEmail("u@g.educaand.es"));
  }

  @Test
  void rejectsConsumerAndUnknownDomains() {
    assertFalse(checker.isStudentEmail("lee@leerilly.net"));
    assertFalse(checker.isStudentEmail("user@gmail.com"));
    assertFalse(checker.isStudentEmail("not-an-email"));
  }

  @Test
  void rejectsSwotAbusedDomainsEvenIfTheyLookAcademic() {
    assertTrue(checker.isAbusedStudentDomain("mdx.ac"));
    assertFalse(checker.isStudentEmail("student@mdx.ac"));
    assertFalse(checker.isStudentEmail("student@campus.mdx.ac"));
  }

  @Test
  void acceptsFolioEsOverlayEvenWhenSwotListsDomainAsAbused() {
    // educa.jcyl.es is on JetBrains abused.txt but Folio allowlists it for institutes.
    assertTrue(checker.isAbusedStudentDomain("educa.jcyl.es"));
    assertTrue(checker.isStudentEmail("alumno@educa.jcyl.es"));
  }

  @Test
  void matchesExactAndSubdomainsOnly() {
    assertTrue(checker.matchesFolioSpanishEducationDomain("educa.jcyl.es"));
    assertTrue(checker.matchesFolioSpanishEducationDomain("mail.educa.jcyl.es"));
    assertFalse(checker.matchesFolioSpanishEducationDomain("jcyl.es"));
    assertFalse(checker.matchesFolioSpanishEducationDomain("gmail.com"));
  }
}
