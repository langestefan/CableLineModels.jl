# CHANGELOG

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog],
and this project adheres to [Semantic Versioning].

## [Unreleased]

### Added

- `Material` type and a standard material library.
- `UnsupportedError` for valid but unsupported input combinations.
- Cable design types: conductor shapes, `Conductor`, layers, `CableCore`, `CableDesign`
  (`SingleCore`, `FourCoreLV`), with geometry validation.
- Cable system types: `PlacedCable`, `EarthModel`, installations (`DirectBuried`, `InDuct`),
  bonding (`BothEnds`, `SinglePoint`, `CrossBonded`), `Compensation` and `CableSystem`.
- Parameter interface: `ParameterMethod`, `IEC60287Method`, `LoopMethod`, `ZYData` and
  `compute_ZY`, with DC resistance and leakage conductance at `f = 0`.

<!-- Links -->

[keep a changelog]: https://keepachangelog.com/en/1.1.0/
[semantic versioning]: https://semver.org/spec/v2.0.0.html

<!-- Versions -->

[unreleased]: https://github.com/langestefan/CableLineModels.jl/compare/v0.1.0...HEAD
