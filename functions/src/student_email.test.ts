import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  isAbusedStudentDomain,
  isStudentEmail,
  matchesFolioSpanishEducationDomain,
} from "./student_email";

describe("isStudentEmail", () => {
  it("accepts known SWOT university domains", async () => {
    assert.equal(await isStudentEmail("pedro@ugr.es"), true);
    assert.equal(await isStudentEmail("lreilly@strath.ac.uk"), true);
    assert.equal(await isStudentEmail("lreilly@soft-eng.strath.ac.uk"), true);
  });

  it("accepts Folio Spanish regional education domains", async () => {
    assert.equal(await isStudentEmail("alumno@educa.jcyl.es"), true);
    assert.equal(await isStudentEmail("a@alu.edu.gva.es"), true);
    assert.equal(await isStudentEmail("profe@centro.xtec.cat"), true);
    assert.equal(await isStudentEmail("u@g.educaand.es"), true);
  });

  it("rejects consumer and unknown domains", async () => {
    assert.equal(await isStudentEmail("lee@leerilly.net"), false);
    assert.equal(await isStudentEmail("user@gmail.com"), false);
    assert.equal(await isStudentEmail("not-an-email"), false);
  });

  it("rejects SWOT abused domains even if they look academic", async () => {
    assert.equal(isAbusedStudentDomain("mdx.ac"), true);
    assert.equal(await isStudentEmail("student@mdx.ac"), false);
    assert.equal(await isStudentEmail("student@campus.mdx.ac"), false);
  });

  it("accepts Folio ES overlay even when SWOT lists the domain as abused", async () => {
    // educa.jcyl.es is on JetBrains abused.txt but Folio allowlists it for institutes.
    assert.equal(isAbusedStudentDomain("educa.jcyl.es"), true);
    assert.equal(await isStudentEmail("alumno@educa.jcyl.es"), true);
  });
});

describe("matchesFolioSpanishEducationDomain", () => {
  it("matches exact and subdomains only", () => {
    assert.equal(matchesFolioSpanishEducationDomain("educa.jcyl.es"), true);
    assert.equal(matchesFolioSpanishEducationDomain("mail.educa.jcyl.es"), true);
    assert.equal(matchesFolioSpanishEducationDomain("jcyl.es"), false);
    assert.equal(matchesFolioSpanishEducationDomain("gmail.com"), false);
  });
});
