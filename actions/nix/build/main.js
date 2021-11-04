const core = require('../../core.js');
const process = require('process');
const { spawn } = require('child_process');
const path = require('path')
const fs = require('fs')

const compat = path.resolve(path.join(__dirname, '../../../nix/compat.nix'));

const add_path = core.getInput('add-path') !== '';
const nix2 = core.getInput('nix2') !== 'false';
const quiet = core.getInput('quiet') !== 'false';
const nix_path = core.getInput('nix-path').split(':').filter(a => a !== '');
const nix_version = core.nix.version();
let file = core.getInput('file');
let attrs = core.getInput('attrs').split(' ');
let options = core.getInput('options').split(' ');
let out_link = core.getInput('out-link');

if (add_path && out_link === '') {
  do {
    out_link = `.ci-nix-bin/result-_${Math.random()}`; // make up a path :(
  } while (fs.existsSync(out_link));
}

if (options.length === 1) {
  options = options.filter(o => o !== '');
}

if (attrs.length === 1) {
  attrs = attrs.filter(a => a !== '');
}

file = core.nix.adjustFileAttrs(nix_version, file, attrs);

let args;
let no_link;
let arg0;
if (nix2) {
  arg0 = 'nix';
  no_link = '--no-link';
  args = [
    'build',
  ].concat(file !== '' ? ['-f', file] : [])
    .concat(quiet ? [] : ['-L', '--show-trace'])
    .concat(attrs);
} else {
  arg0 = 'nix-build';
  no_link = '--no-out-link';
  args = [
    file !== '' ? file : compat
  ].concat(attrs.map(attr => ['-A', attr]).flat())
    .concat(quiet ? ['-Q'] : []);
}

const builder = spawn(arg0, args
  .concat(nix_path.map(p => ['-I', p]).flat())
  .concat(out_link === '' ? [no_link] : ['-o', out_link])
  .concat(options), {
  env: Object.assign({}, process.env, {
    CI_PLATFORM: 'gh-actions',
  }),
  windowsHide: true,
  stdio: 'inherit',
});

builder.on('close', (code) => {
  if (code === 0 && add_path) {
    core.addPath(path.join(path.resolve(out_link), 'bin'));
    core.setOutput('out-link', out_link);
  }
  process.exit(code);
});
