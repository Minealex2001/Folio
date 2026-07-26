/**
 * Student / academic email verification for Folio Cloud student pricing.
 *
 * Uses JetBrains SWOT (via swot-node) for worldwide higher-education domains,
 * plus a Folio overlay for Spanish regional non-university education mail
 * (institutos / FP via consejerias). Abused SWOT domains are always rejected.
 */
import { isAcademic } from "swot-node";
import { SWOT_ABUSED_DOMAINS } from "./swot_abused_domains";

/** Regional education mail domains used by Spanish IES / non-uni centres. */
export const FOLIO_SPANISH_EDUCATION_DOMAINS: ReadonlySet<string> = new Set([
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
  "edu.juntaex.es",
]);

/** True if domain or any parent suffix is in the set (e.g. a.b.edu matches b.edu). */
export function domainOrParentInSet(
  domain: string,
  set: ReadonlySet<string>
): boolean {
  let d = domain.toLowerCase();
  while (d) {
    if (set.has(d)) return true;
    const i = d.indexOf(".");
    if (i < 0) return false;
    d = d.slice(i + 1);
  }
  return false;
}

export function extractEmailDomain(email: string): string {
  const trimmed = email.trim().toLowerCase();
  const at = trimmed.lastIndexOf("@");
  if (at < 0) return trimmed;
  return trimmed.slice(at + 1);
}

export function isAbusedStudentDomain(domain: string): boolean {
  return domainOrParentInSet(domain, SWOT_ABUSED_DOMAINS);
}

export function matchesFolioSpanishEducationDomain(domain: string): boolean {
  return domainOrParentInSet(domain, FOLIO_SPANISH_EDUCATION_DOMAINS);
}

/**
 * Returns true if the address qualifies for the Folio Cloud student rate.
 * Does not prove mailbox ownership — domain policy only.
 *
 * Folio Spanish education domains are checked before SWOT abused, because some
 * regional education mail domains appear on JetBrains' abused list (they are
 * still intentional for Folio institute pricing).
 */
export async function isStudentEmail(email: string): Promise<boolean> {
  const domain = extractEmailDomain(email);
  if (!domain || !domain.includes(".")) return false;
  if (matchesFolioSpanishEducationDomain(domain)) return true;
  if (isAbusedStudentDomain(domain)) return false;
  try {
    return Boolean(await isAcademic(email.trim().toLowerCase()));
  } catch {
    return false;
  }
}
