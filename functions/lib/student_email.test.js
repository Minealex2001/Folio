"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = require("node:test");
const student_email_1 = require("./student_email");
(0, node_test_1.describe)("isStudentEmail", () => {
    (0, node_test_1.it)("accepts known SWOT university domains", async () => {
        strict_1.default.equal(await (0, student_email_1.isStudentEmail)("pedro@ugr.es"), true);
        strict_1.default.equal(await (0, student_email_1.isStudentEmail)("lreilly@strath.ac.uk"), true);
        strict_1.default.equal(await (0, student_email_1.isStudentEmail)("lreilly@soft-eng.strath.ac.uk"), true);
    });
    (0, node_test_1.it)("accepts Folio Spanish regional education domains", async () => {
        strict_1.default.equal(await (0, student_email_1.isStudentEmail)("alumno@educa.jcyl.es"), true);
        strict_1.default.equal(await (0, student_email_1.isStudentEmail)("a@alu.edu.gva.es"), true);
        strict_1.default.equal(await (0, student_email_1.isStudentEmail)("profe@centro.xtec.cat"), true);
        strict_1.default.equal(await (0, student_email_1.isStudentEmail)("u@g.educaand.es"), true);
    });
    (0, node_test_1.it)("rejects consumer and unknown domains", async () => {
        strict_1.default.equal(await (0, student_email_1.isStudentEmail)("lee@leerilly.net"), false);
        strict_1.default.equal(await (0, student_email_1.isStudentEmail)("user@gmail.com"), false);
        strict_1.default.equal(await (0, student_email_1.isStudentEmail)("not-an-email"), false);
    });
    (0, node_test_1.it)("rejects SWOT abused domains even if they look academic", async () => {
        strict_1.default.equal((0, student_email_1.isAbusedStudentDomain)("mdx.ac"), true);
        strict_1.default.equal(await (0, student_email_1.isStudentEmail)("student@mdx.ac"), false);
        strict_1.default.equal(await (0, student_email_1.isStudentEmail)("student@campus.mdx.ac"), false);
    });
    (0, node_test_1.it)("accepts Folio ES overlay even when SWOT lists the domain as abused", async () => {
        // educa.jcyl.es is on JetBrains abused.txt but Folio allowlists it for institutes.
        strict_1.default.equal((0, student_email_1.isAbusedStudentDomain)("educa.jcyl.es"), true);
        strict_1.default.equal(await (0, student_email_1.isStudentEmail)("alumno@educa.jcyl.es"), true);
    });
});
(0, node_test_1.describe)("matchesFolioSpanishEducationDomain", () => {
    (0, node_test_1.it)("matches exact and subdomains only", () => {
        strict_1.default.equal((0, student_email_1.matchesFolioSpanishEducationDomain)("educa.jcyl.es"), true);
        strict_1.default.equal((0, student_email_1.matchesFolioSpanishEducationDomain)("mail.educa.jcyl.es"), true);
        strict_1.default.equal((0, student_email_1.matchesFolioSpanishEducationDomain)("jcyl.es"), false);
        strict_1.default.equal((0, student_email_1.matchesFolioSpanishEducationDomain)("gmail.com"), false);
    });
});
//# sourceMappingURL=student_email.test.js.map