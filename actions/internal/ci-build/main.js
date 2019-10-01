const core = require('../../core.js');
const process = require('process');
const { spawn } = require('child_process');
const path = require('path')

const ci_path = path.join(__dirname, '../../..');

const stage = core.getInput('stage');
const stage_prefix = stage === '' ? '' : `stage.${stage}.`;

const nix = spawn('nix', [
  '--show-trace', '-L',
  'run', '-f', ci_path,
  `${stage_prefix}test`,
  '--arg', 'config', core.getInput('configPath'),
  '-c', 'ci-build',
], {
  env: Object.assign({}, process.env, {
    CI_PLATFORM: 'gh-actions',
  }),
  windowsHide: true,
  stdio: 'inherit',
});

nix.on('close', (code) => {
  process.exit(code);
});
