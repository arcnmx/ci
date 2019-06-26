[![ci-badge][]][ci]

Utilities and helper scripts for continuous integration.

# CI backends

## Travis CI

Add the following to your `.travis.yml` manifest:

```yaml
before_script:
    - curl -L https://github.com/arcnmx/ci/archive/master.tar.gz | tar -xzC $HOME && . $HOME/ci-master/src
```

# Languages

## Rust

Provides functionality similar to
[travis-cargo](https://github.com/huonw/travis-cargo).

### Features

- All cargo commands will run in verbose mode unless `$CARGO_QUIET` is set in
  the environment.
- A global `$CARGO_FEATURES` may be used to provide additional feature flags to
  all invocations of cargo.
- `cargo doc` will automatically use `--no-deps` unless `--deps` is provided.
- `$CARGO_TARGET_DIR` will be automatically set to a subdir of
  `$TRAVIS_BUILD_DIR/target`, hashed by the current rust version and cargo
  features. You may want to add this directory to the CI cache.
- `cargo publish` will automatically use the `$CRATES_IO_TOKEN` environment
  variable if it exists.

### Commands

- `cargo pages-publish` will automatically upload your generated docs to Github
  Pages. Requires a run of `cargo doc` beforehand. Must be passed an OAuth
  token as the first argument or via the `$GH_TOKEN` environment variable.

[ci-badge]: https://dev.azure.com/arcnmx/CI/_apis/build/status/ci?branchName=master
[ci]: https://dev.azure.com/arcnmx/CI/_build/latest?definitionId=4
