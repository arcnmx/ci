const process = require('process');
const os = require('os');
const fs = require('fs');
const crypto = require("crypto");

const envfile = process.env['GITHUB_ENV'];
const pathfile = process.env['GITHUB_PATH'];
const outputfile = process.env['GITHUB_OUTPUT'];
const statefile = process.env['GITHUB_STATE'];
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
  if (outputfile) {
    fs.appendFileSync(outputfile, `${name}=${value}${os.EOL}`);
  } else {
    writeCommand(`::set-output name=${name}::${value}`);
  }
};

exports.saveState = function(name, value) {
  fs.appendFileSync(statefile, `${name}=${value}${os.EOL}`);
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
