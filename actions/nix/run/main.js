const core = require('../../core.js');
const process = require('process');
const { spawn } = require('child_process');
const path = require('path')
const fs = require('fs')

const quiet = core.getInput('quiet') !== 'false';
const nix_path = core.getInput('nix-path').split(':').filter(a => a !== '');
const ignore_exit = core.getInput('ignore-exit-code') !== 'false';
const stdout_path = core.getInput('stdout');
const stdin_path = core.getInput('stdin');
const nix_version = core.nix.version();
const nix2_4 = core.nix.versionIs24(nix_version);
let file = core.getInput('file');
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

file = core.nix.adjustFileAttrs(nix_version, file, attrs);

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

let stdin;
if (stdin_path === '') {
  stdin = 'inherit';
} else {
  const fd = fs.openSync(stdin_path, 'r');
  stdin = fs.createReadStream(stdin_path, {
    encoding: 'binary',
    fd: fd,
  });
}

let cmd = 'run';
if (nix2_4 && command !== '') {
  cmd = 'shell';
}

let args = [
  cmd,
].concat(quiet ? [] : ['-L', '--show-trace'])
  .concat(file !== '' ? ['-f', file] : [])
  .concat(attrs)
  .concat(nix_path.map(p => ['-I', p]).flat())
  .concat(options);

if (cmd === 'shell' || !nix2_4) {
  if (command !== '' || cargs.length > 0) {
    if (command === '') {
      command = 'bash';
    }
    args = args.concat(['-c', command]).concat(cargs);
  }
} else if (cargs.length > 0) {
  args = args.concat(['--']).concat(cargs);
}

const builder = spawn('nix', args, {
  env: Object.assign({}, process.env, {
    CI_PLATFORM: 'gh-actions',
  }),
  windowsHide: true,
  stdio: [
    stdin,
    stdout,
    'inherit',
  ],
});

builder.on('close', (code) => {
  core.setOutput('exit-code', code);
  process.exit(ignore_exit ? 0 : code);
});
