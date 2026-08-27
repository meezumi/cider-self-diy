// Extract an asar archive to a directory.
const asar = require('@electron/asar');
const [, , archive, dest] = process.argv;
asar.extractAll(archive, dest);
console.log(`extracted ${archive} -> ${dest}`);
