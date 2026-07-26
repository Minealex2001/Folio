const fs = require("fs");

// Usage: node scripts/generate_abused_domains.js [path-to-abused.txt]
// Source: https://github.com/JetBrains/swot/blob/master/lib/domains/abused.txt
const p = process.argv[2];
if (!p) {
  console.error(
    "Usage: node scripts/generate_abused_domains.js <path-to-abused.txt>"
  );
  process.exit(1);
}
const lines = fs
  .readFileSync(p, "utf8")
  .split(/\r?\n/)
  .map((s) => s.trim().toLowerCase())
  .filter(Boolean);
const body = lines.map((d) => JSON.stringify(d)).join(",\n  ");
const out =
  "/** Domains from JetBrains/swot lib/domains/abused.txt - rejected for student verification. */\n" +
  "export const SWOT_ABUSED_DOMAINS: ReadonlySet<string> = new Set([\n  " +
  body +
  ",\n]);\n";
fs.writeFileSync("src/swot_abused_domains.ts", out);
console.log("wrote", lines.length, "domains");
