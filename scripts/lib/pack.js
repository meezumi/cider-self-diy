// Repack a directory into an asar archive.
//
// unpackDir MUST keep these three modules outside the archive: they contain
// native .node binaries, which cannot be dlopen'd from inside an asar.
// The '**/' prefix is required by @electron/asar v4 -- without it the glob
// matches almost nothing, silently packs the native modules in, and STILL
// EXITS 0. That failure breaks AirPlay at runtime, not at build time.
const asar = require('@electron/asar');
const [, , src, out] = process.argv;
asar
  .createPackageWithOptions(src, out, {
    unpackDir: '**/node_modules/{wallpaper,airtunes2,abstract-socket}',
  })
  .then(() => console.log(`packed ${src} -> ${out}`))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
