const core = require('../../core.js');
const process = require('process');
const { spawn } = require('child_process');
const path = require('path')

const ci_root = path.resolve(path.join(__dirname, '../../..'));
const installer_script = path.join(ci_root, 'actions/nix/install/script.sh');

const installer = spawn('bash', [installer_script], {
  env: Object.assign({}, process.env, {
    CI_PLATFORM: 'gh-actions',
    CI_ROOT: ci_root,
    NIX_VERSION: core.getInput('version'),
    NIX_PATH: nix_path.join(':'),
  }),
  windowsHide: true,
  stdio: 'inherit',
});

installer.on('close', (code) => {
  if (code === 0) {
  }
  process.exit(code);
});

const timeout = core.getInput('timeout');
if (timeout !== '') {
  setTimeout(() => {
    core.error('Nix installer timed out');
    process.exit(1);
  }, timeout * 60 * 1000);
}
