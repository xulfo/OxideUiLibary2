// ══════════════════════════════════════════════════════════════════
// encrypt.js — UI Library verschlüsseln (XOR + Base64)
// BENUTZUNG:  node encrypt.js
// AUSGABE:    lib.enc  → verschlüsselter Blob (Codeberg hochladen)
// KEY / AUTH über Umgebungsvariablen: LIB_KEY=... LIB_AUTH=... node encrypt.js
// ══════════════════════════════════════════════════════════════════

const fs = require("fs");
const path = require("path");

const LIB_PATH = path.join(__dirname, process.env.LIB_SOURCE || "Libary.lua");
const OUT_ENC   = path.join(__dirname, process.env.LIB_OUTPUT || "lib.enc");

const KEY  = process.env.LIB_KEY  || "Buffy-Lib-2026-XyZ!";
const AUTH = process.env.LIB_AUTH || "UltraGeheim42";

function xor(buf, key) {
    const out = Buffer.alloc(buf.length);
    for (let i = 0; i < buf.length; i++) {
        out[i] = buf[i] ^ key.charCodeAt(i % key.length);
    }
    return out;
}

let src = fs.readFileSync(LIB_PATH, "utf8").replace(/^\uFEFF/, "");
const buf = Buffer.from(src, "utf8");
const b64 = xor(buf, KEY).toString("base64");

// round-trip verify
const back = xor(Buffer.from(b64, "base64"), KEY).toString("utf8");
if (back !== src) { console.error("VERIFY FAILED"); process.exit(1); }

fs.writeFileSync(OUT_ENC, b64);

console.log("✔ OK! " + src.length + " Bytes → " + b64.length + " Zeichen Base64");
console.log("  " + path.basename(OUT_ENC));
console.log("  KEY : " + KEY);
console.log("  AUTH: " + AUTH);
console.log(`→ ${path.basename(OUT_ENC)} is ready; deploy it only through the matching loader path.`);
