// Deep-compare two asar archives: entry listing, then every packed file byte
// for byte. This is the check that catches a repack which "succeeded" but
// quietly dropped or absorbed files.
const asar = require('@electron/asar');
// disk.js is not listed in the package's "exports", so resolve it by path
// off the resolved entry point rather than by subpath specifier.
const path = require('path');
const { readFilesystemSync } = require(path.join(path.dirname(require.resolve('@electron/asar')), 'disk.js'));

function listing(archive) {
  const fs = readFilesystemSync(archive);
  const rows = [];
  (function walk(node, prefix) {
    for (const [name, entry] of Object.entries(node.files || {})) {
      const full = `${prefix}/${name}`;
      if (entry.files) walk(entry, full);
      else {
        const size = entry.size === undefined ? `LINK:${entry.link}` : entry.size;
        rows.push(`${full}\t${size}\t${entry.unpacked ? 'U' : 'P'}`);
      }
    }
  })(fs.header, '');
  return rows.sort();
}

const [, , a, b] = process.argv;
const la = listing(a);
const lb = listing(b);
console.log(`entries: ${a}=${la.length}  ${b}=${lb.length}`);

const sa = new Set(la);
const sb = new Set(lb);
const onlyA = la.filter((r) => !sb.has(r));
const onlyB = lb.filter((r) => !sa.has(r));
if (onlyA.length || onlyB.length) {
  console.log(`listing differences: ${onlyA.length + onlyB.length} line(s)`);
  onlyA.slice(0, 20).forEach((r) => console.log(`  only in ${a}: ${r}`));
  onlyB.slice(0, 20).forEach((r) => console.log(`  only in ${b}: ${r}`));
}

const packed = la.filter((r) => r.split('\t')[2] === 'P').map((r) => r.split('\t')[0]);
const differing = [];
let errors = 0;
for (const p of packed) {
  let bufA, bufB;
  try {
    bufA = asar.extractFile(a, p.slice(1));
    bufB = asar.extractFile(b, p.slice(1));
  } catch (e) {
    errors++;
    continue;
  }
  if (!bufA.equals(bufB)) differing.push(p);
}
console.log(`packed files compared: ${packed.length}   read errors: ${errors}`);
console.log(`differing: ${differing.length}`);
differing.forEach((d) => console.log(`   ${d}`));
