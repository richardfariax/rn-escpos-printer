# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2026-08-25

### Added

- Added PC860 Portuguese text encoding on iOS and Android through `codePage: 'cp860'` and the standard ESC/POS character table 3.

### Tests

- Added native golden-byte coverage for Portuguese receipt text, including `Não`, `RAZÃO`, `ORÇAMENTO`, `ação`, `café`, and `preço`.

## [1.0.1] - 2026-08-25

### Fixed

- Corrected iOS raster row orientation so base64 images print from the document top without mirroring or vertical inversion.

### Tests

- Added native iOS coverage for top-left pixel placement, 24-dot ESC/POS golden bytes, 384/576-pixel paper widths, raw base64, and data URIs.

## [1.0.0] - 2026-08-24

### Added

- ESC/POS Bluetooth Classic transport for paired Android printers.
- Generic BLE writable-characteristic transport for iOS printers.
- CP850 and Windows-1252 text printing.
- Proportional base64 image printing for 58 mm and 80 mm paper.
- Native operation serialization, pacing, backpressure, and stable error codes.
