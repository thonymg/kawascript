/**
 * run_showcase.js
 *
 * Compile un fichier showcase et affiche le JavaScript produit.
 *
 * Usage :
 *   node examples/run_showcase.js              → compile immutability_showcase.coffee  (futur)
 *   node examples/run_showcase.js baseline     → compile immutability_baseline.coffee  (actuel)
 */

const CoffeeScript = require('../lib/coffeescript');
const fs           = require('fs');
const path         = require('path');

const isBaseline = process.argv[2] === 'baseline';
const filename   = isBaseline
  ? 'immutability_baseline.coffee'
  : 'immutability_showcase.coffee';

const srcPath = path.join(__dirname, filename);
const src     = fs.readFileSync(srcPath, 'utf8');

const label   = isBaseline
  ? 'BASELINE (compilateur actuel — avant refactorisation)'
  : 'CIBLE (compilateur refactorisé — après implémentation)';

const divider = '═'.repeat(78);

console.log('\n' + divider);
console.log(` ${label}`);
console.log(` Fichier : ${filename}`);
console.log(divider + '\n');

try {
  const js = CoffeeScript.compile(src, { bare: true });
  console.log(js);
} catch (err) {
  console.error('Erreur de compilation :\n', err.message);
  process.exit(1);
}

console.log('\n' + divider + '\n');
