const process = require('process');
const os = require('os');
const fs = require('fs');
const crypto = require("crypto");
const { spawnSync } = require('child_process');

const envfile = process.env['GITHUB_ENV'];
const pathfile = process.env['GITHUB_PATH'];
const delim = crypto.randomBytes(32).toString('hex');

process.env['PWD'] = process.cwd();

function writeCommand(cmd) {
  // https://github.com/actions/runner/blob/6bec1e3bb832aad26f4ad5b64759a8e4d468df24/src/Runner.Common/ActionCommand.cs
  process.stdout.write(`${cmd}${os.EOL}`)
}

// Available actions:
// https://docs.github.com/en/free-pro-team@latest/actions/reference/workflow-commands-for-github-actions
// https://github.com/actions/runner/blob/6bec1e3bb832aad26f4ad5b64759a8e4d468df24/src/Runner.Worker/ActionCommandManager.cs

exports.error = function(msg) {
  writeCommand(`::error::${msg}`);
};

exports.warning = function(msg) {
  writeCommand(`::warning::${msg}`);
};

exports.setOutput = function(name, value) {
  writeCommand(`::set-output name=${name}::${value}`);
};

exports.addPath = function(path) {
  if (pathfile) {
    fs.appendFileSync(pathfile, `${path}${os.EOL}`);
  } else {
    writeCommand(`::add-path::${path}`);
  }
  // TODO: modify process.env like @actions/core does?
};

exports.exportVariable = function(name, value) {
  if (envfile) {
    fs.appendFileSync(envfile, `${name}<<${delim}${os.EOL}${value}${os.EOL}${delim}`);
  } else {
    writeCommand(`::set-env name=${name}::${value}`);
  }
  // TODO: modify process.env like @actions/core does?
};

exports.getInput = function(name) {
  return (process.env[`INPUT_${name.toUpperCase()}`] || '').trim();
};

exports.nix = { };
exports.nix.version = function() {
  const env_ver = process.env['NIX_VERSION'];
  if (env_ver) {
    return env_ver;
  } else {
    const res = spawnSync('nix', ['--version'], {
      windowsHide: true,
      stdio: [
        'ignore',
        'pipe',
        'inherit',
      ],
    });
    if (res.error) {
      throw res.error;
    } else {
      const stdout = res.stdout.split(' ');
      if (stdout[0] === 'nix') {
        return stdout[2].trimRight();
      } else {
        exports.error(`Unexpected nix --version output: ${res.stdout}`);
        throw 'unexpected';
      }
    }
  }
};

exports.nix.versionIs24 = function(version) {
  return version.startsWith('2.4');
}

exports.nix.adjustFileAttrs = function(version, file, attrs) {
  if (file === '' && exports.nix.versionIs24(version)) {
    // compatibility from nix <2.4
    attrs.forEach(function(attr, index) {
      if (attr.includes('#')) {
        return; // assume flake reference
      }

      const attr_split = attr.split('.');
      let [ first ] = attr_split.splice(0, 1);
      first = `<${first}>`;
      if (file === '') {
        file = first;
      } else if (file !== first) {
        exports.error(`cannot find common base with ${file} in ${attr}`);
        return; // let nix deal with it
      }
      this[index] = attr_split.join('.');
    }, attrs);
  }

  return file;
}
