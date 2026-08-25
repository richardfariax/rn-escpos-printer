# Architecture

`rn-escpos-printer` is a React Native TurboModule. Its public TypeScript API validates inputs and supplies stable defaults; all transport and image work runs natively so long print jobs do not block the JavaScript thread.

## Layers

1. **TypeScript API** — input validation, defaults, public types, and the stable package contract.
2. **TurboModule bridge** — maps promises to a single native operation queue.
3. **ESC/POS encoder** — produces initialization, code-page, 24-dot raster, feed, and partial-cut commands.
4. **Transport** — owns the active Bluetooth connection and sends bounded chunks with platform-specific flow control.

## Android

Android lists bonded devices and connects through the standard SPP UUID over RFCOMM. It attempts insecure and secure sockets using public Android APIs. Writes are split into 512-byte chunks with a small pacing interval to avoid overflowing low-cost printer buffers.

Image decoding and proportional scaling use `BitmapFactory` and `Bitmap.createScaledBitmap`. A 24-row working buffer keeps monochrome conversion bounded even for long receipts.

## iOS

iOS uses CoreBluetooth without a proprietary SDK. Scanning records named peripherals by stable UUID. Reconnection can use `retrievePeripherals(withIdentifiers:)`, so a previously persisted identifier does not require an initial scan.

After connecting, all services and characteristics are discovered. Writable characteristics matching common printer UUIDs receive priority. A characteristic with acknowledged writes is preferred; write-without-response is supported with `canSendWriteWithoutResponse` backpressure.

Images are rendered at scale 1 to exactly 384 or 576 pixels. This prevents Retina scale factors from stretching 58 mm and 80 mm output.

## Reliability invariants

- Native operations are serialized per module instance.
- A connection promise resolves only after the transport is writable.
- Every scan, connection, and write has a bounded timeout.
- A write failure or disconnect clears unusable transport state.
- Image dimensions and base64 input size are bounded before allocation.
- Cut commands are queued only after feed data has entered the native transport.
