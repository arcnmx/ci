const core = require('../../core.js');
const process = require('process');
const { spawn } = require('child_process');
const path = require('path')

const ci_path = path.resolve(path.join(__dirname, '../../..'));
const installer_script = path.join(ci_path, 'nix/tools/install.sh');

const installer = spawn('bash', [installer_script], {
  env: Object.assign({}, process.env, {
    CI_PLATFORM: 'gh-actions',
    NIX_VERSION: core.getInput('version'),
  }),
  windowsHide: true,
  stdio: 'inherit',
});

installer.on('close', (code) => {
  if (code === 0) {
    // TODO: option to turn this off?
    let nix_path = core.getInput('nix-path').split(':').filter(p => p !== '');
    if (nix_path.filter(p => p.startsWith('nixpkgs=') || !p.includes('=')).length === 0) {
      // provide a fallback nixpkgs matching the version of nix installed
      nix_path = nix_path.concat([`nixpkgs=${ci_path}/nix/pkgs.nix`]);
    }
    if (nix_path.filter(p => p.startsWith('ci=') || !p.includes('=')).length === 0) {
      nix_path = nix_path.concat([`ci=${ci_path}`]);
    }
    if (nix_path.length > 0) {
      core.exportVariable('NIX_PATH', nix_path.join(':'));
    }
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
