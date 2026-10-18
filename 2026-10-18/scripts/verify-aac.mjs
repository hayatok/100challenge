import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';

const app = new URL('../', import.meta.url);
const provenance = JSON.parse(readFileSync(new URL('public/licenses/aac-rebuild/provenance.json', app), 'utf8'));
const digest = value => createHash('sha256').update(value).digest('hex');
for (const [name, expected] of Object.entries(provenance.files)) {
  const actual = digest(readFileSync(new URL(name, app)));
  if (actual !== expected) throw new Error(`AAC source/build file differs from provenance: ${name}`);
}
const installed = readFileSync(fileURLToPath(import.meta.resolve('@mediabunny/aac-encoder')), 'utf8');
if (digest(installed) !== provenance.files['vendor/aac-encoder/index.mjs']) {
  throw new Error('Installed AAC encoder differs from the pinned local build. Run npm ci.');
}

// The upstream inlined worker contains Emscripten's encoded binary string.
const wasmDigests = new Set();
function scan(code, depth = 0) {
  const source = ts.createSourceFile('encoder.js', code, ts.ScriptTarget.Latest, true, ts.ScriptKind.JS);
  function visit(node) {
    if (ts.isStringLiteralLike(node) && node.text.length > 1000) {
      const value = node.text;
      const bytes = Uint8Array.from({ length: value.length }, (_, index) => {
        const charCode = value.charCodeAt(index);
        return (~charCode >> 8) & charCode;
      });
      if (bytes[0] === 0 && bytes[1] === 97 && bytes[2] === 115 && bytes[3] === 109) {
        wasmDigests.add(digest(bytes));
      } else if (depth < 3 && value.includes('WebAssembly')) scan(value, depth + 1);
    }
    ts.forEachChild(node, visit);
  }
  visit(source);
}
scan(installed);
if (wasmDigests.size !== 1 || !wasmDigests.has(provenance.wasmSha256)) {
  throw new Error(`AAC embedded WASM does not match the source build: ${[...wasmDigests]}`);
}
console.log(`AAC source archives, installed wrapper and embedded WASM match ${provenance.ffmpegCommit}.`);
