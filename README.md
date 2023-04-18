# ci

[![ci-badge][]][ci] [![docs-badge][]][docs]

A configurable continuous integration and testing system built on top of nix and
the NixOS module system.


## Getting Started

See the proper [documentation page][docs] for a full description.


### Quick Sample

With [nix](https://nixos.org/nix/) installed...

```bash
export NIX_PATH=ci=https://github.com/arcnmx/ci/archive/v0.5.tar.gz
nix run --arg config '<ci/examples/ci.nix>' -f '<ci>' test
```


### Provider Support

Though a simple command like the above can be run on any machine or CI service,
automated configuration generators and full support for job descriptions and
integrated features such as matrix builds are currently supported for:

- [GitHub Actions](https://github.com/features/actions)


[ci-badge]: https://github.com/arcnmx/ci/workflows/tests-tasks/badge.svg
[ci]: https://github.com/arcnmx/ci/actions
[docs-badge]: https://img.shields.io/badge/API-docs-blue.svg?style=flat-square
[docs]: https://arcnmx.github.io/ci
