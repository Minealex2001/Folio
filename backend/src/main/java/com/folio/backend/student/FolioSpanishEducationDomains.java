package com.folio.backend.student;

import java.util.Collections;
import java.util.Set;

/** Regional education mail domains used by Spanish IES / non-uni centres. */
public final class FolioSpanishEducationDomains {

  private FolioSpanishEducationDomains() {}

  public static final Set<String> DOMAINS =
      Collections.unmodifiableSet(
          Set.of(
              "educa.jcyl.es",
              "edu.gva.es",
              "alu.edu.gva.es",
              "g.educaand.es",
              "educaand.es",
              "xtec.cat",
              "edu.xunta.gal",
              "educacion.navarra.es",
              "educa.madrid.org",
              "educarioja.org",
              "educantabria.es",
              "educastur.es",
              "murciaeduca.es",
              "educa.jccm.es",
              "edu.juntaex.es"));
}
