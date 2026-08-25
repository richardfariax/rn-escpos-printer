import NativeRnEscposPrinter from './NativeRnEscposPrinter';
import type {
  ConnectOptions,
  GetPrintersOptions,
  PaperWidth,
  PrinterDevice,
  PrinterTransport,
  PrintImageOptions,
  PrintTextOptions,
  TextCodePage,
} from './types';

const DEFAULT_SCAN_DURATION_MS = 4_000;
const DEFAULT_CONNECT_TIMEOUT_MS = 12_000;
const DEFAULT_FEED_LINES = 5;
const DEFAULT_THRESHOLD = 160;
const DEFAULT_PAPER_WIDTH: PaperWidth = 80;
const DEFAULT_CODE_PAGE: TextCodePage = 'cp850';

const assertIntegerInRange = (
  value: number,
  name: string,
  min: number,
  max: number
): number => {
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new RangeError(
      `${name} must be an integer between ${min} and ${max}`
    );
  }

  return value;
};

const assertDuration = (value: number, name: string): number => {
  if (!Number.isFinite(value) || value < 1_000 || value > 60_000) {
    throw new RangeError(`${name} must be between 1000 and 60000 milliseconds`);
  }

  return value;
};

const assertNonEmpty = (value: string, name: string): string => {
  if (value.trim().length === 0) {
    throw new TypeError(`${name} must not be empty`);
  }

  return value;
};

const toPrinterDevice = (device: {
  id: string;
  name: string;
  address: string;
  transport: string;
  connected: boolean;
}): PrinterDevice => {
  if (device.transport !== 'bluetooth-classic' && device.transport !== 'ble') {
    throw new Error(
      `Unsupported native printer transport: ${device.transport}`
    );
  }
  const transport: PrinterTransport = device.transport;

  return { ...device, transport };
};

export const EscPosPrinter = Object.freeze({
  initialize(): Promise<void> {
    return NativeRnEscposPrinter.initialize();
  },

  async getPrinters(
    options: GetPrintersOptions = {}
  ): Promise<PrinterDevice[]> {
    const scanDurationMs = assertDuration(
      options.scanDurationMs ?? DEFAULT_SCAN_DURATION_MS,
      'scanDurationMs'
    );
    const devices = await NativeRnEscposPrinter.getPrinters(scanDurationMs);

    return devices.map(toPrinterDevice);
  },

  connect(
    printer: PrinterDevice | string,
    options: ConnectOptions = {}
  ): Promise<void> {
    const identifier = assertNonEmpty(
      typeof printer === 'string' ? printer : printer.id,
      'printer identifier'
    );
    const timeoutMs = assertDuration(
      options.timeoutMs ?? DEFAULT_CONNECT_TIMEOUT_MS,
      'timeoutMs'
    );

    return NativeRnEscposPrinter.connect(identifier, timeoutMs);
  },

  disconnect(): Promise<void> {
    return NativeRnEscposPrinter.disconnect();
  },

  isConnected(): Promise<boolean> {
    return NativeRnEscposPrinter.isConnected();
  },

  printText(text: string, options: PrintTextOptions = {}): Promise<void> {
    assertNonEmpty(text, 'text');
    const feedLines = assertIntegerInRange(
      options.feedLines ?? DEFAULT_FEED_LINES,
      'feedLines',
      0,
      10
    );

    return NativeRnEscposPrinter.printText(
      text,
      options.codePage ?? DEFAULT_CODE_PAGE,
      feedLines,
      options.cut ?? true
    );
  },

  printImageBase64(
    base64: string,
    options: PrintImageOptions = {}
  ): Promise<void> {
    assertNonEmpty(base64, 'base64');
    const paperWidth = options.paperWidth ?? DEFAULT_PAPER_WIDTH;
    if (paperWidth !== 58 && paperWidth !== 80) {
      throw new RangeError('paperWidth must be 58 or 80');
    }
    const threshold = assertIntegerInRange(
      options.threshold ?? DEFAULT_THRESHOLD,
      'threshold',
      0,
      255
    );
    const feedLines = assertIntegerInRange(
      options.feedLines ?? DEFAULT_FEED_LINES,
      'feedLines',
      0,
      10
    );

    return NativeRnEscposPrinter.printImageBase64(
      base64,
      paperWidth,
      threshold,
      feedLines,
      options.cut ?? true
    );
  },
});

export type {
  ConnectOptions,
  EscPosPrinterErrorCode,
  GetPrintersOptions,
  PaperWidth,
  PrinterDevice,
  PrinterTransport,
  PrintImageOptions,
  PrintTextOptions,
  TextCodePage,
} from './types';
