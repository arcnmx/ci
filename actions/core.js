const process = require('process');
const os = require('os');

process.env['PWD'] = process.cwd();

function writeCommand(cmd) {
  process.stdout.write(cmd + os.EOL)
}

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
  writeCommand(`::add-path::${path}`);
  // TODO: modify process.env like @actions/core does?
};

exports.exportVariable = function(name, value) {
  writeCommand(`::set-env name=${name}::${value}`);
  // TODO: modify process.env like @actions/core does?
};

exports.getInput = function(name) {
  return (process.env[`INPUT_${name.toUpperCase()}`] || '').trim();
};
