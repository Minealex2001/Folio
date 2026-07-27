package com.folio.backend.student;

import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/**
 * Student / academic email verification for Folio Cloud student pricing.
 *
 * <p>Ports {@code functions/src/student_email.ts}: Folio Spanish education overlay, SWOT abused
 * rejection, then academic-domain heuristics (SWOT-compatible for common university TLDs).
 */
@Component
public class StudentEmailChecker {

  private static final Pattern AC_TLD = Pattern.compile(".*\\.ac\\.[a-z]{2}(\\.[a-z]{2})?$");

  /**
   * Free-text academic stems from JetBrains SWOT used by the original suite (plus common ES
   * universities). Parent-suffix matching applies (e.g. {@code mail.ugr.es}).
   */
  private static final Set<String> ACADEMIC_STEMS =
      Set.of(
          "ugr.es",
          "strath.ac.uk",
          "uam.es",
          "ucm.es",
          "upv.es",
          "upc.edu",
          "ub.edu",
          "uv.es",
          "usal.es",
          "unican.es",
          "us.es",
          "uva.es",
          "unizar.es",
          "um.es",
          "ull.es",
          "ulpgc.es",
          "uhu.es",
          "ujaen.es",
          "uco.es",
          "uca.es",
          "ual.es",
          "umh.es",
          "urjc.es",
          "uah.es",
          "unileon.es",
          "uniovi.es",
          "usc.es",
          "uvigo.es",
          "udc.es");

  /** True if domain or any parent suffix is in the set (e.g. a.b.edu matches b.edu). */
  public static boolean domainOrParentInSet(String domain, Set<String> set) {
    String d = domain.toLowerCase(Locale.ROOT);
    while (!d.isEmpty()) {
      if (set.contains(d)) {
        return true;
      }
      int i = d.indexOf('.');
      if (i < 0) {
        return false;
      }
      d = d.substring(i + 1);
    }
    return false;
  }

  public static String extractEmailDomain(String email) {
    String trimmed = email.trim().toLowerCase(Locale.ROOT);
    int at = trimmed.lastIndexOf('@');
    if (at < 0) {
      return trimmed;
    }
    return trimmed.substring(at + 1);
  }

  public boolean isAbusedStudentDomain(String domain) {
    return domainOrParentInSet(domain, AbusedEmailDomains.DOMAINS);
  }

  public boolean matchesFolioSpanishEducationDomain(String domain) {
    return domainOrParentInSet(domain, FolioSpanishEducationDomains.DOMAINS);
  }

  /**
   * Returns true if the address qualifies for the Folio Cloud student rate. Does not prove mailbox
   * ownership — domain policy only.
   *
   * <p>Folio Spanish education domains are checked before SWOT abused, because some regional
   * education mail domains appear on JetBrains' abused list (they are still intentional for Folio
   * institute pricing).
   */
  public boolean isStudentEmail(String email) {
    String domain = extractEmailDomain(email);
    if (domain.isEmpty() || !domain.contains(".")) {
      return false;
    }
    if (matchesFolioSpanishEducationDomain(domain)) {
      return true;
    }
    if (isAbusedStudentDomain(domain)) {
      return false;
    }
    try {
      return isAcademicDomain(domain);
    } catch (RuntimeException e) {
      return false;
    }
  }

  private boolean isAcademicDomain(String domain) {
    String d = domain.toLowerCase(Locale.ROOT);
    if (d.endsWith(".edu") || d.contains(".edu.")) {
      return true;
    }
    if (AC_TLD.matcher(d).matches()) {
      return true;
    }
    return domainOrParentInSet(d, ACADEMIC_STEMS);
  }
}
