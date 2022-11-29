# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2022-11-28
### Changed
- hidden commands are configured by setting `hidden: true` on the command, instead of listing them with `hide: [:commands, :to, :hide]`
- commands can be either an atom, a string, or a keyword list
- `no_args_command` renamed to `default_command`
- ensure no unused variables in Zig code

## [0.1.0] - 2022-03-17
### Added
- generate an executable and dotenv files for a Mix Release instead of `bat`/`sh` scripts.

[Unreleased]: https://github.com/simonmcconnell/relexe/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/simonmcconnell/relexe/releases/tag/v0.2.0
[0.1.0]: https://github.com/simonmcconnell/relexe/releases/tag/v0.1.0
