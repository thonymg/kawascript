const CoffeeScript = require('./lib/coffeescript');
const fs = require('fs');
const assert = require('assert');
const helpers = require('./test/support/helpers');

global.CoffeeScript = CoffeeScript;
global.passedTests = 0;
global.failures = [];
global.currentFile = 'test/pipe_operator.coffee';

Object.keys(assert).forEach(name => { if (typeof assert[name] === 'function') global[name] = assert[name]; });

global.test = (description, fn) => {
  try {
    fn();
    passedTests++;
    process.stdout.write('✓ ' + description + '\n');
  } catch(err) {
    failures.push({description, error: err});
    process.stdout.write('✗ ' + description + ' -> ' + err.message + '\n');
  }
};

Object.assign(global, helpers);

const code = fs.readFileSync('test/pipe_operator.coffee');
CoffeeScript.run(code.toString(), {filename: 'test/pipe_operator.coffee'});

console.log('\nTotal: ' + passedTests + ' passed, ' + failures.length + ' failed');
