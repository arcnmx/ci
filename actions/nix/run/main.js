const core = require('../../core.js');
const process = require('process');
const { spawn } = require('child_process');
const path = require('path')
const fs = require('fs')

const file = core.getInput('file');
const quiet = core.getInput('quiet') !== 'false';
const nix_path = core.getInput('nix-path').split(':').filter(a => a !== '');
const ignore_exit = core.getInput('ignore-exit-code') !== 'false';
const stdout_path = core.getInput('stdout');
let command = core.getInput('command');
let cargs = core.getInput('args').split(' ');
let attrs = core.getInput('attrs').split(' ');
let options = core.getInput('options').split(' ');

if (options.length === 1) {
  options = options.filter(o => o !== '');
}

if (attrs.length === 1) {
  attrs = attrs.filter(a => a !== '');
}

if (cargs.length === 1) {
  cargs = cargs.filter(a => a !== '');
}

if (command === '' && cargs.length > 0) {
  command = cargs[0];
  cargs = cargs.splice(1);
}

let stdout;
if (stdout_path === '') {
  stdout = 'inherit';
} else {
  const fd = fs.openSync(stdout_path, 'w', 0o666); // TODO: append+mode options?
  stdout = fs.createWriteStream(stdout_path, {
    encoding: 'binary',
    fd: fd,
  });
}

const args = [
  'run',
].concat(quiet ? [] : ['-L', '--show-trace'])
  .concat(file !== '' ? ['-f', file] : [])
  .concat(attrs);

const builder = spawn('nix', args
  .concat(nix_path.map(p => ['-I', p]).flat())
  .concat(options)
  .concat(command !== '' ? ['-c', command] : [])
  .concat(cargs), {
  env: Object.assign({}, process.env, {
    CI_PLATFORM: 'gh-actions',
  }),
  windowsHide: true,
  stdio: [
    'inherit', // TODO: option to provide stdin?
    stdout,
    'inherit',
  ],
});

builder.on('close', (code) => {
  core.setOutput('exit-code', code);
  process.exit(ignore_exit ? 0 : code);
});
