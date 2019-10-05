const core = require('../../core.js');
const process = require('process');
const { spawn } = require('child_process');
const path = require('path')

const ci_path = path.join(__dirname, '../../..');

const stage = core.getInput('stage');
const job = core.getInput('job');
const stage_prefix = stage === '' ? '' : `stage.${stage}.`;
const job_prefix = job === '' ? '' : `job.${job}.`;

const nix = spawn('nix', [
  '--show-trace', '-L',
  'run', `ci.${stage_prefix}test`,
  '--arg', 'config', core.getInput('configPath'),
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
