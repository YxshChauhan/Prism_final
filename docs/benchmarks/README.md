# Benchmarks

## Overview

This directory stores benchmark methodology, raw results, and generated reports for cross‑platform file transfers.

## Test Environment

- Devices: Document device models used
- OS Versions: iOS/Android versions tested
- Network Conditions: Proximity, interference, background load
- Configurations: Transport method, chunk size, encryption settings

## Benchmark Results

- Results will be saved as JSON and CSV per run
- Summary tables will be maintained here with links to raw data

## File Organization

- JSON files: `<date>_<scenario>.json`
- CSV files: `<date>_<scenario>.csv`
- Report: `<date>_report.md`

### JSON/CSV Schema

- Fields: fileSize, durationMs, speedMBps, connectionSetupMs, handshakeMs, success, error

## How to Run Benchmarks

1. Execute integration tests:
```
flutter test test/integration/cross_platform_benchmark_test.dart
```
2. Generated outputs will be written to this directory

## Performance Targets

- Target speeds up to 100 MB/s over Wi‑Fi Direct (to be validated)
- Reasonable latency and stable throughput across transports

## Known Limitations

- Results depend on device hardware and environment
- iOS↔Android performance still being collected

## Placeholder

Benchmark data will be populated after running tests created in `cross_platform_benchmark_test.dart`.


