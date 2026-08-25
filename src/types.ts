export type PaperWidth = 58 | 80;

export type TextCodePage = 'cp850' | 'cp860' | 'windows1252';

export type PrinterTransport = 'bluetooth-classic' | 'ble';

export type PrinterDevice = Readonly<{
  /** Stable identifier used by `connect` (MAC address on Android, UUID on iOS). */
  id: string;
  name: string;
  address: string;
  transport: PrinterTransport;
  connected: boolean;
}>;

export type GetPrintersOptions = Readonly<{
  /** BLE scan duration on iOS. Android returns already-paired devices. */
  scanDurationMs?: number;
}>;

export type ConnectOptions = Readonly<{
  timeoutMs?: number;
}>;

export type PrintTextOptions = Readonly<{
  codePage?: TextCodePage;
  feedLines?: number;
  cut?: boolean;
}>;

export type PrintImageOptions = Readonly<{
  paperWidth?: PaperWidth;
  /** Black/white cutoff from 0 to 255. Lower values print fewer black pixels. */
  threshold?: number;
  feedLines?: number;
  cut?: boolean;
}>;

export type EscPosPrinterErrorCode =
  | 'ERR_BLUETOOTH_DISABLED'
  | 'ERR_BLUETOOTH_PERMISSION'
  | 'ERR_CONNECTION_FAILED'
  | 'ERR_CONNECTION_LOST'
  | 'ERR_CONNECTION_TIMEOUT'
  | 'ERR_INVALID_ARGUMENT'
  | 'ERR_INVALID_IMAGE'
  | 'ERR_NOT_CONNECTED'
  | 'ERR_PRINTER_NOT_FOUND'
  | 'ERR_SCAN_FAILED'
  | 'ERR_WRITE_FAILED';
