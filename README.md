# rn-escpos-printer

[![CI](https://github.com/richardfariax/rn-escpos-printer/actions/workflows/ci.yml/badge.svg)](https://github.com/richardfariax/rn-escpos-printer/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/rn-escpos-printer.svg)](https://www.npmjs.com/package/rn-escpos-printer)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](./LICENSE)

Reliable ESC/POS Bluetooth printing for React Native on iOS and Android. The library owns discovery, connection lifecycle, image rasterization, command generation, write serialization, and Bluetooth backpressure without a closed vendor SDK.

## Features

- Pure React Native TurboModule with autolinking
- Android Bluetooth Classic (RFCOMM/SPP) support
- iOS Bluetooth Low Energy support through writable GATT characteristics
- Paired-printer discovery on Android and timed BLE scanning on iOS
- Text printing with CP850 and Windows-1252 code pages
- Base64 image printing at the native 58 mm (384 px) or 80 mm (576 px) width
- Proportional image resizing without stretching
- Serialized native operations, connection timeouts, chunked writes, and BLE backpressure
- No Expo dependency and no proprietary printer SDK

## Supported versions

| Platform     | Requirement                                            | Transport                                          |
| ------------ | ------------------------------------------------------ | -------------------------------------------------- |
| React Native | 0.76 or newer                                          | New Architecture/TurboModule                       |
| Android      | API 24 or newer                                        | Bonded Bluetooth Classic device with SPP/RFCOMM    |
| iOS          | The minimum supported by the host React Native version | BLE peripheral with a writable GATT characteristic |

The printer must understand ESC/POS. iOS does not expose arbitrary Bluetooth Classic SPP devices, so the printer must offer BLE unless it is part of Apple's MFi program with a dedicated integration.

## Installation

```sh
npm install rn-escpos-printer
```

or:

```sh
yarn add rn-escpos-printer
```

Install CocoaPods after adding the package:

```sh
cd ios && pod install
```

This package contains native code. It works with bare React Native apps and Expo development builds/prebuilds, but it cannot run inside Expo Go.

## Native configuration

### Android

The library manifest declares the Bluetooth permissions. On Android 12 (API 31) and newer, request `BLUETOOTH_CONNECT` before calling the library:

```ts
import { PermissionsAndroid, Platform } from 'react-native';

if (Platform.OS === 'android' && Platform.Version >= 31) {
  await PermissionsAndroid.request(
    PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT
  );
}
```

Pair the printer in Android system settings before discovery. `getPrinters()` intentionally returns bonded devices only; v1 does not request location or perform broad Android device discovery.

### iOS

Add a Bluetooth usage description to `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth is used to connect to your receipt printer.</string>
```

iOS returns a stable peripheral UUID as the printer `id`. Persist that value if the app should reconnect without scanning after a restart.

## Quick start

```ts
import { EscPosPrinter, type PrinterDevice } from 'rn-escpos-printer';

await EscPosPrinter.initialize();

const printers: PrinterDevice[] = await EscPosPrinter.getPrinters({
  scanDurationMs: 4_000,
});

const printer = printers[0];
if (!printer) {
  throw new Error('No ESC/POS printer found');
}

await EscPosPrinter.connect(printer, { timeoutMs: 12_000 });

await EscPosPrinter.printText('Pedido 123\nTotal: R$ 42,90', {
  codePage: 'cp850',
  feedLines: 5,
  cut: true,
});

await EscPosPrinter.printImageBase64(receiptPngBase64, {
  paperWidth: 80,
  threshold: 160,
  feedLines: 5,
  cut: true,
});

await EscPosPrinter.disconnect();
```

`printImageBase64` accepts either a raw base64 payload or a `data:image/...;base64,...` URI.

## API

### `initialize(): Promise<void>`

Validates Bluetooth availability and permission. Call it before discovery or connection so configuration failures are reported early.

### `getPrinters(options?): Promise<PrinterDevice[]>`

On Android, returns bonded Bluetooth devices immediately. On iOS, scans for named BLE peripherals for `scanDurationMs` (default: 4000 ms).

```ts
type PrinterDevice = {
  id: string;
  name: string;
  address: string;
  transport: 'bluetooth-classic' | 'ble';
  connected: boolean;
};
```

### `connect(printer, options?): Promise<void>`

Accepts a `PrinterDevice` or its `id`. The default timeout is 12 seconds. The promise resolves only after Android opens the SPP socket or iOS discovers a writable characteristic.

### `disconnect(): Promise<void>`

Closes the active connection and clears native transport state.

### `isConnected(): Promise<boolean>`

Returns whether a usable native printer transport is active.

### `printText(text, options?): Promise<void>`

| Option      | Type                                  | Default   |
| ----------- | ------------------------------------- | --------- |
| `codePage`  | `'cp850' \| 'cp860' \| 'windows1252'` | `'cp850'` |
| `feedLines` | integer from 0 to 10                  | `5`       |
| `cut`       | `boolean`                             | `true`    |

The printer's configured character table must match the selected code page. CP850 remains the backward-compatible default. For Portuguese receipts, use CP860 when the printer supports the standard ESC/POS page 3 mapping:

```ts
await EscPosPrinter.printText('Não autorizado: ação e preço', {
  codePage: 'cp860',
});
```

Character-table support and page numbers can vary on non-Epson-compatible firmware, so validate the selected code page on every printer model used in production.

### `printImageBase64(base64, options?): Promise<void>`

| Option       | Type                  | Default |
| ------------ | --------------------- | ------- |
| `paperWidth` | `58 \| 80`            | `80`    |
| `threshold`  | integer from 0 to 255 | `160`   |
| `feedLines`  | integer from 0 to 10  | `5`     |
| `cut`        | `boolean`             | `true`  |

Images are decoded and rasterized natively. They are resized to 384 or 576 pixels with the original aspect ratio, converted to monochrome, and sent with the widely supported ESC `*` 24-dot bit-image command.

## Error handling

Rejected native promises expose one of these stable error codes through `error.code`:

- `ERR_BLUETOOTH_DISABLED`
- `ERR_BLUETOOTH_PERMISSION`
- `ERR_CONNECTION_FAILED`
- `ERR_CONNECTION_LOST`
- `ERR_CONNECTION_TIMEOUT`
- `ERR_INVALID_ARGUMENT`
- `ERR_INVALID_IMAGE`
- `ERR_NOT_CONNECTED`
- `ERR_PRINTER_NOT_FOUND`
- `ERR_SCAN_FAILED`
- `ERR_WRITE_FAILED`

```ts
try {
  await EscPosPrinter.connect(printer);
} catch (error) {
  const code =
    error instanceof Error && 'code' in error ? error.code : undefined;
  console.error(code, error);
}
```

## Scope of v1

Version 1 is intentionally limited to the production needs that motivated the package:

- Bluetooth transport only
- ESC/POS printers only
- Text and base64 images only
- 58 mm and 80 mm paper

USB, TCP/IP, QR codes, barcodes, cash drawers, printer status queries, and vendor-specific protocols are not part of v1.

## Printer compatibility

ESC/POS describes the print command language, while each printer also chooses a Bluetooth profile, GATT service, characteristic, buffer size, cutter, and character-table mapping. The library uses standard SPP on Android and dynamically discovers writable GATT characteristics on iOS, with conservative chunking and flow control.

For a production rollout, validate every printer model and firmware revision used by the business. When reporting a compatibility issue, include the platform, OS version, printer model, firmware, advertised BLE services/characteristics (iOS), and a minimal print payload.

## Development

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the local workflow and [docs/architecture.md](./docs/architecture.md) for implementation details.

```sh
yarn
yarn verify
```

## License

[MIT](./LICENSE) © HighSoft Sistemas
