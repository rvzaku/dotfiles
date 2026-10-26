#!/usr/bin/env bash
# Real built package behavior; no AXI backend/credential calls. Nix may fetch locked inputs.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
AXI_PACKAGE_DIR=${AXI_PACKAGE_DIR:-$(nix build "$ROOT#axi" --no-link --print-out-paths)}
export AXI_PACKAGE_DIR
for command in gh-axi chrome-devtools-axi lavish-axi quota-axi tasks-axi; do
  "$AXI_PACKAGE_DIR/bin/$command" --help >/dev/null
done
node --input-type=module <<'JS'
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require = createRequire(`${process.env.AXI_PACKAGE_DIR}/lib/axi/node_modules/quota-axi/package.json`);
const {encode, decode} = await import(require.resolve('@toon-format/toon'));
assert.equal(encode({ok:true,count:2}), 'ok: true\ncount: 2');
assert.deepEqual(decode('ok: true\ncount: 2'), {ok:true,count:2});
// Valid hostile-key input must be data, never an inherited prototype property.
const hostile = decode('__proto__:\n  polluted: true');
assert.equal(Object.getPrototypeOf(hostile), Object.prototype);
assert.equal(hostile.polluted, undefined);
assert.equal(Object.hasOwn(hostile, '__proto__'), true);
assert.equal({}.polluted, undefined);
console.log('ok - real AXI binaries start; quota TOON roundtrip and prototype-pollution control pass');
JS
