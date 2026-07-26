"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.FOLIO_SPANISH_EDUCATION_DOMAINS = void 0;
exports.domainOrParentInSet = domainOrParentInSet;
exports.extractEmailDomain = extractEmailDomain;
exports.isAbusedStudentDomain = isAbusedStudentDomain;
exports.matchesFolioSpanishEducationDomain = matchesFolioSpanishEducationDomain;
exports.isStudentEmail = isStudentEmail;
/**
 * Student / academic email verification for Folio Cloud student pricing.
 *
 * Uses JetBrains SWOT (via swot-node) for worldwide higher-education domains,
 * plus a Folio overlay for Spanish regional non-university education mail
 * (institutos / FP via consejerias). Abused SWOT domains are always rejected.
 */
const swot_node_1 = require("swot-node");
const swot_abused_domains_1 = require("./swot_abused_domains");
/** Regional education mail domains used by Spanish IES / non-uni centres. */
exports.FOLIO_SPANISH_EDUCATION_DOMAINS = new Set([
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
function domainOrParentInSet(domain, set) {
    let d = domain.toLowerCase();
    while (d) {
        if (set.has(d))
            return true;
        const i = d.indexOf(".");
        if (i < 0)
            return false;
        d = d.slice(i + 1);
    }
    return false;
}
function extractEmailDomain(email) {
    const trimmed = email.trim().toLowerCase();
    const at = trimmed.lastIndexOf("@");
    if (at < 0)
        return trimmed;
    return trimmed.slice(at + 1);
}
function isAbusedStudentDomain(domain) {
    return domainOrParentInSet(domain, swot_abused_domains_1.SWOT_ABUSED_DOMAINS);
}
function matchesFolioSpanishEducationDomain(domain) {
    return domainOrParentInSet(domain, exports.FOLIO_SPANISH_EDUCATION_DOMAINS);
}
/**
 * Returns true if the address qualifies for the Folio Cloud student rate.
 * Does not prove mailbox ownership — domain policy only.
 *
 * Folio Spanish education domains are checked before SWOT abused, because some
 * regional education mail domains appear on JetBrains' abused list (they are
 * still intentional for Folio institute pricing).
 */
async function isStudentEmail(email) {
    const domain = extractEmailDomain(email);
    if (!domain || !domain.includes("."))
        return false;
    if (matchesFolioSpanishEducationDomain(domain))
        return true;
    if (isAbusedStudentDomain(domain))
        return false;
    try {
        return Boolean(await (0, swot_node_1.isAcademic)(email.trim().toLowerCase()));
    }
    catch {
        return false;
    }
}
//# sourceMappingURL=student_email.js.map