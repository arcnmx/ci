const core = require('../../core.js');
const process = require('process');
const { spawn } = require('child_process');
const path = require('path')

const ci_root = path.resolve(path.join(__dirname, '../../..'));
const installer_script = path.join(ci_root, 'nix/tools/install.sh');

// provide <ci> and a fallback nixpkgs matching the version of nix installed
// TODO: option to turn this off?
let nix_path = core.getInput('nix-path').split(':').filter(p => p !== '');
nix_path = nix_path.concat([`ci=${ci_root}`]);
process.env['CI_NIX_PATH_NIXPKGS'] = '1'; // instruct script to add nixpkgs to NIX_PATH
// TODO: if (nix_path.filter(p => p.startsWith('ci=') || !p.includes('=')).length === 0) ?

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
