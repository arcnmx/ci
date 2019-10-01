const core = require('../../core.js');
const process = require('process');
const { spawn } = require('child_process');
const path = require('path')

const ci_path = path.join(__dirname, '../../..');
const ci_env = '/nix/var/ci-source';

const stage = core.getInput('stage');
const stage_prefix = stage === '' ? '' : `stage.${stage}.`;

const nix = spawn('nix', [
  '--show-trace', '-L',
  'run', '-f', ci_path,
  `${stage_prefix}environment`,
  '--arg', 'config', core.getInput('configPath'),
  '-c', 'ci-setup',
], {
  env: Object.assign({}, process.env, {
    CI_PLATFORM: 'gh-actions',
    CI_ENV: ci_env,
  }),
  windowsHide: true,
  stdio: 'inherit',
});
core.exportVariable('BASH_ENV', `${ci_env}/${core.getInput('prefix')}/source`);

nix.on('close', (code) => {
  process.exit(code);
});

const timeout = core.getInput('timeout');
if (timeout !== '') {
  setTimeout(() => {
    core.error('nix action timed out');
    process.exit(1);
  }, timeout * 60 * 1000);
}
